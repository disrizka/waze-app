import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../constants/app_colors.dart';
import '../../../constants/design_system.dart';
import '../../../providers/purchase_stepper_provider.dart';
import '../../../widgets/stepper_header.dart';

class CheckOrderStep extends StatelessWidget {
  final bool withHeader;
  const CheckOrderStep({super.key, this.withHeader = true});

  @override
  Widget build(BuildContext context) {
    final prov = context.watch<PurchaseStepperProvider>();
    return Column(
      children: [
        if (withHeader)
          const StepperHeader(activeIndex: 1)
        else
          const SizedBox.shrink(),
        Expanded(
          child: ListView(
            padding: DS.p16,
            children: [
              _Section(
                title: 'Delivery order',
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Order number:', style: DS.tsPrice),
                    Row(
                      children: [
                        Text(prov.orderNumber, style: DS.tsTitle),
                        const SizedBox(width: 8),
                        const Icon(
                          Icons.copy,
                          size: 16,
                          color: AppColors.textSecondary,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              _Section(
                title: 'Order summary',
                child: Column(
                  children: prov.cartItems.map((it) {
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 6),
                      child: Row(
                        children: [
                          Container(
                            width: 48,
                            height: 48,
                            decoration: BoxDecoration(
                              color: AppColors.greyBackground,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: const Icon(
                              Icons.image,
                              color: AppColors.disabledFg,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  '${it.qty} x ${it.product.name}',
                                  style: DS.tsTitle,
                                ),
                                const SizedBox(height: 2),
                                const Text('Note here', style: DS.tsPrice),
                              ],
                            ),
                          ),
                          _QtyPill(
                            qty: it.qty,
                            onMinus: () => prov.removeOne(it.product),
                            onPlus: () => prov.add(it.product),
                          ),
                        ],
                      ),
                    );
                  }).toList(),
                ),
              ),
              const SizedBox(height: 8),
              _RowKV(label: 'Subtotal', value: prov.subtotal),
              _RowKV(label: 'Service Fee 2%', value: prov.serviceFee),
              const Divider(color: AppColors.divider),
              _RowKV(label: 'Total', value: prov.total, bold: true),
            ],
          ),
        ),
        SafeArea(
          minimum: DS.p16,
          child: SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: prov.cartItems.isEmpty ? null : () => prov.goTo(2),
              style: DS.primaryBtn(enabled: !prov.cartItems.isEmpty),
              child: const Text('Payment'),
            ),
          ),
        ),
      ],
    );
  }
}

class _Section extends StatelessWidget {
  final String title;
  final Widget child;
  const _Section({required this.title, required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.divider),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: DS.tsPrice),
          const SizedBox(height: 8),
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
  const _RowKV({required this.label, required this.value, this.bold = false});

  @override
  Widget build(BuildContext context) {
    final style = bold
        ? DS.tsTitle.copyWith(fontWeight: FontWeight.w700)
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

class _QtyPill extends StatelessWidget {
  final int qty;
  final VoidCallback onMinus;
  final VoidCallback onPlus;
  const _QtyPill({
    required this.qty,
    required this.onMinus,
    required this.onPlus,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 36,
      decoration: BoxDecoration(
        border: Border.all(color: AppColors.divider),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            visualDensity: VisualDensity.compact,
            onPressed: onMinus,
            icon: const Icon(Icons.remove),
          ),
          Text('$qty', style: const TextStyle(fontWeight: FontWeight.w700)),
          IconButton(
            visualDensity: VisualDensity.compact,
            onPressed: onPlus,
            icon: const Icon(Icons.add),
          ),
        ],
      ),
    );
  }
}
