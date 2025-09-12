import 'package:dotted_border/dotted_border.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../providers/purchase_provider.dart';
import 'detail_purchase_screen.dart';

class PurchaseScreen extends StatelessWidget {
  const PurchaseScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded),
          onPressed: () => Navigator.pushReplacementNamed(context, '/splash'),
        ),
        title: const Text('Purchase'),
      ),
      body: const _PurchaseList(),
    );
  }
}

class _PurchaseList extends StatelessWidget {
  const _PurchaseList();

  @override
  Widget build(BuildContext context) {
    final fTime = DateFormat('hh:mm:ss a');
    final fMoney = NumberFormat.decimalPattern('id_ID');

    return Consumer<PurchaseProvider>(
      builder: (context, prov, _) {
        final items = prov.items;
        return ListView.builder(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
          itemCount: items.length + 1,
          itemBuilder: (context, index) {
            if (index == 0) {
              return const Padding(
                padding: EdgeInsets.only(bottom: 12),
                child: Text(
                  'History Purchase',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF6B7280),
                  ),
                ),
              );
            }

            final item = items[index - 1];

            final card = DottedBorder(
              options: RoundedRectDottedBorderOptions(
                color: const Color(0xFFD1D5DB),
                dashPattern: const [6, 6],
                strokeWidth: 1.4,
                radius: const Radius.circular(12),
                padding: const EdgeInsets.all(0),
              ),
              child: Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // header
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(
                            color: Colors.indigo.shade50,
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            Icons.shopping_bag_rounded,
                            size: 20,
                            color: Colors.indigo.shade700,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                item.code,
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w700,
                                  color: Color(0xFF111827),
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                fTime.format(item.time),
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: Color(0xFF9CA3AF),
                                ),
                              ),
                            ],
                          ),
                        ),
                        _StatusChip(status: item.status),
                      ],
                    ),
                    const SizedBox(height: 16),
                    // amounts
                    Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Total amount',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Color(0xFF6B7280),
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'Rp. ${fMoney.format(item.totalAmount)}',
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w700,
                                  color: Color(0xFF111827),
                                ),
                              ),
                            ],
                          ),
                        ),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            const Text(
                              'Quantity',
                              style: TextStyle(
                                fontSize: 12,
                                color: Color(0xFF6B7280),
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              '${item.quantity}',
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w700,
                                color: Color(0xFF111827),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );

            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () {
                  Navigator.pushNamed(
                    context,
                    '/detail-purchase',
                    arguments: {'code': item.code},
                  );
                },
                child: card,
              ),
            );
          },
        );
      },
    );
  }
}

class _StatusChip extends StatelessWidget {
  final PurchaseStatus status;
  const _StatusChip({required this.status});

  @override
  Widget build(BuildContext context) {
    late String label;
    late final Color dot;
    late final Color textColor;

    switch (status) {
      case PurchaseStatus.inProgress:
        label = 'Completed?'; // opsional ganti sesuai kebutuhan
        label = 'In Progress';
        dot = const Color(0xFFB45309);
        textColor = const Color(0xFFB45309);
        break;
      case PurchaseStatus.completed:
        label = 'Completed';
        dot = const Color(0xFF059669);
        textColor = const Color(0xFF059669);
        break;
      case PurchaseStatus.canceled:
        label = 'Canceled';
        dot = const Color(0xFFDC2626);
        textColor = const Color(0xFFDC2626);
        break;
    }

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(color: dot, shape: BoxShape.circle),
        ),
        const SizedBox(width: 6),
        Text(
          label,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: textColor,
          ),
        ),
      ],
    );
  }
}
