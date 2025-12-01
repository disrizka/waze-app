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

  // 🔹 Plan yang benar-benar dipilih user (bisa 1/3/6/12 bulan, dsb)
  PremiumPlan? _selectedPlan;

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
    if (months == 1) return 'month';
    if (months == 12) return 'year';
    return '$months months';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white, // background putih
      body: SafeArea(
        child: Consumer<SubscriptionProvider>(
          builder: (context, subscription, _) {
            final List<PremiumPlan> plans = subscription.plans;

            // 🔹 Cari plan 1 bulan (monthly), meski di API tidak ada → tetap bikin card
            PremiumPlan? monthlyPlan;
            final List<PremiumPlan> otherPlans = [];

            for (final p in plans) {
              if (!p.isActive) continue;

              if (p.months == 1 && monthlyPlan == null) {
                monthlyPlan = p;
              } else {
                otherPlans.add(p);
              }
            }

            // Sort other plans berdasarkan months (3,6,12,dst)
            otherPlans.sort((a, b) => a.months.compareTo(b.months));

            // 🔹 Set default _selectedPlan sekali saja, setelah data plan masuk
            if (!subscription.isLoadingPlans &&
                _selectedPlan == null &&
                (monthlyPlan != null || otherPlans.isNotEmpty)) {
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (!mounted) return;
                setState(() {
                  _selectedPlan = monthlyPlan ?? otherPlans.first;
                });
              });
            }

            // ---------- LABEL HARGA MONTHLY CARD ----------
            String monthlyPriceLabel;
            final bool monthlyAvailable = monthlyPlan != null;

            if (subscription.isLoadingPlans) {
              monthlyPriceLabel = 'Loading...';
            } else {
              if (monthlyAvailable) {
                final formatted = _idrFormatter.format(
                  monthlyPlan!.price.round(),
                );
                monthlyPriceLabel = 'Rp. $formatted /month';
              } else {
                monthlyPriceLabel = 'Not available yet';
              }
            }

            final bool canProceed =
                !subscription.isProcessing && _selectedPlan != null;

            // ---------- TEKS BAWAH TOMBOL (BOTTOM INFO) ----------
            String bottomInfoText;
            if (_selectedPlan == null) {
              bottomInfoText = 'Choose a plan to see how you will be charged.';
            } else if (_selectedPaymentMethod == 3) {
              // One-time payment
              bottomInfoText =
                  'You will be charged once for this ${_periodLabelForMonths(_selectedPlan!.months)} plan.';
            } else {
              // Recurring card payment
              bottomInfoText =
                  'You will be charged every ${_periodLabelForMonths(_selectedPlan!.months)}. Auto-renews unless canceled.';
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
                          'Select how you want to pay for premium features.',
                          style: TextStyle(fontSize: 13, color: Colors.black54),
                        ),

                        const SizedBox(height: 25),

                        // ---------- MONTHLY CARD (SELALU ADA) ----------
                        _PlanCard(
                          title: 'Monthly',
                          priceLabel: monthlyPriceLabel,
                          isSelected:
                              monthlyAvailable &&
                              _selectedPlan?.idPlan == monthlyPlan?.idPlan,
                          onTap: monthlyAvailable
                              ? () {
                                  setState(() {
                                    _selectedPlan = monthlyPlan;
                                  });
                                }
                              : null,
                          highlightColor:
                              SubscriptionCheckoutScreen._primaryBlue,
                          enabled: monthlyAvailable,
                          disabledCaption: 'Unavailable',
                        ),

                        const SizedBox(height: 12),

                        // ---------- PLAN LAIN DARI API (3, 6, 12 BULAN, DST) ----------
                        if (subscription.isLoadingPlans && plans.isEmpty) ...[
                          const Text(
                            'Loading plans...',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.black45,
                            ),
                          ),
                        ] else ...[
                          for (final plan in otherPlans) ...[
                            const SizedBox(height: 8),
                            _PlanCard(
                              title: '${plan.months} months',
                              priceLabel:
                                  'Rp. ${_idrFormatter.format(plan.price.round())} for ${plan.months} months',
                              isSelected: _selectedPlan?.idPlan == plan.idPlan,
                              onTap: () {
                                setState(() {
                                  _selectedPlan = plan;
                                });
                              },
                              highlightColor:
                                  SubscriptionCheckoutScreen._primaryBlue,
                            ),
                          ],
                        ],

                        const SizedBox(height: 20),

                        // ---------- PLAN SUMMARY ----------
                        _PlanSummaryTile(
                          selectedPlan: _selectedPlan,
                          formatter: _idrFormatter,
                        ),

                        const SizedBox(height: 20),

                        // ---------- PAYMENT METHOD ----------
                        if (_selectedPlan != null) ...[
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
                                'Automatically billed every ${_periodLabelForMonths(_selectedPlan!.months)}.',
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
                                    final planId = _selectedPlan!.idPlan;
                                    subscription.goToPayment(
                                      context: context,
                                      planId: planId,
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
// WIDGET: Plan Card (support disabled + "Not available yet")
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
                      Text(
                        title,
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 16,
                          color: titleColor,
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
// WIDGET: Plan Summary (pakai Rp + titik, berdasarkan selectedPlan)
// -------------------------------------------------------------
class _PlanSummaryTile extends StatelessWidget {
  final PremiumPlan? selectedPlan;
  final NumberFormat formatter;

  const _PlanSummaryTile({required this.selectedPlan, required this.formatter});

  @override
  Widget build(BuildContext context) {
    if (selectedPlan == null) {
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
                'No plan selected yet. Choose one of the premium plans above to see the billing summary.',
                style: TextStyle(fontSize: 12, color: Colors.black87),
              ),
            ),
          ],
        ),
      );
    }

    final months = selectedPlan!.months;
    final mainPrice = 'Rp. ${formatter.format(selectedPlan!.price.round())}';

    String periodLabel;
    String titleLabel;

    if (months == 1) {
      periodLabel = 'month';
      titleLabel = 'Monthly billing selected';
    } else if (months == 12) {
      periodLabel = 'year';
      titleLabel = '12-month plan selected';
    } else {
      periodLabel = '$months months';
      titleLabel = '$months-month plan selected';
    }

    final effectiveMonthly = selectedPlan!.price / months;
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
