import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/constants/app_colors.dart';
import '../../core/providers/app_providers.dart';
import '../../core/services/achievement_service.dart';
import '../../models/challenge_model.dart';
import '../streaks/providers/streak_provider.dart';

class ChallengeScreen extends ConsumerStatefulWidget {
  const ChallengeScreen({super.key});

  @override
  ConsumerState<ChallengeScreen> createState() => _ChallengeScreenState();
}

class _ChallengeScreenState extends ConsumerState<ChallengeScreen> {
  List<ChallengeModel> _challenges = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadChallenges();
  }

  Future<void> _loadChallenges() async {
    try {
      final jsonString =
          await rootBundle.loadString('assets/data/challenges.json');
      final list = jsonDecode(jsonString) as List<dynamic>;
      _challenges = list
          .map((e) => ChallengeModel.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (e) {
      debugPrint('Error loading challenges: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _startChallenge(ChallengeModel challenge) async {
    // Record challenge accepted/solved progress & streak XP
    final prefs = ref.read(preferencesServiceProvider);
    await prefs.incrementChallengesSolved();
    ref.read(streakProvider.notifier).recordAction('challenge');
    if (mounted) {
      await ref.read(achievementServiceProvider).checkAndUnlockAchievements(context: context);
    }

    if (!mounted) return;
    if (challenge.targetFeature == 'reply') {
      context.push(
        '/studio?tab=reply&prompt=${Uri.encodeComponent(challenge.prompt)}&option=${Uri.encodeComponent(challenge.tone)}',
      );
    } else if (challenge.targetFeature == 'caption') {
      context.push(
        '/studio?tab=caption&prompt=${Uri.encodeComponent(challenge.prompt)}&option=${Uri.encodeComponent(challenge.tone)}',
      );
    } else {
      context.push(
        '/card-maker?initialPrompt=${Uri.encodeComponent(challenge.prompt)}',
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final scaffoldBg = isDark ? AppColors.backgroundDark : AppColors.backgroundLight;
    final cardBg = isDark ? AppColors.surfaceCardDark : AppColors.surfaceCardLight;
    final borderCol = isDark ? AppColors.borderDark : AppColors.borderLight;
    final titleCol = isDark ? Colors.white : AppColors.textPrimaryLight;
    final subtitleCol = isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight;
    final toneMutedCol = isDark ? AppColors.textMutedDark : AppColors.textSecondaryLight;

    return Scaffold(
      backgroundColor: scaffoldBg,
      appBar: AppBar(
        title: Text(
          'Creative Challenges',
          style: TextStyle(fontWeight: FontWeight.bold, color: titleCol),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_new, color: titleCol, size: 20),
          onPressed: () {
            if (context.canPop()) {
              context.pop();
            } else {
              context.go('/home');
            }
          },
        ),
      ),
      body: SafeArea(
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : _challenges.isEmpty
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(28),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.explore_off_rounded, size: 48, color: subtitleCol),
                          const SizedBox(height: 12),
                          Text(
                            'No Challenges Loaded',
                            style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: titleCol),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            'Tap retry to reload today\'s creative challenge prompts.',
                            textAlign: TextAlign.center,
                            style: TextStyle(fontSize: 13, color: subtitleCol),
                          ),
                          const SizedBox(height: 16),
                          ElevatedButton.icon(
                            onPressed: () {
                              setState(() => _isLoading = true);
                              _loadChallenges();
                            },
                            icon: const Icon(Icons.refresh_rounded, size: 18),
                            label: const Text('Retry'),
                          ),
                        ],
                      ),
                    ),
                  )
                : ListView.separated(
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.all(20),
                itemCount: _challenges.length,
                separatorBuilder: (_, __) => const SizedBox(height: 14),
                itemBuilder: (context, index) {
                  final item = _challenges[index];
                  final icon = item.targetFeature == 'reply'
                      ? Icons.chat_bubble_outline_rounded
                      : item.targetFeature == 'caption'
                          ? Icons.auto_awesome_rounded
                          : Icons.brush_outlined;
                  final color = item.targetFeature == 'reply'
                      ? AppColors.primary
                      : item.targetFeature == 'caption'
                          ? AppColors.accent
                          : AppColors.accentPink;

                  return Container(
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
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Flexible(
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 8, vertical: 3),
                                decoration: BoxDecoration(
                                  color: color.withOpacity(0.15),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(icon, size: 14, color: color),
                                    const SizedBox(width: 6),
                                    Flexible(
                                      child: Text(
                                        item.tag.toUpperCase(),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: TextStyle(
                                          fontSize: 11,
                                          fontWeight: FontWeight.bold,
                                          color: color,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              'Tone: ${item.tone}',
                              style: TextStyle(
                                  fontSize: 12, color: toneMutedCol),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Text(
                          item.title,
                          style: TextStyle(
                              fontSize: 16, fontWeight: FontWeight.bold, color: titleCol),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          item.prompt,
                          style: TextStyle(
                              fontSize: 13,
                              color: subtitleCol,
                              height: 1.4),
                        ),
                        const SizedBox(height: 14),
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton.icon(
                            onPressed: () => _startChallenge(item),
                            icon:
                                const Icon(Icons.play_arrow_rounded, size: 18),
                            label: const Text('Accept Challenge (+25 XP)',
                                style: TextStyle(
                                    fontSize: 13, fontWeight: FontWeight.bold)),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: color,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 10),
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
      ),
    );
  }
}
