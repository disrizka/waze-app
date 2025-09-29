import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:wa_blast/providers/sales_provider.dart';
import 'package:wa_blast/services/api_service.dart';
import 'dart:ui';
import 'package:flutter/material.dart';
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

    if (ok) {
      await showOrderSuccessDialog(
        context,
        reference: prov.currentReference ?? '-',
        total: prov.total,
        onViewOrder: () {
          // TODO: arahkan ke halaman detail order
          Navigator.of(context).pop(); // tutup dialog
          // Navigator.pushNamed(context, '/sales/detail', arguments: ...);
        },
        onNewSale: () {
          Navigator.of(context).pop(); // tutup dialog
          prov.reset();
          // Optionally balik ke step pertama
          prov.goTo(0);
        },
      );
    } else {
      final err = prov.consumeLastError() ?? 'Gagal submit order';
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(err)));
    }
  }

  @override
  Widget build(BuildContext context) {
    final prov = context.watch<SalesProvider>();

    return Container(
      color: Colors.white,
      child: Column(
        children: [
          if (widget.withHeader) const StepperHeader(activeIndex: 2),
          Expanded(
            child: ListView(
              padding: DS.p16,
              children: [
                _RowKV(label: 'Subtotal', value: prov.subtotal),
                _RowKV(label: 'Service Fee 2%', value: prov.serviceFee),
                const Divider(color: AppColors.divider),
                _RowKV(label: 'Total', value: prov.total, bold: true),
                const SizedBox(height: 24),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Reference number:', style: DS.tsPrice),
                    Text(prov.currentReference ?? '-', style: DS.tsTitle),
                  ],
                ),
              ],
            ),
          ),
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
                    : const Text('Place Order'),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _RowKV extends StatelessWidget {
  final String label;
  final int value;
  final bool bold;
  const _RowKV({required this.label, required this.value, this.bold = false});

  @override
  Widget build(BuildContext context) {
    final style = bold
        ? DS.tsTitle.copyWith(fontWeight: FontWeight.w800)
        : DS.tsTitle;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: style),
          Text(formatRp(value), style: style),
        ],
      ),
    );
  }
}

Future<void> showOrderSuccessDialog(
  BuildContext context, {
  required String reference,
  required int total,
  VoidCallback? onViewOrder,
  VoidCallback? onNewSale,
}) {
  return showGeneralDialog(
    context: context,
    barrierLabel: 'Order success',
    barrierDismissible: true,
    barrierColor: Colors.black.withOpacity(0.35),
    transitionDuration: const Duration(milliseconds: 320),
    pageBuilder: (ctx, anim1, anim2) {
      return const SizedBox.shrink(); // required, content from transitionBuilder
    },
    transitionBuilder: (ctx, anim, _, __) {
      final curved = CurvedAnimation(parent: anim, curve: Curves.easeOutCubic);
      return FadeTransition(
        opacity: curved,
        child: Stack(
          children: [
            // Blur background
            BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
              child: Container(color: Colors.transparent),
            ),
            // Card
            Center(
              child: ScaleTransition(
                scale: Tween<double>(begin: 0.94, end: 1.0).animate(curved),
                child: _SuccessCard(
                  reference: reference,
                  total: total,
                  onClose: () => Navigator.of(ctx).maybePop(),
                  onViewOrder: onViewOrder,
                  onNewSale: onNewSale,
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
  final VoidCallback onClose;
  final VoidCallback? onViewOrder;
  final VoidCallback? onNewSale;

  const _SuccessCard({
    required this.reference,
    required this.total,
    required this.onClose,
    this.onViewOrder,
    this.onNewSale,
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

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

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
            // Header gradient + animated check
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
                  // animated ring + check
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
                              child: CircleAvatar(
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

            // Body
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
              child: Column(
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.greyBackground,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Text(
                          'Sales',
                          style: TextStyle(fontWeight: FontWeight.w700),
                        ),
                      ),
                      const Spacer(),
                      const Icon(
                        Icons.receipt_long_outlined,
                        color: AppColors.textSecondary,
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
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
                  const SizedBox(height: 16),

                  // Quick actions
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: widget.onViewOrder,
                          icon: const Icon(Icons.visibility_outlined),
                          label: const Text('View order'),
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            side: const BorderSide(color: AppColors.divider),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: widget.onNewSale,
                          icon: const Icon(
                            Icons.add_shopping_cart_outlined,
                            color: Colors.white,
                          ),
                          label: const Text(
                            'New sale',
                            style: TextStyle(color: Colors.white),
                          ),
                          style: ElevatedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            backgroundColor: AppColors.primary,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  TextButton.icon(
                    onPressed: () {
                      Navigator.of(context).pop(); // tutup dialog dulu
                      Navigator.of(context).pushNamedAndRemoveUntil(
                        '/splash',
                        (route) => false, // clear semua stack
                      );
                    },
                    icon: const Icon(Icons.close),
                    label: const Text('Close'),
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
