import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../constants/app_durations.dart';
import '../../features/onboarding/onboarding_screen.dart';
import '../../features/home/home_screen.dart';
import '../../features/reply_studio/reply_studio_screen.dart';
import '../../features/caption_lab/caption_lab_screen.dart';
import '../../features/card_maker/card_maker_screen.dart';
import '../../features/challenge/challenge_screen.dart';
import '../../features/history/history_screen.dart';
import '../../features/settings/settings_screen.dart';
import '../../features/settings/privacy_policy_screen.dart';
import '../../features/settings/terms_of_service_screen.dart';
import '../../features/settings/ai_disclosure_screen.dart';
import '../../features/paywall/paywall_screen.dart';
import '../../features/streaks/presentation/streak_screen.dart';
import '../../features/bio_lab/presentation/bio_lab_screen.dart';
import '../../features/achievements/presentation/achievements_screen.dart';
import '../../features/settings/help_support_screen.dart';
import '../../features/vibe_check/vibe_check_screen.dart';
import '../../features/studio/studio_screen.dart';
import '../../features/aura_radar/presentation/aura_radar_screen.dart';

enum _RouteTransitionKind { tabCrossFade, drillSlide, modalRise }

CustomTransitionPage<void> _buildTransitionPage({
  required GoRouterState state,
  required Widget child,
  _RouteTransitionKind kind = _RouteTransitionKind.drillSlide,
}) {
  final duration = switch (kind) {
    _RouteTransitionKind.tabCrossFade => AppDurations.fast,
    _RouteTransitionKind.drillSlide => AppDurations.normal,
    _RouteTransitionKind.modalRise => const Duration(milliseconds: 300),
  };

  return CustomTransitionPage<void>(
    key: state.pageKey,
    transitionDuration: duration,
    reverseTransitionDuration: AppDurations.fast,
    child: child,
    transitionsBuilder: (context, animation, secondaryAnimation, pageChild) {
      if (MediaQuery.disableAnimationsOf(context)) {
        return pageChild;
      }
      final curved = CurvedAnimation(
        parent: animation,
        curve: AppCurves.espressoPour,
        reverseCurve: Curves.easeInQuad,
      );
      if (kind == _RouteTransitionKind.tabCrossFade) {
        return FadeTransition(opacity: curved, child: pageChild);
      }
      final beginOffset = kind == _RouteTransitionKind.modalRise
          ? const Offset(0.0, 0.08)
          : const Offset(0.05, 0.0);
      return FadeTransition(
        opacity: curved,
        child: SlideTransition(
          position: Tween<Offset>(
            begin: beginOffset,
            end: Offset.zero,
          ).animate(curved),
          child: pageChild,
        ),
      );
    },
  );
}

GoRouter createRouter({required bool initialOnboardingDone}) {
  return GoRouter(
    initialLocation: initialOnboardingDone ? '/home' : '/onboarding',
    routes: [
      GoRoute(
        path: '/onboarding',
        pageBuilder: (context, state) => _buildTransitionPage(
          state: state,
          kind: _RouteTransitionKind.tabCrossFade,
          child: const OnboardingScreen(),
        ),
      ),
      GoRoute(
        path: '/home',
        pageBuilder: (context, state) => _buildTransitionPage(
          state: state,
          kind: _RouteTransitionKind.tabCrossFade,
          child: const HomeScreen(),
        ),
      ),
      GoRoute(
        path: '/studio',
        pageBuilder: (context, state) {
          final tab = state.uri.queryParameters['tab'];
          final prompt = state.uri.queryParameters['prompt'] ??
              state.uri.queryParameters['initialPrompt'];
          final option = state.uri.queryParameters['option'] ??
              state.uri.queryParameters['initialTone'];
          return _buildTransitionPage(
            state: state,
            kind: _RouteTransitionKind.tabCrossFade,
            child: StudioScreen(
              initialTabId: tab,
              initialPrompt: prompt,
              initialOption: option,
            ),
          );
        },
      ),
      GoRoute(
        path: '/reply-studio',
        pageBuilder: (context, state) {
          final prompt = state.uri.queryParameters['initialPrompt'];
          final tone = state.uri.queryParameters['initialTone'];
          return _buildTransitionPage(
            state: state,
            child: ReplyStudioScreen(initialPrompt: prompt, initialTone: tone),
          );
        },
      ),
      GoRoute(
        path: '/caption-lab',
        pageBuilder: (context, state) {
          final prompt = state.uri.queryParameters['initialPrompt'];
          final tone = state.uri.queryParameters['initialTone'];
          return _buildTransitionPage(
            state: state,
            child: CaptionLabScreen(initialPrompt: prompt, initialTone: tone),
          );
        },
      ),
      GoRoute(
        path: '/card-maker',
        pageBuilder: (context, state) {
          String? prompt = state.uri.queryParameters['initialPrompt'];
          if (prompt == null && state.extra != null) {
            if (state.extra is String) {
              prompt = state.extra as String;
            } else if (state.extra is Map &&
                (state.extra as Map).containsKey('text')) {
              prompt = (state.extra as Map)['text']?.toString();
            }
          }
          return _buildTransitionPage(
            state: state,
            kind: _RouteTransitionKind.tabCrossFade,
            child: CardMakerScreen(initialText: prompt),
          );
        },
      ),
      GoRoute(
        path: '/bio-lab',
        pageBuilder: (context, state) => _buildTransitionPage(
          state: state,
          child: const BioLabScreen(),
        ),
      ),
      GoRoute(
        path: '/vibe-check',
        pageBuilder: (context, state) {
          final text = state.uri.queryParameters['text'] ??
              (state.extra is Map
                  ? (state.extra as Map)['text']?.toString()
                  : null);
          return _buildTransitionPage(
            state: state,
            child: VibeCheckScreen(initialText: text),
          );
        },
      ),
      GoRoute(
        path: '/challenge',
        pageBuilder: (context, state) => _buildTransitionPage(
          state: state,
          child: const ChallengeScreen(),
        ),
      ),
      GoRoute(
        path: '/history',
        pageBuilder: (context, state) => _buildTransitionPage(
          state: state,
          child: const HistoryScreen(),
        ),
      ),
      GoRoute(
        path: '/settings',
        pageBuilder: (context, state) => _buildTransitionPage(
          state: state,
          kind: _RouteTransitionKind.tabCrossFade,
          child: const SettingsScreen(),
        ),
      ),
      GoRoute(
        path: '/paywall',
        pageBuilder: (context, state) => _buildTransitionPage(
          state: state,
          kind: _RouteTransitionKind.modalRise,
          child: const PaywallScreen(),
        ),
      ),
      GoRoute(
        path: '/streaks',
        pageBuilder: (context, state) => _buildTransitionPage(
          state: state,
          kind: _RouteTransitionKind.modalRise,
          child: const StreakScreen(),
        ),
      ),
      GoRoute(
        path: '/achievements',
        pageBuilder: (context, state) => _buildTransitionPage(
          state: state,
          child: const AchievementsScreen(),
        ),
      ),
      GoRoute(
        path: '/help-support',
        pageBuilder: (context, state) => _buildTransitionPage(
          state: state,
          child: const HelpSupportScreen(),
        ),
      ),
      GoRoute(
        path: '/privacy-policy',
        pageBuilder: (context, state) => _buildTransitionPage(
          state: state,
          child: const PrivacyPolicyScreen(),
        ),
      ),
      GoRoute(
        path: '/terms-of-service',
        pageBuilder: (context, state) => _buildTransitionPage(
          state: state,
          child: const TermsOfServiceScreen(),
        ),
      ),
      GoRoute(
        path: '/ai-disclosure',
        pageBuilder: (context, state) => _buildTransitionPage(
          state: state,
          child: const AiDisclosureScreen(),
        ),
      ),
      GoRoute(
        path: '/aura-radar',
        pageBuilder: (context, state) => _buildTransitionPage(
          state: state,
          child: const AuraRadarScreen(),
        ),
      ),
    ],
    errorBuilder: (context, state) => Scaffold(
      appBar: AppBar(title: const Text('Page Not Found')),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.explore_off_rounded, size: 48),
              const SizedBox(height: 12),
              Text(
                'Route not found: ${state.uri.path}',
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              ElevatedButton.icon(
                onPressed: () => context.go('/home'),
                icon: const Icon(Icons.home_rounded, size: 18),
                label: const Text('Back to Home'),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}
