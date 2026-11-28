import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import '../config/app_config.dart';
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
  int _initCheckAttempts = 0;
  Timer? _initCheckTimer;

  @override
  void initState() {
    super.initState();
    _loadBanner();
  }

  void _loadBanner() {
    if (!mounted || kIsWeb || AppConfig.bannerAdUnitId.isEmpty) return;
    final isPro = ref.read(quotaProvider).isPro;
    if (isPro) return;

    final adMob = ref.read(adMobServiceProvider);
    if (!adMob.isInitialized) {
      // AdMob SDK may still be initializing asynchronously post-first-frame on cold start
      if (_initCheckAttempts < 10) {
        _initCheckAttempts++;
        _initCheckTimer = Timer(const Duration(milliseconds: 500), () {
          if (mounted) _loadBanner();
        });
      }
      return;
    }

    _bannerAd?.dispose();
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
        _bannerAd = null;
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
    _initCheckTimer?.cancel();
    _initCheckTimer = null;
    _bannerAd?.dispose();
    _bannerAd = null;
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<bool>(quotaProvider.select((q) => q.isPro), (prev, next) {
      if (next && _bannerAd != null) {
        _bannerAd?.dispose();
        _bannerAd = null;
        if (mounted) setState(() => _isLoaded = false);
      } else if (prev == true && !next && _bannerAd == null) {
        _loadFailed = false;
        _initCheckAttempts = 0;
        _loadBanner();
      }
    });
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
          Padding(
            padding: const EdgeInsets.only(bottom: 2),
            child: Text(
              'ADVERTISEMENT',
              style: TextStyle(
                color: Theme.of(context).brightness == Brightness.dark
                    ? AppColors.textMutedDark
                    : AppColors.textMutedLight,
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
