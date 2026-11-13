import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/constants/app_colors.dart';
import '../../core/providers/app_providers.dart';
import '../../core/services/achievement_service.dart';
import '../../models/challenge_model.dart';

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
    // Record challenge accepted/solved progress
    final prefs = ref.read(preferencesServiceProvider);
    await prefs.incrementChallengesSolved();
    if (mounted) {
      await ref.read(achievementServiceProvider).checkAndUnlockAchievements(context: context);
    }

    if (!mounted) return;
    if (challenge.targetFeature == 'reply') {
      context.push(
        '/studio?tab=reply&prompt=${Uri.encodeComponent(challenge.prompt)}&option=${challenge.tone}',
      );
    } else if (challenge.targetFeature == 'caption') {
      context.push(
        '/studio?tab=caption&prompt=${Uri.encodeComponent(challenge.prompt)}&option=${challenge.tone}',
      );
    } else {
      context.push(
        '/card-maker?initialPrompt=${Uri.encodeComponent(challenge.prompt)}',
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundDark,
      appBar: AppBar(
        title: const Text('Creative Challenges', style: TextStyle(fontWeight: FontWeight.bold)),
      ),
      body: SafeArea(
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
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
                      color: AppColors.surfaceCardDark,
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(color: AppColors.borderDark),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: color.withOpacity(0.15),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Row(
                                children: [
                                  Icon(icon, size: 14, color: color),
                                  const SizedBox(width: 6),
                                  Text(
                                    item.tag.toUpperCase(),
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.bold,
                                      color: color,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Text(
                              'Tone: ${item.tone}',
                              style: const TextStyle(
                                  fontSize: 12, color: AppColors.textMutedDark),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Text(
                          item.title,
                          style: const TextStyle(
                              fontSize: 16, fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          item.prompt,
                          style: const TextStyle(
                              fontSize: 13,
                              color: AppColors.textSecondaryDark,
                              height: 1.4),
                        ),
                        const SizedBox(height: 14),
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton.icon(
                            onPressed: () => _startChallenge(item),
                            icon:
                                const Icon(Icons.play_arrow_rounded, size: 18),
                            label: const Text('Accept Challenge (+120 XP)',
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
