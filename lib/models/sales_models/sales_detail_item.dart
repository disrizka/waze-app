part of '../../providers/sales_provider.dart';

@immutable
class SalesDetailItem {
  final String productId;
  final String productSkuId;
  final int qtyOut;
  final int price;
  final int discount;
  final ProductLite? product;
  final ProductSkuLite? productSku;

  const SalesDetailItem({
    required this.productId,
    required this.productSkuId,
    required this.qtyOut,
    required this.price,
    required this.discount,
    this.product,
    this.productSku,
  });

  factory SalesDetailItem.fromJson(Map<String, dynamic> j) => SalesDetailItem(
    productId: (j['product_id'] ?? '').toString(),
    productSkuId: (j['product_sku_id'] ?? '').toString(),
    qtyOut: (j['qty_out'] is num)
        ? (j['qty_out'] as num).toInt()
        : int.tryParse('${j['qty_out'] ?? 0}') ?? 0,
    price: (j['price'] is num)
        ? (j['price'] as num).toInt()
        : int.tryParse('${j['price'] ?? 0}') ?? 0,
    discount: (j['discount'] is num)
        ? (j['discount'] as num).toInt()
        : int.tryParse('${j['discount'] ?? 0}') ?? 0,
    product: (j['product'] is Map)
        ? ProductLite.fromJson((j['product'] as Map).cast<String, dynamic>())
        : null,
    productSku: (j['product_sku'] is Map)
        ? ProductSkuLite.fromJson(
            (j['product_sku'] as Map).cast<String, dynamic>(),
          )
        : null,
  );
}
