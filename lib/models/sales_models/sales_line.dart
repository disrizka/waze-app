part of '../../providers/sales_provider.dart';

/// =========================
/// MODEL RINGAN UNTUK LIST REPORT
/// =========================
@immutable
class SalesLine {
  final String productId;
  final String productSkuId;
  final int qtyOut;
  final int price;

  const SalesLine({
    required this.productId,
    required this.productSkuId,
    required this.qtyOut,
    required this.price,
  });

  factory SalesLine.fromJson(Map<String, dynamic> j) => SalesLine(
    productId: (j['product_id'] ?? '').toString(),
    productSkuId: (j['product_sku_id'] ?? '').toString(),
    qtyOut: (j['qty_out'] is num)
        ? (j['qty_out'] as num).toInt()
        : int.tryParse('${j['qty_out'] ?? 0}') ?? 0,
    price: (j['price'] is num)
        ? (j['price'] as num).toInt()
        : int.tryParse('${j['price'] ?? 0}') ?? 0,
  );
}
