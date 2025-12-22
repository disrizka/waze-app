import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:wa_blast/constants/app_colors.dart';

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
  int _selectedPaymentMethod = 2;

  PremiumPlan? _selectedPlan;
  PlanPricing? _selectedPricing;

  // 🔹 Voucher
  final TextEditingController _voucherC = TextEditingController();
  bool _isCheckingVoucher = false;
  String? _voucherMessage;

  int? _voucherDiscountValue; // Rp
  int? _voucherFinalPrice; // Rp
  int? _voucherOriginalPrice; // Rp (as returned by backend)

  String? _appliedVoucherCode;
  String? _voucherName;
  String? _voucherDesc;

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

  String _money(int v) => 'Rp. ${_idrFormatter.format(v)}';

  // ---------------------------------------------------------------------------
  // PAYMENT METHODS SECTION
  // ---------------------------------------------------------------------------
  Widget _buildPaymentMethodsSection() {
    if (_selectedPricing == null) return const SizedBox.shrink();

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
    ];

    final creditCardMethod = methods.firstWhere((m) => m.value == 2);
    final otherMethods = methods.where((m) => m.value != 2).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Payment method',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 2),
        const Text(
          'Choose one option to continue your payment.',
          style: TextStyle(fontSize: 12, color: Colors.black54, height: 1.3),
        ),
        const SizedBox(height: 12),

        // Primary
        _PaymentRadioTileMinimal(
          title: creditCardMethod.title,
          subtitle: creditCardMethod.subtitle,
          value: creditCardMethod.value,
          groupValue: _selectedPaymentMethod,
          leadingIcon: Icons.credit_card_rounded,
          onChanged: (v) => setState(() => _selectedPaymentMethod = v),
        ),

        const SizedBox(height: 10),

        // Other payments (collapsible)
        InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: () => setState(() => _showOtherPayments = !_showOtherPayments),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: Colors.black.withOpacity(0.10),
                width: 1.2,
              ),
              color: Colors.white,
            ),
            child: Row(
              children: [
                const Icon(Icons.account_balance_wallet_rounded, size: 20),
                const SizedBox(width: 10),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Other payments',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      SizedBox(height: 2),
                      Text(
                        'QRIS & Virtual Account options.',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.black54,
                          height: 1.3,
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(
                  _showOtherPayments
                      ? Icons.expand_less_rounded
                      : Icons.expand_more_rounded,
                  size: 22,
                ),
              ],
            ),
          ),
        ),

        AnimatedSize(
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeInOut,
          child: !_showOtherPayments
              ? const SizedBox.shrink()
              : Padding(
                  padding: const EdgeInsets.only(top: 10),
                  child: Column(
                    children: [
                      for (int i = 0; i < otherMethods.length; i++) ...[
                        if (i > 0) const SizedBox(height: 8),
                        _PaymentRadioTileMinimal(
                          title: otherMethods[i].title,
                          subtitle: otherMethods[i].subtitle,
                          value: otherMethods[i].value,
                          groupValue: _selectedPaymentMethod,
                          leadingIcon: otherMethods[i].value == 6
                              ? Icons.qr_code_rounded
                              : Icons.account_balance_rounded,
                          onChanged: (v) =>
                              setState(() => _selectedPaymentMethod = v),
                        ),
                      ],
                    ],
                  ),
                ),
        ),
      ],
    );
  }

  // ---------------------------------------------------------------------------
  // PREFS HEADER
  // ---------------------------------------------------------------------------
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

  String _periodLabelForMonths(int months) => '$months months';

  void _clearVoucherState() {
    _voucherMessage = null;
    _voucherDiscountValue = null;
    _voucherFinalPrice = null;
    _voucherOriginalPrice = null;
    _appliedVoucherCode = null;
    _voucherName = null;
    _voucherDesc = null;
    _voucherC.text = '';
  }

  bool get _voucherApplied =>
      _appliedVoucherCode != null &&
      _voucherDiscountValue != null &&
      _voucherDiscountValue! > 0 &&
      _voucherFinalPrice != null;

  // ---------------------------------------------------------------------------
  // CHECK VOUCHER
  // ---------------------------------------------------------------------------
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
      setState(() => _voucherMessage = 'Please enter a voucher code first.');
      return;
    }

    setState(() {
      _isCheckingVoucher = true;
      _voucherMessage = null;
    });

    try {
      final int originalPrice = _selectedPricing!.price;

      final result = await subscription.checkVoucher(
        context: context,
        code: code,
        originalPrice: originalPrice,
      );

      if (!mounted) return;

      setState(() {
        if (result.isValid) {
          _voucherDiscountValue = result.discount;
          _voucherFinalPrice = result.finalPrice;
          _voucherOriginalPrice = result.originalPrice;
          _appliedVoucherCode = code;
          _voucherName = result.voucherName;
          _voucherDesc = result.voucherDesc;

          // ✅ input langsung dibersihkan & hilang dari UI karena applied
          _voucherC.text = '';
          FocusManager.instance.primaryFocus?.unfocus();

          _voucherMessage = null;
        } else {
          _voucherDiscountValue = null;
          _voucherFinalPrice = null;
          _voucherOriginalPrice = null;
          _appliedVoucherCode = null;
          _voucherName = null;
          _voucherDesc = null;

          final msg =
              result.message ?? 'Voucher is not valid for this plan / price.';

          // ✅ jangan tampil card merah, langsung modal
          _voucherMessage = null;

          // tampilkan modal setelah setState selesai
          WidgetsBinding.instance.addPostFrameCallback((_) {
            _showVoucherErrorModal(title: 'Voucher Invalid', message: msg);
          });
        }
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _voucherMessage = 'Failed to check voucher: $e';
        _voucherDiscountValue = null;
        _voucherFinalPrice = null;
        _voucherOriginalPrice = null;
        _appliedVoucherCode = null;
        _voucherName = null;
        _voucherDesc = null;
      });
    } finally {
      if (!mounted) return;
      setState(() => _isCheckingVoucher = false);
    }
  }

  void _removeVoucher() {
    setState(() {
      _voucherMessage = null;
      _voucherDiscountValue = null;
      _voucherFinalPrice = null;
      _voucherOriginalPrice = null;
      _appliedVoucherCode = null;
      _voucherName = null;
      _voucherDesc = null;

      // ✅ input muncul lagi (kosong) setelah remove
      _voucherC.text = '';
    });
  }

  // ---------------------------------------------------------------------------
  // UI: VOUCHER SECTION (INPUT HILANG KETIKA APPLIED + REMOVE DI CARD HIJAU)
  // ---------------------------------------------------------------------------
  Widget _buildVoucherSection(SubscriptionProvider subscription) {
    if (_selectedPlan == null || _selectedPricing == null) {
      return const SizedBox.shrink();
    }

    final bool applied = _voucherApplied;

    // Harga
    final int originalPrice = _selectedPricing!.price;
    final int beforePrice = _voucherOriginalPrice ?? originalPrice;
    final int discount = _voucherDiscountValue ?? 0;
    final int afterPrice = _voucherFinalPrice ?? originalPrice;

    // Optional label diskon “30%” kalau kamu mau tampilkan
    String? discountLabel;
    if (beforePrice > 0 && discount > 0) {
      final pct = ((discount / beforePrice) * 100).round();
      if (pct > 0 && pct < 100) discountLabel = '$pct%';
    }

    Widget sectionHeader() {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: const [
          Text(
            'Have a voucher?',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
          ),
          SizedBox(height: 6),
          Text(
            'Enter your voucher code and we’ll calculate your savings instantly.',
            style: TextStyle(fontSize: 12, color: Colors.black54, height: 1.35),
          ),
          SizedBox(height: 12),
        ],
      );
    }

    Widget inputCard() {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ✅ Minimal voucher input row
          Row(
            children: [
              // Leading icon (small)
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: SubscriptionCheckoutScreen._primaryBlue.withOpacity(
                    0.10,
                  ),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.local_offer_rounded,
                  size: 18,
                  color: SubscriptionCheckoutScreen._primaryBlue,
                ),
              ),
              const SizedBox(width: 10),

              // Input
              Expanded(
                child: TextField(
                  controller: _voucherC,
                  enabled: !_isCheckingVoucher,
                  textCapitalization: TextCapitalization.characters,
                  decoration: InputDecoration(
                    hintText: 'Voucher code',
                    hintStyle: const TextStyle(
                      fontSize: 13,
                      color: Color(0xFF9CA3AF),
                      fontWeight: FontWeight.w600,
                    ),
                    isDense: true,
                    filled: true,
                    fillColor: const Color(0xFFF9FAFB),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 12,
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: const BorderSide(
                        color: SubscriptionCheckoutScreen._primaryBlue,
                        width: 1.4,
                      ),
                    ),
                    suffixIcon: _voucherC.text.trim().isEmpty
                        ? null
                        : IconButton(
                            tooltip: 'Clear',
                            onPressed: _isCheckingVoucher
                                ? null
                                : () => setState(() => _voucherC.clear()),
                            icon: const Icon(Icons.close_rounded, size: 18),
                          ),
                  ),
                  onChanged: (_) => setState(() {}),
                  onSubmitted: (_) =>
                      _isCheckingVoucher ? null : _checkVoucher(subscription),
                ),
              ),
              const SizedBox(width: 10),

              // Apply button (compact)
              SizedBox(
                height: 44,
                child: ElevatedButton(
                  onPressed: _isCheckingVoucher
                      ? null
                      : () => _checkVoucher(subscription),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: SubscriptionCheckoutScreen._primaryBlue,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(horizontal: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  child: _isCheckingVoucher
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation(Colors.white),
                          ),
                        )
                      : const Text(
                          'Apply',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                ),
              ),
            ],
          ),

          // ✅ Minimal error message
          if ((_voucherMessage ?? '').trim().isNotEmpty) ...[
            const SizedBox(height: 8),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: const Color(0xFFFFF1F2),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: const Color(0xFFFECACA)),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: const [
                  Icon(
                    Icons.error_outline_rounded,
                    size: 18,
                    color: Color(0xFFEF4444),
                  ),
                  SizedBox(width: 8),
                  Expanded(child: _VoucherErrorText()),
                ],
              ),
            ),
          ],
        ],
      );
    }

    Widget appliedCard() {
      final code = (_appliedVoucherCode ?? '').toUpperCase();

      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          color: const Color(0xFFE9F9EF),
          border: Border.all(color: const Color(0xFFBFECCB)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ✅ Header rapi: kiri (icon+title) kanan (remove)
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(16),
                    color: const Color(0xFF16A34A),
                  ),
                  child: const Icon(
                    Icons.verified_rounded,
                    color: Colors.white,
                    size: 22,
                  ),
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Text(
                    'Voucher applied',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w900,
                      color: Color(0xFF0F172A),
                    ),
                  ),
                ),
                TextButton.icon(
                  onPressed: _removeVoucher,
                  icon: const Icon(Icons.close_rounded, size: 16),
                  label: const Text(
                    'Remove',
                    style: TextStyle(fontWeight: FontWeight.w800),
                  ),
                  style: TextButton.styleFrom(
                    foregroundColor: const Color(0xFF991B1B),
                    backgroundColor: Colors.white.withOpacity(0.65),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 10,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(999),
                      side: const BorderSide(color: Color(0xFFFECACA)),
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 12),

            // ✅ Chip + Savings (Wrap biar responsif, gak maksa 1 baris)
            Wrap(
              spacing: 10,
              runSpacing: 8,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 7,
                  ),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(999),
                    color: const Color(0xFFDCFCE7),
                    border: Border.all(color: const Color(0xFF86EFAC)),
                  ),
                  child: Text(
                    code,
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w900,
                      color: Color(0xFF166534),
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
                Text(
                  'You saved ${_money(discount)} 🎉',
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w900,
                    color: Color(0xFF0F172A),
                  ),
                ),
              ],
            ),

            // ✅ Nama/desc rapi, ringkas
            if ((_voucherName ?? '').trim().isNotEmpty ||
                (_voucherDesc ?? '').trim().isNotEmpty ||
                (discountLabel != null)) ...[
              const SizedBox(height: 10),
              if ((_voucherName ?? '').trim().isNotEmpty) ...[
                Text(
                  _voucherName!.trim(),
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w900,
                    color: Color(0xFF14532D),
                  ),
                ),
                const SizedBox(height: 6),
              ],
              if ((_voucherDesc ?? '').trim().isNotEmpty)
                Text(
                  _voucherDesc!.trim(),
                  style: const TextStyle(
                    fontSize: 11,
                    height: 1.35,
                    color: Color(0xFF166534),
                    fontWeight: FontWeight.w600,
                  ),
                ),
            ],

            const SizedBox(height: 12),

            // ✅ Before/After rapi & sejajar
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                color: Colors.white,
                border: Border.all(color: const Color(0xFFE5E7EB)),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Before',
                          style: TextStyle(
                            fontSize: 10,
                            color: Color(0xFF64748B),
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          _money(beforePrice),
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w900,
                            color: Color(0xFF0F172A),
                            decoration: TextDecoration.lineThrough,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Icon(
                    Icons.arrow_forward_rounded,
                    size: 18,
                    color: Color(0xFF64748B),
                  ),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        const Text(
                          'After',
                          style: TextStyle(
                            fontSize: 10,
                            color: Color(0xFF64748B),
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          _money(afterPrice),
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w900,
                            color: Color(0xFF0F172A),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }

    // ✅ Section title + desc jangan hilang
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 10),
        sectionHeader(),
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 220),
          child: applied ? appliedCard() : inputCard(),
        ),
        const SizedBox(height: 30),
      ],
    );
  }

  Future<void> _showVoucherErrorModal({
    required String title,
    required String message,
  }) async {
    if (!mounted) return;

    const blue = SubscriptionCheckoutScreen._primaryBlue;

    await showDialog(
      context: context,
      barrierDismissible: true,
      barrierColor: Colors.black.withOpacity(0.35),
      builder: (ctx) {
        return Dialog(
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(22),
          ),
          insetPadding: const EdgeInsets.symmetric(
            horizontal: 18,
            vertical: 24,
          ),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(18, 16, 18, 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Header: spacer + close button
                Row(
                  children: [
                    const Spacer(),
                    IconButton(
                      onPressed: () => Navigator.of(ctx).pop(),
                      icon: const Icon(Icons.close_rounded),
                      splashRadius: 20,
                      tooltip: 'Close',
                    ),
                  ],
                ),

                // Icon badge
                Container(
                  width: 64,
                  height: 64,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(22),
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [blue.withOpacity(0.18), blue.withOpacity(0.08)],
                    ),
                    border: Border.all(color: blue.withOpacity(0.18)),
                  ),
                  child: const Icon(
                    Icons.local_offer_rounded,
                    color: blue,
                    size: 30,
                  ),
                ),

                const SizedBox(height: 14),

                Text(
                  title,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w900,
                    color: Color(0xFF111827),
                  ),
                ),

                const SizedBox(height: 8),

                Text(
                  message,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 12,
                    height: 1.45,
                    color: Color(0xFF6B7280),
                    fontWeight: FontWeight.w600,
                  ),
                ),

                const SizedBox(height: 18),

                Row(
                  children: [
                    Expanded(
                      child: TextButton(
                        onPressed: () => Navigator.of(ctx).pop(),
                        style: TextButton.styleFrom(
                          foregroundColor: const Color(0xFF111827),
                          backgroundColor: const Color(0xFFF3F4F6),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(999),
                          ),
                        ),
                        child: const Text(
                          'Close',
                          style: TextStyle(fontWeight: FontWeight.w800),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () {
                          Navigator.of(ctx).pop();
                          // opsional: fokus balik ke input
                          Future.delayed(const Duration(milliseconds: 120), () {
                            if (!mounted) return;
                            FocusManager.instance.primaryFocus?.unfocus();
                          });
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: blue,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(999),
                          ),
                        ),
                        child: const Text(
                          'Try again',
                          style: TextStyle(fontWeight: FontWeight.w900),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  // ---------------------------------------------------------------------------
  // BOTTOM SUMMARY
  // ---------------------------------------------------------------------------
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
                _money(originalPrice),
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
                  '- ${_money(_voucherDiscountValue!)}',
                  style: const TextStyle(
                    fontSize: 12,
                    color: Colors.green,
                    fontWeight: FontWeight.w700,
                  ),
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
                _money(finalPrice),
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

  // ---------------------------------------------------------------------------
  // BUILD
  // ---------------------------------------------------------------------------
  @override
  Widget build(BuildContext context) {
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
                bottomInfoText =
                    'You will be charged every ${_periodLabelForMonths(_selectedPricing!.period)}. Auto-renews unless canceled.';
              } else {
                bottomInfoText =
                    'You will be charged once for this ${_periodLabelForMonths(_selectedPricing!.period)} plan.';
              }
            }

            final bool canProceed =
                !subscription.isProcessing &&
                _selectedPlan != null &&
                _selectedPricing != null;

            String _buildPlanPriceLabel(PremiumPlan plan) {
              if (plan.pricing.isEmpty) return 'No pricing available yet';
              final minPrice = plan.pricing
                  .map((p) => p.price)
                  .reduce((a, b) => a < b ? a : b);
              return 'Starts from ${_money(minPrice)}';
            }

            final String primaryButtonLabel = _currentStep == 0
                ? 'Continue'
                : 'Go to payment';

            return Column(
              children: [
                // ---------- HEADER ----------
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
                            setState(() => _currentStep = 0);
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
                                _businessUsername.isNotEmpty)
                              Text(
                                '@$_businessUsername',
                                style: const TextStyle(
                                  fontSize: 11,
                                  color: Colors.black45,
                                ),
                              ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 12),
                    ],
                  ),
                ),

                // ---------- STEPPER ----------
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 4, 20, 8),
                  child: _HorizontalLineStepper(currentStep: _currentStep),
                ),

                // ---------- CONTENT ----------
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 8,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (_currentStep == 0) ...[
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
                                        if (_selectedPlan!.pricing.isEmpty)
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
                                          )
                                        else
                                          for (final pricing
                                              in _selectedPlan!.pricing) ...[
                                            const SizedBox(height: 8),
                                            _PlanCard(
                                              title: _periodLabelForMonths(
                                                pricing.period,
                                              ),
                                              priceLabel:
                                                  '${_money(pricing.price)} for ${_periodLabelForMonths(pricing.period)}',
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
                          const Text(
                            'Payment',
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

                          const SizedBox(height: 16),

                          // ✅ Voucher UI (input hilang saat applied + remove di card hijau)
                          _buildVoucherSection(subscription),

                          _buildPaymentMethodsSection(),
                          const SizedBox(height: 24),
                        ],
                      ],
                    ),
                  ),
                ),

                // ---------- BOTTOM ----------
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
                              backgroundColor: AppColors.blueButton,
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
                                      final voucherCode = _voucherApplied
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

/// STEP INDICATOR
class _HorizontalLineStepper extends StatelessWidget {
  final int currentStep;

  const _HorizontalLineStepper({required this.currentStep});

  @override
  Widget build(BuildContext context) {
    final blue = SubscriptionCheckoutScreen._primaryBlue;
    final grey = Colors.grey.shade400;

    TextStyle labelStyle({required bool isActive, required bool isDone}) {
      final Color color = (isActive || isDone) ? blue : Colors.grey.shade500;
      final FontWeight weight = isActive ? FontWeight.w700 : FontWeight.w500;
      return TextStyle(fontSize: 14, fontWeight: weight, color: color);
    }

    Color barColor({required bool isActive, required bool isDone}) {
      return (isActive || isDone) ? blue : grey.withOpacity(0.3);
    }

    Widget _buildStep(String title, int index) {
      final bool isActive = currentStep == index;
      final bool isDone = currentStep > index;

      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
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

    final description = currentStep == 0
        ? 'Choose your premium plan and billing period.'
        : 'Review your plan, voucher, and payment method.';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
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

/// Supaya build utama lebih ringkas (text-nya tetap ambil dari state)
class _VoucherErrorText extends StatelessWidget {
  const _VoucherErrorText();

  @override
  Widget build(BuildContext context) {
    // ambil _voucherMessage dari parent lewat Inherited? tidak bisa.
    // jadi kalau kamu tidak mau class terpisah, hapus widget ini dan inline Text saja.
    return const SizedBox.shrink();
  }
}

// -------------------------------------------------------------
// WIDGET: Payment Method Option
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

class _PaymentRadioTile extends StatelessWidget {
  const _PaymentRadioTile({
    required this.title,
    required this.subtitle,
    required this.value,
    required this.groupValue,
    required this.onChanged,
    required this.leading,
  });

  final String title;
  final String subtitle;
  final int value;
  final int? groupValue;
  final ValueChanged<int> onChanged;
  final Widget leading;

  @override
  Widget build(BuildContext context) {
    const primary = Color(0xFF4C6EF5);
    final selected = groupValue == value;

    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: () => onChanged(value),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOut,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          color: selected ? primary.withOpacity(0.07) : Colors.transparent,
          border: Border.all(
            color: selected
                ? primary.withOpacity(0.45)
                : Colors.black.withOpacity(0.10),
            width: 1.2,
          ),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(
                color: selected
                    ? primary.withOpacity(0.12)
                    : Colors.black.withOpacity(0.05),
                borderRadius: BorderRadius.circular(10),
              ),
              child: IconTheme(
                data: IconThemeData(color: selected ? primary : Colors.black87),
                child: Center(child: leading),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                      color: selected ? Colors.black : Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    subtitle,
                    style: const TextStyle(
                      fontSize: 12,
                      color: Colors.black54,
                      height: 1.35,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Transform.translate(
              offset: const Offset(0, -2),
              child: Radio<int>(
                value: value,
                groupValue: groupValue,
                activeColor: primary,
                onChanged: (v) => onChanged(v!),
                materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                visualDensity: const VisualDensity(
                  horizontal: -2,
                  vertical: -2,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PaymentRadioTileMinimal extends StatelessWidget {
  const _PaymentRadioTileMinimal({
    required this.title,
    required this.subtitle,
    required this.value,
    required this.groupValue,
    required this.onChanged,
    required this.leadingIcon,
  });

  final String title;
  final String subtitle;
  final int value;
  final int? groupValue;
  final ValueChanged<int> onChanged;
  final IconData leadingIcon;

  @override
  Widget build(BuildContext context) {
    const primary = Color(0xFF4C6EF5);
    final selected = groupValue == value;

    return InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: () => onChanged(value),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: selected
                ? primary.withOpacity(0.45)
                : Colors.black.withOpacity(0.10),
            width: 1.2,
          ),
          color: selected ? primary.withOpacity(0.06) : Colors.white,
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(
              leadingIcon,
              size: 20,
              color: selected ? primary : Colors.black87,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: const TextStyle(
                      fontSize: 12,
                      color: Colors.black54,
                      height: 1.3,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Transform.translate(
              offset: const Offset(0, -2),
              child: Radio<int>(
                value: value,
                groupValue: groupValue,
                activeColor: primary,
                materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                visualDensity: const VisualDensity(
                  horizontal: -2,
                  vertical: -2,
                ),
                onChanged: (v) => onChanged(v!),
              ),
            ),
          ],
        ),
      ),
    );
  }
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

  String _money(int v) => 'Rp. ${formatter.format(v)}';

  String _periodLabel(int months) {
    if (months == 1) return 'Monthly';
    if (months == 12) return 'Yearly';
    return '$months months';
  }

  String _cycleText(int months) {
    if (months == 1) return 'every month';
    if (months == 12) return 'every year';
    return 'every $months months';
  }

  Widget _dashedDivider() {
    return LayoutBuilder(
      builder: (context, c) {
        final dashW = 6.0;
        final dashH = 1.2;
        final dashCount = (c.maxWidth / (dashW + 4)).floor();
        return Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: List.generate(dashCount, (_) {
            return SizedBox(
              width: dashW,
              height: dashH,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: const Color(0xFFE5E7EB),
                  borderRadius: BorderRadius.circular(99),
                ),
              ),
            );
          }),
        );
      },
    );
  }

  Widget _billRow({
    required String label,
    required String value,
    bool isMuted = false,
    bool isBold = false,
    bool isNegative = false,
  }) {
    final labelStyle = TextStyle(
      fontSize: 12,
      height: 1.3,
      color: isMuted ? const Color(0xFF6B7280) : const Color(0xFF111827),
      fontWeight: isBold ? FontWeight.w800 : FontWeight.w600,
    );

    final valueStyle = TextStyle(
      fontSize: 12,
      height: 1.3,
      color: isNegative ? const Color(0xFF16A34A) : const Color(0xFF111827),
      fontWeight: isBold ? FontWeight.w900 : FontWeight.w700,
    );

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Expanded(child: Text(label, style: labelStyle)),
          const SizedBox(width: 10),
          Text(value, style: valueStyle),
        ],
      ),
    );
  }

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
    final bool hasVoucher =
        (voucherDiscount ?? 0) > 0 && (voucherFinalPrice ?? 0) > 0;

    final int discount = hasVoucher ? (voucherDiscount ?? 0) : 0;
    final int total = hasVoucher
        ? (voucherFinalPrice ?? originalPrice)
        : originalPrice;

    final String planName = selectedPlan!.name;
    final String periodLabel = _periodLabel(months);
    final String cycleText = _cycleText(months);

    // Effective monthly cost
    final int effectiveMonthly = (total / months).round();

    // Optional % badge
    String? pctText;
    if (hasVoucher && originalPrice > 0 && discount > 0) {
      final pct = ((discount / originalPrice) * 100).round();
      if (pct > 0 && pct < 100) pctText = '$pct%';
    }

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFF),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE0E7FF)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header (bill style)
          Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(14),
                  color: SubscriptionCheckoutScreen._primaryBlue.withOpacity(
                    0.12,
                  ),
                ),
                child: const Icon(
                  Icons.receipt_long_rounded,
                  color: SubscriptionCheckoutScreen._primaryBlue,
                  size: 22,
                ),
              ),
              const SizedBox(width: 10),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Summary',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w900,
                        color: Color(0xFF111827),
                      ),
                    ),
                    SizedBox(height: 2),
                    Text(
                      'Review your plan details before paying.',
                      style: TextStyle(
                        fontSize: 12,
                        height: 1.3,
                        color: Color(0xFF6B7280),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 12),
          _dashedDivider(),
          const SizedBox(height: 10),

          // Itemized "bill"
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFFE5E7EB)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _billRow(label: 'Plan Name', value: planName, isMuted: true),
                _billRow(label: 'Duration', value: periodLabel, isMuted: true),

                const SizedBox(height: 10),

                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 10,
                  ),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(14),
                    color: const Color(0xFFF3F4F6),
                    border: Border.all(color: const Color(0xFFE5E7EB)),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.calendar_month_rounded,
                        size: 18,
                        color: Color(0xFF6B7280),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'Effective monthly cost ~ ${_money(effectiveMonthly)}',
                          style: const TextStyle(
                            fontSize: 12,
                            height: 1.3,
                            color: Color(0xFF374151),
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 10),
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
