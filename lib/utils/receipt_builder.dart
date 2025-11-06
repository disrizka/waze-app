import 'dart:typed_data';
import 'package:esc_pos_utils_plus/esc_pos_utils_plus.dart';
import 'package:wa_blast/constants/design_system.dart';

class PurchaseLine {
  final String product;
  final String sku;
  final num qty;
  final int price; // per item
  PurchaseLine({
    required this.product,
    required this.sku,
    required this.qty,
    required this.price,
  });
}

Future<Uint8List> buildEscPosReceiptBytes({
  required String store,
  required String number,
  required DateTime date,
  required String note,
  required List<PurchaseLine> items,
  required int discount,
  required int shipping,
  required int grandTotal,
  bool is80mm = false,
}) async {
  final profile = await CapabilityProfile.load();
  final gen = Generator(is80mm ? PaperSize.mm80 : PaperSize.mm58, profile);
  List<int> bytes = [];

  // Header
  bytes += gen.text(
    store.toUpperCase(),
    styles: const PosStyles(
      align: PosAlign.center,
      bold: true,
      height: PosTextSize.size2,
      width: PosTextSize.size2,
    ),
  );
  bytes += gen.text(
    'No: $number',
    styles: const PosStyles(align: PosAlign.center),
  );
  bytes += gen.text(
    'Tanggal: $date',
    styles: const PosStyles(align: PosAlign.center),
  );
  bytes += gen.hr();

  // Items
  for (final it in items) {
    bytes += gen.text(it.product, styles: const PosStyles(bold: true));
    // Qty x price  ..... line total
    final lineTotal = (it.qty * it.price).round();
    bytes += gen.row([
      PosColumn(text: 'x${it.qty}', width: 3),
      PosColumn(text: 'Rp ${_money(it.price)}', width: 5),
      PosColumn(
        text: 'Rp ${_money(lineTotal)}',
        width: 4,
        styles: const PosStyles(align: PosAlign.right),
      ),
    ]);
    if (it.sku.isNotEmpty) {
      bytes += gen.text('SKU: ${it.sku}');
    }
    bytes += gen.feed(1);
  }
  bytes += gen.hr();

  // Totals
  int itemsTotal = items.fold(0, (p, e) => p + (e.price * e.qty).round());
  bytes += gen.row([
    PosColumn(text: 'Items total', width: 8),
    PosColumn(
      text: 'Rp ${_money(itemsTotal)}',
      width: 4,
      styles: const PosStyles(align: PosAlign.right),
    ),
  ]);
  bytes += gen.row([
    PosColumn(text: 'Discount', width: 8),
    PosColumn(
      text: 'Rp ${_money(discount)}',
      width: 4,
      styles: const PosStyles(align: PosAlign.right),
    ),
  ]);
  bytes += gen.row([
    PosColumn(text: 'Shipping', width: 8),
    PosColumn(
      text: 'Rp ${_money(shipping)}',
      width: 4,
      styles: const PosStyles(align: PosAlign.right),
    ),
  ]);
  bytes += gen.feed(1);
  bytes += gen.row([
    PosColumn(
      text: 'GRAND TOTAL',
      width: 8,
      styles: const PosStyles(
        bold: true,
        height: PosTextSize.size2,
        width: PosTextSize.size2,
      ),
    ),
    PosColumn(
      text: 'Rp ${_money(grandTotal)}',
      width: 4,
      styles: const PosStyles(
        align: PosAlign.right,
        bold: true,
        height: PosTextSize.size2,
        width: PosTextSize.size2,
      ),
    ),
  ]);

  bytes += gen.hr();
  if (note.isNotEmpty && note != '—') {
    bytes += gen.text('Note: $note');
    bytes += gen.feed(1);
  }

  // (Opsional) QR berisi nomor transaksi
  bytes += gen.qrcode(number, size: QRSize.size4);
  bytes += gen.feed(1);

  bytes += gen.text(
    'Terima kasih!',
    styles: const PosStyles(align: PosAlign.center, bold: true),
  );
  bytes += gen.feed(2);
  bytes += gen.cut();
  return Uint8List.fromList(bytes);
}

String _money(num v) {
  // Format sederhana "1.234.567" (Indonesia)
  final s = v.round().toString();
  final buf = StringBuffer();
  for (int i = 0; i < s.length; i++) {
    final idx = s.length - i;
    buf.write(s[i]);
    if (idx > 1 && idx % 3 == 1) buf.write('.');
  }
  return buf.toString();
}
