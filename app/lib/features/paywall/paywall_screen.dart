import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:in_app_purchase_android/in_app_purchase_android.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../core/config/app_config.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_durations.dart';
import '../../core/constants/app_typography.dart';
import '../../core/providers/app_providers.dart';
import '../../core/services/analytics_service.dart';
import '../../core/widgets/motion_widgets.dart';

class PaywallScreen extends ConsumerStatefulWidget {
  const PaywallScreen({super.key});

  @override
  ConsumerState<PaywallScreen> createState() => _PaywallScreenState();
}

class _PaywallScreenState extends ConsumerState<PaywallScreen> {
  String _selectedPlan = AppConfig.proYearlyId; // default to yearly best-value
  bool _isPurchasing = false;

  final List<Map<String, dynamic>> _proFeatures = [
    {
      'icon': Icons.block_rounded,
      'title': '100% Ad-Free Experience',
      'desc': 'Zero banner or interstitial interruptions anywhere in the app.',
    },
    {
      'icon': Icons.bolt_rounded,
      'title': '200 High-Priority AI Credits / Month',
      'desc': 'Generous allowance for replies, captions, and reel hooks.',
    },
    {
      'icon': Icons.branding_watermark_rounded,
      'title': 'Watermark-Free Card Exports',
      'desc': 'Export crisp, ultra-clean meme and quote cards without branding.',
    },
    {
      'icon': Icons.palette_rounded,
      'title': 'All Premium Designer Templates',
      'desc': 'Unlock exclusive Sapphire, Nebula, Aura, and modern styles.',
    },
    {
      'icon': Icons.speed_rounded,
      'title': 'Priority AI Edge Processing',
      'desc': 'Near-zero latency generation through dedicated compute nodes.',
    },
  ];

  @override
  void initState() {
    super.initState();
    AnalyticsService.instance.logPaywallView('paywall_screen');
  }

  Future<void> _handlePurchase() async {
    AnalyticsService.instance.logPaywallCtaTap(_selectedPlan);
    final billing = ref.read(billingServiceProvider);
    if (!billing.isAvailable) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Google Play Billing is unavailable on this device.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    ProductDetails? targetProduct;
    for (final p in billing.products) {
      if (p.id == _selectedPlan) {
        targetProduct = p;
        break;
      }
    }

    if (targetProduct == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Product $_selectedPlan is pending Play Store activation. Please ensure billing products are published.',
          ),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    setState(() => _isPurchasing = true);
    final isConsumable = targetProduct.id == AppConfig.creditPack50Id;
    final success = await billing.buyProduct(targetProduct, isConsumable: isConsumable);
    if (!mounted) return;
    setState(() => _isPurchasing = false);

    if (!success) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Purchase could not be initiated.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Future<void> _handleRestore() async {
    final billing = ref.read(billingServiceProvider);
    setState(() => _isPurchasing = true);
    await billing.restorePurchases();
    if (!mounted) return;
    setState(() => _isPurchasing = false);

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Purchase restore requested. Reconciling entitlements...'),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Future<void> _openPlaySubscriptions() async {
    final uri = Uri.parse(AppConfig.playSubscriptionsUrl);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  @override
  Widget build(BuildContext context) {
    final billing = ref.watch(billingServiceProvider);
    final quota = ref.watch(quotaProvider);

    // Resolve live localized prices & verified trial phases from Play Billing when loaded.
    String yearlyPrice = 'Annual auto-renewing plan (view price in Google Play)';
    String monthlyPrice = 'Monthly auto-renewing plan (view price in Google Play)';
    String lifetimePrice = 'One-time non-consumable purchase (view price in Google Play)';
    String creditPackPrice = 'One-time 50 Credits pack (view price in Google Play)';
    bool hasYearlyFreeTrial = false;
    double? yearlyRecurringRaw;
    double? monthlyRecurringRaw;

    for (final prod in billing.products) {
      if (prod.id == AppConfig.proYearlyId) {
        String formattedRecurring = prod.price;
        yearlyRecurringRaw = prod.rawPrice;
        if (prod is GooglePlayProductDetails && prod.subscriptionIndex != null) {
          final offers = prod.productDetails.subscriptionOfferDetails;
          if (offers != null && prod.subscriptionIndex! < offers.length) {
            final phases = offers[prod.subscriptionIndex!].pricingPhases;
            if (phases.isNotEmpty) {
              formattedRecurring = phases.last.formattedPrice;
              yearlyRecurringRaw = phases.last.priceAmountMicros / 1000000.0;
              hasYearlyFreeTrial =
                  phases.length > 1 && phases.first.priceAmountMicros == 0;
            }
          }
        }
        yearlyPrice = hasYearlyFreeTrial
            ? '$formattedRecurring / year (includes introductory free trial)'
            : '$formattedRecurring / year • Auto-renews annually';
      } else if (prod.id == AppConfig.proMonthlyId) {
        monthlyPrice = '${prod.price} / month • Auto-renews monthly';
        monthlyRecurringRaw = prod.rawPrice;
      } else if (prod.id == AppConfig.proLifetimeId) {
        lifetimePrice = '${prod.price} • One-time payment';
      } else if (prod.id == AppConfig.creditPack50Id) {
        creditPackPrice = '${prod.price} • 50 AI Credits';
      }
    }

    String? yearlySavingsLabel;
    if (yearlyRecurringRaw != null &&
        monthlyRecurringRaw != null &&
        monthlyRecurringRaw > 0 &&
        yearlyRecurringRaw < monthlyRecurringRaw * 12) {
      final pct =
          ((1 - (yearlyRecurringRaw / (monthlyRecurringRaw * 12))) * 100).round();
      if (pct >= 5) {
        yearlySavingsLabel = 'Save $pct%';
      }
    }

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final scaffoldBg = isDark ? AppColors.backgroundDark : AppColors.backgroundLight;
    final textCol = isDark ? Colors.white : AppColors.textPrimaryLight;
    final textSecCol = isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight;
    final textMutedCol = isDark ? AppColors.textMutedDark : AppColors.textMutedLight;
    final cardBg = isDark ? AppColors.surfaceDark : AppColors.surfaceCardLight;
    final borderCol = isDark ? AppColors.borderDark : AppColors.borderLight;

    return Scaffold(
      backgroundColor: scaffoldBg,
      appBar: AppBar(
        title: Text(
          'VibeKit VIP & Pro',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight,
          ),
        ),
        leading: IconButton(
          icon: Icon(
            Icons.arrow_back_ios_new,
            size: 20,
            color: isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight,
          ),
          onPressed: () {
            if (context.canPop()) {
              context.pop();
            } else {
              context.go('/home');
            }
          },
        ),
        actions: [
          TextButton(
            onPressed: _isPurchasing ? null : _handleRestore,
            child: Text(
              'Restore',
              style: TextStyle(color: isDark ? AppColors.accentWarm : AppColors.primary),
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Hero Banner
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(22),
                decoration: BoxDecoration(
                  gradient: AppColors.primaryGradient,
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: kIsWeb
                      ? null
                      : [
                          BoxShadow(
                            color: AppColors.primary.withOpacity(0.35),
                            blurRadius: 28,
                            offset: const Offset(0, 8),
                          ),
                        ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Text(
                            'PRO CREATOR ACCESS',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 1.1,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      'Upgrade to VIP\nCreator Status',
                      style: TextStyle(
                        fontSize: 26,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                        height: 1.2,
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Zero ads, no watermarks, full template access & 200 monthly AI generations.',
                      style: TextStyle(fontSize: 13, color: Colors.white70),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 24),

              // Feature Highlights
              Text('What is Included in Pro & VIP',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: textCol)),
              const SizedBox(height: 12),
              ..._proFeatures.map((feat) {
                return Padding(
                  padding: const EdgeInsets.only(bottom: 14),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: AppColors.primary.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Icon(
                          feat['icon'] as IconData,
                          size: 20,
                          color: isDark ? AppColors.accentWarm : AppColors.primary,
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              feat['title'] as String,
                              style: TextStyle(
                                  fontWeight: FontWeight.bold, fontSize: 14, color: textCol),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              feat['desc'] as String,
                              style: TextStyle(
                                  color: textSecCol,
                                  fontSize: 12),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                );
              }),

              const SizedBox(height: 16),

              // Plan Selection Cards
              Text('Choose Your Pass',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: textCol)),
              const SizedBox(height: 12),

              // 1. Yearly Plan (Best Value)
              _buildPlanCard(
                planId: AppConfig.proYearlyId,
                title: 'Annual Creator Pass',
                subtitle: yearlyPrice,
                badgeText: hasYearlyFreeTrial
                    ? 'BEST VALUE • FREE TRIAL'
                    : 'BEST VALUE • ANNUAL',
                badgeGradient: AppColors.accentGradient,
                savings: yearlySavingsLabel,
                isDark: isDark,
              ),

              const SizedBox(height: 10),

              // 2. Lifetime VIP Pass (Pay once, own forever)
              _buildPlanCard(
                planId: AppConfig.proLifetimeId,
                title: 'Lifetime VIP Pass',
                subtitle: lifetimePrice,
                badgeText: 'ONE-TIME PURCHASE • OWN FOREVER',
                badgeGradient: const LinearGradient(
                  colors: [Color(0xFFF59E0B), Color(0xFFD97706)],
                ),
                savings: 'No Subscriptions',
                isDark: isDark,
              ),

              const SizedBox(height: 10),

              // 3. Monthly Plan
              _buildPlanCard(
                planId: AppConfig.proMonthlyId,
                title: 'Monthly Pass',
                subtitle: monthlyPrice,
                badgeText: null,
                savings: null,
                isDark: isDark,
              ),

              // 4. Consumable Credit Pack Top-Up (only when the server has packs enabled)
              if (billing.creditPacksEnabled) ...[
                const SizedBox(height: 10),
                _buildPlanCard(
                  planId: AppConfig.creditPack50Id,
                  title: '50 Credits Top-Up Pack',
                  subtitle: creditPackPrice,
                  badgeText: 'INSTANT BOOST',
                  savings: null,
                  isDark: isDark,
                ),
              ],

              const SizedBox(height: 24),

              // Plan Comparison Table
              Text('Tier Comparison Matrix',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: textCol)),
              const SizedBox(height: 12),
              Container(
                decoration: BoxDecoration(
                  color: cardBg,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: borderCol),
                ),
                child: Column(
                  children: [
                    _buildComparisonRow('Feature', 'Free', 'Pro', 'Lifetime VIP', isHeader: true, isDark: isDark),
                    Divider(height: 1, color: borderCol),
                    _buildComparisonRow('AI Generations', '3 / day', '200 / mo', '200 / mo', isDark: isDark),
                    Divider(height: 1, color: borderCol),
                    _buildComparisonRow('Ad-Free Clean UI', 'No', 'Yes', 'Yes', isDark: isDark),
                    Divider(height: 1, color: borderCol),
                    _buildComparisonRow('Watermark-Free Cards', 'No', 'Yes', 'Yes', isDark: isDark),
                    Divider(height: 1, color: borderCol),
                    _buildComparisonRow('Exclusive Templates', 'Basic', 'All', 'All + Future', isDark: isDark),
                    Divider(height: 1, color: borderCol),
                    _buildComparisonRow('Priority Edge Queue', 'Standard', 'High', 'Highest VIP', isDark: isDark),
                  ],
                ),
              ),

              const SizedBox(height: 24),

              // Social Proof & Creator Testimonials
              Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: cardBg,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: borderCol),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Text('💬', style: TextStyle(fontSize: 20)),
                        const SizedBox(width: 8),
                        Text('What Creators Say',
                            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: textCol)),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Text(
                      '"VibeKit Pro transformed my social workflow. The reply tones and aesthetic watermark-free cards saved me hours every week."',
                      style: TextStyle(
                        fontSize: 13,
                        fontStyle: FontStyle.italic,
                        color: isDark ? Colors.white.withOpacity(0.8) : AppColors.textPrimaryLight,
                        height: 1.4,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      '— VibeKit Creator Community',
                      style: TextStyle(
                        fontSize: 11,
                        color: isDark ? AppColors.accentWarm : AppColors.primary,
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 24),

              // Legal Terms & Google Play Cancellation
              Center(
                child: Column(
                  children: [
                    Text(
                      'Payment is charged to your Google Play account upon purchase confirmation. Auto-renewing plans (Monthly/Annual) renew automatically unless canceled at least 24 hours before the current period ends. Lifetime VIP and Credit Packs are one-time purchases.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                          fontSize: 11,
                          color: textMutedCol,
                          height: 1.4),
                    ),
                    const SizedBox(height: 8),
                    TextButton(
                      onPressed: _openPlaySubscriptions,
                      child: const Text(
                        'Manage or Cancel on Google Play',
                        style: TextStyle(
                            fontSize: 12, decoration: TextDecoration.underline),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        TextButton(
                          onPressed: () => context.push('/privacy-policy'),
                          child: Text(
                            'Privacy Policy',
                            style: TextStyle(
                              fontSize: 11,
                              color: textSecCol,
                              decoration: TextDecoration.underline,
                            ),
                          ),
                        ),
                        Text('•', style: TextStyle(color: textMutedCol)),
                        TextButton(
                          onPressed: () => context.push('/terms-of-service'),
                          child: Text(
                            'Terms of Service',
                            style: TextStyle(
                              fontSize: 11,
                              color: textSecCol,
                              decoration: TextDecoration.underline,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
      bottomNavigationBar: Container(
        padding: const EdgeInsets.fromLTRB(20, 10, 20, 14),
        decoration: BoxDecoration(
          color: isDark ? AppColors.surfaceDark : AppColors.surfaceLight,
          border: Border(
            top: BorderSide(color: borderCol, width: 1),
          ),
        ),
        child: SafeArea(
          top: false,
          child: TactileScale(
            enabled: !_isPurchasing,
            child: SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton(
                onPressed: _isPurchasing
                    ? null
                    : (quota.isPro && _selectedPlan != AppConfig.creditPack50Id
                        ? _openPlaySubscriptions
                        : _handlePurchase),
                child: _isPurchasing
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white),
                      )
                    : Text(
                        quota.isPro && _selectedPlan != AppConfig.creditPack50Id
                            ? 'Manage Active Subscription'
                            : _selectedPlan == AppConfig.proLifetimeId
                                ? 'Get Lifetime VIP Access'
                                : _selectedPlan == AppConfig.creditPack50Id
                                    ? 'Purchase 50 AI Credits'
                                    : hasYearlyFreeTrial &&
                                            _selectedPlan == AppConfig.proYearlyId
                                        ? 'Start Free Trial'
                                        : 'Subscribe Now',
                        style: const TextStyle(
                            fontSize: 16, fontWeight: FontWeight.bold),
                      ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPlanCard({
    required String planId,
    required String title,
    required String subtitle,
    required String? badgeText,
    Gradient? badgeGradient,
    String? savings,
    required bool isDark,
  }) {
    final isSelected = _selectedPlan == planId;
    final planCardBg = isSelected
        ? (isDark ? AppColors.surfaceElevatedDark : const Color(0xFFFFF7ED))
        : (isDark ? AppColors.surfaceCardDark : AppColors.surfaceCardLight);
    final planBorder = isSelected
        ? AppColors.primary
        : (isDark ? AppColors.borderDark : AppColors.borderLight);
    final radioCol = isSelected
        ? AppColors.primary
        : (isDark ? AppColors.textMutedDark : AppColors.textMutedLight);
    final titleCol = isDark ? Colors.white : AppColors.textPrimaryLight;
    final subCol = isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight;

    return TactileScale(
      child: InkWell(
        onTap: () => setState(() => _selectedPlan = planId),
        borderRadius: BorderRadius.circular(16),
        child: AnimatedContainer(
          duration: AppDurations.fast,
          curve: AppCurves.espressoPour,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: planCardBg,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: planBorder,
              width: isSelected ? 2 : 1,
            ),
            boxShadow: (isSelected && !kIsWeb)
                ? [
                    BoxShadow(
                      color: AppColors.primary.withOpacity(0.18),
                      blurRadius: 14,
                      offset: const Offset(0, 4),
                    ),
                  ]
                : null,
          ),
          child: Row(
            children: [
              Icon(
                isSelected
                    ? Icons.radio_button_checked_rounded
                    : Icons.radio_button_off_rounded,
                color: radioCol,
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Wrap(
                      crossAxisAlignment: WrapCrossAlignment.center,
                      spacing: 8,
                      runSpacing: 4,
                      children: [
                        Text(
                          title,
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: titleCol),
                        ),
                        if (badgeText != null)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              gradient: badgeGradient ?? AppColors.accentGradient,
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              badgeText,
                              style: const TextStyle(
                                fontSize: 9,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 3),
                    Text(
                      subtitle,
                      style: TextStyle(
                        color: subCol,
                        fontSize: 13,
                        fontFeatures: AppTypography.tabularFigures,
                      ),
                    ),
                  ],
                ),
              ),
              if (savings != null)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppColors.success.withValues(alpha: isDark ? 0.22 : 0.12),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    savings,
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      color: isDark ? const Color(0xFF69F0AE) : AppColors.success,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildComparisonRow(
    String col1,
    String col2,
    String col3,
    String col4, {
    bool isHeader = false,
    required bool isDark,
  }) {
    final activeAccent = isDark ? AppColors.accentWarm : AppColors.primary;
    final titleCol = isHeader
        ? activeAccent
        : (isDark ? Colors.white : AppColors.textPrimaryLight);
    final freeCol = isHeader
        ? (isDark ? Colors.white70 : AppColors.textSecondaryLight)
        : (isDark ? Colors.white60 : AppColors.textMutedLight);
    final proCol = isHeader
        ? (isDark ? Colors.white70 : AppColors.textSecondaryLight)
        : activeAccent;
    final vipCol = isHeader
        ? (isDark ? Colors.white70 : AppColors.textSecondaryLight)
        : (isDark ? AppColors.amberGold : const Color(0xFFB45309));

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      child: Row(
        children: [
          Expanded(
            flex: 4,
            child: Text(
              col1,
              style: TextStyle(
                fontSize: 12,
                fontWeight: isHeader ? FontWeight.bold : FontWeight.w600,
                color: titleCol,
              ),
            ),
          ),
          Expanded(
            flex: 2,
            child: Text(
              col2,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 11,
                fontWeight: isHeader ? FontWeight.bold : FontWeight.normal,
                color: freeCol,
              ),
            ),
          ),
          Expanded(
            flex: 2,
            child: Text(
              col3,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 11,
                fontWeight: isHeader ? FontWeight.bold : FontWeight.bold,
                color: proCol,
              ),
            ),
          ),
          Expanded(
            flex: 3,
            child: Text(
              col4,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 11,
                fontWeight: isHeader ? FontWeight.bold : FontWeight.bold,
                color: vipCol,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
