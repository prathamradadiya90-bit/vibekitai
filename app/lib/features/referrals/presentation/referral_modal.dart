import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/providers/app_providers.dart';
import '../../../core/services/share_service.dart';
import '../../../core/services/analytics_service.dart';

class ReferralModal extends ConsumerStatefulWidget {
  const ReferralModal({super.key});

  static Future<void> show(BuildContext context) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const ReferralModal(),
    );
  }

  @override
  ConsumerState<ReferralModal> createState() => _ReferralModalState();
}

class _ReferralModalState extends ConsumerState<ReferralModal> {
  final _codeController = TextEditingController();
  bool _isLoading = true;
  bool _isClaiming = false;
  int _totalReferred = 0;
  int _creditsEarned = 0;
  int _maxReferrals = 10;
  String _referralCode = '';

  @override
  void initState() {
    super.initState();
    _fetchStats();
  }

  @override
  void dispose() {
    _codeController.dispose();
    super.dispose();
  }

  Future<void> _fetchStats() async {
    final apiClient = ref.read(apiClientProvider);
    try {
      final res = await apiClient.getReferralStats();
      if (mounted) {
        setState(() {
          _referralCode = (res['referral_code'] as String?) ?? '';
          _totalReferred = (res['total_referred'] as num?)?.toInt() ?? 0;
          _creditsEarned = (res['credits_earned'] as num?)?.toInt() ?? 0;
          _maxReferrals = (res['max_referrals'] as num?)?.toInt() ?? 10;
          _isLoading = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _claimReferral() async {
    final code = _codeController.text.trim();
    if (code.isEmpty) return;

    setState(() => _isClaiming = true);
    final apiClient = ref.read(apiClientProvider);

    try {
      final res = await apiClient.claimReferral(code);
      if (mounted) {
        AnalyticsService.instance.logEvent('referral_claimed');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(res['message'] ?? 'Referral reward claimed! +2 credits.'),
            backgroundColor: const Color(0xFF00B894),
          ),
        );
        ref.invalidate(quotaProvider);
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed: ${e.toString()}'),
            backgroundColor: const Color(0xFFFF7675),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isClaiming = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E1E2E) : Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      ),
      padding: EdgeInsets.only(
        top: 24,
        left: 20,
        right: 20,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                width: 48,
                height: 5,
                decoration: BoxDecoration(
                  color: Colors.grey.withAlpha(80),
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFF6C5CE7).withAlpha(40),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.group_add_rounded, color: Color(0xFF6C5CE7), size: 28),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Refer & Earn Credits',
                        style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
                      ),
                      Text(
                        'Invite friends. Both of you get +2 AI credits!',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: isDark ? Colors.grey[400] : Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            if (_isLoading)
              const Center(child: CircularProgressIndicator())
            else ...[
              // Stats Card
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [const Color(0xFF6C5CE7).withAlpha(30), const Color(0xFFA29BFE).withAlpha(30)],
                  ),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: const Color(0xFF6C5CE7).withAlpha(60)),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    Column(
                      children: [
                        Text('$_totalReferred / $_maxReferrals',
                            style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold, color: const Color(0xFF6C5CE7))),
                        const Text('Friends Joined', style: TextStyle(fontSize: 12)),
                      ],
                    ),
                    Container(height: 36, width: 1, color: Colors.grey.withAlpha(60)),
                    Column(
                      children: [
                        Text('+$_creditsEarned',
                            style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold, color: const Color(0xFF00B894))),
                        const Text('Credits Earned', style: TextStyle(fontSize: 12)),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              // Your referral code box
              Text('Your Referral Code', style: theme.textTheme.labelLarge?.copyWith(fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF282A36) : const Color(0xFFF1F2F6),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        _referralCode.isEmpty ? 'Loading...' : _referralCode,
                        style: const TextStyle(fontWeight: FontWeight.bold, letterSpacing: 1),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.copy_rounded, size: 20),
                      onPressed: () => ShareService.copyToClipboard(
                        context,
                        _referralCode,
                        message: 'Referral code copied!',
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              ElevatedButton.icon(
                onPressed: () {
                  AnalyticsService.instance.logEvent('referral_shared');
                  final link = ShareService.buildReferralLink(_referralCode);
                  ShareService.shareText(
                    'Hey! Try VibeKit AI to create awesome replies, captions, and profile bios. Use my referral code: $_referralCode for +2 bonus credits!\n\nDownload: $link',
                  );
                },
                icon: const Icon(Icons.share_rounded),
                label: const Text('Share Invite Link'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF6C5CE7),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
              ),
              const SizedBox(height: 24),
              const Divider(),
              const SizedBox(height: 12),
              // Enter friend's code
              Text('Have a referral code?', style: theme.textTheme.labelLarge?.copyWith(fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _codeController,
                      decoration: InputDecoration(
                        hintText: "Enter friend's code",
                        isDense: true,
                        filled: true,
                        fillColor: isDark ? const Color(0xFF282A36) : const Color(0xFFF1F2F6),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide.none,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  ElevatedButton(
                    onPressed: _isClaiming ? null : _claimReferral,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF00B894),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    child: _isClaiming
                        ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                        : const Text('Claim'),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}
