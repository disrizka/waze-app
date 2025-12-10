import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../models/premium_plan_model.dart';
import '../../providers/subscription_provider.dart';
import '../../services/api_service.dart';

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
  bool _showOtherPayments = false;

  final NumberFormat _idrFormatter = NumberFormat('#,###', 'id_ID');

  // 🔹 0 = Step 1 (Plan), 1 = Step 2 (Payment)
  int _currentStep = 0;

  // 🔹 3 = One-time payment, 2 = Recurring card
  int _selectedPaymentMethod = 3;

  // 🔹 Plan utama yang dipilih (idPlan + name + list pricing)
  PremiumPlan? _selectedPlan;

  // 🔹 Pricing (durasi + harga) yang dipilih dari plan di atas
  PlanPricing? _selectedPricing;

  // 🔹 Voucher
  final TextEditingController _voucherC = TextEditingController();
  bool _isCheckingVoucher = false;
  String? _voucherMessage;
  int? _voucherDiscountValue; // nominal diskon (Rp)
  int? _voucherFinalPrice; // harga akhir setelah diskon (Rp)
  String? _appliedVoucherCode;

  @override
  void initState() {
    super.initState();
    _loadBusinessFromPrefs();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      final subscription = context.read<SubscriptionProvider>();
      subscription.fetchPremiumPlans(context);
    });
  }

  @override
  void dispose() {
    _voucherC.dispose();
    super.dispose();
  }

  Widget _buildPaymentMethodsSection() {
    if (_selectedPricing == null) {
      return const SizedBox.shrink();
    }

    // 🔢 Definisi semua metode pembayaran
    final List<_PaymentMethodData> methods = [
      _PaymentMethodData(
        value: 2,
        title: 'Credit Card',
        subtitle:
            'Automatically billed every ${_periodLabelForMonths(_selectedPricing!.period)}. Auto-renews unless canceled.',
      ),
      _PaymentMethodData(
        value: 6,
        title: 'QRIS',
        subtitle:
            'Pay once using QRIS via supported mobile banking or e-wallet.',
      ),
      _PaymentMethodData(
        value: 7,
        title: 'Mandiri Virtual Account',
        subtitle:
            'Pay once via Mandiri Bill Payment using your Mandiri account.',
      ),
      _PaymentMethodData(
        value: 8,
        title: 'Permata Virtual Account',
        subtitle: 'Pay once via Permata Bank virtual account.',
      ),
      _PaymentMethodData(
        value: 9,
        title: 'BCA Virtual Account',
        subtitle: 'Pay once via BCA virtual account.',
      ),
      _PaymentMethodData(
        value: 10,
        title: 'BNI Virtual Account',
        subtitle: 'Pay once via BNI virtual account.',
      ),
      _PaymentMethodData(
        value: 11,
        title: 'BRI Virtual Account',
        subtitle: 'Pay once via BRI virtual account.',
      ),
      // _PaymentMethodData(
      //   value: 12,
      //   title: 'CIMB Virtual Account',
      //   subtitle: 'Pay once via CIMB Niaga virtual account.',
      // ),
      // _PaymentMethodData(
      //   value: 13,
      //   title: 'Danamon Virtual Account',
      //   subtitle: 'Pay once via Danamon virtual account.',
      // ),
      // _PaymentMethodData(
      //   value: 14,
      //   title: 'BSI Virtual Account',
      //   subtitle: 'Pay once via BSI virtual account.',
      // ),
    ];

    // 🔹 Pisahkan Credit Card vs yang lain
    final _PaymentMethodData creditCardMethod = methods.firstWhere(
      (m) => m.value == 2,
    );
    final List<_PaymentMethodData> otherMethods = methods
        .where((m) => m.value != 2)
        .toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Payment method',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 10),

        // 🔝 Credit Card berdiri sendiri
        _PaymentMethodOption(
          title: creditCardMethod.title,
          subtitle: creditCardMethod.subtitle,
          value: creditCardMethod.value,
          groupValue: _selectedPaymentMethod,
          onChanged: (v) {
            setState(() {
              _selectedPaymentMethod = v!;
            });
          },
        ),

        const SizedBox(height: 12),

        // 🔻 Header accordion "Other Payment"
        InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () {
            setState(() {
              _showOtherPayments = !_showOtherPayments;
            });
          },
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: Colors.grey.withOpacity(0.35),
                width: 1.5,
              ),
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.account_balance_wallet_rounded,
                  size: 20,
                  color: Colors.black87,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: const [
                      Text(
                        'Other Payment',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      SizedBox(height: 2),
                      Text(
                        'QRIS & Virtual Account options.',
                        style: TextStyle(
                          fontSize: 11,
                          color: Colors.black54,
                          height: 1.3,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Icon(
                  _showOtherPayments
                      ? Icons.expand_less_rounded
                      : Icons.expand_more_rounded,
                  size: 20,
                  color: Colors.black87,
                ),
              ],
            ),
          ),
        ),

        // 🔽 Isi accordion: semua payment selain Credit Card
        AnimatedSize(
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeInOut,
          child: !_showOtherPayments
              ? const SizedBox.shrink()
              : Column(
                  children: [
                    const SizedBox(height: 8),
                    for (int i = 0; i < otherMethods.length; i++) ...[
                      if (i > 0) const SizedBox(height: 8),
                      _PaymentMethodOption(
                        title: otherMethods[i].title,
                        subtitle: otherMethods[i].subtitle,
                        value: otherMethods[i].value,
                        groupValue: _selectedPaymentMethod,
                        onChanged: (v) {
                          setState(() {
                            _selectedPaymentMethod = v!;
                          });
                        },
                      ),
                    ],
                  ],
                ),
        ),
      ],
    );
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

  String _periodLabelForMonths(int months) {
    return '$months months';
  }

  void _clearVoucherState() {
    _voucherMessage = null;
    _voucherDiscountValue = null;
    _voucherFinalPrice = null;
    _appliedVoucherCode = null;
    _voucherC.text = '';
  }

  Future<void> _checkVoucher(SubscriptionProvider subscription) async {
    final code = _voucherC.text.trim();

    if (_selectedPlan == null || _selectedPricing == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Please choose a plan and billing period before checking voucher.',
          ),
        ),
      );
      return;
    }

    if (code.isEmpty) {
      setState(() {
        _voucherMessage = 'Please enter a voucher code first.';
        _voucherDiscountValue = null;
        _voucherFinalPrice = null;
        _appliedVoucherCode = null;
      });
      return;
    }

    setState(() {
      _isCheckingVoucher = true;
      _voucherMessage = null;
    });

    try {
      // harga asli dari pricing yang dipilih (dalam rupiah)
      final int originalPrice = _selectedPricing!.price;

      // 🔗 panggil fungsi di SubscriptionProvider
      final result = await subscription.checkVoucher(
        context: context,
        code: code,
        originalPrice: originalPrice,
      );

      if (!mounted) return;

      setState(() {
        if (result.isValid) {
          // ✅ voucher valid → pakai nilai dari backend
          _voucherDiscountValue = result.discount;
          _voucherFinalPrice = result.finalPrice;
          _appliedVoucherCode = code;
          _voucherMessage = 'Voucher applied successfully.';
        } else {
          // ❌ voucher tidak valid → reset state & tampilkan pesan dari backend
          _voucherDiscountValue = null;
          _voucherFinalPrice = null;
          _appliedVoucherCode = null;
          _voucherMessage =
              result.message ?? 'Voucher is not valid for this plan / price.';
        }
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _voucherMessage = 'Failed to check voucher: $e';
        _voucherDiscountValue = null;
        _voucherFinalPrice = null;
        _appliedVoucherCode = null;
      });
    } finally {
      if (!mounted) return;
      setState(() {
        _isCheckingVoucher = false;
      });
    }
  }

  /// Ringkasan harga di bawah info & di atas tombol (Step 2)
  Widget _buildBottomPriceSummary() {
    if (_selectedPricing == null) return const SizedBox.shrink();

    final int originalPrice = _selectedPricing!.price;
    final bool hasVoucher =
        _voucherDiscountValue != null &&
        _voucherDiscountValue! > 0 &&
        _voucherFinalPrice != null;

    final int finalPrice = hasVoucher ? _voucherFinalPrice! : originalPrice;

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Subtotal',
                style: TextStyle(fontSize: 12, color: Colors.black54),
              ),
              Text(
                'Rp. ${_idrFormatter.format(originalPrice)}',
                style: const TextStyle(fontSize: 12, color: Colors.black87),
              ),
            ],
          ),
          if (hasVoucher) ...[
            const SizedBox(height: 4),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Voucher discount',
                  style: TextStyle(fontSize: 12, color: Colors.black54),
                ),
                Text(
                  '- Rp. ${_idrFormatter.format(_voucherDiscountValue!)}',
                  style: const TextStyle(fontSize: 12, color: Colors.green),
                ),
              ],
            ),
          ],
          const SizedBox(height: 6),
          const Divider(height: 1),
          const SizedBox(height: 6),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Total',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
              ),
              Text(
                'Rp. ${_idrFormatter.format(finalPrice)}',
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // 🔹 Accordion metode pembayaran (top 3 + see more)

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Consumer<SubscriptionProvider>(
          builder: (context, subscription, _) {
            final List<PremiumPlan> plans = subscription.plans
                .where((p) => p.isActive)
                .toList();

            final bool isLoadingPlans = subscription.isLoadingPlans;

            String bottomInfoText;
            if (_currentStep == 0) {
              if (_selectedPlan == null) {
                bottomInfoText = 'Choose a plan first to continue.';
              } else if (_selectedPricing == null) {
                bottomInfoText = 'Choose your billing period to continue.';
              } else {
                bottomInfoText =
                    'Tap Continue to enter voucher and choose your payment method.';
              }
            } else {
              if (_selectedPlan == null || _selectedPricing == null) {
                bottomInfoText =
                    'Please go back and choose a plan and billing period first.';
              } else if (_selectedPaymentMethod == 2) {
                // 2 = Midtrans Recurring Payment
                bottomInfoText =
                    'You will be charged every ${_periodLabelForMonths(_selectedPricing!.period)}. Auto-renews unless canceled.';
              } else {
                // Semua selain 2 dianggap sekali bayar (QRIS / VA / dll)
                bottomInfoText =
                    'You will be charged once for this ${_periodLabelForMonths(_selectedPricing!.period)} plan.';
              }
            }

            final bool voucherApplied =
                _appliedVoucherCode != null &&
                _voucherDiscountValue != null &&
                _voucherDiscountValue! > 0 &&
                _voucherFinalPrice != null;

            final bool canProceed =
                !subscription.isProcessing &&
                _selectedPlan != null &&
                _selectedPricing != null;

            String _buildPlanPriceLabel(PremiumPlan plan) {
              if (plan.pricing.isEmpty) {
                return 'No pricing available yet';
              }
              final minPrice = plan.pricing
                  .map((p) => p.price)
                  .reduce((a, b) => a < b ? a : b);
              return 'Starts from Rp. ${_idrFormatter.format(minPrice)}';
            }

            final String primaryButtonLabel = _currentStep == 0
                ? 'Continue'
                : 'Go to payment';

            return Column(
              children: [
                // ---------- HEADER (sticky) ----------
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  child: Row(
                    children: [
                      IconButton(
                        icon: const Icon(
                          Icons.arrow_back_ios_new_rounded,
                          size: 18,
                        ),
                        onPressed: () {
                          if (_currentStep == 0) {
                            Navigator.of(context).pop();
                          } else {
                            setState(() {
                              _currentStep = 0;
                            });
                          }
                        },
                      ),
                      const SizedBox(width: 2),
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
                      const SizedBox(width: 12),
                    ],
                  ),
                ),

                // ---------- STEPPER (sticky, sama seperti header) ----------
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 4, 20, 8),
                  child: _HorizontalLineStepper(currentStep: _currentStep),
                ),

                // ---------- CONTENT (scrollable) ----------
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 8,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // ⬇️ STEP 1 / STEP 2 content TANPA stepper lagi
                        if (_currentStep == 0) ...[
                          // STEP 1
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
                            style: TextStyle(
                              fontSize: 13,
                              color: Colors.black54,
                            ),
                          ),
                          const SizedBox(height: 20),

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
                            for (final plan in plans) ...[
                              const SizedBox(height: 8),
                              _PlanCard(
                                title: plan.name,
                                priceLabel: _buildPlanPriceLabel(plan),
                                isSelected:
                                    _selectedPlan?.idPlan == plan.idPlan,
                                onTap: () {
                                  setState(() {
                                    _selectedPlan = plan;
                                    _selectedPricing = null;
                                    _clearVoucherState();
                                  });
                                },
                                highlightColor:
                                    SubscriptionCheckoutScreen._primaryBlue,
                              ),
                            ],
                            const SizedBox(height: 20),
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
                                              borderRadius:
                                                  BorderRadius.circular(16),
                                              color: const Color(0xFFF8FAFF),
                                              border: Border.all(
                                                color: Color(0xFFE0E7FF),
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
                                                  _clearVoucherState();
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
                            const SizedBox(height: 24),
                          ],
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
                        ] else ...[
                          // STEP 2
                          const Text(
                            'Voucher & payment',
                            style: TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 4),
                          const Text(
                            'Review your plan, apply a voucher, and choose how you want to pay.',
                            style: TextStyle(
                              fontSize: 13,
                              color: Colors.black54,
                            ),
                          ),
                          const SizedBox(height: 20),
                          _PlanSummaryTile(
                            selectedPlan: _selectedPlan,
                            selectedPricing: _selectedPricing,
                            formatter: _idrFormatter,
                            voucherDiscount: _voucherDiscountValue,
                            voucherFinalPrice: _voucherFinalPrice,
                            voucherCode: _appliedVoucherCode,
                          ),
                          const SizedBox(height: 20),

                          if (_selectedPlan != null &&
                              _selectedPricing != null) ...[
                            const Text(
                              'Have a voucher?',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            Row(
                              children: [
                                Expanded(
                                  child: TextField(
                                    controller: _voucherC,
                                    enabled:
                                        !voucherApplied && !_isCheckingVoucher,
                                    decoration: const InputDecoration(
                                      labelText: 'Voucher code',
                                      hintText: 'Enter voucher code',
                                      border: OutlineInputBorder(),
                                      isDense: true,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                SizedBox(
                                  height: 48,
                                  child: ElevatedButton(
                                    onPressed: _isCheckingVoucher
                                        ? null
                                        : () {
                                            if (voucherApplied) {
                                              setState(() {
                                                _voucherMessage = null;
                                                _voucherDiscountValue = null;
                                                _voucherFinalPrice = null;
                                                _appliedVoucherCode = null;
                                              });
                                            } else {
                                              _checkVoucher(subscription);
                                            }
                                          },
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: Colors.black,
                                      foregroundColor: Colors.white,
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(
                                          999,
                                        ),
                                      ),
                                    ),
                                    child: _isCheckingVoucher
                                        ? const SizedBox(
                                            width: 16,
                                            height: 16,
                                            child: CircularProgressIndicator(
                                              strokeWidth: 2,
                                              valueColor:
                                                  AlwaysStoppedAnimation(
                                                    Colors.white,
                                                  ),
                                            ),
                                          )
                                        : Text(
                                            voucherApplied ? 'Change' : 'Check',
                                            style: const TextStyle(
                                              fontSize: 13,
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 6),
                            if (_voucherMessage != null &&
                                _voucherMessage!.isNotEmpty)
                              Text(
                                _voucherMessage!,
                                style: TextStyle(
                                  fontSize: 11,
                                  color:
                                      (_voucherDiscountValue != null &&
                                          _voucherDiscountValue! > 0 &&
                                          _voucherFinalPrice != null)
                                      ? Colors.green
                                      : Colors.red,
                                ),
                              ),
                            const SizedBox(height: 10),
                            _buildPaymentMethodsSection(),

                            const SizedBox(height: 24),
                          ] else ...[
                            const Text(
                              'Please go back to Step 1 and choose a plan and billing period.',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.black54,
                              ),
                            ),
                            const SizedBox(height: 16),
                          ],
                        ],
                      ],
                    ),
                  ),
                ),

                // ---------- BOTTOM SECTION ----------
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

                        if (_currentStep == 1 && _selectedPricing != null) ...[
                          _buildBottomPriceSummary(),
                          const SizedBox(height: 8),
                        ],

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
                                    if (_currentStep == 0) {
                                      setState(() => _currentStep = 1);
                                    } else {
                                      final planId = _selectedPlan!.idPlan;
                                      final pricingId = _selectedPricing!.id;
                                      final voucherCode =
                                          (_voucherFinalPrice != null &&
                                              _appliedVoucherCode != null)
                                          ? _appliedVoucherCode!
                                          : '';

                                      subscription.goToPayment(
                                        context: context,
                                        planId: planId,
                                        pricingId: pricingId,
                                        paymentMethod: _selectedPaymentMethod,
                                        voucherCode: voucherCode,
                                      );
                                    }
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
                                : Text(
                                    primaryButtonLabel,
                                    style: const TextStyle(
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

/// STEP INDICATOR: line horizontal seperti screenshot
/// STEP INDICATOR: line horizontal seperti screenshot
class _HorizontalLineStepper extends StatelessWidget {
  final int currentStep;

  const _HorizontalLineStepper({required this.currentStep});

  @override
  Widget build(BuildContext context) {
    final blue = SubscriptionCheckoutScreen._primaryBlue;
    final grey = Colors.grey.shade400;

    TextStyle labelStyle({required bool isActive, required bool isDone}) {
      // ✅ step aktif & step yang sudah lewat sama-sama biru
      final Color color = (isActive || isDone) ? blue : Colors.grey.shade500;
      final FontWeight weight = isActive ? FontWeight.w700 : FontWeight.w500;

      return TextStyle(fontSize: 14, fontWeight: weight, color: color);
    }

    Color barColor({required bool isActive, required bool isDone}) {
      // ✅ bar biru kalau aktif ATAU sudah lewat
      return (isActive || isDone) ? blue : grey.withOpacity(0.3);
    }

    Widget _buildStep(String title, int index) {
      final bool isActive = currentStep == index;
      final bool isDone = currentStep > index;

      return Column(
        crossAxisAlignment: CrossAxisAlignment.start, // ✅ rata kiri
        children: [
          Text(
            title,
            style: labelStyle(isActive: isActive, isDone: isDone),
          ),
          const SizedBox(height: 4),
          Container(
            height: 3,
            width: double.infinity,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(999),
              color: barColor(isActive: isActive, isDone: isDone),
            ),
          ),
        ],
      );
    }

    // Deskripsi aktif di bawah judul stepper
    String description;
    if (currentStep == 0) {
      description = 'Choose your premium plan and billing period.';
    } else {
      description = 'Review your plan, voucher, and payment method.';
    }

    return Column(
      crossAxisAlignment:
          CrossAxisAlignment.start, // ✅ deskripsi ikut rata kiri
      children: [
        Row(
          children: [
            Expanded(child: _buildStep('Choose your plan', 0)),
            const SizedBox(width: 16),
            Expanded(child: _buildStep('Payment', 1)),
          ],
        ),
        const SizedBox(height: 6),
        Text(
          description,
          style: const TextStyle(fontSize: 11, color: Colors.black54),
        ),
      ],
    );
  }
}

// -------------------------------------------------------------
// WIDGET: Payment Method Option (radio row)
// -------------------------------------------------------------
class _PaymentMethodData {
  final int value;
  final String title;
  final String subtitle;

  const _PaymentMethodData({
    required this.value,
    required this.title,
    required this.subtitle,
  });
}

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
// WIDGET: Plan Card
// -------------------------------------------------------------
class _PlanCard extends StatelessWidget {
  final String title;
  final String priceLabel;
  final bool isSelected;
  final VoidCallback? onTap;
  final Color highlightColor;
  final String? badgeText;
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
// WIDGET: Plan Summary
// -------------------------------------------------------------
class _PlanSummaryTile extends StatelessWidget {
  final PremiumPlan? selectedPlan;
  final PlanPricing? selectedPricing;
  final NumberFormat formatter;

  final int? voucherDiscount;
  final int? voucherFinalPrice;
  final String? voucherCode;

  const _PlanSummaryTile({
    required this.selectedPlan,
    required this.selectedPricing,
    required this.formatter,
    this.voucherDiscount,
    this.voucherFinalPrice,
    this.voucherCode,
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
                'No plan selected yet. Choose a premium plan and billing period in Step 1 to see the billing summary.',
                style: TextStyle(fontSize: 12, color: Colors.black87),
              ),
            ),
          ],
        ),
      );
    }

    final months = selectedPricing!.period;
    final int originalPrice = selectedPricing!.price;
    final int effectivePrice = voucherFinalPrice ?? originalPrice;

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

    final mainPrice = 'Rp. ${formatter.format(effectivePrice)}';
    final effectiveMonthly = effectivePrice / months;
    final effectiveText = 'Rp. ${formatter.format(effectiveMonthly.round())}';

    final hasVoucher =
        voucherDiscount != null &&
        voucherDiscount! > 0 &&
        voucherFinalPrice != null;

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
                // if (hasVoucher) ...[
                //   const SizedBox(height: 6),
                //   Text(
                //     'Original price: Rp. ${formatter.format(originalPrice)}',
                //     style: const TextStyle(
                //       fontSize: 11,
                //       color: Colors.black54,
                //       decoration: TextDecoration.lineThrough,
                //     ),
                //   ),
                //   Text(
                //     'Voucher discount: - Rp. ${formatter.format(voucherDiscount)}',
                //     style: const TextStyle(fontSize: 11, color: Colors.black87),
                //   ),
                //   Text(
                //     'Total after voucher: Rp. ${formatter.format(voucherFinalPrice)}'
                //     '${voucherCode != null ? ' (code: $voucherCode)' : ''}',
                //     style: const TextStyle(
                //       fontSize: 11,
                //       fontWeight: FontWeight.w600,
                //     ),
                //   ),
                // ],
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
