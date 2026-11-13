import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/constants/app_colors.dart';
import '../../core/providers/app_providers.dart';

class OnboardingScreen extends ConsumerStatefulWidget {
  const OnboardingScreen({super.key});

  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends ConsumerState<OnboardingScreen> {
  final PageController _pageController = PageController();
  int _currentPage = 0;

  // Interactive tone for Slide 0
  String _selectedTone = 'Savage';

  final Map<String, String> _repliesByTone = {
    'Savage': "Not ignoring, just maintaining an aura of mystery. ☕",
    'Flirty': "For you? My schedule just magically cleared right up. 😉",
    'Witty': "Depends... does this conversation come with a warm latte? ⚡",
    'Boss': "Reviewing priority requests now. Let's schedule for 8 PM. 📈",
  };

  Future<void> _completeOnboarding() async {
    final prefs = ref.read(preferencesServiceProvider);
    await prefs.setOnboardingCompleted(true);
    if (mounted) {
      context.go('/home');
    }
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundDark,
      body: SafeArea(
        child: Column(
          children: [
            // Top Bar: Brand Pill + Skip Action
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          AppColors.primary.withOpacity(0.35),
                          AppColors.accent.withOpacity(0.18),
                        ],
                      ),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: AppColors.accent.withOpacity(0.4),
                        width: 1,
                      ),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.coffee_rounded,
                          color: AppColors.accent,
                          size: 15,
                        ),
                        SizedBox(width: 6),
                        Text(
                          'VIBEKIT AI',
                          style: TextStyle(
                            color: AppColors.textPrimaryDark,
                            fontWeight: FontWeight.w800,
                            fontSize: 11,
                            letterSpacing: 1.4,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (_currentPage < 3)
                    TextButton(
                      onPressed: _completeOnboarding,
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      ),
                      child: Text(
                        'Skip',
                        style: TextStyle(
                          color: AppColors.accentWarm.withOpacity(0.8),
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                ],
              ),
            ),

            // Main Interactive Carousel
            Expanded(
              child: PageView(
                controller: _pageController,
                onPageChanged: (index) => setState(() => _currentPage = index),
                children: [
                  _buildReplyStudioSlide(),
                  _buildCaptionLabSlide(),
                  _buildCardMakerSlide(),
                  _buildPrivacySlide(),
                ],
              ),
            ),

            // Bottom Actions & Animated Progress Bar
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Dynamic Capsule Page Indicator
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: List.generate(
                      4,
                      (index) => AnimatedContainer(
                        duration: const Duration(milliseconds: 280),
                        curve: Curves.easeOutCubic,
                        margin: const EdgeInsets.symmetric(horizontal: 4),
                        width: _currentPage == index ? 28 : 8,
                        height: 7,
                        decoration: BoxDecoration(
                          gradient: _currentPage == index
                              ? AppColors.primaryGradient
                              : null,
                          color: _currentPage == index
                              ? null
                              : AppColors.borderDark,
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(height: 20),

                  // High-End Pill CTA Button
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 400),
                    child: Container(
                      width: double.infinity,
                      height: 54,
                      decoration: BoxDecoration(
                        gradient: AppColors.primaryGradient,
                        borderRadius: BorderRadius.circular(28),
                        border: Border.all(
                          color: AppColors.accent.withOpacity(0.4),
                          width: 1.2,
                        ),
                      ),
                      child: Material(
                        color: Colors.transparent,
                        child: InkWell(
                          borderRadius: BorderRadius.circular(28),
                          onTap: () {
                            if (_currentPage < 3) {
                              _pageController.nextPage(
                                duration: const Duration(milliseconds: 320),
                                curve: Curves.easeInOutCubic,
                              );
                            } else {
                              _completeOnboarding();
                            }
                          },
                          child: Center(
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(
                                  _currentPage < 3 ? 'Continue' : 'Get Started — Free',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                    letterSpacing: 0.3,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Icon(
                                  _currentPage < 3
                                      ? Icons.arrow_forward_rounded
                                      : Icons.auto_awesome_rounded,
                                  color: AppColors.accentWarm,
                                  size: 18,
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),

                  if (_currentPage == 3) ...[
                    const SizedBox(height: 10),
                    const Text(
                      'Free to use • No credit card required',
                      style: TextStyle(
                        color: AppColors.textMutedDark,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // -------------------------------------------------------------
  // SLIDE 0: Reply Studio (Interactive Chat Simulation)
  // -------------------------------------------------------------
  Widget _buildReplyStudioSlide() {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        children: [
          const SizedBox(height: 8),

          // Badge
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
            decoration: BoxDecoration(
              color: AppColors.primary.withOpacity(0.2),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: AppColors.accent.withOpacity(0.4)),
            ),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.chat_bubble_outline_rounded, color: AppColors.accentWarm, size: 13),
                SizedBox(width: 6),
                Text(
                  'Reply Studio',
                  style: TextStyle(
                    color: AppColors.accentWarm,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 12),

          const Text(
            'Clever Replies in Seconds',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w800,
              color: AppColors.textPrimaryDark,
              letterSpacing: -0.5,
            ),
          ),

          const SizedBox(height: 8),

          const Text(
            'Turn dry, awkward or tricky texts into witty, flirty, or savage responses with one tap.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 13,
              color: AppColors.textSecondaryDark,
              height: 1.4,
            ),
          ),

          const SizedBox(height: 20),

          // Interactive Phone Chat Card
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.surfaceDark,
              borderRadius: BorderRadius.circular(24),
              border: Border.all(
                color: AppColors.borderDark,
                width: 1.2,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Mini Chat Header
                Row(
                  children: [
                    Container(
                      width: 32,
                      height: 32,
                      decoration: const BoxDecoration(
                        gradient: AppColors.accentGradient,
                        shape: BoxShape.circle,
                      ),
                      child: const Center(
                        child: Text(
                          'S',
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Sarah 💫',
                            style: TextStyle(
                              color: AppColors.textPrimaryDark,
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                            ),
                          ),
                          Text(
                            'Active now',
                            style: TextStyle(
                              color: AppColors.accentWarm,
                              fontSize: 10,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: AppColors.surfaceElevatedDark,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Text(
                        '10:42 PM',
                        style: TextStyle(color: AppColors.textMutedDark, fontSize: 10),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 16),

                // Inbound Message Bubble
                Align(
                  alignment: Alignment.centerLeft,
                  child: Container(
                    constraints: const BoxConstraints(maxWidth: 280),
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    decoration: BoxDecoration(
                      color: AppColors.surfaceCardDark,
                      borderRadius: const BorderRadius.only(
                        topLeft: Radius.circular(18),
                        topRight: Radius.circular(18),
                        bottomRight: Radius.circular(18),
                        bottomLeft: Radius.circular(4),
                      ),
                      border: Border.all(color: AppColors.borderDark),
                    ),
                    child: const Text(
                      'Leaving me on read again? 👀 What are you doing tonight?',
                      style: TextStyle(
                        color: AppColors.textPrimaryDark,
                        fontSize: 13,
                        height: 1.35,
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 14),

                // Live Tone Selector Chips
                Row(
                  children: [
                    const Text(
                      'Select Tone:',
                      style: TextStyle(
                        color: AppColors.textMutedDark,
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(
                          children: ['Savage', 'Flirty', 'Witty', 'Boss'].map((tone) {
                            final isSelected = _selectedTone == tone;
                            return GestureDetector(
                              onTap: () => setState(() => _selectedTone = tone),
                              child: AnimatedContainer(
                                duration: const Duration(milliseconds: 200),
                                margin: const EdgeInsets.only(right: 6),
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                                decoration: BoxDecoration(
                                  color: isSelected
                                      ? AppColors.primary
                                      : AppColors.surfaceCardDark,
                                  borderRadius: BorderRadius.circular(14),
                                  border: Border.all(
                                    color: isSelected
                                        ? AppColors.accent
                                        : AppColors.borderDark,
                                  ),
                                ),
                                child: Text(
                                  tone == 'Savage'
                                      ? '🔥 Savage'
                                      : tone == 'Flirty'
                                          ? '✨ Flirty'
                                          : tone == 'Witty'
                                              ? '☕ Witty'
                                              : '💼 Boss',
                                  style: TextStyle(
                                    color: isSelected ? Colors.white : AppColors.textSecondaryDark,
                                    fontSize: 11,
                                    fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                                  ),
                                ),
                              ),
                            );
                          }).toList(),
                        ),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 12),

                // Outbound AI Generated Bubble
                Align(
                  alignment: Alignment.centerRight,
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 250),
                    constraints: const BoxConstraints(maxWidth: 300),
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    decoration: BoxDecoration(
                      gradient: AppColors.primaryGradient,
                      borderRadius: const BorderRadius.only(
                        topLeft: Radius.circular(18),
                        topRight: Radius.circular(18),
                        bottomLeft: Radius.circular(18),
                        bottomRight: Radius.circular(4),
                      ),
                      border: Border.all(color: AppColors.accent.withOpacity(0.4)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.coffee_rounded, color: AppColors.accentWarm, size: 12),
                            const SizedBox(width: 4),
                            Text(
                              'VibeKit AI • $_selectedTone',
                              style: const TextStyle(
                                color: AppColors.accentWarm,
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          _repliesByTone[_selectedTone] ?? '',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            height: 1.35,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 10),

                // Live Hint Pill
                Center(
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                    decoration: BoxDecoration(
                      color: AppColors.surfaceElevatedDark,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Text(
                      '👆 Tap the tone pills above to test live',
                      style: TextStyle(color: AppColors.textMutedDark, fontSize: 10),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // -------------------------------------------------------------
  // SLIDE 1: Caption Lab (Viral Feed Simulator)
  // -------------------------------------------------------------
  Widget _buildCaptionLabSlide() {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        children: [
          const SizedBox(height: 8),

          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
            decoration: BoxDecoration(
              color: AppColors.primary.withOpacity(0.2),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: AppColors.accent.withOpacity(0.4)),
            ),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.auto_awesome_rounded, color: AppColors.accentWarm, size: 13),
                SizedBox(width: 6),
                Text(
                  'Caption Lab',
                  style: TextStyle(
                    color: AppColors.accentWarm,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 12),

          const Text(
            'Viral Captions & Reel Hooks',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w800,
              color: AppColors.textPrimaryDark,
              letterSpacing: -0.5,
            ),
          ),

          const SizedBox(height: 8),

          const Text(
            'Generate scroll-stopping hooks, high-converting CTAs, and tailored hashtags for Instagram & Shorts.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 13,
              color: AppColors.textSecondaryDark,
              height: 1.4,
            ),
          ),

          const SizedBox(height: 20),

          // Creator Mock Post Card
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.surfaceDark,
              borderRadius: BorderRadius.circular(24),
              border: Border.all(
                color: AppColors.borderDark,
                width: 1.2,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(2),
                      decoration: const BoxDecoration(
                        gradient: AppColors.accentGradient,
                        shape: BoxShape.circle,
                      ),
                      child: Container(
                        width: 32,
                        height: 32,
                        decoration: const BoxDecoration(
                          color: AppColors.surfaceDark,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.person, color: AppColors.accentWarm, size: 18),
                      ),
                    ),
                    const SizedBox(width: 10),
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '@yourbrand • Reel Hook',
                            style: TextStyle(
                              color: AppColors.textPrimaryDark,
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                            ),
                          ),
                          Text(
                            'Instagram Reels & Shorts',
                            style: TextStyle(color: AppColors.textMutedDark, fontSize: 10),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: AppColors.accent.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: AppColors.accent.withOpacity(0.4)),
                      ),
                      child: const Row(
                        children: [
                          Icon(Icons.local_fire_department_rounded, color: AppColors.accent, size: 12),
                          SizedBox(width: 2),
                          Text(
                            '98% Hook',
                            style: TextStyle(
                              color: AppColors.accent,
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 14),

                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.surfaceCardDark,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: AppColors.borderDark),
                  ),
                  child: const Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '“Stop writing boring captions in 2026! ☕ Here is the 3-second psychology trick that gets viewers to watch until the very end...”',
                        style: TextStyle(
                          color: AppColors.textPrimaryDark,
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          height: 1.4,
                        ),
                      ),
                      SizedBox(height: 8),
                      Text(
                        '#ViralHooks #ContentStrategy #CreatorTips #VibeKitAI',
                        style: TextStyle(
                          color: AppColors.accentWarm,
                          fontSize: 11,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 12),

                // Engagement Metrics Row
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _buildMetricItem(Icons.favorite_rounded, '48.2K', const Color(0xFFC2410C)),
                    _buildMetricItem(Icons.chat_bubble_rounded, '1,290', AppColors.accent),
                    _buildMetricItem(Icons.send_rounded, '16.4K', const Color(0xFF2E7D32)),
                    _buildMetricItem(Icons.bookmark_rounded, '9.8K', AppColors.accentWarm),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMetricItem(IconData icon, String count, Color color) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, color: color, size: 14),
        const SizedBox(width: 4),
        Text(
          count,
          style: const TextStyle(
            color: AppColors.textSecondaryDark,
            fontSize: 11,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }

  // -------------------------------------------------------------
  // SLIDE 2: Card & Meme Maker (Aesthetic Canvas)
  // -------------------------------------------------------------
  Widget _buildCardMakerSlide() {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        children: [
          const SizedBox(height: 8),

          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
            decoration: BoxDecoration(
              color: AppColors.primary.withOpacity(0.2),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: AppColors.accent.withOpacity(0.4)),
            ),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.palette_rounded, color: AppColors.accentWarm, size: 13),
                SizedBox(width: 6),
                Text(
                  'Local-First Card Studio',
                  style: TextStyle(
                    color: AppColors.accentWarm,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 12),

          const Text(
            'Stunning Cards & Memes',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w800,
              color: AppColors.textPrimaryDark,
              letterSpacing: -0.5,
            ),
          ),

          const SizedBox(height: 8),

          const Text(
            'Turn quotes and thoughts into high-res story cards locally with multi-language support (English, Hindi & Gujarati).',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 13,
              color: AppColors.textSecondaryDark,
              height: 1.4,
            ),
          ),

          const SizedBox(height: 20),

          // Mini Aesthetic Card Canvas
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: AppColors.cardGlowGradient,
              borderRadius: BorderRadius.circular(24),
              border: Border.all(
                color: AppColors.accent.withOpacity(0.45),
                width: 1.5,
              ),
            ),
            child: Column(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Text(
                    'DAILY VIBE • WARM ROAST',
                    style: TextStyle(
                      color: AppColors.accentWarm,
                      fontSize: 10,
                      letterSpacing: 1.5,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                const Text(
                  '“The vibe speaks before you do.”',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    fontStyle: FontStyle.italic,
                    letterSpacing: -0.2,
                  ),
                ),
                const SizedBox(height: 20),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    _buildPillTag('🎨 8 Presets'),
                    const SizedBox(width: 6),
                    _buildPillTag('🌐 हिंदी & ગુજરાતી'),
                    const SizedBox(width: 6),
                    _buildPillTag('⚡ 100% Offline'),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPillTag(String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: AppColors.surfaceElevatedDark,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.borderDark),
      ),
      child: Text(
        label,
        style: const TextStyle(
          color: AppColors.accentWarm,
          fontSize: 10,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }

  // -------------------------------------------------------------
  // SLIDE 3: Privacy & Responsible AI (Apple-Style Trust)
  // -------------------------------------------------------------
  Widget _buildPrivacySlide() {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        children: [
          const SizedBox(height: 8),

          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
            decoration: BoxDecoration(
              color: AppColors.success.withOpacity(0.18),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: AppColors.success.withOpacity(0.4)),
            ),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.shield_rounded, color: Color(0xFF66BB6A), size: 13),
                SizedBox(width: 6),
                Text(
                  'Privacy & Trust First',
                  style: TextStyle(
                    color: Color(0xFF66BB6A),
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 12),

          const Text(
            'Private & Responsible AI',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w800,
              color: AppColors.textPrimaryDark,
              letterSpacing: -0.5,
            ),
          ),

          const SizedBox(height: 8),

          const Text(
            'Experience next-gen AI creativity without ever compromising your privacy or personal conversations.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 13,
              color: AppColors.textSecondaryDark,
              height: 1.4,
            ),
          ),

          const SizedBox(height: 20),

          // 3 Trust Certification Cards
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.surfaceDark,
              borderRadius: BorderRadius.circular(24),
              border: Border.all(
                color: AppColors.borderDark,
                width: 1.2,
              ),
            ),
            child: Column(
              children: [
                _buildTrustRow(
                  icon: Icons.lock_rounded,
                  color: const Color(0xFF66BB6A),
                  title: 'Zero Chat Retention',
                  desc: 'Your inputs are processed in-memory and never saved to a database.',
                ),
                const Divider(height: 20, color: AppColors.borderDark),
                _buildTrustRow(
                  icon: Icons.bolt_rounded,
                  color: AppColors.accent,
                  title: 'Local-First Rendering',
                  desc: 'Quote & meme cards are created and saved directly on your device GPU.',
                ),
                const Divider(height: 20, color: AppColors.borderDark),
                _buildTrustRow(
                  icon: Icons.verified_user_rounded,
                  color: AppColors.accentWarm,
                  title: 'Play Store Data Safety',
                  desc: 'Full compliance with Google Play Developer Privacy standards.',
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTrustRow({
    required IconData icon,
    required Color color,
    required String title,
    required String desc,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: color.withOpacity(0.15),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, color: color, size: 18),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  color: AppColors.textPrimaryDark,
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                desc,
                style: const TextStyle(
                  color: AppColors.textSecondaryDark,
                  fontSize: 11,
                  height: 1.35,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
