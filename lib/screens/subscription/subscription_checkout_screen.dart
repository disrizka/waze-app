import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:wa_blast/constants/app_colors.dart';

import '../../providers/subscription_provider.dart';

class SubscriptionCheckoutScreen extends StatefulWidget {
  const SubscriptionCheckoutScreen({super.key});

  static const Color _primaryBlue = Color(0xFF4C6EF5);

  @override
  State<SubscriptionCheckoutScreen> createState() =>
      _SubscriptionCheckoutScreenState();
}

class _SubscriptionCheckoutScreenState
    extends State<SubscriptionCheckoutScreen> {
  String _businessName = '—';
  String _businessUsername = '—';
  String _businessLogoPath = '';
  bool _isLoadingHeader = true;

  @override
  void initState() {
    super.initState();
    _loadBusinessFromPrefs();
  }

  Future<void> _loadBusinessFromPrefs() async {
    final prefs = await SharedPreferences.getInstance();

    String businessName = '';
    String businessUsername = '';
    String businessLogoPath = '';

    final activeId = (prefs.getString('activeBizId') ?? '').trim();
    final businessJson = prefs.getString('business');

    if (businessJson != null && businessJson.isNotEmpty) {
      try {
        final list = (jsonDecode(businessJson) as List)
            .cast<Map<String, dynamic>>();

        Map<String, dynamic>? match;
        if (activeId.isNotEmpty) {
          match = list.firstWhere(
            (e) => (e['idBusiness'] ?? '').toString() == activeId,
            orElse: () => <String, dynamic>{},
          );
        }

        if (match != null && match.isNotEmpty) {
          businessName = (match['name'] ?? '').toString();
          businessUsername = (match['username'] ?? '').toString();
          businessLogoPath = (match['logoPath'] ?? match['logo'] ?? '')
              .toString();
        } else {
          businessName = prefs.getString('activeBizName') ?? '';
          businessUsername = prefs.getString('activeBizUsername') ?? '';
          businessLogoPath = prefs.getString('activeBizLogoPath') ?? '';
        }
      } catch (_) {
        businessName = prefs.getString('activeBizName') ?? '';
        businessUsername = prefs.getString('activeBizUsername') ?? '';
        businessLogoPath = prefs.getString('activeBizLogoPath') ?? '';
      }
    } else {
      businessName = prefs.getString('activeBizName') ?? '';
      businessUsername = prefs.getString('activeBizUsername') ?? '';
      businessLogoPath = prefs.getString('activeBizLogoPath') ?? '';
    }

    if (!mounted) return;
    setState(() {
      _businessName = businessName.isNotEmpty ? businessName : '—';
      _businessUsername = businessUsername.isNotEmpty ? businessUsername : '—';
      _businessLogoPath = businessLogoPath;
      _isLoadingHeader = false;
    });
  }

  String _buildInitials(String name) {
    final parts = name.trim().split(' ');
    if (parts.isEmpty || parts.first.isEmpty) return '?';
    if (parts.length == 1) {
      return parts.first.characters.take(2).toString().toUpperCase();
    }
    return (parts.first.characters.first + parts.last.characters.first)
        .toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white, // background putih
      body: SafeArea(
        child: Consumer<SubscriptionProvider>(
          builder: (context, subscription, _) {
            return Column(
              children: [
                // ---------- HEADER ----------
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 8,
                  ),
                  child: Row(
                    children: [
                      // Business avatar
                      _isLoadingHeader
                          ? const CircleAvatar(
                              radius: 18,
                              backgroundColor: Color(0xFFE5EDFF),
                              child: SizedBox(
                                height: 16,
                                width: 16,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              ),
                            )
                          : CircleAvatar(
                              radius: 18,
                              backgroundColor: const Color(0xFFE5EDFF),
                              backgroundImage: _businessLogoPath.isNotEmpty
                                  ? NetworkImage(_businessLogoPath)
                                  : null,
                              child: _businessLogoPath.isEmpty
                                  ? Text(
                                      _buildInitials(_businessName),
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w700,
                                        color: SubscriptionCheckoutScreen
                                            ._primaryBlue,
                                      ),
                                    )
                                  : null,
                            ),
                      const SizedBox(width: 10),
                      // Business info
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _businessName,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontWeight: FontWeight.w600,
                                fontSize: 15,
                              ),
                            ),
                            const SizedBox(height: 2),

                            if (_businessUsername != '—' &&
                                _businessUsername.isNotEmpty) ...[
                              const SizedBox(height: 2),
                              Text(
                                '@$_businessUsername',
                                style: const TextStyle(
                                  fontSize: 11,
                                  color: Colors.black45,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close),
                        onPressed: () => Navigator.of(context).pop(),
                      ),
                    ],
                  ),
                ),

                // ---------- CONTENT ----------
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 12,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Choose a plan',
                          style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 4),
                        const Text(
                          'Select how you want to pay for premium features.',
                          style: TextStyle(fontSize: 13, color: Colors.black54),
                        ),

                        // const SizedBox(height: 16),

                        // // small info pill
                        // Container(
                        //   padding: const EdgeInsets.symmetric(
                        //     horizontal: 10,
                        //     vertical: 6,
                        //   ),
                        //   decoration: BoxDecoration(
                        //     color: const Color(0xFFE5EDFF),
                        //     borderRadius: BorderRadius.circular(999),
                        //   ),
                        //   child: const Row(
                        //     mainAxisSize: MainAxisSize.min,
                        //     children: [
                        //       Icon(
                        //         Icons.shield_rounded,
                        //         size: 14,
                        //         color: AppColors.primary,
                        //       ),
                        //       SizedBox(width: 6),
                        //       Text(
                        //         'Secure payments • Cancel anytime',
                        //         style: TextStyle(
                        //           fontSize: 11,
                        //           fontWeight: FontWeight.w500,
                        //           color: AppColors.primary,
                        //         ),
                        //       ),
                        //     ],
                        //   ),
                        // ),
                        const SizedBox(height: 25),

                        // Monthly card
                        _PlanCard(
                          title: 'Monthly',
                          priceLabel:
                              '\$${subscription.monthlyPrice.toStringAsFixed(2)} /month',
                          isSelected:
                              subscription.selectedCycle ==
                              BillingCycle.monthly,
                          onTap: () =>
                              subscription.selectCycle(BillingCycle.monthly),
                          highlightColor:
                              SubscriptionCheckoutScreen._primaryBlue,
                        ),

                        const SizedBox(height: 12),

                        // Yearly card
                        _PlanCard(
                          title: 'Annually',
                          priceLabel:
                              '\$${subscription.yearlyPrice.toStringAsFixed(2)} /year',
                          isSelected:
                              subscription.selectedCycle == BillingCycle.yearly,
                          onTap: () =>
                              subscription.selectCycle(BillingCycle.yearly),
                          highlightColor:
                              SubscriptionCheckoutScreen._primaryBlue,
                          badgeText:
                              'Save ${subscription.yearlyDiscountPercent.toStringAsFixed(0)}%',
                        ),

                        const SizedBox(height: 20),

                        // ---------- PLAN SUMMARY (lebih informatif) ----------
                        _PlanSummaryTile(subscription: subscription),

                        const SizedBox(height: 24),

                        // ---------- FEATURES ----------
                        const Text(
                          'What you’ll get',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 10),
                        const _FeatureList(),

                        const SizedBox(height: 16),

                        // // extra info
                        // const _SmallInfoSection(),
                      ],
                    ),
                  ),
                ),

                // ---------- BOTTOM BUTTON ----------
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 12,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: const BorderRadius.vertical(
                      top: Radius.circular(20),
                    ),
                    boxShadow: [
                      BoxShadow(
                        offset: const Offset(0, -3),
                        blurRadius: 16,
                        color: Colors.black.withOpacity(0.07),
                      ),
                    ],
                  ),
                  child: SafeArea(
                    top: false,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text(
                          subscription.selectedCycle == BillingCycle.yearly
                              ? 'You will be charged yearly. Auto-renews unless canceled.'
                              : 'You will be charged monthly. Auto-renews unless canceled.',
                          style: const TextStyle(
                            fontSize: 11,
                            color: Colors.black54,
                          ),
                        ),
                        const SizedBox(height: 8),
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              minimumSize: const Size.fromHeight(56),
                              backgroundColor: Colors.black,
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(28),
                              ),
                            ),
                            onPressed: subscription.isProcessing
                                ? null
                                : () => subscription.goToPayment(context),
                            child: subscription.isProcessing
                                ? const SizedBox(
                                    height: 22,
                                    width: 22,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      valueColor: AlwaysStoppedAnimation(
                                        Colors.white,
                                      ),
                                    ),
                                  )
                                : const Text(
                                    'Go to payment',
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

// -------------------------------------------------------------
// WIDGET: Plan Card
// -------------------------------------------------------------
class _PlanCard extends StatelessWidget {
  final String title;
  final String priceLabel;
  final bool isSelected;
  final VoidCallback onTap;
  final Color highlightColor;
  final String? badgeText;

  const _PlanCard({
    required this.title,
    required this.priceLabel,
    required this.isSelected,
    required this.onTap,
    required this.highlightColor,
    this.badgeText,
  });

  @override
  Widget build(BuildContext context) {
    final borderColor = isSelected
        ? highlightColor
        : Colors.grey.withOpacity(0.35);
    final bgColor = isSelected
        ? highlightColor.withOpacity(0.04)
        : Colors.white;

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        decoration: BoxDecoration(
          color: bgColor,
          border: Border.all(color: borderColor, width: 2),
          borderRadius: BorderRadius.circular(22),
        ),
        child: Row(
          children: [
            // left text
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        title,
                        style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 16,
                        ),
                      ),
                      const SizedBox(width: 8),
                      if (badgeText != null)
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(999),
                            color: highlightColor.withOpacity(0.12),
                          ),
                          child: Text(
                            badgeText!,
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                              color: highlightColor,
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    priceLabel,
                    style: const TextStyle(fontSize: 14, color: Colors.black87),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            // radio indicator
            Container(
              width: 22,
              height: 22,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: isSelected ? highlightColor : Colors.grey,
                  width: 2,
                ),
              ),
              child: Center(
                child: Container(
                  width: 12,
                  height: 12,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: isSelected ? highlightColor : Colors.transparent,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// -------------------------------------------------------------
// WIDGET: Plan Summary (lebih informatif)
// -------------------------------------------------------------
class _PlanSummaryTile extends StatelessWidget {
  final SubscriptionProvider subscription;

  const _PlanSummaryTile({required this.subscription});

  @override
  Widget build(BuildContext context) {
    final isMonthly = subscription.selectedCycle == BillingCycle.monthly;
    final mainPrice = isMonthly
        ? subscription.monthlyPrice
        : subscription.yearlyPrice;
    final period = isMonthly ? 'month' : 'year';

    final effectiveMonthly = subscription.yearlyPrice > 0
        ? subscription.yearlyPrice / 12
        : 0;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFF),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE0E7FF)),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.receipt_long_rounded,
            size: 20,
            color: SubscriptionCheckoutScreen._primaryBlue,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isMonthly
                      ? 'Monthly billing selected'
                      : 'Annual billing selected',
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'You’ll pay \$${mainPrice.toStringAsFixed(2)} per $period.',
                  style: const TextStyle(fontSize: 12, color: Colors.black87),
                ),
                if (!isMonthly && effectiveMonthly > 0) ...[
                  const SizedBox(height: 2),
                  Text(
                    'Effective monthly cost ~ \$${effectiveMonthly.toStringAsFixed(2)}.',
                    style: const TextStyle(fontSize: 11, color: Colors.black54),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// -------------------------------------------------------------
// WIDGET: Feature List
// -------------------------------------------------------------
class _FeatureList extends StatelessWidget {
  const _FeatureList();

  @override
  Widget build(BuildContext context) {
    const features = [
      'Access to all premium content',
      'Unlimited products for your business',
      'Unlimited transactions every month',
      'Advanced analytics & automation',
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final f in features) ...[
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const Icon(
                Icons.check_circle_rounded,
                size: 20,
                color: SubscriptionCheckoutScreen._primaryBlue,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  f,
                  style: const TextStyle(fontSize: 13, height: 1.4),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
        ],
      ],
    );
  }
}

// -------------------------------------------------------------
// WIDGET: Extra info kecil di bawah
// -------------------------------------------------------------
class _SmallInfoSection extends StatelessWidget {
  const _SmallInfoSection();

  @override
  Widget build(BuildContext context) {
    const items = [
      (Icons.lock_rounded, 'We don’t store your card details on device.'),
      (
        Icons.refresh_rounded,
        'Your plan will renew automatically unless you cancel.',
      ),
      (
        Icons.support_agent_rounded,
        'Need help? You can contact support at any time.',
      ),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final i in items) ...[
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(i.$1, size: 16, color: Colors.black45),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  i.$2,
                  style: const TextStyle(
                    fontSize: 11,
                    color: Colors.black54,
                    height: 1.4,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
        ],
      ],
    );
  }
}
