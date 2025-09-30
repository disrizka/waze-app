import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../providers/purchase_provider.dart';

class DetailPurchaseScreen extends StatelessWidget {
  const DetailPurchaseScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final fMoney = NumberFormat.decimalPattern('id_ID');

    // contoh dummy data
    final status = "pending";
    final number = "PUR250929100830";
    final date = "Mon, 29 Sep 2025 • 10:08";
    final store = "X";
    final reference = "REF-526792";
    final note = "Stok Awal SM Blue";
    final items = [
      {
        "product": "Samsung Galaxy S23",
        "sku": "SKU: 3627dc...",
        "qty": 12,
        "price": 189000000,
      },
    ];
    final total = 2268000000;

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text("Detail Purchase"),
        backgroundColor: Colors.white,
        elevation: 0,
        foregroundColor: Colors.black,
        actions: [
          IconButton(icon: const Icon(Icons.refresh_rounded), onPressed: () {}),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // === Header Card ===
          Card(
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: const BorderSide(color: Color(0xFFE5E7EB)),
            ),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    number,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF111827),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    date,
                    style: const TextStyle(
                      fontSize: 13,
                      color: Color(0xFF6B7280),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      _StatusChip(status: status),
                      const SizedBox(width: 12),
                      Icon(
                        Icons.store_rounded,
                        size: 16,
                        color: Color(0xFF6B7280),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        store,
                        style: const TextStyle(color: Color(0xFF374151)),
                      ),
                      const Spacer(),
                      Icon(Icons.tag, size: 16, color: Color(0xFF6B7280)),
                      const SizedBox(width: 4),
                      Text(
                        reference,
                        style: const TextStyle(color: Color(0xFF374151)),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // === Note ===
          const Text(
            "Note",
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: Color(0xFF374151),
            ),
          ),
          const SizedBox(height: 6),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFFF9FAFB),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: const Color(0xFFE5E7EB)),
            ),
            child: Text(note, style: const TextStyle(color: Color(0xFF111827))),
          ),
          const SizedBox(height: 20),

          // === Items ===
          const Text(
            "Items",
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: Color(0xFF374151),
            ),
          ),
          const SizedBox(height: 8),
          ...items.map((it) {
            return Card(
              margin: const EdgeInsets.only(bottom: 10),
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
                side: const BorderSide(color: Color(0xFFE5E7EB)),
              ),
              child: ListTile(
                leading: const Icon(
                  Icons.inventory_2_rounded,
                  color: Color(0xFF6B7280),
                ),
                title: Text(
                  it["product"].toString(),
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                subtitle: Text(it["sku"].toString()),
                trailing: Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      "x${it["qty"]}",
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                    Text(
                      "Rp ${fMoney.format(it["price"])}",
                      style: const TextStyle(color: Color(0xFF374151)),
                    ),
                  ],
                ),
              ),
            );
          }),

          const Divider(height: 32),

          // === Totals ===
          _totalRow("Items total", fMoney.format(total)),
          _totalRow("Discount", "0"),
          _totalRow("Shipping fee", "0"),
          const SizedBox(height: 8),
          _totalRow(
            "Grand total",
            fMoney.format(total),
            bold: true,
            highlight: true,
          ),
        ],
      ),

      // === Buttons ===
      bottomNavigationBar: SafeArea(
        minimum: const EdgeInsets.fromLTRB(16, 8, 16, 16),
        child: Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: () {},
                icon: const Icon(Icons.picture_as_pdf),
                label: const Text("Invoice"),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: ElevatedButton.icon(
                onPressed: () {},
                icon: const Icon(Icons.print),
                label: const Text("Print"),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF426FD4),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _totalRow(
    String label,
    String value, {
    bool bold = false,
    bool highlight = false,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                fontWeight: bold ? FontWeight.w700 : FontWeight.normal,
                color: highlight ? Colors.black : const Color(0xFF6B7280),
              ),
            ),
          ),
          Text(
            "Rp $value",
            style: TextStyle(
              fontWeight: bold ? FontWeight.w700 : FontWeight.normal,
              fontSize: bold ? 16 : 14,
              color: highlight ? Colors.black : const Color(0xFF111827),
            ),
          ),
        ],
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  final String status;
  const _StatusChip({required this.status});

  @override
  Widget build(BuildContext context) {
    Color c;
    String label;
    switch (status) {
      case "completed":
        c = const Color(0xFF059669);
        label = "Completed";
        break;
      case "canceled":
        c = const Color(0xFFDC2626);
        label = "Canceled";
        break;
      default:
        c = const Color(0xFFB45309);
        label = "Pending";
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: c.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        label,
        style: TextStyle(color: c, fontWeight: FontWeight.w600, fontSize: 13),
      ),
    );
  }
}

class _StatusPill extends StatelessWidget {
  final String status;
  const _StatusPill({required this.status});

  @override
  Widget build(BuildContext context) {
    final lower = status.toLowerCase();
    late Color c;
    late String label;
    switch (lower) {
      case 'completed':
        c = const Color(0xFF059669);
        label = 'Completed';
        break;
      case 'canceled':
        c = const Color(0xFFDC2626);
        label = 'Canceled';
        break;
      case 'pending':
      default:
        c = const Color(0xFFB45309);
        label = 'Pending';
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: c.withOpacity(0.08),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: c.withOpacity(0.25)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(color: c, shape: BoxShape.circle),
          ),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(color: c, fontWeight: FontWeight.w700),
          ),
        ],
      ),
    );
  }
}

class _MiniInfoChip extends StatelessWidget {
  final IconData icon;
  final String label;
  const _MiniInfoChip({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0xFFF3F4F6),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: const Color(0xFF6B7280)),
          const SizedBox(width: 6),
          Text(
            label,
            style: const TextStyle(fontSize: 12, color: Color(0xFF374151)),
          ),
        ],
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;
  const _ErrorState({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.error_outline_rounded,
              size: 42,
              color: Color(0xFFDC2626),
            ),
            const SizedBox(height: 10),
            Text(message, textAlign: TextAlign.center),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }
}

String _ellipsis(String s, int max) {
  if (s.length <= max) return s;
  return '${s.substring(0, max - 1)}…';
}
