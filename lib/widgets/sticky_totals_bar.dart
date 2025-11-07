import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:wa_blast/constants/design_system.dart';

class StickyTotalsBar extends StatelessWidget {
  final int subtotal; // ← dipertahankan demi kompat, TIDAK ditampilkan
  final String
  serviceFeeLabel; // ← dipertahankan demi kompat, TIDAK ditampilkan
  final int serviceFee; // ← dipertahankan demi kompat, TIDAK ditampilkan
  final int adjustment;
  final int total;
  final bool enabled;
  final VoidCallback? onNext;

  const StickyTotalsBar({
    required this.subtotal,
    required this.serviceFeeLabel,
    required this.serviceFee,
    required this.adjustment,
    required this.total,
    this.enabled = true,
    this.onNext,
    Key? key,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final money = NumberFormat.decimalPattern('id_ID');
    return SafeArea(
      top: false,
      minimum: const EdgeInsets.fromLTRB(16, 8, 16, 12),
      child: Column(
        children: [
          // ⬇️ Subtotal & Service Fee dihilangkan dari tampilan
          if (adjustment > 0)
            _kv(
              'Discount',
              '- Rp ${money.format(adjustment)}',
              color: UI.ok,
              bold: true,
            ),
          Divider(height: 8, thickness: 0.5),
          const SizedBox(height: 8),

          // Total kiri, angka kanan
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Total', style: UI.tsH6),
              Text(
                'Rp ${money.format(total)}',
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _kv(String k, String v, {Color? color, bool bold = false}) {
    final style = TextStyle(
      fontWeight: bold ? FontWeight.w700 : FontWeight.w600,
      color: color ?? UI.text,
      fontSize: 13,
    );
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(k, style: style),
          Text(v, style: style),
        ],
      ),
    );
  }
}
