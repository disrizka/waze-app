import 'package:dotted_border/dotted_border.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:wa_blast/providers/sales_provider.dart';

class SalesReportDetailScreen extends StatefulWidget {
  final String idTransaction;
  const SalesReportDetailScreen({super.key, required this.idTransaction});

  @override
  State<SalesReportDetailScreen> createState() =>
      _SalesReportDetailScreenState();
}

class _SalesReportDetailScreenState extends State<SalesReportDetailScreen> {
  bool _triedRefetch = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final prov = context.read<SalesProvider>();
      final hit = prov.reports.firstWhere(
        (e) => e.idTransaction == widget.idTransaction,
        orElse: () => null as dynamic,
      );
      if (hit == null && !_triedRefetch) {
        _triedRefetch = true;
        await prov.fetchSalesReports(context);
        if (mounted) setState(() {});
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final fDate = DateFormat('EEE, dd MMM yyyy • HH:mm');
    final fMoney = NumberFormat.decimalPattern('id_ID');

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        scrolledUnderElevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Sales Detail',
          style: TextStyle(fontWeight: FontWeight.w800),
        ),
      ),
      body: Consumer<SalesProvider>(
        builder: (context, prov, _) {
          final item = prov.reports.firstWhere(
            (e) => e.idTransaction == widget.idTransaction,
            orElse: () => null as dynamic,
          );

          if (item == null) {
            if (prov.loadingReports) {
              return const Center(child: CircularProgressIndicator());
            }
            return _ErrorBox(
              message:
                  'Data transaksi tidak ditemukan.\nCoba kembali ke halaman Sales Report dan tap itemnya lagi.',
              onRetry: () => prov.fetchSalesReports(context),
            );
          }

          final lines = item.lines;
          final qtyTotal = item.quantity;
          final amount = item.totalAmount;

          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
            children: [
              // Ringkasan dengan DottedBorder & ikon indigo (match purchase list)
              DottedBorder(
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
                              Icons.receipt_long_rounded,
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
                                  (item.code.isEmpty
                                      ? item.reference
                                      : item.code),
                                  style: const TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.w800,
                                    color: Color(0xFF111827),
                                  ),
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  fDate.format(item.time),
                                  style: const TextStyle(
                                    fontSize: 12,
                                    color: Color(0xFF9CA3AF),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),
                          _StatusChip(status: item.status),
                        ],
                      ),
                      const SizedBox(height: 16),
                      // amounts
                      Row(
                        children: [
                          Expanded(
                            child: _KV(
                              label: 'Total amount',
                              value: 'Rp ${fMoney.format(amount)}',
                            ),
                          ),
                          _KV(
                            label: 'Quantity',
                            value: '$qtyTotal',
                            alignEnd: true,
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      _KV(
                        label: 'Reference',
                        value: item.reference.isEmpty ? '-' : item.reference,
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 16),
              const Text(
                'Items',
                style: TextStyle(
                  fontSize: 14,
                  color: Color(0xFF6B7280),
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 8),

              // daftar item
              ...List.generate(lines.length, (i) {
                final l = lines[i];
                final subtotal = l.qtyOut * l.price;
                return DottedBorder(
                  options: RoundedRectDottedBorderOptions(
                    color: const Color(0xFFE5E7EB),
                    dashPattern: const [6, 6],
                    strokeWidth: 1.2,
                    radius: const Radius.circular(10),
                    padding: const EdgeInsets.all(0),
                  ),
                  child: Container(
                    margin: const EdgeInsets.only(bottom: 10),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 42,
                          height: 42,
                          decoration: BoxDecoration(
                            color: Colors.indigo.shade50,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Icon(
                            Icons.inventory_2_rounded,
                            color: Colors.indigo.shade700,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // tampilkan SKU ID sebagai judul (bisa di-enrich nanti)
                              Text(
                                l.productSkuId,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w800,
                                  fontSize: 15,
                                  color: Color(0xFF111827),
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'Qty ${l.qtyOut} × Rp ${fMoney.format(l.price)}',
                                style: const TextStyle(
                                  fontSize: 13,
                                  color: Color(0xFF6B7280),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 12),
                        Text(
                          'Rp ${fMoney.format(subtotal)}',
                          style: const TextStyle(
                            fontWeight: FontWeight.w800,
                            color: Color(0xFF111827),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }),
            ],
          );
        },
      ),
    );
  }
}

class _KV extends StatelessWidget {
  final String label;
  final String value;
  final bool alignEnd;
  const _KV({required this.label, required this.value, this.alignEnd = false});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: alignEnd
          ? CrossAxisAlignment.end
          : CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(fontSize: 12, color: Color(0xFF6B7280)),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w800,
            color: Color(0xFF111827),
          ),
        ),
      ],
    );
  }
}

class _StatusChip extends StatelessWidget {
  final String status;
  const _StatusChip({required this.status});

  @override
  Widget build(BuildContext context) {
    if (status.isEmpty) return const SizedBox.shrink();

    Color bg;
    Color fg;
    switch (status.toLowerCase()) {
      case 'completed':
      case 'paid':
        bg = const Color(0xFFE6F4EA);
        fg = const Color(0xFF166534);
        break;
      case 'canceled':
      case 'void':
        bg = const Color(0xFFFEE2E2);
        fg = const Color(0xFF991B1B);
        break;
      case 'pending':
      default:
        bg = const Color(0xFFFEF3C7);
        fg = const Color(0xFF92400E);
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        status,
        style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: fg),
      ),
    );
  }
}

class _ErrorBox extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;
  const _ErrorBox({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: const Color(0xFFFEE2E2),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFFFCA5A5)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Failed to load sales detail',
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF991B1B),
                ),
              ),
              const SizedBox(height: 6),
              Text(message, style: const TextStyle(color: Color(0xFF7F1D1D))),
              const SizedBox(height: 10),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton.icon(
                  onPressed: onRetry,
                  icon: const Icon(Icons.refresh_rounded),
                  label: const Text('Retry'),
                  style: TextButton.styleFrom(
                    foregroundColor: const Color(0xFF991B1B),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
