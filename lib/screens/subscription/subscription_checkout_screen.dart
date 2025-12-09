import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../models/premium_plan_model.dart';
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

  final NumberFormat _idrFormatter = NumberFormat('#,###', 'id_ID');

  // 🔹 3 = One-time payment, 2 = Recurring card
  int _selectedPaymentMethod = 3;

  // 🔹 Plan utama yang dipilih (idPlan + name + list pricing)
  PremiumPlan? _selectedPlan;

  // 🔹 Pricing (durasi + harga) yang dipilih dari plan di atas
  PlanPricing? _selectedPricing;

  @override
  void initState() {
    super.initState();
    _loadBusinessFromPrefs();

    // setelah build pertama, fetch list premium plan dari API
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final subscription = context.read<SubscriptionProvider>();
      subscription.fetchPremiumPlans(context);
    });
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

  /// Helper label untuk period teks (month/year/X months)
  String _periodLabelForMonths(int months) {
    // if (months == 1) return 'Month';
    // if (months == 12) return 'Year';
    return '$months months';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white, // background putih
      body: SafeArea(
        child: Consumer<SubscriptionProvider>(
          builder: (context, subscription, _) {
            // 🔹 Ambil semua plan aktif dari provider
            final List<PremiumPlan> plans = subscription.plans
                .where((p) => p.isActive)
                .toList();

            final bool isLoadingPlans = subscription.isLoadingPlans;

            // ---------- TEKS BAWAH TOMBOL (BOTTOM INFO) ----------
            String bottomInfoText;
            if (_selectedPlan == null) {
              bottomInfoText =
                  'Choose a plan and billing period to see how you will be charged.';
            } else if (_selectedPricing == null) {
              bottomInfoText =
                  'Choose how long you want your premium period for this plan.';
            } else if (_selectedPaymentMethod == 3) {
              // One-time payment
              bottomInfoText =
                  'You will be charged once for this ${_periodLabelForMonths(_selectedPricing!.period)} plan.';
            } else {
              // Recurring card payment
              bottomInfoText =
                  'You will be charged every ${_periodLabelForMonths(_selectedPricing!.period)}. Auto-renews unless canceled.';
            }

            final bool canProceed =
                !subscription.isProcessing &&
                _selectedPlan != null &&
                _selectedPricing != null;

            // Helper label kecil di card plan: "Starts from Rp ..."
            String _buildPlanPriceLabel(PremiumPlan plan) {
              if (plan.pricing.isEmpty) {
                return 'No pricing available yet';
              }
              final minPrice = plan.pricing
                  .map((p) => p.price)
                  .reduce((a, b) => a < b ? a : b);
              return 'Starts from Rp. ${_idrFormatter.format(minPrice)}';
            }

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
                          'First, select a premium plan. Then choose how long you want to subscribe.',
                          style: TextStyle(fontSize: 13, color: Colors.black54),
                        ),

                        const SizedBox(height: 25),

                        if (isLoadingPlans && plans.isEmpty) ...[
                          const Text(
                            'Loading plans...',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.black45,
                            ),
                          ),
                        ] else if (plans.isEmpty) ...[
                          const Text(
                            'No active premium plans available at the moment.',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.black54,
                            ),
                          ),
                        ] else ...[
                          // ---------- LIST PLAN (idPlan + name) ----------
                          for (final plan in plans) ...[
                            const SizedBox(height: 8),
                            _PlanCard(
                              title: plan.name, // tulis nama plan-nya
                              priceLabel: _buildPlanPriceLabel(plan),
                              isSelected: _selectedPlan?.idPlan == plan.idPlan,
                              onTap: () {
                                setState(() {
                                  _selectedPlan = plan;
                                  _selectedPricing = null; // reset pricing
                                });
                              },
                              highlightColor:
                                  SubscriptionCheckoutScreen._primaryBlue,
                            ),
                          ],

                          const SizedBox(height: 20),

                          // ---------- COLLAPSIBLE: PLAN PRICING DARI PLAN TERPILIH ----------
                          AnimatedSize(
                            duration: const Duration(milliseconds: 220),
                            curve: Curves.easeInOut,
                            child: _selectedPlan == null
                                ? const SizedBox.shrink()
                                : Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      const Text(
                                        'Choose billing period',
                                        style: TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                      const SizedBox(height: 8),
                                      if (_selectedPlan!.pricing.isEmpty) ...[
                                        Container(
                                          width: double.infinity,
                                          padding: const EdgeInsets.all(14),
                                          decoration: BoxDecoration(
                                            borderRadius: BorderRadius.circular(
                                              16,
                                            ),
                                            color: const Color(0xFFF8FAFF),
                                            border: Border.all(
                                              color: const Color(0xFFE0E7FF),
                                            ),
                                          ),
                                          child: const Text(
                                            'No pricing options are configured for this plan yet.',
                                            style: TextStyle(
                                              fontSize: 12,
                                              color: Colors.black87,
                                            ),
                                          ),
                                        ),
                                      ] else ...[
                                        for (final pricing
                                            in _selectedPlan!.pricing) ...[
                                          const SizedBox(height: 8),
                                          _PlanCard(
                                            title: _periodLabelForMonths(
                                              pricing.period,
                                            ),
                                            priceLabel:
                                                'Rp. ${_idrFormatter.format(pricing.price)} for ${_periodLabelForMonths(pricing.period)}',
                                            isSelected:
                                                _selectedPricing?.id ==
                                                pricing.id,
                                            onTap: () {
                                              setState(() {
                                                _selectedPricing = pricing;
                                              });
                                            },
                                            highlightColor:
                                                SubscriptionCheckoutScreen
                                                    ._primaryBlue,
                                          ),
                                        ],
                                      ],
                                    ],
                                  ),
                          ),

                          const SizedBox(height: 20),

                          // ---------- PLAN SUMMARY ----------
                          _PlanSummaryTile(
                            selectedPlan: _selectedPlan,
                            selectedPricing: _selectedPricing,
                            formatter: _idrFormatter,
                          ),

                          const SizedBox(height: 20),

                          // ---------- PAYMENT METHOD ----------
                          if (_selectedPlan != null &&
                              _selectedPricing != null) ...[
                            const Text(
                              'Payment method',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(height: 10),

                            // One-time payment (payment_method = 3)
                            _PaymentMethodOption(
                              title: 'One-time payment',
                              subtitle:
                                  'Pay once for this premium period. No automatic renewal.',
                              value: 3,
                              groupValue: _selectedPaymentMethod,
                              onChanged: (v) {
                                setState(() {
                                  _selectedPaymentMethod = v!;
                                });
                              },
                            ),
                            const SizedBox(height: 8),

                            // Recurring card payment (payment_method = 2)
                            _PaymentMethodOption(
                              title: 'Recurring card payment',
                              subtitle:
                                  'Automatically billed every ${_periodLabelForMonths(_selectedPricing!.period)}.',
                              value: 2,
                              groupValue: _selectedPaymentMethod,
                              onChanged: (v) {
                                setState(() {
                                  _selectedPaymentMethod = v!;
                                });
                              },
                            ),
                            const SizedBox(height: 24),
                          ],
                        ],

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
                          bottomInfoText,
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
                            onPressed: !canProceed
                                ? null
                                : () {
                                    // 🔹 Di sini aku kirim ID pricing sebagai planId,
                                    // karena tiap kombinasi plan+period punya id sendiri.
                                    final planId = _selectedPlan!.idPlan;
                                    final pricingId = _selectedPricing!.id;
                                    subscription.goToPayment(
                                      context: context,
                                      planId: planId,
                                      pricingId: pricingId,
                                      paymentMethod: _selectedPaymentMethod,
                                    );
                                  },
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
// WIDGET: Payment Method Option (radio row)
// -------------------------------------------------------------
class _PaymentMethodOption extends StatelessWidget {
  final String title;
  final String subtitle;
  final int value;
  final int groupValue;
  final ValueChanged<int?> onChanged;

  const _PaymentMethodOption({
    required this.title,
    required this.subtitle,
    required this.value,
    required this.groupValue,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final bool selected = value == groupValue;

    return InkWell(
      onTap: () => onChanged(value),
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: selected
                ? SubscriptionCheckoutScreen._primaryBlue
                : Colors.grey.withOpacity(0.35),
            width: 1.5,
          ),
          color: selected
              ? SubscriptionCheckoutScreen._primaryBlue.withOpacity(0.03)
              : Colors.white,
        ),
        child: Row(
          children: [
            Radio<int>(
              value: value,
              groupValue: groupValue,
              activeColor: SubscriptionCheckoutScreen._primaryBlue,
              onChanged: onChanged,
            ),
            const SizedBox(width: 4),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: selected ? Colors.black : Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: const TextStyle(
                      fontSize: 11,
                      color: Colors.black54,
                      height: 1.3,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// -------------------------------------------------------------
// WIDGET: Plan Card (dipakai untuk pilih Plan & PlanPricing)
// -------------------------------------------------------------
class _PlanCard extends StatelessWidget {
  final String title;
  final String priceLabel;
  final bool isSelected;
  final VoidCallback? onTap;
  final Color highlightColor;
  final String? badgeText;

  /// kalau false → kartu abu2, tidak bisa di-tap, dan bisa pakai disabledCaption
  final bool enabled;
  final String? disabledCaption;

  const _PlanCard({
    required this.title,
    required this.priceLabel,
    required this.isSelected,
    required this.onTap,
    required this.highlightColor,
    this.badgeText,
    this.enabled = true,
    this.disabledCaption,
  });

  @override
  Widget build(BuildContext context) {
    final bool effectiveSelected = isSelected && enabled;

    final borderColor = !enabled
        ? Colors.grey.withOpacity(0.4)
        : (effectiveSelected ? highlightColor : Colors.grey.withOpacity(0.35));

    final bgColor = !enabled
        ? Colors.grey.shade100
        : (effectiveSelected ? highlightColor.withOpacity(0.04) : Colors.white);

    final titleColor = enabled ? Colors.black : Colors.black38;
    final priceColor = enabled ? Colors.black87 : Colors.black45;

    final String shownPrice = enabled
        ? priceLabel
        : (disabledCaption ?? priceLabel);

    return GestureDetector(
      onTap: enabled ? onTap : null,
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
                      Flexible(
                        child: Text(
                          title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 16,
                            color: titleColor,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      if (badgeText != null && enabled)
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
                    shownPrice,
                    style: TextStyle(fontSize: 14, color: priceColor),
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
                  color: effectiveSelected ? highlightColor : Colors.grey,
                  width: 2,
                ),
              ),
              child: Center(
                child: Container(
                  width: 12,
                  height: 12,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: effectiveSelected
                        ? highlightColor
                        : Colors.transparent,
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
// WIDGET: Plan Summary (pakai plan + pricing terpilih)
// -------------------------------------------------------------
class _PlanSummaryTile extends StatelessWidget {
  final PremiumPlan? selectedPlan;
  final PlanPricing? selectedPricing;
  final NumberFormat formatter;

  const _PlanSummaryTile({
    required this.selectedPlan,
    required this.selectedPricing,
    required this.formatter,
  });

  @override
  Widget build(BuildContext context) {
    if (selectedPlan == null || selectedPricing == null) {
      return Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: const Color(0xFFF8FAFF),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFE0E7FF)),
        ),
        child: Row(
          children: const [
            Icon(
              Icons.receipt_long_rounded,
              size: 20,
              color: SubscriptionCheckoutScreen._primaryBlue,
            ),
            SizedBox(width: 10),
            Expanded(
              child: Text(
                'No plan selected yet. Choose a premium plan and billing period above to see the billing summary.',
                style: TextStyle(fontSize: 12, color: Colors.black87),
              ),
            ),
          ],
        ),
      );
    }

    final months = selectedPricing!.period;
    final mainPrice = 'Rp. ${formatter.format(selectedPricing!.price)}';

    String periodLabel;
    String titleLabel;

    if (months == 1) {
      periodLabel = 'Month';
      titleLabel = 'Monthly billing selected for ${selectedPlan!.name}';
    } else if (months == 12) {
      periodLabel = 'Year';
      titleLabel = '12-month billing selected for ${selectedPlan!.name}';
    } else {
      periodLabel = '$months months';
      titleLabel = '$months-month billing selected for ${selectedPlan!.name}';
    }

    final effectiveMonthly = selectedPricing!.price / months;
    final effectiveText = 'Rp. ${formatter.format(effectiveMonthly.round())}';

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
                  titleLabel,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'You’ll pay $mainPrice every $periodLabel.',
                  style: const TextStyle(fontSize: 12, color: Colors.black87),
                ),
                const SizedBox(height: 2),
                Text(
                  'Effective monthly cost ~ $effectiveText.',
                  style: const TextStyle(fontSize: 11, color: Colors.black54),
                ),
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
