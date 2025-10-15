import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import 'package:wa_blast/providers/sales_provider.dart';
import '../../../constants/app_colors.dart';
import '../../../constants/design_system.dart';
import '../../../widgets/stepper_header.dart';

class PaymentStep extends StatefulWidget {
  final bool withHeader;
  const PaymentStep({super.key, this.withHeader = true});

  @override
  State<PaymentStep> createState() => _PaymentStepState();
}

class _PaymentStepState extends State<PaymentStep> {
  Future<void> _onPlaceOrder() async {
    final prov = context.read<SalesProvider>();

    final ok = await prov.submitSales(context);
    if (!mounted) return;

    // ▼ gunakan subtotalEffective (sudah net diskon per-item)
    final subtotal = prov.subtotalEffective; // <— ganti
    final disc = prov.discount ?? 0; // order-level adjustment
    final totalFinal =
        (subtotal - disc).clamp(0, 1 << 31) as int; // clamp ≥ 0, cast int

    if (ok) {
      await showOrderSuccessDialog(
        context,
        reference: prov.currentReference ?? '-',
        total: totalFinal,
        paymentMethodLabel: _PayMethod.byId(prov.paymentMethod ?? 1).label,
      );
    } else {
      final err = prov.consumeLastError() ?? 'Failed to submit order';
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(err)));
    }
  }

  @override
  Widget build(BuildContext context) {
    final prov = context.watch<SalesProvider>();
    prov.ensureReferenceInitialized(); // ensure REF exists

    // === Konsisten dengan Make Order ===
    // Subtotal efektif = Σ (price - diskon per item) * qty  (clamp ≥ 0)
    final subtotal = prov.cartItems.fold<int>(0, (sum, it) {
      final d = prov.perItemDiscountOf(it.sku.skuId);
      final unitAfter = it.sku.price - d;
      final safeUnit = unitAfter < 0 ? 0 : unitAfter;
      return sum + safeUnit * it.qty;
    });

    // Order-level discount (adjustment)
    final disc = prov.discount ?? 0;

    // Service fee ditiadakan
    const serviceFee = 0;

    // Total akhir = subtotal - adjustment  (clamp ≥ 0)
    final totalFinal = (subtotal + serviceFee - disc);
    final pmId = prov.paymentMethod ?? 1;
    final pm = _PayMethod.byId(pmId);

    return Container(
      color: Colors.white,
      child: Column(
        children: [
          if (widget.withHeader) const StepperHeader(activeIndex: 2),

          // BODY
          Expanded(
            child: ListView(
              padding: DS.p16,
              children: [
                // ===== SUMMARY =====
                _SectionCard(
                  title: 'Payment Summary',
                  trailing: _MethodBadge(method: pm),
                  child: Column(
                    children: [
                      _RowKV(label: 'Subtotal', value: subtotal),
                      if (disc > 0)
                        _RowKV(
                          label: 'Discount',
                          value: -disc,
                          forceColor: const Color(0xFF059669),
                        ),
                      const Divider(color: AppColors.divider),
                      _RowKV(
                        label: 'Total',
                        value: totalFinal < 0 ? 0 : totalFinal,
                        bold: true,
                      ),
                      const SizedBox(height: 12),
                    ],
                  ),
                ),
                const SizedBox(height: 14),

                // ===== EXTRA DETAILS (optional) =====
                if ((prov.storeLocationName ?? '').isNotEmpty ||
                    (prov.customerName ?? '').isNotEmpty ||
                    (prov.note ?? '').isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 14),
                    child: _SectionCard(
                      title: 'Details',
                      child: Column(
                        children: [
                          if ((prov.storeLocationName ?? '').isNotEmpty)
                            _RowText('Store', prov.storeLocationName!),
                          if ((prov.customerName ?? '').isNotEmpty)
                            _RowText('Customer', prov.customerName!),
                          if ((prov.note ?? '').isNotEmpty)
                            _RowText('Note', prov.note!),
                        ],
                      ),
                    ),
                  ),
                const SizedBox(height: 14),

                // ===== PAYMENT METHOD =====
                _SectionCard(
                  title: 'Payment Method',
                  subtitle:
                      'Choose how to pay. If you select Midtrans, the customer can pay via QRIS/VA/e-wallet.',
                  child: Column(
                    children: _PayMethod.all.map((m) {
                      final selected = m.id == pmId;
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: _PaymentOptionTile(
                          method: m,
                          selected: selected,
                          onTap: () => prov.setOrderMeta(paymentMethod: m.id),
                        ),
                      );
                    }).toList(),
                  ),
                ),
              ],
            ),
          ),

          // FOOTER CTA
          SafeArea(
            minimum: DS.p16,
            child: SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: prov.submitting ? null : _onPlaceOrder,
                style: DS.primaryBtn(enabled: !prov.submitting),
                child: prov.submitting
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : Text('Pay with ${pm.label}'),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/* ----------------------------- SUB WIDGETS ----------------------------- */

class _SectionCard extends StatelessWidget {
  final String title;
  final String? subtitle;
  final Widget child;
  final Widget? trailing;
  const _SectionCard({
    required this.title,
    required this.child,
    this.subtitle,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    final titleStyle = DS.tsTitle.copyWith(fontWeight: FontWeight.w800);
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: const [
          BoxShadow(
            blurRadius: 18,
            color: Color(0x12000000),
            offset: Offset(0, 8),
          ),
        ],
        border: Border.all(color: AppColors.divider),
      ),
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: titleStyle),
                    if (subtitle != null && subtitle!.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Text(
                          subtitle!,
                          style: DS.tsPrice.copyWith(
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              if (trailing != null) trailing!,
            ],
          ),
          const SizedBox(height: 10),
          child,
        ],
      ),
    );
  }
}

class _RowKV extends StatelessWidget {
  final String label;
  final int value;
  final bool bold;
  final Color? forceColor; // allow override color (e.g., discount green)
  const _RowKV({
    required this.label,
    required this.value,
    this.bold = false,
    this.forceColor,
  });

  @override
  Widget build(BuildContext context) {
    final isDiscount = label.toLowerCase().contains('discount') || value < 0;
    final baseStyle = bold
        ? DS.tsTitle.copyWith(fontWeight: FontWeight.w900)
        : DS.tsTitle;
    final valueStyle = (forceColor != null || isDiscount)
        ? baseStyle.copyWith(color: forceColor ?? const Color(0xFF059669))
        : baseStyle;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Expanded(child: Text(label, style: DS.tsPrice)),
          Text(
            (value >= 0 ? formatRp(value) : '-${formatRp(value.abs())}'),
            style: valueStyle,
          ),
        ],
      ),
    );
  }
}

class _RowText extends StatelessWidget {
  final String k;
  final String v;
  const _RowText(this.k, this.v);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Expanded(
            child: Text(
              k,
              style: DS.tsPrice.copyWith(color: AppColors.textSecondary),
            ),
          ),
          Flexible(
            child: Text(
              v,
              style: DS.tsTitle,
              textAlign: TextAlign.right,
              overflow: TextOverflow.ellipsis,
              maxLines: 1,
            ),
          ),
        ],
      ),
    );
  }
}

class _RefRow extends StatelessWidget {
  final String reference;
  final VoidCallback onCopy;
  const _RefRow({required this.reference, required this.onCopy});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.greyBackground,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          const Icon(Icons.tag, size: 18, color: AppColors.textSecondary),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'Reference: $reference',
              style: DS.tsPrice,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          TextButton(
            onPressed: () {
              Clipboard.setData(ClipboardData(text: reference));
              onCopy();
            },
            child: const Text('Copy'),
          ),
        ],
      ),
    );
  }
}

class _MethodBadge extends StatelessWidget {
  final _PayMethod method;
  const _MethodBadge({required this.method});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.greyBackground,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(method.icon, size: 16, color: AppColors.textSecondary),
          const SizedBox(width: 6),
          Text(
            method.shortLabel,
            style: const TextStyle(
              fontWeight: FontWeight.w700,
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}

class _PaymentOptionTile extends StatelessWidget {
  final _PayMethod method;
  final bool selected;
  final VoidCallback? onTap;
  const _PaymentOptionTile({
    required this.method,
    required this.selected,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final borderColor = selected ? AppColors.primary : AppColors.divider;
    final fill = selected ? AppColors.primary.withOpacity(0.06) : Colors.white;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: fill,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: borderColor),
        ),
        child: Row(
          children: [
            CircleAvatar(
              radius: 18,
              backgroundColor: Colors.white,
              child: Icon(method.icon, color: AppColors.textSecondary),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    method.label,
                    style: const TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    method.subtitle,
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            if (selected)
              const Icon(Icons.check_circle, color: AppColors.primary)
            else
              const Icon(
                Icons.radio_button_unchecked,
                color: AppColors.textSecondary,
              ),
          ],
        ),
      ),
    );
  }
}

/* ----------------------------- PAYMENT MODEL ----------------------------- */

class _PayMethod {
  final int id;
  final String label;
  final String shortLabel;
  final String subtitle;
  final IconData icon;

  const _PayMethod({
    required this.id,
    required this.label,
    required this.shortLabel,
    required this.subtitle,
    required this.icon,
  });

  static const all = <_PayMethod>[
    _PayMethod(
      id: 1,
      label: 'Cash',
      shortLabel: 'Cash',
      subtitle: 'Pay with cash at the cashier.',
      icon: Icons.payments_outlined,
    ),
    _PayMethod(
      id: 2,
      label: 'EDC',
      shortLabel: 'Transfer',
      subtitle: 'Manual bank transfer to the store account.',
      icon: Icons.account_balance_outlined,
    ),
    _PayMethod(
      id: 3,
      label: 'QRIS/VA',
      shortLabel: 'Midtrans',
      subtitle: 'QRIS, Virtual Account, and e-wallet via Midtrans.',
      icon: Icons.qr_code_2_outlined,
    ),
  ];

  static _PayMethod byId(int id) =>
      all.firstWhere((m) => m.id == id, orElse: () => all.first);
}

/* ------------------------- ORDER SUCCESS DIALOG ------------------------- */

Future<void> showOrderSuccessDialog(
  BuildContext context, {
  required String reference,
  required int total,
  String? paymentMethodLabel,
}) {
  return showGeneralDialog(
    context: context,
    barrierLabel: 'Order success',
    barrierDismissible: true,
    barrierColor: Colors.black.withOpacity(0.35),
    transitionDuration: const Duration(milliseconds: 320),
    pageBuilder: (_, __, ___) => const SizedBox.shrink(),
    transitionBuilder: (ctx, anim, _, __) {
      final curved = CurvedAnimation(parent: anim, curve: Curves.easeOutCubic);
      return FadeTransition(
        opacity: curved,
        child: Stack(
          children: [
            // blur background
            BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
              child: Container(color: Colors.transparent),
            ),
            // content card
            Center(
              child: ScaleTransition(
                scale: Tween<double>(begin: 0.94, end: 1.0).animate(curved),
                child: _SuccessCard(
                  reference: reference,
                  total: total,
                  paymentMethodLabel: paymentMethodLabel,
                ),
              ),
            ),
          ],
        ),
      );
    },
  );
}

class _SuccessCard extends StatefulWidget {
  final String reference;
  final int total;
  final String? paymentMethodLabel;

  const _SuccessCard({
    required this.reference,
    required this.total,
    this.paymentMethodLabel,
  });

  @override
  State<_SuccessCard> createState() => _SuccessCardState();
}

class _SuccessCardState extends State<_SuccessCard>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ac;
  late final Animation<double> _ring;
  late final Animation<double> _check;

  @override
  void initState() {
    super.initState();
    _ac = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 850),
    )..forward();
    _ring = CurvedAnimation(
      parent: _ac,
      curve: const Interval(0.0, 0.6, curve: Curves.easeOutBack),
    );
    _check = CurvedAnimation(
      parent: _ac,
      curve: const Interval(0.35, 1.0, curve: Curves.easeOutCubic),
    );
  }

  @override
  void dispose() {
    _ac.dispose();
    super.dispose();
  }

  void _onClose() {
    Navigator.of(context).pop(); // close dialog first
    Navigator.of(context).pushNamedAndRemoveUntil(
      '/sales/list',
      (route) => false, // clear all routes
    );
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: Container(
        width: MediaQuery.of(context).size.width * 0.92,
        constraints: const BoxConstraints(maxWidth: 420),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: const [
            BoxShadow(
              blurRadius: 24,
              color: Color(0x22000000),
              offset: Offset(0, 10),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // header gradient + animation
            Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    AppColors.primary,
                    AppColors.primary.withOpacity(0.75),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(20),
                ),
              ),
              child: Column(
                children: [
                  AnimatedBuilder(
                    animation: _ac,
                    builder: (_, __) {
                      final ringSize = 82.0 * _ring.value.clamp(0.0, 1.0);
                      final ringOpacity = (_ring.value).clamp(0.0, 1.0);
                      final checkScale = (_check.value).clamp(0.0, 1.0);

                      return SizedBox(
                        height: 90,
                        child: Stack(
                          alignment: Alignment.center,
                          children: [
                            Opacity(
                              opacity: ringOpacity,
                              child: Container(
                                width: ringSize,
                                height: ringSize,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: Colors.white.withOpacity(0.12),
                                  boxShadow: const [
                                    BoxShadow(
                                      color: Color(0x33FFFFFF),
                                      blurRadius: 16,
                                      spreadRadius: 2,
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            Transform.scale(
                              scale: checkScale,
                              child: const CircleAvatar(
                                radius: 30,
                                backgroundColor: Colors.white,
                                child: Icon(
                                  Icons.check_rounded,
                                  size: 34,
                                  color: AppColors.primary,
                                ),
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'Order Placed!',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w800,
                      fontSize: 18,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Reference: ${widget.reference}',
                    style: const TextStyle(
                      color: Colors.white70,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),

            // body content
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
              child: Column(
                children: [
                  Row(
                    children: [
                      const Text(
                        'Total',
                        style: TextStyle(
                          fontSize: 14,
                          color: AppColors.textSecondary,
                        ),
                      ),
                      const Spacer(),
                      Text(
                        formatRp(widget.total),
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFF111827),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  if ((widget.paymentMethodLabel ?? '').isNotEmpty)
                    Row(
                      children: [
                        const Icon(
                          Icons.payments_outlined,
                          color: AppColors.textSecondary,
                          size: 18,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          widget.paymentMethodLabel!,
                          style: const TextStyle(
                            fontSize: 13,
                            color: AppColors.textSecondary,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  const SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: _onClose,
                      icon: const Icon(
                        Icons.check_circle_outline,
                        color: Colors.white,
                      ),
                      label: const Text(
                        'Close',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
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
