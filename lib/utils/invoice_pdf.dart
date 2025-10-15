// lib/utils/invoice_pdf.dart
import 'dart:typed_data';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

/// Optional: kalau kamu pakai font sendiri, taruh di assets dan load via pw.Font.ttf.
/// Untuk simple latin, Helvetica bawaan sudah cukup.
final _money = NumberFormat.currency(
  locale: 'id_ID',
  symbol: 'Rp ',
  decimalDigits: 0,
);
final _dateHuman = DateFormat('EEE, d MMM y • HH:mm', 'id_ID');

class PurchaseLine {
  final String product;
  final String sku;
  final int qty;
  final int price; // per item (rupiah)
  const PurchaseLine({
    required this.product,
    required this.sku,
    required this.qty,
    required this.price,
  });
  int get lineTotal => qty * price;
}

Future<Uint8List> buildPurchaseInvoicePdf({
  required String number,
  required DateTime date,
  required String store,
  String? note,
  required List<PurchaseLine> items,
  int discount = 0,
  int shipping = 0,
  String? companyName,
  String? companyAddress,
}) async {
  final doc = pw.Document();

  final subtotal = items.fold<int>(0, (s, e) => s + e.lineTotal);
  final grandTotal = (subtotal - discount + shipping);

  pw.Widget _header() {
    return pw.Row(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
      children: [
        pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Text(
              companyName ?? 'WaveUp',
              style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold),
            ),
            if ((companyAddress ?? '').isNotEmpty) pw.SizedBox(height: 4),
            if ((companyAddress ?? '').isNotEmpty)
              pw.Text(companyAddress!, style: const pw.TextStyle(fontSize: 10)),
          ],
        ),
        pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.end,
          children: [
            pw.Text(
              'INVOICE',
              style: pw.TextStyle(fontSize: 22, fontWeight: pw.FontWeight.bold),
            ),
            pw.SizedBox(height: 4),
            pw.Text(number, style: const pw.TextStyle(fontSize: 12)),
            pw.Text(
              _dateHuman.format(date),
              style: const pw.TextStyle(fontSize: 11),
            ),
          ],
        ),
      ],
    );
  }

  pw.Widget _meta() {
    return pw.Container(
      padding: const pw.EdgeInsets.all(12),
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: PdfColors.grey300),
        borderRadius: pw.BorderRadius.circular(8),
      ),
      child: pw.Row(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Expanded(
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text(
                  'Store',
                  style: pw.TextStyle(color: PdfColors.grey700, fontSize: 10),
                ),
                pw.SizedBox(height: 2),
                pw.Text(
                  store,
                  style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                ),
              ],
            ),
          ),
          pw.SizedBox(width: 12),
          if ((note ?? '').isNotEmpty) pw.SizedBox(width: 12),
          if ((note ?? '').isNotEmpty)
            pw.Expanded(
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text(
                    'Note',
                    style: pw.TextStyle(color: PdfColors.grey700, fontSize: 10),
                  ),
                  pw.SizedBox(height: 2),
                  pw.Text(note!, style: const pw.TextStyle(fontSize: 11)),
                ],
              ),
            ),
        ],
      ),
    );
  }

  pw.Widget _table() {
    return pw.Table(
      border: pw.TableBorder.symmetric(
        inside: pw.BorderSide(color: PdfColors.grey300),
      ),
      columnWidths: {
        0: const pw.FlexColumnWidth(4),
        1: const pw.FlexColumnWidth(2),
        2: const pw.FlexColumnWidth(1),
        3: const pw.FlexColumnWidth(2),
        4: const pw.FlexColumnWidth(2),
      },
      children: [
        pw.TableRow(
          decoration: const pw.BoxDecoration(
            color: PdfColor.fromInt(0xFFF3F4F6),
          ),
          children: [
            _th('Product'),
            _th('SKU'),
            _th('Qty', alignRight: true),
            _th('Price', alignRight: true),
            _th('Total', alignRight: true),
          ],
        ),
        ...items.map(
          (e) => pw.TableRow(
            children: [
              _td(e.product),
              _td(e.sku),
              _td('${e.qty}', alignRight: true),
              _td(_money.format(e.price), alignRight: true),
              _td(_money.format(e.lineTotal), alignRight: true),
            ],
          ),
        ),
      ],
    );
  }

  pw.Widget _totals() {
    pw.Widget row(String label, String val, {bool bold = false}) {
      return pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text(
            label,
            style: pw.TextStyle(
              fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal,
            ),
          ),
          pw.Text(
            val,
            style: pw.TextStyle(
              fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal,
            ),
          ),
        ],
      );
    }

    return pw.Container(
      alignment: pw.Alignment.centerRight,
      child: pw.Container(
        width: 260,
        padding: const pw.EdgeInsets.all(12),
        decoration: pw.BoxDecoration(
          border: pw.Border.all(color: PdfColors.grey300),
          borderRadius: pw.BorderRadius.circular(8),
        ),
        child: pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.stretch,
          children: [
            row('Items total', _money.format(subtotal)),
            if (discount != 0) row('Discount', _money.format(discount)),
            if (shipping != 0) row('Shipping fee', _money.format(shipping)),
            pw.Divider(),
            row('Grand total', _money.format(grandTotal), bold: true),
          ],
        ),
      ),
    );
  }

  doc.addPage(
    pw.MultiPage(
      pageTheme: pw.PageTheme(
        margin: const pw.EdgeInsets.symmetric(horizontal: 28, vertical: 36),
        theme: pw.ThemeData.withFont(
          base: pw.Font.helvetica(),
          bold: pw.Font.helveticaBold(),
        ),
      ),
      build: (context) => [
        _header(),
        pw.SizedBox(height: 18),
        _meta(),
        pw.SizedBox(height: 16),
        _table(),
        pw.SizedBox(height: 16),
        _totals(),
        pw.SizedBox(height: 24),
      ],
      footer: (ctx) => pw.Align(
        alignment: pw.Alignment.centerRight,
        child: pw.Text(
          'Halaman ${ctx.pageNumber}/${ctx.pagesCount}',
          style: const pw.TextStyle(fontSize: 10),
        ),
      ),
    ),
  );

  return doc.save();
}

pw.Widget _th(String text, {bool alignRight = false}) => pw.Padding(
  padding: const pw.EdgeInsets.symmetric(vertical: 8, horizontal: 8),
  child: pw.Text(
    text,
    style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
    textAlign: alignRight ? pw.TextAlign.right : pw.TextAlign.left,
  ),
);

pw.Widget _td(String text, {bool alignRight = false}) => pw.Padding(
  padding: const pw.EdgeInsets.symmetric(vertical: 8, horizontal: 8),
  child: pw.Text(
    text,
    textAlign: alignRight ? pw.TextAlign.right : pw.TextAlign.left,
  ),
);
