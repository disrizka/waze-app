import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:wa_blast/providers/sales_provider.dart';
import '../../../constants/app_colors.dart';
import '../../../constants/design_system.dart';
import '../../../widgets/stepper_header.dart';

class PaymentStep extends StatelessWidget {
  final bool withHeader;
  const PaymentStep({super.key, this.withHeader = true});

  @override
  Widget build(BuildContext context) {
    final prov = context.watch<SalesProvider>();
    return Column(
      children: [
        if (withHeader)
          const StepperHeader(activeIndex: 2)
        else
          const SizedBox.shrink(),
        Expanded(
          child: ListView(
            padding: DS.p16,
            children: [
              _RowKV(label: 'Subtotal', value: prov.subtotal),
              _RowKV(label: 'Service Fee 2%', value: prov.serviceFee),
              const Divider(color: AppColors.divider),
              _RowKV(label: 'Total', value: prov.total, bold: true),
              const SizedBox(height: 24),
              Text('Order number: ${prov.orderNumber}', style: DS.tsPrice),
            ],
          ),
        ),
        SafeArea(
          minimum: DS.p16,
          child: SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () {
                showDialog(
                  context: context,
                  builder: (_) => AlertDialog(
                    title: const Text('Order Placed'),
                    content: const Text('Pesanan berhasil dibuat.'),
                    actions: [
                      TextButton(
                        onPressed: () {
                          prov.reset();
                          Navigator.of(context).pop();
                        },
                        child: const Text('OK'),
                      ),
                    ],
                  ),
                );
              },
              style: DS.primaryBtn(),
              child: const Text('Placed Order'),
            ),
          ),
        ),
      ],
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
