import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../core/config/app_config.dart';
import '../../core/constants/app_colors.dart';
import '../../core/providers/app_providers.dart';
import '../../core/services/analytics_service.dart';

class PaywallScreen extends ConsumerStatefulWidget {
  const PaywallScreen({super.key});

  @override
  ConsumerState<PaywallScreen> createState() => _PaywallScreenState();
}

class _PaywallScreenState extends ConsumerState<PaywallScreen> {
  String _selectedPlan = AppConfig.proYearlyId; // default to yearly best-value
  bool _isPurchasing = false;

  final List<Map<String, dynamic>> _proFeatures = [
    {
      'icon': Icons.block_rounded,
      'title': '100% Ad-Free Experience',
      'desc': 'Zero banner or interstitial interruptions anywhere in the app.',
    },
    {
      'icon': Icons.bolt_rounded,
      'title': '200 High-Priority AI Credits / Month',
      'desc': 'Generous allowance for replies, captions, and reel hooks.',
    },
    {
      'icon': Icons.branding_watermark_rounded,
      'title': 'Watermark-Free Card Exports',
      'desc': 'Export crisp, ultra-clean meme and quote cards without branding.',
    },
    {
      'icon': Icons.palette_rounded,
      'title': 'All Premium Designer Templates',
      'desc': 'Unlock exclusive Sapphire, Nebula, Aura, and modern styles.',
    },
    {
      'icon': Icons.speed_rounded,
      'title': 'Priority AI Edge Processing',
      'desc': 'Near-zero latency generation through dedicated compute nodes.',
    },
  ];

  @override
  void initState() {
    super.initState();
    AnalyticsService.instance.logPaywallView('paywall_screen');
  }

  Future<void> _handlePurchase() async {
    AnalyticsService.instance.logPaywallCtaTap(_selectedPlan);
    final billing = ref.read(billingServiceProvider);
    if (!billing.isAvailable) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Google Play Billing is unavailable on this device.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    ProductDetails? targetProduct;
    for (final p in billing.products) {
      if (p.id == _selectedPlan) {
        targetProduct = p;
        break;
      }
    }

    if (targetProduct == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Product $_selectedPlan is pending Play Store activation. Please ensure billing products are published.',
          ),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    setState(() => _isPurchasing = true);
    final isConsumable = targetProduct.id == AppConfig.creditPack50Id;
    final success = await billing.buyProduct(targetProduct, isConsumable: isConsumable);
    if (!mounted) return;
    setState(() => _isPurchasing = false);

    if (!success) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Purchase could not be initiated.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Future<void> _handleRestore() async {
    final billing = ref.read(billingServiceProvider);
    setState(() => _isPurchasing = true);
    await billing.restorePurchases();
    if (!mounted) return;
    setState(() => _isPurchasing = false);

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Purchase restore requested. Reconciling entitlements...'),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Future<void> _openPlaySubscriptions() async {
    final uri = Uri.parse(AppConfig.playSubscriptionsUrl);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  @override
  Widget build(BuildContext context) {
    final billing = ref.watch(billingServiceProvider);
    final quota = ref.watch(quotaProvider);

    // Resolve real localized prices if available from Play Billing
    String yearlyPrice = '₹699 / year (3-Day Free Trial • Save 41%)';
    String monthlyPrice = '₹99 / month';
    String lifetimePrice = '₹1,999 (Pay Once • Lifetime VIP)';
    String creditPackPrice = '₹149 (50 Credits Top-Up)';

    for (final prod in billing.products) {
      if (prod.id == AppConfig.proYearlyId) {
        yearlyPrice = '${prod.price} / year (3-Day Free Trial)';
      } else if (prod.id == AppConfig.proMonthlyId) {
        monthlyPrice = '${prod.price} / month';
      } else if (prod.id == AppConfig.proLifetimeId) {
        lifetimePrice = '${prod.price} (Lifetime VIP)';
      } else if (prod.id == AppConfig.creditPack50Id) {
        creditPackPrice = '${prod.price} (50 Credits)';
      }
    }

    return Scaffold(
      backgroundColor: AppColors.backgroundDark,
      appBar: AppBar(
        title: const Text('VibeKit VIP & Pro', style: TextStyle(fontWeight: FontWeight.bold)),
        actions: [
          TextButton(
            onPressed: _isPurchasing ? null : _handleRestore,
            child: const Text('Restore', style: TextStyle(color: AppColors.primaryLight)),
          ),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Hero Banner
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(22),
                decoration: BoxDecoration(
                  gradient: AppColors.primaryGradient,
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: kIsWeb
                      ? null
                      : [
                          BoxShadow(
                            color: AppColors.primary.withOpacity(0.35),
                            blurRadius: 28,
                            offset: const Offset(0, 8),
                          ),
                        ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Text(
                            'UNLIMITED CREATIVITY',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 1.1,
                            ),
                          ),
                        ),
                        const Spacer(),
                        const Text('⭐ 4.9 Rating',
                            style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold)),
                      ],
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      'Upgrade to VIP\nCreator Status',
                      style: TextStyle(
                        fontSize: 26,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                        height: 1.2,
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Zero ads, no watermarks, full template access & 200 monthly AI generations.',
                      style: TextStyle(fontSize: 13, color: Colors.white70),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 24),

              // Feature Highlights
              const Text('What is Included in Pro & VIP',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              const SizedBox(height: 12),
              ..._proFeatures.map((feat) {
                return Padding(
                  padding: const EdgeInsets.only(bottom: 14),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: AppColors.primary.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Icon(feat['icon'] as IconData,
                            size: 20, color: AppColors.primaryLight),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              feat['title'] as String,
                              style: const TextStyle(
                                  fontWeight: FontWeight.bold, fontSize: 14),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              feat['desc'] as String,
                              style: const TextStyle(
                                  color: AppColors.textSecondaryDark,
                                  fontSize: 12),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                );
              }),

              const SizedBox(height: 16),

              // Plan Selection Cards
              const Text('Choose Your Pass',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              const SizedBox(height: 12),

              // 1. Yearly Plan (Best Value with Trial)
              _buildPlanCard(
                planId: AppConfig.proYearlyId,
                title: 'Annual Creator Pass',
                subtitle: yearlyPrice,
                badgeText: 'BEST VALUE • 3-DAY FREE TRIAL',
                badgeGradient: AppColors.accentGradient,
                savings: 'Save 41%',
              ),

              const SizedBox(height: 10),

              // 2. Lifetime VIP Pass (Pay once, own forever)
              _buildPlanCard(
                planId: AppConfig.proLifetimeId,
                title: 'Lifetime VIP Pass',
                subtitle: lifetimePrice,
                badgeText: 'ONE-TIME PURCHASE • OWN FOREVER',
                badgeGradient: const LinearGradient(
                  colors: [Color(0xFFF59E0B), Color(0xFFD97706)],
                ),
                savings: 'No Subscriptions',
              ),

              const SizedBox(height: 10),

              // 3. Monthly Plan
              _buildPlanCard(
                planId: AppConfig.proMonthlyId,
                title: 'Monthly Pass',
                subtitle: monthlyPrice,
                badgeText: null,
                savings: null,
              ),

              // 4. Consumable Credit Pack Top-Up (only when the server has packs enabled)
              if (billing.creditPacksEnabled) ...[
                const SizedBox(height: 10),
                _buildPlanCard(
                  planId: AppConfig.creditPack50Id,
                  title: '50 Credits Top-Up Pack',
                  subtitle: creditPackPrice,
                  badgeText: 'INSTANT BOOST',
                  savings: null,
                ),
              ],

              const SizedBox(height: 24),

              // Purchase Button
              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton(
                  onPressed: _isPurchasing ? null : _handlePurchase,
                  child: _isPurchasing
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.white),
                        )
                      : Text(
                          quota.isPro && _selectedPlan != AppConfig.creditPack50Id
                              ? 'Manage Active Subscription'
                              : _selectedPlan == AppConfig.proLifetimeId
                                  ? 'Get Lifetime VIP Access'
                                  : _selectedPlan == AppConfig.creditPack50Id
                                      ? 'Purchase 50 AI Credits'
                                      : 'Start 3-Day Free Trial',
                          style: const TextStyle(
                              fontSize: 16, fontWeight: FontWeight.bold),
                        ),
                ),
              ),

              const SizedBox(height: 28),

              // Plan Comparison Table
              const Text('Tier Comparison Matrix',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              const SizedBox(height: 12),
              Container(
                decoration: BoxDecoration(
                  color: AppColors.surfaceDark,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppColors.borderDark),
                ),
                child: Column(
                  children: [
                    _buildComparisonRow('Feature', 'Free', 'Pro', 'Lifetime VIP', isHeader: true),
                    const Divider(height: 1, color: AppColors.borderDark),
                    _buildComparisonRow('AI Generations', '3 / day', '200 / mo', '200 / mo'),
                    const Divider(height: 1, color: AppColors.borderDark),
                    _buildComparisonRow('Ad-Free Clean UI', 'No', 'Yes', 'Yes'),
                    const Divider(height: 1, color: AppColors.borderDark),
                    _buildComparisonRow('Watermark-Free Cards', 'No', 'Yes', 'Yes'),
                    const Divider(height: 1, color: AppColors.borderDark),
                    _buildComparisonRow('Exclusive Templates', 'Basic', 'All', 'All + Future'),
                    const Divider(height: 1, color: AppColors.borderDark),
                    _buildComparisonRow('Priority Edge Queue', 'Standard', 'High', 'Highest VIP'),
                  ],
                ),
              ),

              const SizedBox(height: 24),

              // Social Proof & Creator Testimonials
              Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: AppColors.surfaceDark,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: Colors.white.withOpacity(0.08)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Row(
                      children: [
                        Text('💬', style: TextStyle(fontSize: 20)),
                        SizedBox(width: 8),
                        Text('What Creators Say',
                            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Text(
                      '"VibeKit Pro transformed my social workflow. The reply tones and aesthetic watermark-free cards saved me hours every week."',
                      style: TextStyle(
                        fontSize: 13,
                        fontStyle: FontStyle.italic,
                        color: Colors.white.withOpacity(0.8),
                        height: 1.4,
                      ),
                    ),
                    const SizedBox(height: 6),
                    const Text('— Sarah K., Content Creator (85k followers)',
                        style: TextStyle(fontSize: 11, color: AppColors.primaryLight)),
                  ],
                ),
              ),

              const SizedBox(height: 24),

              // Legal Terms & Google Play Cancellation
              Center(
                child: Column(
                  children: [
                    const Text(
                      'Payment is processed securely by Google Play Billing. Subscriptions renew automatically unless cancelled at least 24 hours prior to the end of the current billing cycle.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                          fontSize: 11,
                          color: AppColors.textMutedDark,
                          height: 1.4),
                    ),
                    const SizedBox(height: 8),
                    TextButton(
                      onPressed: _openPlaySubscriptions,
                      child: const Text(
                        'Manage or Cancel on Google Play',
                        style: TextStyle(
                            fontSize: 12, decoration: TextDecoration.underline),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        TextButton(
                          onPressed: () => context.push('/privacy-policy'),
                          child: const Text(
                            'Privacy Policy',
                            style: TextStyle(
                              fontSize: 11,
                              color: AppColors.textSecondaryDark,
                              decoration: TextDecoration.underline,
                            ),
                          ),
                        ),
                        const Text('•', style: TextStyle(color: AppColors.textMutedDark)),
                        TextButton(
                          onPressed: () => context.push('/terms-of-service'),
                          child: const Text(
                            'Terms of Service',
                            style: TextStyle(
                              fontSize: 11,
                              color: AppColors.textSecondaryDark,
                              decoration: TextDecoration.underline,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPlanCard({
    required String planId,
    required String title,
    required String subtitle,
    required String? badgeText,
    Gradient? badgeGradient,
    String? savings,
  }) {
    final isSelected = _selectedPlan == planId;

    return InkWell(
      onTap: () => setState(() => _selectedPlan = planId),
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.surfaceElevatedDark : AppColors.surfaceCardDark,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected ? AppColors.primary : AppColors.borderDark,
            width: isSelected ? 2 : 1,
          ),
          boxShadow: (isSelected && !kIsWeb)
              ? [
                  BoxShadow(
                    color: AppColors.primary.withOpacity(0.18),
                    blurRadius: 14,
                    offset: const Offset(0, 4),
                  ),
                ]
              : null,
        ),
        child: Row(
          children: [
            Icon(
              isSelected
                  ? Icons.radio_button_checked_rounded
                  : Icons.radio_button_off_rounded,
              color: isSelected ? AppColors.primary : AppColors.textMutedDark,
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Wrap(
                    crossAxisAlignment: WrapCrossAlignment.center,
                    spacing: 8,
                    runSpacing: 4,
                    children: [
                      Text(
                        title,
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                      ),
                      if (badgeText != null)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            gradient: badgeGradient ?? AppColors.accentGradient,
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            badgeText,
                            style: const TextStyle(
                              fontSize: 9,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 3),
                  Text(
                    subtitle,
                    style: const TextStyle(
                      color: AppColors.textSecondaryDark,
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            ),
            if (savings != null)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.green.withOpacity(0.18),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  savings,
                  style: const TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: Colors.greenAccent,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildComparisonRow(
    String col1,
    String col2,
    String col3,
    String col4, {
    bool isHeader = false,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      child: Row(
        children: [
          Expanded(
            flex: 4,
            child: Text(
              col1,
              style: TextStyle(
                fontSize: 12,
                fontWeight: isHeader ? FontWeight.bold : FontWeight.w600,
                color: isHeader ? AppColors.primaryLight : Colors.white,
              ),
            ),
          ),
          Expanded(
            flex: 2,
            child: Text(
              col2,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 11,
                fontWeight: isHeader ? FontWeight.bold : FontWeight.normal,
                color: isHeader ? Colors.white70 : Colors.white60,
              ),
            ),
          ),
          Expanded(
            flex: 2,
            child: Text(
              col3,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 11,
                fontWeight: isHeader ? FontWeight.bold : FontWeight.bold,
                color: isHeader ? Colors.white70 : AppColors.primaryLight,
              ),
            ),
          ),
          Expanded(
            flex: 3,
            child: Text(
              col4,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 11,
                fontWeight: isHeader ? FontWeight.bold : FontWeight.bold,
                color: isHeader ? Colors.white70 : Colors.amberAccent,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
