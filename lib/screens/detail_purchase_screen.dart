import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:printing/printing.dart';
import 'package:provider/provider.dart';
import 'package:open_filex/open_filex.dart';
import 'package:path_provider/path_provider.dart';

import '../providers/purchase_provider.dart';
import '../utils/invoice_pdf.dart';

class DetailPurchaseScreen extends StatefulWidget {
  const DetailPurchaseScreen({super.key});

  @override
  State<DetailPurchaseScreen> createState() => _DetailPurchaseScreenState();
}

class _DetailPurchaseScreenState extends State<DetailPurchaseScreen> {
  String? _id;
  bool _initialFetched = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Ambil id dari arguments sekali
    if (_id == null) {
      final args = ModalRoute.of(context)?.settings.arguments;
      if (args is Map && args['id'] != null) {
        _id = args['id'].toString();
      }
    }
    if (!_initialFetched && _id != null) {
      _initialFetched = true;
      _fetch();
    }
  }

  Future<void> _fetch() async {
    if (!mounted || _id == null) return;
    await context.read<PurchaseProvider>().fetchPurchaseDetail(context, _id!);
  }

  @override
  Widget build(BuildContext context) {
    final fMoney = NumberFormat.decimalPattern('id_ID');
    final fDate = DateFormat('EEE, d MMM y • HH:mm', 'id_ID');

    return Consumer<PurchaseProvider>(
      builder: (context, prov, _) {
        final detail = prov.purchaseDetail;
        final isLoading = prov.loadingPurchaseDetail && detail == null;
        final error = prov.purchaseDetailError;

        return Scaffold(
          backgroundColor: Colors.white,
          appBar: AppBar(
            title: const Text('Detail Purchase'),
            backgroundColor: Colors.white,
            elevation: 0,
            foregroundColor: Colors.black,
            actions: [
              IconButton(
                icon: const Icon(Icons.refresh_rounded),
                onPressed: _fetch,
              ),
            ],
          ),
          body: Builder(
            builder: (_) {
              if (_id == null) {
                return const _ErrorState(
                  message: 'ID purchase tidak ditemukan dari arguments.',
                );
              }
              if (isLoading) {
                return const Center(child: CircularProgressIndicator());
              }
              if (error != null && detail == null) {
                return _ErrorState(message: error, onRetry: _fetch);
              }
              if (detail == null) {
                return _ErrorState(
                  message: 'Data purchase tidak tersedia.',
                  onRetry: _fetch,
                );
              }

              // ==== Data siap pakai dari model baru ====
              final number = detail.number;
              final status = detail.status;
              final dateText = fDate.format(detail.createdAt);
              final storeName = detail.storeLocationName;
              final note = detail.note.isNotEmpty ? detail.note : '—';
              final storeLocation = detail.storeLocation?.city?.name;

              final subtotal = detail.itemsSubtotal;
              final discount = detail.discount;
              final shipping = detail.shippingFee;
              final grandTotal = detail.grandTotal;

              return ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  // Header
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
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 4),
                          Text(
                            dateText,
                            style: const TextStyle(
                              fontSize: 13,
                              color: Color(0xFF6B7280),
                            ),
                          ),
                          const SizedBox(height: 12),
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              _StatusChip(status: status),
                              const SizedBox(width: 12),
                              const Icon(
                                Icons.store_rounded,
                                size: 16,
                                color: Color(0xFF6B7280),
                              ),
                              const SizedBox(width: 4),
                              Expanded(
                                child: Text(
                                  storeName,
                                  style: const TextStyle(
                                    color: Color(0xFF374151),
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                  maxLines: 1,
                                ),
                              ),
                              const SizedBox(width: 10),
                              const Icon(
                                Icons.pin_drop,
                                size: 16,
                                color: Color(0xFF6B7280),
                              ),
                              const SizedBox(width: 4),
                              Expanded(
                                child: Text(
                                  storeLocation!,
                                  style: const TextStyle(
                                    color: Color(0xFF374151),
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                  maxLines: 1,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Note
                  const Text(
                    'Note',
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
                    child: Text(
                      note,
                      style: const TextStyle(color: Color(0xFF111827)),
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Items
                  const Text(
                    'Items',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF374151),
                    ),
                  ),
                  const SizedBox(height: 8),
                  if (detail.items.isEmpty)
                    const Text('No items', style: TextStyle(color: Colors.grey))
                  else
                    ...detail.items.map((line) {
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
                            line.productName.isNotEmpty
                                ? line.productName
                                : '—',
                            style: const TextStyle(fontWeight: FontWeight.w600),
                          ),
                          subtitle: Text(
                            line.skuCode.isNotEmpty
                                ? 'SKU: ${line.skuCode}'
                                : 'SKU: —',
                          ),
                          trailing: Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text(
                                'x${line.netQty}',
                                style: const TextStyle(
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              Text(
                                'Rp ${fMoney.format(line.price)}',
                                style: const TextStyle(
                                  color: Color(0xFF374151),
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    }),

                  const Divider(height: 32),

                  // Totals
                  _totalRow('Items total', fMoney.format(subtotal)),
                  _totalRow('Discount', fMoney.format(discount)),
                  _totalRow('Shipping fee', fMoney.format(shipping)),
                  const SizedBox(height: 8),
                  _totalRow(
                    'Grand total',
                    fMoney.format(grandTotal),
                    bold: true,
                    highlight: true,
                  ),
                ],
              );
            },
          ),

          // Bottom buttons
          bottomNavigationBar: Consumer<PurchaseProvider>(
            builder: (context, p, __) {
              final d = p.purchaseDetail;
              if (d == null) return const SizedBox.shrink();

              final number = d.number;
              final date = d.createdAt;
              final storeName = d.storeLocationName;
              final reference = d.reference.isNotEmpty ? d.reference : '—';
              final note = d.note.isNotEmpty ? d.note : '—';
              final discount = d.discount;
              final shipping = d.shippingFee;

              final pdfLines = d.items
                  .map(
                    (it) => PurchaseLine(
                      product: it.productName.isNotEmpty ? it.productName : '—',
                      sku: it.skuCode.isNotEmpty ? it.skuCode : '—',
                      qty: it.netQty,
                      price: it.price,
                    ),
                  )
                  .toList();

              return SafeArea(
                minimum: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                child: Row(
                  children: [
                    // ===== INVOICE = DOWNLOAD PDF =====
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () async {
                          final bytes = await buildPurchaseInvoicePdf(
                            number: number,
                            date: date,
                            store: storeName,
                            note: note,
                            items: pdfLines,
                            discount: discount,
                            shipping: shipping,
                            companyName: 'WaveUp',
                            companyAddress: 'Jakarta, Indonesia',
                          );

                          final safeName =
                              '${number.replaceAll(RegExp(r"[^A-Za-z0-9._-]"), "_")}.pdf';
                          final dir = await getApplicationDocumentsDirectory();
                          final file = File('${dir.path}/$safeName');
                          await file.writeAsBytes(bytes, flush: true);

                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                backgroundColor: Colors.grey[50],
                                behavior: SnackBarBehavior.floating,
                                elevation: 3,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                content: Row(
                                  children: [
                                    const Icon(
                                      Icons.picture_as_pdf,
                                      color: Color(0xFFDC2626),
                                      size: 22,
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          const Text(
                                            'PDF saved to device',
                                            style: TextStyle(
                                              color: Colors.black,
                                              fontWeight: FontWeight.w600,
                                              fontSize: 14,
                                            ),
                                          ),
                                          const SizedBox(height: 2),
                                          Text(
                                            safeName,
                                            style: const TextStyle(
                                              color: Color(0xFF6B7280),
                                              fontSize: 12,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                                action: SnackBarAction(
                                  label: 'Open',
                                  textColor: const Color(0xFF426FD4),
                                  onPressed: () => OpenFilex.open(file.path),
                                ),
                                duration: const Duration(seconds: 4),
                              ),
                            );
                          }
                        },
                        icon: const Icon(Icons.picture_as_pdf),
                        label: const Text('Invoice'),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),

                    // ===== PRINT =====
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: () async {
                          final bytes = await buildPurchaseInvoicePdf(
                            number: number,
                            date: date,
                            store: storeName,
                            note: note,
                            items: pdfLines,
                            discount: discount,
                            shipping: shipping,
                            companyName: 'WaveUp',
                            companyAddress: 'Jakarta, Indonesia',
                          );

                          await Printing.layoutPdf(
                            onLayout: (_) async => bytes,
                          );
                        },
                        icon: const Icon(Icons.print),
                        label: const Text('Print'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF426FD4),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                        ),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        );
      },
    );
  }

  // ===== Helper yg hilang (INI YANG MENYEBABKAN ERROR) =====
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
    final s = status.toLowerCase();
    late Color c;
    late String label;
    switch (s) {
      case 'completed':
      case 'success':
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

class _ErrorState extends StatelessWidget {
  final String message;
  final VoidCallback? onRetry;
  const _ErrorState({required this.message, this.onRetry});

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
            if (onRetry != null)
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
