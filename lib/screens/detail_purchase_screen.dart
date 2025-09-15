import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:wa_blast/widgets/primary_button.dart';
import '../providers/purchase_provider.dart';
import '../widgets/net_image_square.dart';

class DetailPurchaseScreen extends StatelessWidget {
  final String code;
  const DetailPurchaseScreen({super.key, required this.code});

  Future<String?> _getUserNameFromPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('name');
  }

  @override
  Widget build(BuildContext context) {
    final item = context.select<PurchaseProvider, PurchaseItem?>(
      (p) => p.getByCode(code),
    );
    final fMoney = NumberFormat.decimalPattern('id_ID');
    final fTime = DateFormat('hh:mm a');

    if (item == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Detail Purchase')),
        body: const Center(child: Text('Data tidak ditemukan')),
      );
    }

    Color statusColor(PurchaseStatus s) {
      switch (s) {
        case PurchaseStatus.completed:
          return const Color(0xFF059669);
        case PurchaseStatus.inProgress:
          return const Color(0xFFB45309);
        case PurchaseStatus.canceled:
          return const Color(0xFFDC2626);
      }
    }

    String statusLabel(PurchaseStatus s) {
      switch (s) {
        case PurchaseStatus.completed:
          return 'Completed';
        case PurchaseStatus.inProgress:
          return 'In Progress';
        case PurchaseStatus.canceled:
          return 'Canceled';
      }
    }

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded),
          onPressed: () => Navigator.of(context).maybePop(),
        ),
        title: const Text('Detail Purchase'),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
        children: [
          // status row
          Row(
            children: [
              const Spacer(),
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  color: statusColor(item.status),
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 6),
              Text(
                statusLabel(item.status),
                style: TextStyle(
                  color: statusColor(item.status),
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // serviced by
          const Text(
            'Serviced by',
            style: TextStyle(
              fontWeight: FontWeight.w600,
              color: Color(0xFF6B7280),
            ),
          ),
          const SizedBox(height: 8),
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              CircleAvatar(
                radius: 22,
                backgroundImage: NetworkImage(item.servicedByAvatarUrl),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: FutureBuilder<String?>(
                  future: _getUserNameFromPrefs(),
                  builder: (context, snap) {
                    final name = snap.data ?? 'Unknown User';
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          name,
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                        Text(
                          item.servicedById,
                          style: const TextStyle(
                            fontSize: 12,
                            color: Color(0xFF9CA3AF),
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ),
              Text(
                fTime.format(item.time),
                style: const TextStyle(fontSize: 12, color: Color(0xFF6B7280)),
              ),
            ],
          ),

          const SizedBox(height: 16),
          const Divider(height: 1),

          const SizedBox(height: 12),
          const Text(
            'Order summary',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
          ),

          const SizedBox(height: 8),

          // lines
          ...item.lines.map(
            (l) => Padding(
              padding: const EdgeInsets.symmetric(vertical: 10),
              child: Row(
                children: [
                  NetImageSquare(size: 44, url: l.imageUrl),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        RichText(
                          text: TextSpan(
                            style: const TextStyle(
                              color: Color(0xFF111827),
                              fontSize: 14,
                            ),
                            children: [
                              TextSpan(
                                text: '${l.qty} x  ',
                                style: const TextStyle(
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              TextSpan(text: l.name),
                            ],
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          l.note,
                          style: const TextStyle(
                            fontSize: 12,
                            color: Color(0xFF9CA3AF),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Text(
                    'IDR ${fMoney.format(l.price)}',
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 8),
          const Divider(),

          // totals
          _totalRow('Subtotal', 'Rp ${fMoney.format(item.subtotal)}'),
          _totalRow(
            'Service Fee ${(item.serviceFeePercent * 100).toStringAsFixed(0)}%',
            'Rp ${fMoney.format(item.serviceFee)}',
          ),
          const SizedBox(height: 6),
          Row(
            children: const [
              Expanded(
                child: Text(
                  'Total',
                  style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
                ),
              ),
            ],
          ),
          Row(
            children: [
              Expanded(child: Container()),
              Text(
                'Rp ${fMoney.format(item.grandTotal)}',
                style: const TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 16,
                ),
              ),
            ],
          ),

          const SizedBox(height: 20),
        ],
      ),
      bottomNavigationBar: SafeArea(
        minimum: const EdgeInsets.fromLTRB(16, 8, 16, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton(
                onPressed: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Print Receipt tapped')),
                  );
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF3B82F6),
                  foregroundColor: Colors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text(
                  'Print Receipt',
                  style: TextStyle(fontWeight: FontWeight.w600, fontSize: 16),
                ),
              ),
            ),
            const SizedBox(height: 8),
            TextButton(
              onPressed: () {
                Navigator.pushNamed(
                  context,
                  '/edit-purchase',
                  arguments: {'code': item.code},
                );
              },
              child: const Text('Edit Order'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _totalRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: const TextStyle(color: Color(0xFF6B7280)),
            ),
          ),
          Text(value),
        ],
      ),
    );
  }
}
