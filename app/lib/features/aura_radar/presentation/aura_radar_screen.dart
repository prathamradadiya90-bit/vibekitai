import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/services/achievement_service.dart';
import '../../../core/services/share_service.dart';
import '../../streaks/providers/streak_provider.dart';

class AuraRadarScreen extends ConsumerStatefulWidget {
  const AuraRadarScreen({super.key});

  @override
  ConsumerState<AuraRadarScreen> createState() => _AuraRadarScreenState();
}

class _AuraRadarScreenState extends ConsumerState<AuraRadarScreen> {
  int _currentQuestionIndex = 0;
  final Map<String, int> _scores = {
    'savage': 0,
    'rizz': 0,
    'unbothered': 0,
    'golden': 0,
    'mystic': 0,
  };
  bool _quizCompleted = false;

  final List<Map<String, dynamic>> _questions = [
    {
      'question': 'Someone texts a dry ‘k’ after you wrote 3 paragraphs. You…',
      'options': [
        {
          'text': 'Match energy: Send ‘.’ or leave on read',
          'type': 'savage',
          'points': 3,
        },
        {
          'text': '“Did your keyboard run out of letters?”',
          'type': 'rizz',
          'points': 3,
        },
        {
          'text': '“All good! Let me know when you\'re free.”',
          'type': 'unbothered',
          'points': 3,
        },
        {
          'text': 'Send a funny meme to defuse the dryness',
          'type': 'golden',
          'points': 3,
        },
      ],
    },
    {
      'question': 'Your crush drops a low-effort selfie with no caption. Your move?',
      'options': [
        {
          'text': '“You owe me a coffee for distracting me like this”',
          'type': 'rizz',
          'points': 3,
        },
        {
          'text': 'Roast their camera angle in DMs',
          'type': 'savage',
          'points': 3,
        },
        {
          'text': 'Double tap, no reply, keep the mystery alive',
          'type': 'mystic',
          'points': 3,
        },
        {
          'text': 'Hype them up with 100% wholesome energy',
          'type': 'golden',
          'points': 3,
        },
      ],
    },
    {
      'question': 'Your social battery is at 0% and you need to cancel tonight. You text:',
      'options': [
        {
          'text': '“Completely drained from work today, let\'s reschedule this weekend!”',
          'type': 'unbothered',
          'points': 3,
        },
        {
          'text': '“My bed took me hostage. Rescheduling is non-negotiable.”',
          'type': 'rizz',
          'points': 3,
        },
        {
          'text': '“I’m ghosting reality tonight. Catch you next week.”',
          'type': 'mystic',
          'points': 3,
        },
        {
          'text': '“So sorry to miss out! I will make it up to you with pizza!”',
          'type': 'golden',
          'points': 3,
        },
      ],
    },
    {
      'question': 'Your ultimate texting superpower is:',
      'options': [
        {
          'text': 'Mic-drop comebacks that shut down disrespect',
          'type': 'savage',
          'points': 3,
        },
        {
          'text': 'Magnetic banter that makes anyone smile',
          'type': 'rizz',
          'points': 3,
        },
        {
          'text': 'Zero overthinking, calm composure under pressure',
          'type': 'unbothered',
          'points': 3,
        },
        {
          'text': 'Deep intrigue & quiet independence',
          'type': 'mystic',
          'points': 3,
        },
      ],
    },
  ];

  Map<String, dynamic> _computeArchetype() {
    String topKey = 'savage';
    int maxPts = -1;
    _scores.forEach((key, val) {
      if (val > maxPts) {
        maxPts = val;
        topKey = key;
      }
    });

    switch (topKey) {
      case 'rizz':
        return {
          'title': 'The Magnetic Rizzler',
          'glyph': '🥂',
          'badge': 'CHARM ARCHETYPE',
          'tagline': 'Effortless banter, magnetic confidence, and main-character energy.',
          'stats': [
            {'label': 'Banter & Charm', 'val': 0.98},
            {'label': 'Confidence', 'val': 0.94},
            {'label': 'Timing', 'val': 0.88},
            {'label': 'Awkwardness', 'val': 0.08},
          ],
          'cardQuote': '“Too charming to leave on delivered, too confident to care.” ✨',
        };
      case 'unbothered':
        return {
          'title': 'The Unbothered CEO',
          'glyph': '💎',
          'badge': 'EXECUTIVE CALM',
          'tagline': 'Clear boundaries, calm presence, and zero patience for low-effort drama.',
          'stats': [
            {'label': 'Composure', 'val': 0.97},
            {'label': 'Directness', 'val': 0.92},
            {'label': 'Overthinking', 'val': 0.05},
            {'label': 'Peace of Mind', 'val': 0.99},
          ],
          'cardQuote': '“Peace over drama, clarity over games, silence over low effort.” ☕',
        };
      case 'golden':
        return {
          'title': 'The Golden Retriever',
          'glyph': '🧸',
          'badge': 'WHOLESOME VIBE',
          'tagline': 'Warm, loyal, uplifting, and makes everyone feel valued in 1 text.',
          'stats': [
            {'label': 'Warmth', 'val': 0.99},
            {'label': 'Loyalty', 'val': 0.95},
            {'label': 'Hype Factor', 'val': 0.92},
            {'label': 'Sarcasm', 'val': 0.15},
          ],
          'cardQuote': '“Protect your peace and hype your friends unconditionally.” 💛',
        };
      case 'mystic':
        return {
          'title': 'The Mystic Ghost',
          'glyph': '🕵️',
          'badge': 'INTRIGUE ARCHETYPE',
          'tagline': 'Deep thoughts, selective replies, and an effortless aura of mystery.',
          'stats': [
            {'label': 'Intrigue', 'val': 0.96},
            {'label': 'Independence', 'val': 0.93},
            {'label': 'Availability', 'val': 0.12},
            {'label': 'Observation', 'val': 0.95},
          ],
          'cardQuote': '“Not ignoring, just maintaining an aura of quiet mystery.” 🌙',
        };
      case 'savage':
      default:
        return {
          'title': 'The Savage Virtuoso',
          'glyph': '⚡',
          'badge': 'MIC-DROP ARCHETYPE',
          'tagline': 'Lightning-fast comebacks, unfiltered truth, and unmatched wit.',
          'stats': [
            {'label': 'Wit & Sarcasm', 'val': 0.98},
            {'label': 'Roast Precision', 'val': 0.95},
            {'label': 'Filter', 'val': 0.14},
            {'label': 'Fearlessness', 'val': 0.92},
          ],
          'cardQuote': '“I would match your energy, but my standards are higher.” 🔥',
        };
    }
  }

  void _selectOption(String type, int points) {
    _scores[type] = (_scores[type] ?? 0) + points;
    if (_currentQuestionIndex < _questions.length - 1) {
      setState(() => _currentQuestionIndex++);
    } else {
      setState(() => _quizCompleted = true);
      // Award XP & trigger achievements
      ref.read(streakProvider.notifier).recordAction('aura_radar');
      ref.read(achievementServiceProvider).checkAndUnlockAchievements(context: context);
    }
  }

  void _resetQuiz() {
    setState(() {
      _currentQuestionIndex = 0;
      _scores.updateAll((key, val) => 0);
      _quizCompleted = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? AppColors.backgroundDark : AppColors.backgroundLight,
      appBar: AppBar(
        title: Text(
          'Vibe Radar & Aura',
          style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 18),
        ),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded, size: 20),
            tooltip: 'Retake Quiz',
            onPressed: _resetQuiz,
          ),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 600),
            child: _quizCompleted ? _buildResultsView(isDark) : _buildQuizView(isDark),
          ),
        ),
      ),
    );
  }

  Widget _buildQuizView(bool isDark) {
    final currentQ = _questions[_currentQuestionIndex];
    final options = currentQ['options'] as List<Map<String, dynamic>>;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Progress header
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: isDark ? AppColors.surfaceElevatedDark : AppColors.surfaceElevatedLight,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: isDark ? AppColors.borderDark : AppColors.borderLight),
              ),
              child: Text(
                'QUESTION ${_currentQuestionIndex + 1} OF ${_questions.length}',
                style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.primary),
              ),
            ),
            Text(
              '+50 XP',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: isDark ? AppColors.accentWarm : AppColors.primary,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),

        // Progress bar
        ClipRRect(
          borderRadius: BorderRadius.circular(6),
          child: LinearProgressIndicator(
            value: (_currentQuestionIndex + 1) / _questions.length,
            backgroundColor: isDark ? AppColors.surfaceCardDark : AppColors.surfaceCardLight,
            valueColor: const AlwaysStoppedAnimation<Color>(AppColors.primary),
            minHeight: 6,
          ),
        ),
        const SizedBox(height: 28),

        // Question card
        Container(
          padding: const EdgeInsets.all(22),
          decoration: BoxDecoration(
            color: isDark ? AppColors.surfaceCardDark : AppColors.surfaceCardLight,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: isDark ? AppColors.borderDark : AppColors.borderLight),
          ),
          child: Text(
            currentQ['question'] as String,
            style: GoogleFonts.outfit(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              height: 1.35,
              color: isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight,
            ),
          ),
        ),
        const SizedBox(height: 20),

        // Options
        ...options.map((opt) {
          return Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: InkWell(
              onTap: () => _selectOption(opt['type'] as String, opt['points'] as int),
              borderRadius: BorderRadius.circular(16),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
                decoration: BoxDecoration(
                  color: isDark ? AppColors.surfaceElevatedDark : Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: isDark ? AppColors.borderDark : AppColors.borderLight,
                    width: 1.2,
                  ),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        opt['text'] as String,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                          color: isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight,
                          height: 1.35,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Icon(
                      Icons.arrow_forward_ios_rounded,
                      size: 14,
                      color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
                    ),
                  ],
                ),
              ),
            ),
          );
        }),
      ],
    );
  }

  Widget _buildResultsView(bool isDark) {
    final res = _computeArchetype();
    final stats = res['stats'] as List<Map<String, dynamic>>;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Hero Aura Card
        Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: isDark
                  ? [const Color(0xFF2A170C), const Color(0xFF190F08)]
                  : [const Color(0xFFFBF4ED), const Color(0xFFF3E7DA)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
              color: isDark ? AppColors.primary.withOpacity(0.5) : AppColors.primaryLight,
              width: 1.5,
            ),
          ),
          child: Column(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.primary.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  res['badge'] as String,
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.2,
                    color: AppColors.primary,
                  ),
                ),
              ),
              const SizedBox(height: 14),
              Text(
                res['glyph'] as String,
                style: const TextStyle(fontSize: 48),
              ),
              const SizedBox(height: 8),
              Text(
                res['title'] as String,
                textAlign: TextAlign.center,
                style: GoogleFonts.outfit(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                res['tagline'] as String,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 13,
                  color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
                  height: 1.4,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),

        // Vibe Radar Stats
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: isDark ? AppColors.surfaceCardDark : AppColors.surfaceCardLight,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: isDark ? AppColors.borderDark : AppColors.borderLight),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Vibe Radar Analysis',
                style: GoogleFonts.outfit(
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                  color: isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight,
                ),
              ),
              const SizedBox(height: 14),
              ...stats.map((st) {
                final double val = st['val'] as double;
                final int pct = (val * 100).toInt();
                return Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            st['label'] as String,
                            style: TextStyle(
                              fontSize: 13,
                              color: isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight,
                            ),
                          ),
                          Text(
                            '$pct%',
                            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.primary),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: LinearProgressIndicator(
                          value: val,
                          backgroundColor: isDark ? Colors.white10 : Colors.black12,
                          valueColor: const AlwaysStoppedAnimation<Color>(AppColors.primary),
                          minHeight: 6,
                        ),
                      ),
                    ],
                  ),
                );
              }),
            ],
          ),
        ),
        const SizedBox(height: 24),

        // Action Buttons
        ElevatedButton.icon(
          onPressed: () {
            context.push('/card-maker', extra: {'text': res['cardQuote']});
          },
          style: ElevatedButton.styleFrom(
            backgroundColor: isDark ? AppColors.accentWarm : AppColors.primary,
            foregroundColor: isDark ? const Color(0xFF140E0A) : Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 14),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          ),
          icon: const Icon(Icons.palette_outlined, size: 20),
          label: const Text(
            '🎨 Design My Aura Card',
            style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
          ),
        ),
        const SizedBox(height: 12),

        OutlinedButton.icon(
          onPressed: () {
            ShareService.shareText(
              'My VibeKit AI Archetype is ${res['title']}! ${res['tagline']}\n\nQuote: ${res['cardQuote']}\n\nDiscover yours on VibeKit AI!',
            );
          },
          style: OutlinedButton.styleFrom(
            padding: const EdgeInsets.symmetric(vertical: 14),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            side: BorderSide(color: isDark ? AppColors.borderDark : AppColors.borderLight),
          ),
          icon: const Icon(Icons.share_outlined, size: 18),
          label: Text(
            'Share My Aura Result',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight,
            ),
          ),
        ),
        const SizedBox(height: 12),

        TextButton(
          onPressed: _resetQuiz,
          child: const Text('Retake Quiz', style: TextStyle(color: AppColors.primary)),
        ),
      ],
    );
  }
}
