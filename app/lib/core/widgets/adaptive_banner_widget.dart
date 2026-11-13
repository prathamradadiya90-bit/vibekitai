import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import '../constants/app_colors.dart';
import '../constants/app_spacing.dart';
import '../providers/app_providers.dart';

/// Reusable banner ad widget with policy label, no-fill space collapse,
/// and automatic suppression for Pro subscribers.
class AdaptiveBannerWidget extends ConsumerStatefulWidget {
  const AdaptiveBannerWidget({super.key});

  @override
  ConsumerState<AdaptiveBannerWidget> createState() => _AdaptiveBannerWidgetState();
}

class _AdaptiveBannerWidgetState extends ConsumerState<AdaptiveBannerWidget> {
  BannerAd? _bannerAd;
  bool _isLoaded = false;
  bool _loadFailed = false;

  @override
  void initState() {
    super.initState();
    _loadBanner();
  }

  void _loadBanner() {
    final isPro = ref.read(quotaProvider).isPro;
    if (isPro) return;

    final adMob = ref.read(adMobServiceProvider);
    if (!adMob.isInitialized) return;

    _bannerAd = adMob.createBannerAd(
      onAdLoaded: () {
        if (mounted) {
          setState(() {
            _isLoaded = true;
            _loadFailed = false;
          });
        }
      },
      onAdFailed: (error) {
        if (mounted) {
          setState(() {
            _isLoaded = false;
            _loadFailed = true;
          });
        }
      },
    );

    _bannerAd?.load();
  }

  @override
  void dispose() {
    _bannerAd?.dispose();
    _bannerAd = null;
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isPro = ref.watch(quotaProvider.select((q) => q.isPro));
    if (isPro || _loadFailed || !_isLoaded || _bannerAd == null) {
      return const SizedBox.shrink(); // Policy requirement: No blank whitespace on no-fill
    }

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Policy requirement: Ad label must be clearly visible
          const Padding(
            padding: EdgeInsets.only(bottom: 2),
            child: Text(
              'ADVERTISEMENT',
              style: TextStyle(
                color: AppColors.textMutedDark,
                fontSize: 10,
                letterSpacing: 1.0,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          SizedBox(
            width: _bannerAd!.size.width.toDouble(),
            height: _bannerAd!.size.height.toDouble(),
            child: AdWidget(ad: _bannerAd!),
          ),
        ],
      ),
    );
  }
}
