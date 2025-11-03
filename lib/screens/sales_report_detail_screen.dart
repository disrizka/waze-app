import 'dart:io';
import 'dart:typed_data';

import 'package:dotted_border/dotted_border.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

// Thermal printing
import 'package:esc_pos_utils_plus/esc_pos_utils_plus.dart' as esc;
import 'package:print_bluetooth_thermal/print_bluetooth_thermal.dart';
import 'package:permission_handler/permission_handler.dart';

import 'package:wa_blast/providers/sales_provider.dart';

class SalesReportDetailScreen extends StatefulWidget {
  final String idTransaction;
  const SalesReportDetailScreen({super.key, required this.idTransaction});

  @override
  State<SalesReportDetailScreen> createState() =>
      _SalesReportDetailScreenState();
}

class _SalesReportDetailScreenState extends State<SalesReportDetailScreen> {
  bool _working = false;
  bool _busyRetryPay = false;
  bool _busyChange = false;

  // ===== platform flags & regex MAC Android =====
  bool get _isAndroid => Platform.isAndroid;
  bool get _isIOS => Platform.isIOS;
  final _macRegex = RegExp(r'^([0-9A-Fa-f]{2}:){5}[0-9A-Fa-f]{2}$');

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _refreshDetail());
  }

  /// Helper agar refresh bisa dipakai dari mana saja (pull-to-refresh & setelah change payment)
  Future<void> _refreshDetail() async {
    if (!mounted) return;
    final prov = context.read<SalesProvider>();
    await prov.fetchSalesDetail(context, widget.idTransaction);
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
        actions: [
          // manual refresh icon (opsional)
          IconButton(
            tooltip: 'Refresh',
            onPressed: _refreshDetail,
            icon: const Icon(Icons.refresh_rounded),
          ),
          // Save PDF
          IconButton(
            tooltip: 'Save PDF',
            onPressed: _working
                ? null
                : () async {
                    final prov = context.read<SalesProvider>();
                    final d = prov.salesDetail;
                    if (d == null) return;
                    setState(() => _working = true);
                    try {
                      final bytes = await _buildPdfBytes(d);
                      final filePath = await _savePdfToDevice(
                        bytes: bytes,
                        filename: _safeFileName(
                          '${d.number.isEmpty ? d.reference : d.number}.pdf',
                        ),
                      );
                      if (!mounted) return;
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('PDF saved: $filePath'),
                          behavior: SnackBarBehavior.floating,
                          action: SnackBarAction(
                            label: 'Open',
                            onPressed: () => Printing.sharePdf(
                              bytes: bytes,
                              filename: filePath.split('/').last,
                            ),
                          ),
                        ),
                      );
                    } catch (e) {
                      if (!mounted) return;
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Failed to save PDF: $e')),
                      );
                    } finally {
                      if (mounted) setState(() => _working = false);
                    }
                  },
            icon: const Icon(Icons.picture_as_pdf_rounded),
          ),
          // Print Thermal
          IconButton(
            tooltip: 'Print Thermal',
            onPressed: _working
                ? null
                : () async {
                    final prov = context.read<SalesProvider>();
                    final d = prov.salesDetail;
                    if (d == null) return;
                    setState(() => _working = true);
                    try {
                      await _printThermal(d); // ⬅️ pakai setting yang tersimpan
                      if (!mounted) return;
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Thermal print sent'),
                          behavior: SnackBarBehavior.floating,
                        ),
                      );
                    } catch (e) {
                      if (!mounted) return;
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Print failed: $e')),
                      );
                    } finally {
                      if (mounted) setState(() => _working = false);
                    }
                  },
            icon: const Icon(Icons.print_rounded),
          ),
        ],
      ),
      body: Consumer<SalesProvider>(
        builder: (context, prov, _) {
          // Bungkus seluruh konten dengan RefreshIndicator
          return RefreshIndicator(
            onRefresh: _refreshDetail,
            child: Builder(
              builder: (_) {
                if (prov.loadingSalesDetail) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (prov.salesDetailError != null) {
                  return _ErrorBox(
                    message: prov.salesDetailError!,
                    onRetry: _refreshDetail,
                  );
                }

                final d = prov.salesDetail;
                if (d == null) {
                  return _ErrorBox(
                    message:
                        'Data transaksi tidak ditemukan.\nCoba kembali dan buka lagi detailnya.',
                    onRetry: _refreshDetail,
                  );
                }

                final calc = d.calculation;
                final totalAmount = calc?.grandtotal ?? d.amount;

                return ListView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
                  children: [
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
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        (d.number.isEmpty
                                            ? d.reference
                                            : d.number),
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
                                    '${d.customer!.name} ${d.customer!.phone.isNotEmpty ? '• ${d.customer!.phone}' : ''}',
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
                                        [skuCode, attrs]
                                            .where((e) => e.isNotEmpty)
                                            .join(' • '),
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

                    if (calc != null) ...[
                      _rowTotal('Subtotal', calc.subtotal, fMoney),
                      _rowTotal(
                        'Discount',
                        -calc.discount,
                        fMoney,
                        discount: true,
                      ),
                      const SizedBox(height: 6),
                      _rowTotal(
                        'Grand Total',
                        calc.grandtotal,
                        fMoney,
                        bold: true,
                      ),
                    ] else ...[
                      _rowTotal('Amount', d.amount, fMoney, bold: true),
                    ],

                    // === ACTIONS UNTUK STATUS PENDING ===
                    if ((d.status).toLowerCase() == 'pending') ...[
                      const SizedBox(height: 18),

                      Builder(
                        builder: (context) {
                          final hasToken =
                              (d.paymentToken?.isNotEmpty ?? false);

                          return ActionButtons(
                            // anim/opacity flags (disable Payment Ulang bila tak ada token)
                            workingPay: _busyRetryPay || !hasToken,
                            workingChange: _busyChange,

                            onRetryPayment: () async {
                              final prov = context.read<SalesProvider>();
                              final token = d.paymentToken ?? '';
                              if (token.isEmpty) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text(
                                      'Token pembayaran tidak ditemukan.',
                                    ),
                                    behavior: SnackBarBehavior.floating,
                                  ),
                                );
                                return;
                              }

                              setState(() => _busyRetryPay = true);
                              try {
                                HapticFeedback.lightImpact();
                                final res = await prov.payWithExistingToken(
                                  context,
                                  idTransaction: d.idTransaction,
                                  token: token,
                                );
                                if (!mounted) return;
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text(
                                      'Status pembayaran: ${res?.status ?? 'unknown'}',
                                    ),
                                    behavior: SnackBarBehavior.floating,
                                  ),
                                );
                                await _refreshDetail();
                              } catch (e) {
                                if (!mounted) return;
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text(
                                      'Gagal membuka pembayaran: $e',
                                    ),
                                    behavior: SnackBarBehavior.floating,
                                  ),
                                );
                              } finally {
                                if (mounted) {
                                  setState(() => _busyRetryPay = false);
                                }
                              }
                            },

                            onChangePayment: () async {
                              final choice = await _showChangePaymentSheet(
                                context,
                              );
                              if (choice == null) return; // batal
                              if (!mounted) return;

                              final prov = context.read<SalesProvider>();

                              setState(() => _busyChange = true);
                              try {
                                HapticFeedback.mediumImpact();

                                final ok = await prov.changePayment(
                                  context,
                                  idTransaction: d.idTransaction,
                                  newMethod: choice.method,
                                );

                                if (!mounted) return;
                                if (ok) {
                                  // ✅ refresh halaman detail setelah berhasil
                                  await _refreshDetail();

                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text(
                                        'Metode pembayaran diperbarui.',
                                      ),
                                      behavior: SnackBarBehavior.floating,
                                    ),
                                  );
                                } else {
                                  final msg =
                                      prov.lastError ??
                                      'Gagal mengubah metode pembayaran';
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text(msg),
                                      behavior: SnackBarBehavior.floating,
                                    ),
                                  );
                                }
                              } catch (e) {
                                if (!mounted) return;
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text('Gagal mengubah metode: $e'),
                                    behavior: SnackBarBehavior.floating,
                                  ),
                                );
                              } finally {
                                if (mounted) {
                                  setState(() => _busyChange = false);
                                }
                              }
                            },
                          );
                        },
                      ),
                    ],
                  ],
                );
              },
            ),
          );
        },
      ),
    );
  }

  Future<_ChangePaymentChoice?> _showChangePaymentSheet(
    BuildContext context,
  ) async {
    int? selected; // 1 or 4

    return showModalBottomSheet<_ChangePaymentChoice>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
      ),
      builder: (ctx) {
        final bottomInset = MediaQuery.of(ctx).viewInsets.bottom;
        return Padding(
          padding: EdgeInsets.only(
            left: 20,
            right: 20,
            top: 14,
            bottom: bottomInset + 28,
          ),
          child: StatefulBuilder(
            builder: (ctx, setSt) {
              return SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 44,
                      height: 5,
                      margin: const EdgeInsets.only(bottom: 14),
                      decoration: BoxDecoration(
                        color: const Color(0xFFE5E7EB),
                        borderRadius: BorderRadius.circular(999),
                      ),
                    ),
                    const Text(
                      'Change Payment',
                      style: TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 17,
                        color: Color(0xFF111827),
                      ),
                    ),
                    const SizedBox(height: 16),

                    RadioListTile<int>(
                      value: 1,
                      groupValue: selected,
                      onChanged: (v) => setSt(() => selected = v),
                      title: const Text(
                        'Cash',
                        style: TextStyle(fontWeight: FontWeight.w700),
                      ),
                      subtitle: const Text('Bayar tunai di kasir'),
                      contentPadding: EdgeInsets.zero,
                      dense: true,
                    ),
                    const Divider(height: 1),
                    RadioListTile<int>(
                      value: 4,
                      groupValue: selected,
                      onChanged: (v) => setSt(() => selected = v),
                      title: const Text(
                        'EDC',
                        style: TextStyle(fontWeight: FontWeight.w700),
                      ),
                      subtitle: const Text('Kartu debit/kredit via mesin EDC'),
                      contentPadding: EdgeInsets.zero,
                      dense: true,
                    ),

                    const SizedBox(height: 24),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () => Navigator.pop(ctx, null),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: const Color(0xFF374151),
                              side: const BorderSide(color: Color(0xFFD1D5DB)),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              padding: const EdgeInsets.symmetric(vertical: 14),
                            ),
                            child: const Text(
                              'Batal',
                              style: TextStyle(fontWeight: FontWeight.w600),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: ElevatedButton(
                            onPressed: selected == null
                                ? null
                                : () {
                                    Navigator.pop(
                                      ctx,
                                      _ChangePaymentChoice(
                                        method: selected!,
                                        cardNumber: null,
                                      ),
                                    );
                                  },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF2563EB), // biru
                              disabledBackgroundColor: const Color(0xFF93C5FD),
                              foregroundColor: Colors.white,
                              elevation: 0,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              padding: const EdgeInsets.symmetric(vertical: 14),
                            ),
                            child: const Text(
                              'Ubah Sekarang',
                              style: TextStyle(fontWeight: FontWeight.w600),
                            ),
                          ),
                        ),
                      ],
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

  // =======================
  // === PDF GENERATOR =====
  // =======================
  Future<Uint8List> _buildPdfBytes(dynamic d) async {
    final fMoney = NumberFormat.decimalPattern('id_ID');
    final fDate = DateFormat('EEE, dd MMM yyyy • HH:mm');

    final doc = pw.Document();
    final grey = PdfColor.fromHex('#6B7280');
    final dark = PdfColor.fromHex('#111827');

    doc.addPage(
      pw.MultiPage(
        pageTheme: pw.PageTheme(
          margin: const pw.EdgeInsets.fromLTRB(24, 24, 24, 24),
        ),
        build: (context) => [
          pw.Row(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Container(
                width: 34,
                height: 34,
                decoration: pw.BoxDecoration(
                  color: PdfColor.fromInt(0xFFEFF4FF),
                  shape: pw.BoxShape.circle,
                ),
              ),
              pw.SizedBox(width: 10),
              pw.Expanded(
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text(
                      (d.number?.isEmpty ?? true) ? d.reference : d.number,
                      style: pw.TextStyle(
                        fontSize: 18,
                        fontWeight: pw.FontWeight.bold,
                        color: dark,
                      ),
                    ),
                    pw.SizedBox(height: 4),
                    pw.Text(
                      fDate.format(d.time),
                      style: pw.TextStyle(color: grey, fontSize: 10),
                    ),
                  ],
                ),
              ),
              pw.Container(
                padding: const pw.EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),
                decoration: pw.BoxDecoration(
                  color: _statusBgPdf(d.status),
                  borderRadius: pw.BorderRadius.circular(999),
                ),
                child: pw.Text(
                  d.status,
                  style: pw.TextStyle(
                    fontSize: 10,
                    fontWeight: pw.FontWeight.bold,
                    color: _statusFgPdf(d.status),
                  ),
                ),
              ),
            ],
          ),
          pw.SizedBox(height: 14),
          pw.Divider(),

          // Items
          pw.SizedBox(height: 8),
          pw.Text(
            'Items',
            style: pw.TextStyle(fontWeight: pw.FontWeight.bold, color: grey),
          ),
          pw.SizedBox(height: 6),
          ...d.items.map<pw.Widget>((it) {
            final lineSubtotal = it.qtyOut * it.price;
            final title = it.product?.name ?? it.productSkuId;
            final skuCode = it.productSku?.code ?? '';
            final attrs = (it.productSku?.attributes ?? [])
                .map<String>((a) => '${a['name']}: ${a['value']}')
                .join(', ');
            final meta = [
              skuCode,
              attrs,
            ].where((e) => e.isNotEmpty).join(' • ');

            return pw.Padding(
              padding: const pw.EdgeInsets.only(bottom: 8),
              child: pw.Row(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Expanded(
                    child: pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Text(
                          title,
                          style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                        ),
                        if (meta.isNotEmpty)
                          pw.Text(
                            meta,
                            style: pw.TextStyle(fontSize: 9, color: grey),
                          ),
                        pw.Text(
                          'Qty ${it.qtyOut} × Rp ${fMoney.format(it.price)}'
                          '${it.discount > 0 ? ' (disc Rp ${fMoney.format(it.discount)}/item)' : ''}',
                          style: pw.TextStyle(fontSize: 9, color: grey),
                        ),
                      ],
                    ),
                  ),
                  pw.SizedBox(width: 8),
                  pw.Text(
                    'Rp ${fMoney.format(lineSubtotal)}',
                    style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                  ),
                ],
              ),
            );
          }).toList(),

          pw.Divider(),
          pw.SizedBox(height: 6),

          if (d.calculation != null) ...[
            _rowTotalPdf('Subtotal', d.calculation.subtotal, fMoney),
            _rowTotalPdf(
              'Discount',
              -d.calculation.discount,
              fMoney,
              discount: true,
            ),
            pw.SizedBox(height: 4),
            _rowTotalPdf(
              'Grand Total',
              d.calculation.grandtotal,
              fMoney,
              bold: true,
            ),
          ] else ...[
            _rowTotalPdf('Amount', d.amount, fMoney, bold: true),
          ],

          pw.SizedBox(height: 12),
          pw.Text(
            'Payment: ${_paymentLabel(d.paymentMethod)}',
            style: pw.TextStyle(fontSize: 10, color: grey),
          ),

          if (d.customer != null) ...[
            pw.SizedBox(height: 6),
            pw.Text(
              'Customer: ${d.customer!.name}${d.customer!.phone.isNotEmpty ? ' • ${d.customer!.phone}' : ''}',
              style: pw.TextStyle(fontSize: 10, color: grey),
            ),
          ],
          if (d.storeLocation != null) ...[
            pw.SizedBox(height: 2),
            pw.Text(
              'Store: ${d.storeLocation!.name}'
              '${d.storeLocation!.city != null ? ' • ${d.storeLocation!.city!.name}' : ''}',
              style: pw.TextStyle(fontSize: 10, color: grey),
            ),
          ],
          if (d.reference.isNotEmpty) ...[
            pw.SizedBox(height: 2),
            pw.Text(
              'Reference: ${d.reference}',
              style: pw.TextStyle(fontSize: 10, color: grey),
            ),
          ],
          if (d.note.isNotEmpty) ...[
            pw.SizedBox(height: 2),
            pw.Text(
              'Note: ${d.note}',
              style: pw.TextStyle(fontSize: 10, color: grey),
            ),
          ],
        ],
      ),
    );
    return doc.save();
  }

  pw.Widget _rowTotalPdf(
    String label,
    int amount,
    NumberFormat fmt, {
    bool bold = false,
    bool discount = false,
  }) {
    final dark = PdfColor.fromHex('#111827');
    final valueColor = discount
        ? PdfColor.fromHex('#166534')
        : PdfColor.fromHex('#374151');
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 2),
      child: pw.Row(
        children: [
          pw.Expanded(
            child: pw.Text(
              label,
              style: pw.TextStyle(
                fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal,
                color: dark,
              ),
            ),
          ),
          pw.Text(
            'Rp ${fmt.format(amount)}',
            style: pw.TextStyle(
              fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal,
              color: valueColor,
            ),
          ),
        ],
      ),
    );
  }

  PdfColor _statusBgPdf(String status) {
    switch (status.toLowerCase()) {
      case 'completed':
      case 'paid':
        return PdfColor.fromHex('#E6F4EA');
      case 'canceled':
      case 'void':
        return PdfColor.fromHex('#FEE2E2');
      default:
        return PdfColor.fromHex('#FEF3C7');
    }
  }

  PdfColor _statusFgPdf(String status) {
    switch (status.toLowerCase()) {
      case 'completed':
      case 'paid':
        return PdfColor.fromHex('#166534');
      case 'canceled':
      case 'void':
        return PdfColor.fromHex('#991B1B');
      default:
        return PdfColor.fromHex('#92400E');
    }
  }

  Future<String> _savePdfToDevice({
    required Uint8List bytes,
    required String filename,
  }) async {
    Directory dir;
    if (Platform.isAndroid) {
      dir =
          (await getDownloadsDirectory()) ??
          await getApplicationDocumentsDirectory();
    } else {
      dir = await getApplicationDocumentsDirectory();
    }
    final path = '${dir.path}/$filename';
    final file = File(path);
    await file.create(recursive: true);
    await file.writeAsBytes(bytes, flush: true);
    return path;
  }

  String _safeFileName(String s) {
    return s.replaceAll(RegExp(r'[^\w\.-]+'), '_');
  }

  // =========================
  // === THERMAL PRINTING ====
  // =========================

  /// Pastikan kita pakai setting yang disimpan & bluetooth ON.
  /// Key yang dipakai:
  /// - printer.type: 'bluetooth' | 'network'
  /// - printer.bt.id: MAC (Android) / UUID (iOS BLE)
  /// - printer.ip: IP printer
  /// - printer.port: port (default 9100)
  /// - printer.paper: 58 | 80
  Future<void> _printThermal(dynamic d) async {
    final sp = await SharedPreferences.getInstance();

    final type = sp.getString('printer.type') ?? 'bluetooth';
    // fallback ke 'printer.mac' bila setting lama
    final btId =
        (sp.getString('printer.bt.id') ?? sp.getString('printer.mac') ?? '')
            .trim();
    final ip = (sp.getString('printer.ip') ?? '').trim();
    final port = sp.getInt('printer.port') ?? 9100;
    final paper = sp.getInt('printer.paper') ?? 58;

    // Siapkan data ESC/POS
    final bytes = await _buildEscPosBytes(d, paper: paper);

    if (type == 'network') {
      if (ip.isEmpty) {
        throw 'IP Address is empty (atur di Settings > Thermal Printer)';
      }
      await _sendTcpRaw(host: ip, port: port, bytes: bytes);
      return;
    }

    // ===== Bluetooth path =====
    if (btId.isEmpty) {
      throw 'Bluetooth device not selected. Buka Settings > Thermal Printer lalu "Scan & Pick".';
    }

    // iOS: minta izin BLE (best effort)
    await _ensureBluetoothPermission();

    // Pastikan bluetooth ON
    final btOn = await PrintBluetoothThermal.bluetoothEnabled;
    if (btOn != true) {
      throw 'Bluetooth is OFF. Nyalakan Bluetooth terlebih dahulu.';
    }

    // Android harus MAC valid (format XX:XX:XX:XX:XX:XX)
    if (_isAndroid && !_macRegex.hasMatch(btId)) {
      throw 'Invalid Bluetooth MAC. Pair di Settings Android & pilih ulang di app.';
    }

    // Putuskan koneksi lama (best effort)
    try {
      await PrintBluetoothThermal.disconnect;
    } catch (_) {}

    // Coba connect (dengan 1x retry ringan)
    bool connected = await PrintBluetoothThermal.connect(
      macPrinterAddress: btId,
    );
    if (!connected) {
      await Future.delayed(const Duration(milliseconds: 250));
      connected = await PrintBluetoothThermal.connect(macPrinterAddress: btId);
    }
    if (!connected) {
      throw 'Unable to connect to printer ($btId).';
    }

    final status = await PrintBluetoothThermal.connectionStatus;
    if (status != true) {
      throw 'Bluetooth not connected.';
    }

    // Delay kecil sebelum tulis pertama (beberapa chipset butuh warm-up)
    await Future.delayed(const Duration(milliseconds: 120));

    // Kirim data: WAJIB List<int> + CHUNKED supaya stabil
    await _writeBluetoothBytesChunked(bytes);

    // (opsional) tunggu sebentar agar buffer kirim selesai sebelum user close
    await Future.delayed(const Duration(milliseconds: 150));
  }

  /// Kirim dalam chunk agar stabil & menghindari ClassCastException
  /// iOS BLE umumnya 20 bytes; Android SPP relatif besar.
  Future<void> _writeBluetoothBytesChunked(Uint8List data) async {
    final payload = data.toList(); // konversi ke List<int> (bukan Uint8List)
    final chunkSize = _isIOS ? 20 : 512;

    for (int offset = 0; offset < payload.length; offset += chunkSize) {
      final end = (offset + chunkSize < payload.length)
          ? offset + chunkSize
          : payload.length;
      final part = payload.sublist(offset, end);

      final ok = await PrintBluetoothThermal.writeBytes(part);
      if (kDebugMode) {
        debugPrint('[BT] write part $offset..$end => $ok');
      }
      if (ok != true) throw 'Write failed at $offset..$end';
      await Future.delayed(const Duration(milliseconds: 10));
    }
  }

  Future<void> _ensureBluetoothPermission() async {
    if (_isIOS) {
      final status = await Permission.bluetooth.request();
      if (status.isDenied) throw 'Bluetooth permission denied';
    } else {
      final statuses = await [
        Permission.bluetooth,
        Permission.bluetoothScan,
        Permission.bluetoothConnect,
      ].request();

      if (statuses[Permission.bluetoothConnect]?.isDenied == true) {
        throw 'Bluetooth Connect permission is required';
      }
    }
  }

  Future<Uint8List> _buildEscPosBytes(dynamic d, {required int paper}) async {
    final fMoney = NumberFormat.decimalPattern('id_ID');
    String money(int v) => 'Rp ${fMoney.format(v)}';

    final profile = await esc.CapabilityProfile.load();
    final gen = esc.Generator(
      paper == 80 ? esc.PaperSize.mm80 : esc.PaperSize.mm58,
      profile,
    );
    final out = <int>[];

    // HEADER
    final storeName = d.storeLocation?.name ?? '';
    if (storeName.isNotEmpty) {
      out.addAll(
        gen.text(
          storeName,
          styles: const esc.PosStyles(
            align: esc.PosAlign.center,
            bold: true,
            height: esc.PosTextSize.size2,
            width: esc.PosTextSize.size2,
          ),
        ),
      );
    }

    final noFaktur = (d.number?.isEmpty ?? true) ? d.reference : d.number;
    out.addAll(
      gen.text(
        noFaktur,
        styles: const esc.PosStyles(align: esc.PosAlign.center, bold: true),
      ),
    );
    out.addAll(
      gen.text(
        DateFormat('dd MMM yyyy HH:mm').format(d.time),
        styles: const esc.PosStyles(align: esc.PosAlign.center),
      ),
    );
    if (d.customer != null && d.customer!.name.isNotEmpty) {
      out.addAll(
        gen.text(
          'Pelanggan: ${d.customer!.name}',
          styles: const esc.PosStyles(align: esc.PosAlign.center),
        ),
      );
    }
    out.addAll(_hrThin(gen));

    // DAFTAR ITEM
    for (final it in d.items) {
      final title = it.product?.name ?? it.productSkuId;
      final lineSubtotal = it.qtyOut * it.price;

      out.addAll(
        gen.row([
          esc.PosColumn(
            width: 8,
            text: title,
            styles: const esc.PosStyles(bold: true),
          ),
          esc.PosColumn(
            width: 4,
            text: money(lineSubtotal),
            styles: const esc.PosStyles(align: esc.PosAlign.right, bold: true),
          ),
        ]),
      );

      final skuCode = it.productSku?.code ?? '';
      final attrs = (it.productSku?.attributes ?? [])
          .map<String>((a) => '${a['name']}:${a['value']}')
          .join(', ');
      final metaParts = <String>[];
      if (skuCode.isNotEmpty) metaParts.add(skuCode);
      if (attrs.isNotEmpty) metaParts.add(attrs);
      if (metaParts.isNotEmpty) {
        out.addAll(
          gen.text(
            metaParts.join(' • '),
            styles: const esc.PosStyles(
              height: esc.PosTextSize.size1,
              width: esc.PosTextSize.size1,
            ),
          ),
        );
      }

      final discNote = it.discount > 0
          ? ' (disc ${fMoney.format(it.discount)}/item)'
          : '';
      out.addAll(
        gen.text(
          '  ${it.qtyOut} × ${money(it.price)}$discNote',
          styles: const esc.PosStyles(),
        ),
      );

      out.addAll(_hrDots(gen));
    }

    // TOTALS
    final calc = d.calculation;
    if (calc != null) {
      out.addAll(_kv(gen, 'Subtotal', money(calc.subtotal)));
      if (calc.discount != 0) {
        out.addAll(_kv(gen, 'Diskon', '- ${money(calc.discount)}'));
      }

      out.addAll(_hrThick(gen));

      out.addAll(
        gen.row([
          esc.PosColumn(
            width: 8,
            text: 'GRAND TOTAL',
            styles: const esc.PosStyles(
              bold: true,
              height: esc.PosTextSize.size2,
              width: esc.PosTextSize.size1,
            ),
          ),
          esc.PosColumn(
            width: 4,
            text: money(calc.grandtotal),
            styles: const esc.PosStyles(
              align: esc.PosAlign.right,
              bold: true,
              height: esc.PosTextSize.size2,
              width: esc.PosTextSize.size1,
            ),
          ),
        ]),
      );
    } else {
      out.addAll(_hrThick(gen));
      out.addAll(
        gen.row([
          esc.PosColumn(
            width: 8,
            text: 'TOTAL',
            styles: const esc.PosStyles(
              bold: true,
              height: esc.PosTextSize.size2,
            ),
          ),
          esc.PosColumn(
            width: 4,
            text: money(d.amount),
            styles: const esc.PosStyles(
              align: esc.PosAlign.right,
              bold: true,
              height: esc.PosTextSize.size2,
            ),
          ),
        ]),
      );
    }

    out.addAll(_hrThin(gen));

    out.addAll(gen.text('Pembayaran: ${_paymentLabel(d.paymentMethod)}'));
    if (d.reference.isNotEmpty) {
      out.addAll(gen.text('Ref: ${d.reference}'));
    }
    if (d.note.isNotEmpty) {
      out.addAll(gen.text('Catatan: ${d.note}'));
    }

    out.addAll(gen.feed(1));
    out.addAll(
      gen.text(
        'Thank you',
        styles: const esc.PosStyles(align: esc.PosAlign.center, bold: true),
      ),
    );
    if (storeName.isNotEmpty) {
      out.addAll(
        gen.text(
          storeName,
          styles: const esc.PosStyles(align: esc.PosAlign.center),
        ),
      );
    }

    out.addAll(gen.feed(2));
    out.addAll(gen.cut());
    return Uint8List.fromList(out);
  }

  // Helpers struk
  List<int> _kv(esc.Generator gen, String k, String v) {
    return gen.row([
      esc.PosColumn(width: 8, text: k),
      esc.PosColumn(
        width: 4,
        text: v,
        styles: const esc.PosStyles(align: esc.PosAlign.right),
      ),
    ]);
  }

  List<int> _hrThin(esc.Generator gen) => gen.hr(ch: '-');
  List<int> _hrThick(esc.Generator gen) => gen.hr();
  List<int> _hrDots(esc.Generator gen) => gen.hr(ch: '.');

  Future<void> _sendTcpRaw({
    required String host,
    required int port,
    required Uint8List bytes,
  }) async {
    Socket? socket;
    try {
      socket = await Socket.connect(
        host,
        port,
        timeout: const Duration(seconds: 4),
      );
      socket.add(bytes);
      await socket.flush();
      await Future.delayed(const Duration(milliseconds: 200));
    } finally {
      await socket?.close();
    }
  }

  // =======================
  // === UI HELPERS EXIST ===
  // =======================
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

class _ChangePaymentChoice {
  final int method; // 1 = Cash, 4 = EDC
  final String? cardNumber;
  _ChangePaymentChoice({required this.method, this.cardNumber});
}

class ActionButtons extends StatelessWidget {
  /// Disable "Retry Payment" when processing
  final bool workingPay;

  /// Disable "Change Payment" when processing
  final bool workingChange;

  final VoidCallback onRetryPayment;
  final VoidCallback onChangePayment;

  const ActionButtons({
    super.key,
    required this.workingPay,
    required this.workingChange,
    required this.onRetryPayment,
    required this.onChangePayment,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: ElevatedButton(
            onPressed: workingPay ? null : onRetryPayment,
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF2563EB), // primary blue
              disabledBackgroundColor: const Color(0xFF93C5FD), // soft blue
              foregroundColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              padding: const EdgeInsets.symmetric(vertical: 12),
              minimumSize: const Size.fromHeight(48),
            ),
            child: const Text(
              'Retry Payment',
              style: TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: OutlinedButton(
            onPressed: workingChange ? null : onChangePayment,
            style: OutlinedButton.styleFrom(
              foregroundColor: const Color(0xFF111827),
              disabledForegroundColor: const Color(0xFF9CA3AF),
              side: const BorderSide(color: Color(0xFFD1D5DB)),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              padding: const EdgeInsets.symmetric(vertical: 12),
              minimumSize: const Size.fromHeight(48),
            ),
            child: const Text(
              'Change Payment',
              style: TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
        ),
      ],
    );
  }
}

// === Widgets existing ===

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

class _GradientButton extends StatefulWidget {
  final bool enabled;
  final String label;
  final String? subtitle;
  final VoidCallback onTap;
  final Gradient gradient;

  const _GradientButton({
    required this.enabled,
    required this.label,
    this.subtitle,
    required this.onTap,
    required this.gradient,
  });

  @override
  State<_GradientButton> createState() => _GradientButtonState();
}

class _GradientButtonState extends State<_GradientButton> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final ts = MediaQuery.textScaleFactorOf(context).clamp(0.9, 1.1);

    final content = Row(
      children: [
        Expanded(
          child: MediaQuery(
            data: MediaQuery.of(context).copyWith(textScaleFactor: ts),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                    fontSize: 14,
                  ),
                ),
                if (widget.subtitle != null)
                  Opacity(
                    opacity: 0.9,
                    child: Text(
                      widget.subtitle!,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
        const SizedBox(width: 4),
        const Icon(Icons.chevron_right_rounded, color: Colors.white, size: 18),
      ],
    );

    return AnimatedOpacity(
      duration: const Duration(milliseconds: 150),
      opacity: widget.enabled ? 1.0 : 0.5,
      child: GestureDetector(
        onTapDown: (_) => setState(() => _pressed = true),
        onTapCancel: () => setState(() => _pressed = false),
        onTapUp: (_) => setState(() => _pressed = false),
        onTap: widget.enabled ? widget.onTap : null,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 120),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          constraints: const BoxConstraints(minHeight: 52),
          decoration: BoxDecoration(
            gradient: widget.gradient,
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF4C6EF5).withOpacity(0.18),
                blurRadius: 10,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: content,
        ),
      ),
    );
  }
}

class TonalDestructiveButton extends StatelessWidget {
  final bool enabled;
  final String label;
  final String? subtitle;
  final VoidCallback onTap;

  const TonalDestructiveButton({
    super.key,
    required this.enabled,
    required this.label,
    this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final ts = MediaQuery.textScaleFactorOf(context).clamp(0.9, 1.1);

    return MediaQuery(
      data: MediaQuery.of(context).copyWith(textScaleFactor: ts),
      child: AnimatedOpacity(
        duration: const Duration(milliseconds: 150),
        opacity: enabled ? 1.0 : 0.5,
        child: InkWell(
          onTap: enabled ? onTap : null,
          borderRadius: BorderRadius.circular(12),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            constraints: const BoxConstraints(minHeight: 48),
            decoration: BoxDecoration(
              color: const Color(0xFFFFF5F5),
              border: Border.all(color: const Color(0xFFFECACA)),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Color(0xFFB91C1C),
                          fontWeight: FontWeight.w700,
                          fontSize: 14,
                        ),
                      ),
                      if (subtitle != null) ...[
                        const SizedBox(height: 2),
                        Text(
                          subtitle!,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Color(0xFFDC2626),
                            fontSize: 11,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                const Icon(
                  Icons.chevron_right_rounded,
                  color: Color(0xFFB91C1C),
                  size: 18,
                ),
              ],
            ),
          ),
        ),
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
        const SizedBox(height: 4),
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
