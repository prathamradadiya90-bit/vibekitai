import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
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

GoRouter createRouter({required bool initialOnboardingDone}) {
  return GoRouter(
    initialLocation: initialOnboardingDone ? '/home' : '/onboarding',
    routes: [
      GoRoute(
        path: '/onboarding',
        builder: (context, state) => const OnboardingScreen(),
      ),
      GoRoute(
        path: '/home',
        builder: (context, state) => const HomeScreen(),
      ),
      GoRoute(
        path: '/studio',
        builder: (context, state) {
          final tab = state.uri.queryParameters['tab'];
          final prompt = state.uri.queryParameters['prompt'] ?? state.uri.queryParameters['initialPrompt'];
          final option = state.uri.queryParameters['option'] ?? state.uri.queryParameters['initialTone'];
          return StudioScreen(
            initialTabId: tab,
            initialPrompt: prompt,
            initialOption: option,
          );
        },
      ),
      GoRoute(
        path: '/reply-studio',
        builder: (context, state) {
          final prompt = state.uri.queryParameters['initialPrompt'];
          final tone = state.uri.queryParameters['initialTone'];
          return ReplyStudioScreen(initialPrompt: prompt, initialTone: tone);
        },
      ),
      GoRoute(
        path: '/caption-lab',
        builder: (context, state) {
          final prompt = state.uri.queryParameters['initialPrompt'];
          final tone = state.uri.queryParameters['initialTone'];
          return CaptionLabScreen(initialPrompt: prompt, initialTone: tone);
        },
      ),
      GoRoute(
        path: '/card-maker',
        builder: (context, state) {
          String? prompt = state.uri.queryParameters['initialPrompt'];
          if (prompt == null && state.extra != null) {
            if (state.extra is String) {
              prompt = state.extra as String;
            } else if (state.extra is Map && (state.extra as Map).containsKey('text')) {
              prompt = (state.extra as Map)['text']?.toString();
            }
          }
          return CardMakerScreen(initialText: prompt);
        },
      ),
      GoRoute(
        path: '/bio-lab',
        builder: (context, state) => const BioLabScreen(),
      ),
      GoRoute(
        path: '/vibe-check',
        builder: (context, state) {
          final text = state.uri.queryParameters['text'] ??
              (state.extra is Map ? (state.extra as Map)['text']?.toString() : null);
          return VibeCheckScreen(initialText: text);
        },
      ),
      GoRoute(
        path: '/challenge',
        builder: (context, state) => const ChallengeScreen(),
      ),
      GoRoute(
        path: '/history',
        builder: (context, state) => const HistoryScreen(),
      ),
      GoRoute(
        path: '/settings',
        builder: (context, state) => const SettingsScreen(),
      ),
      GoRoute(
        path: '/paywall',
        builder: (context, state) => const PaywallScreen(),
      ),
      GoRoute(
        path: '/streaks',
        builder: (context, state) => const StreakScreen(),
      ),
      GoRoute(
        path: '/achievements',
        builder: (context, state) => const AchievementsScreen(),
      ),
      GoRoute(
        path: '/help-support',
        builder: (context, state) => const HelpSupportScreen(),
      ),
      GoRoute(
        path: '/privacy-policy',
        builder: (context, state) => const PrivacyPolicyScreen(),
      ),
      GoRoute(
        path: '/terms-of-service',
        builder: (context, state) => const TermsOfServiceScreen(),
      ),
      GoRoute(
        path: '/ai-disclosure',
        builder: (context, state) => const AiDisclosureScreen(),
      ),
      GoRoute(
        path: '/aura-radar',
        builder: (context, state) => const AuraRadarScreen(),
      ),
    ],
    errorBuilder: (context, state) => Scaffold(
      body: Center(
        child: Text('Page not found: ${state.uri}'),
      ),
    ),
  );
}
