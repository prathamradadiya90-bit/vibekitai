import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'core/config/app_config.dart';
import 'core/providers/app_providers.dart';
import 'core/router/app_router.dart';
import 'core/services/admob_service.dart';
import 'core/storage/local_database.dart';
import 'core/storage/preferences_service.dart';
import 'core/services/crash_reporting_service.dart';
import 'core/theme/app_theme.dart';
import 'core/widgets/responsive_app_shell.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize privacy-preserving crash and error reporting
  CrashReportingService.instance.initialize();

  // Initialize persistent preferences
  final preferencesService = await PreferencesService.create();

  // Initialize local database (with SharedPreferences web persistence fallback)
  final localDatabase = LocalDatabase(prefs: preferencesService);
  await localDatabase.init();

  // Check initial onboarding state
  final onboardingDone = preferencesService.isOnboardingCompleted();

  // Initialize AdMob service instance (initialized asynchronously after first frame)
  final adMobService = AdMobService();

  runApp(
    ProviderScope(
      overrides: [
        preferencesServiceProvider.overrideWithValue(preferencesService),
        localDatabaseProvider.overrideWithValue(localDatabase),
        adMobServiceProvider.overrideWithValue(adMobService),
      ],
      child: VibeKitApp(initialOnboardingDone: onboardingDone),
    ),
  );
}

class VibeKitApp extends ConsumerStatefulWidget {
  final bool initialOnboardingDone;

  const VibeKitApp({super.key, required this.initialOnboardingDone});

  @override
  ConsumerState<VibeKitApp> createState() => _VibeKitAppState();
}

class _VibeKitAppState extends ConsumerState<VibeKitApp> {
  static final GlobalKey<ScaffoldMessengerState> _scaffoldMessengerKey =
      GlobalKey<ScaffoldMessengerState>();
  static const MethodChannel _shareChannel =
      MethodChannel('com.vibekit.vibekit_ai/share_intent');

  late final _router =
      createRouter(initialOnboardingDone: widget.initialOnboardingDone);

  @override
  void initState() {
    super.initState();
    // Initialize Billing & AdMob asynchronously after first frame to avoid startup jank
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final adMob = ref.read(adMobServiceProvider);
      final billing = ref.read(billingServiceProvider);

      billing.onProStatusChanged = (isPro) {
        if (!mounted) return;
        ref.read(quotaProvider.notifier).setPro(isPro);
        adMob.updateProStatus(isPro);
      };
      billing.onCreditsGranted = () {
        if (!mounted) return;
        ref.read(quotaProvider.notifier).refresh();
      };
      billing.onBillingMessage = (message) {
        _scaffoldMessengerKey.currentState?.showSnackBar(
          SnackBar(
            content: Text(message),
            behavior: SnackBarBehavior.floating,
            duration: const Duration(seconds: 4),
          ),
        );
      };

      // Asynchronous non-blocking SDK initializations
      billing.init();
      adMob.init();

      // Consume incoming Android ACTION_SEND text share intents (cold start & warm start)
      _initAndroidShareTarget();
    });
  }

  Future<void> _initAndroidShareTarget() async {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) return;
    _shareChannel.setMethodCallHandler((call) async {
      if (call.method == 'onSharedText' && call.arguments is String) {
        _openSharedTextInStudio(call.arguments as String);
      }
    });
    try {
      final initialText = await _shareChannel.invokeMethod<String>('getInitialSharedText');
      if (initialText != null && initialText.trim().isNotEmpty) {
        _openSharedTextInStudio(initialText);
      }
    } catch (_) {
      // Ignored cleanly in test / non-Android plugin contexts
    }
  }

  void _openSharedTextInStudio(String sharedText) {
    final trimmed = sharedText.trim();
    if (trimmed.isEmpty) return;
    ref.read(preferencesServiceProvider).setOnboardingCompleted(true);
    _router.go('/studio?tab=reply&prompt=${Uri.encodeComponent(trimmed)}');
  }

  @override
  Widget build(BuildContext context) {
    final themeMode = ref.watch(themeModeProvider);

    return MaterialApp.router(
      title: AppConfig.appName,
      scaffoldMessengerKey: _scaffoldMessengerKey,
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: themeMode,
      routerConfig: _router,
      builder: (context, child) {
        return ResponsiveAppShell(child: child ?? const SizedBox.shrink());
      },
    );
  }
}
