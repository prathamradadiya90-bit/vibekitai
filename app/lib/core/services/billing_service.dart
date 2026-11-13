import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:in_app_purchase_android/in_app_purchase_android.dart';
import '../config/app_config.dart';
import '../network/api_client.dart';
import '../network/api_exception.dart';

enum SubscriptionState {
  inactive,
  active,
  pending,
  inGracePeriod,
  onHold,
  error,
}

class BillingService {
  late final InAppPurchase? _iap;
  final ApiClient _apiClient;
  StreamSubscription<List<PurchaseDetails>>? _subscription;
  List<ProductDetails> _products = [];
  bool _isAvailable = false;
  SubscriptionState _subscriptionState = SubscriptionState.inactive;

  Function(bool isPro)? onProStatusChanged;
  Function(SubscriptionState state)? onSubscriptionStateChanged;
  Function(String message)? onBillingMessage;
  VoidCallback? onCreditsGranted;

  /// Mirrors the server's `feature_flags.credit_packs`; packs are hidden and blocked when off,
  /// so users can't pay for something the backend would refuse to credit.
  bool _creditPacksEnabled = false;
  bool get creditPacksEnabled => _creditPacksEnabled;

  BillingService(this._apiClient) {
    if (!kIsWeb) {
      try {
        _iap = InAppPurchase.instance;
      } catch (_) {
        _iap = null;
      }
    } else {
      _iap = null;
    }
  }

  List<ProductDetails> get products => _products;
  bool get isAvailable => _isAvailable;
  SubscriptionState get subscriptionState => _subscriptionState;

  Future<void> init() async {
    if (kIsWeb || _iap == null) {
      debugPrint('BillingService: Play Billing unavailable on web.');
      return;
    }
    try {
      _isAvailable = await _iap.isAvailable();
      if (!_isAvailable) {
        debugPrint('BillingService: Play Billing unavailable on this device.');
        return;
      }

      // Listen to purchase update stream
      _subscription = _iap.purchaseStream.listen(
        _handlePurchaseUpdates,
        onDone: () => _subscription?.cancel(),
        onError: (error) => debugPrint('Billing purchase stream error: $error'),
      );

      await Future.wait([loadProducts(), _loadFeatureFlags()]);
      // Restore past purchases on startup
      await restorePurchases();
    } catch (e) {
      debugPrint('BillingService: Initialization error: $e');
    }
  }

  Future<void> _loadFeatureFlags() async {
    final config = await _apiClient.getConfig();
    final flags = config['feature_flags'];
    _creditPacksEnabled = flags is Map && flags['credit_packs'] == true;
  }

  Future<void> loadProducts() async {
    if (!_isAvailable || _iap == null) return;
    try {
      final Set<String> ids = {
        AppConfig.proWeeklyId,
        AppConfig.proMonthlyId,
        AppConfig.proYearlyId,
        AppConfig.proLifetimeId,
        AppConfig.creditPack50Id,
      };

      final response = await _iap.queryProductDetails(ids);
      if (response.notFoundIDs.isNotEmpty) {
        debugPrint(
            'Billing products not found in store: ${response.notFoundIDs}');
      }
      _products = response.productDetails;
    } catch (e) {
      debugPrint('Error loading billing products: $e');
    }
  }

  Future<bool> buyProduct(ProductDetails product, {bool isConsumable = false}) async {
    if (_iap == null) return false;
    try {
      final purchaseParam = PurchaseParam(productDetails: product);
      if (isConsumable || product.id == AppConfig.creditPack50Id) {
        if (product.id == AppConfig.creditPack50Id && !_creditPacksEnabled) {
          onBillingMessage?.call('Credit packs are not available right now.');
          return false;
        }
        // autoConsume: false — the plugin would otherwise consume the pack before our
        // server has credited it. We consume manually after the backend confirms.
        return await _iap.buyConsumable(
          purchaseParam: purchaseParam,
          autoConsume: false,
        );
      }
      return await _iap.buyNonConsumable(purchaseParam: purchaseParam);
    } catch (e) {
      debugPrint('Error starting purchase: $e');
      return false;
    }
  }

  Future<void> restorePurchases() async {
    if (_iap == null) return;
    try {
      await _iap.restorePurchases();
    } catch (e) {
      debugPrint('Error restoring purchases: $e');
    }
  }

  Future<void> _handlePurchaseUpdates(
      List<PurchaseDetails> purchaseDetailsList) async {
    for (final purchase in purchaseDetailsList) {
      if (purchase.status == PurchaseStatus.pending) {
        debugPrint('Purchase pending for: ${purchase.productID}');
        _subscriptionState = SubscriptionState.pending;
        onSubscriptionStateChanged?.call(SubscriptionState.pending);
        onBillingMessage?.call(
            'Payment is pending approval. Your Pro access will activate automatically once confirmed.');
      } else if (purchase.status == PurchaseStatus.error) {
        debugPrint('Purchase failed with error: ${purchase.error}');
        _subscriptionState = SubscriptionState.error;
        onSubscriptionStateChanged?.call(SubscriptionState.error);
        if (purchase.pendingCompletePurchase && _iap != null) {
          await _iap.completePurchase(purchase);
        }
      } else if (purchase.status == PurchaseStatus.purchased ||
          purchase.status == PurchaseStatus.restored) {
        // Only finish (acknowledge/consume) once the backend has given a definitive
        // answer. On transient failures the purchase stays open, Play redelivers it via
        // restorePurchases() on next launch, and we retry — so the user never loses it.
        final settled = purchase.productID == AppConfig.creditPack50Id
            ? await _settleCreditPack(purchase)
            : await _settleEntitlement(purchase);

        if (settled && _iap != null) {
          if (purchase.productID == AppConfig.creditPack50Id) {
            await _consume(purchase);
          } else if (purchase.pendingCompletePurchase) {
            await _iap.completePurchase(purchase);
          }
        }
      }
    }
  }

  /// Returns true when the backend gave a final verdict (granted or permanently rejected).
  Future<bool> _settleEntitlement(PurchaseDetails purchase) async {
    try {
      final verification = await _apiClient.verifyPurchase(
        productId: purchase.productID,
        purchaseToken: purchase.verificationData.serverVerificationData,
        orderId: purchase.purchaseID ?? '',
      );
      if (verification['is_verified'] == true) {
        _subscriptionState = SubscriptionState.active;
        onSubscriptionStateChanged?.call(SubscriptionState.active);
        onProStatusChanged?.call(true);
      } else {
        _subscriptionState = SubscriptionState.inactive;
        onSubscriptionStateChanged?.call(SubscriptionState.inactive);
        onProStatusChanged?.call(false);
      }
      return true;
    } catch (e) {
      debugPrint('Backend purchase verification failed: $e');
      return _isPermanentRejection(e);
    }
  }

  Future<bool> _settleCreditPack(PurchaseDetails purchase) async {
    try {
      final packResult = await _apiClient.verifyCreditPack(
        productId: purchase.productID,
        purchaseToken: purchase.verificationData.serverVerificationData,
        orderId: purchase.purchaseID ?? '',
      );
      if (packResult['success'] == true) {
        final granted = (packResult['credits_granted'] as num?)?.toInt() ?? 0;
        if (granted > 0) {
          onBillingMessage?.call('🎉 $granted AI Credits successfully added to your balance!');
          onCreditsGranted?.call();
        }
        return true;
      }
      return false;
    } catch (e) {
      debugPrint('Credit pack verification failed, will retry on next restore: $e');
      onBillingMessage?.call(
          'We couldn\'t confirm your credit pack yet. It will be added automatically — you won\'t be charged twice.');
      return _isPermanentRejection(e);
    }
  }

  /// 400 = token invalid / wrong product; 402 = canceled / not purchased.
  /// Everything else (network, 403 feature flag, 5xx, 503 Play unavailable) is retryable.
  bool _isPermanentRejection(Object e) =>
      e is ApiException && (e.statusCode == 400 || e.statusCode == 402);

  Future<void> _consume(PurchaseDetails purchase) async {
    if (_iap == null) return;
    try {
      if (defaultTargetPlatform == TargetPlatform.android) {
        final addition =
            _iap.getPlatformAddition<InAppPurchaseAndroidPlatformAddition>();
        await addition.consumePurchase(purchase);
      } else if (purchase.pendingCompletePurchase) {
        await _iap.completePurchase(purchase);
      }
    } catch (e) {
      debugPrint('Failed to consume credit pack: $e');
    }
  }

  void dispose() {
    _subscription?.cancel();
  }
}
