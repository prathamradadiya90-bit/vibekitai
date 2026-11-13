import 'package:flutter/material.dart';
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

  // Initialize SQLite local database
  final localDatabase = LocalDatabase();
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
  late final _router =
      createRouter(initialOnboardingDone: widget.initialOnboardingDone);

  @override
  void initState() {
    super.initState();
    // Initialize Billing & AdMob asynchronously after first frame to avoid startup jank
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final adMob = ref.read(adMobServiceProvider);
      final billing = ref.read(billingServiceProvider);

      billing.onProStatusChanged = (isPro) {
        ref.read(quotaProvider.notifier).setPro(isPro);
        adMob.updateProStatus(isPro);
      };
      billing.onCreditsGranted = () {
        ref.read(quotaProvider.notifier).refresh();
      };

      // Asynchronous non-blocking SDK initializations
      billing.init();
      adMob.init();
    });
  }

  @override
  Widget build(BuildContext context) {
    final themeMode = ref.watch(themeModeProvider);

    return MaterialApp.router(
      title: AppConfig.appName,
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
