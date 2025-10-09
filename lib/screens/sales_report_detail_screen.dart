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
  @override
  void initState() {
    super.initState();
    // Ambil detail transaksi langsung dari endpoint detail
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<SalesProvider>().fetchSalesDetail(
        context,
        widget.idTransaction,
      );
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
          if (prov.loadingSalesDetail) {
            return const Center(child: CircularProgressIndicator());
          }
          if (prov.salesDetailError != null) {
            return _ErrorBox(
              message: prov.salesDetailError!,
              onRetry: () =>
                  prov.fetchSalesDetail(context, widget.idTransaction),
            );
          }

          final d = prov.salesDetail;
          if (d == null) {
            return _ErrorBox(
              message:
                  'Data transaksi tidak ditemukan.\nCoba kembali dan buka lagi detailnya.',
              onRetry: () =>
                  prov.fetchSalesDetail(context, widget.idTransaction),
            );
          }

          final calc = d.calculation;
          final totalAmount = calc?.grandtotal ?? d.amount;

          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
            children: [
              // Ringkasan dengan DottedBorder
              DottedBorder(
                options: const RoundedRectDottedBorderOptions(
                  color: Color(0xFFD1D5DB),
                  dashPattern: [6, 6],
                  strokeWidth: 1.4,
                  radius: Radius.circular(12),
                  padding: EdgeInsets.all(0),
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
                                // nomor transaksi atau reference fallback
                                Text(
                                  (d.number.isEmpty ? d.reference : d.number),
                                  style: const TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.w800,
                                    color: Color(0xFF111827),
                                  ),
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  fDate.format(d.time),
                                  style: const TextStyle(
                                    fontSize: 12,
                                    color: Color(0xFF9CA3AF),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),
                          _StatusChip(status: d.status),
                        ],
                      ),
                      const SizedBox(height: 16),

                      // amounts
                      Row(
                        children: [
                          Expanded(
                            child: _KV(
                              label: 'Grand Total',
                              value: 'Rp ${fMoney.format(totalAmount)}',
                            ),
                          ),
                          _KV(
                            label: 'Payment',
                            value: _paymentLabel(d.paymentMethod),
                            alignEnd: true,
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),

                      // customer & store singkat
                      if (d.customer != null) ...[
                        const SizedBox(height: 8),
                        _KV(
                          label: 'Customer',
                          value:
                              '${d.customer!.name} '
                              '${d.customer!.phone.isNotEmpty ? '• ${d.customer!.phone}' : ''}',
                        ),
                      ],
                      if (d.storeLocation != null) ...[
                        const SizedBox(height: 8),
                        _KV(
                          label: 'Store',
                          value:
                              '${d.storeLocation!.name}${d.storeLocation!.city != null ? ' • ${d.storeLocation!.city!.name}' : ''}',
                        ),
                      ],
                      if (d.reference.isNotEmpty) ...[
                        const SizedBox(height: 8),
                        _KV(label: 'Reference', value: d.reference),
                      ],
                      if (d.note.isNotEmpty) ...[
                        const SizedBox(height: 8),
                        _KV(label: 'Note', value: d.note),
                      ],
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

              // daftar item detail
              ...d.items.map((it) {
                final lineSubtotal = it.qtyOut * it.price;
                final img = it.product?.imagePath;
                final title = it.product?.name ?? it.productSkuId;
                final skuCode = it.productSku?.code ?? '';
                final attrs = (it.productSku?.attributes ?? [])
                    .map((a) => '${a['name']}: ${a['value']}')
                    .join(', ');

                return DottedBorder(
                  options: const RoundedRectDottedBorderOptions(
                    color: Color(0xFFE5E7EB),
                    dashPattern: [6, 6],
                    strokeWidth: 1.2,
                    radius: Radius.circular(10),
                    padding: EdgeInsets.all(0),
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
                        _Thumb(imageUrl: img),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // nama produk
                              Text(
                                title,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w800,
                                  fontSize: 15,
                                  color: Color(0xFF111827),
                                ),
                              ),
                              const SizedBox(height: 4),
                              // sku & atribut
                              if (skuCode.isNotEmpty || attrs.isNotEmpty)
                                Text(
                                  [
                                    skuCode,
                                    attrs,
                                  ].where((e) => e.isNotEmpty).join(' • '),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    fontSize: 12,
                                    color: Color(0xFF6B7280),
                                  ),
                                ),
                              const SizedBox(height: 4),
                              // qty x harga (+ discount per item jika ada)
                              Text(
                                'Qty ${it.qtyOut} × Rp ${fMoney.format(it.price)}'
                                '${it.discount > 0 ? ' (disc Rp ${fMoney.format(it.discount)}/item)' : ''}',
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
                          'Rp ${fMoney.format(lineSubtotal)}',
                          style: const TextStyle(
                            fontWeight: FontWeight.w800,
                            color: Color(0xFF111827),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }).toList(),

              const SizedBox(height: 4),
              const Divider(height: 24),

              // totals
              if (calc != null) ...[
                _rowTotal('Subtotal', calc.subtotal, fMoney),
                _rowTotal('Discount', -calc.discount, fMoney, discount: true),
                const SizedBox(height: 6),
                _rowTotal('Grand Total', calc.grandtotal, fMoney, bold: true),
              ] else ...[
                _rowTotal('Amount', d.amount, fMoney, bold: true),
              ],
            ],
          );
        },
      ),
    );
  }

  Widget _rowTotal(
    String label,
    int amount,
    NumberFormat fmt, {
    bool bold = false,
    bool discount = false,
  }) {
    final st = TextStyle(
      fontWeight: bold ? FontWeight.w700 : FontWeight.w600,
      color: const Color(0xFF111827),
    );
    final val = TextStyle(
      fontWeight: bold ? FontWeight.w700 : FontWeight.w600,
      color: discount ? const Color(0xFF166534) : const Color(0xFF374151),
    );
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Expanded(child: Text(label, style: st)),
          Text('Rp ${fmt.format(amount)}', style: val),
        ],
      ),
    );
  }

  String _paymentLabel(int method) {
    switch (method) {
      case 1:
        return 'Cash';
      case 4:
        return 'EDC';
      case 3:
        return 'QRIS/VA';
      default:
        return 'Other';
    }
  }
}

class _Thumb extends StatelessWidget {
  final String? imageUrl;
  const _Thumb({this.imageUrl});

  @override
  Widget build(BuildContext context) {
    final fallback = Container(
      width: 42,
      height: 42,
      decoration: BoxDecoration(
        color: Colors.indigo.shade50,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Icon(Icons.inventory_2_rounded, color: Colors.indigo.shade700),
    );

    if (imageUrl == null || imageUrl!.isEmpty) return fallback;

    return ClipRRect(
      borderRadius: BorderRadius.circular(10),
      child: Image.network(
        imageUrl!,
        width: 42,
        height: 42,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => fallback,
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
