part of '../../providers/stock_provider.dart';

/// Item di dalam dokumen initial stock (untuk detail & payload store/edit).
@immutable
class InitialStockItem {
  final String productId;
  final String productSkuId;
  final int qty;
  final int price;

  /// per item (optional)
  final int? discount;

  /// Optional: data lengkap kalau API detail mengembalikan product / sku
  final Product? product;
  final StockProductSku? productSku;

  const InitialStockItem({
    required this.productId,
    required this.productSkuId,
    required this.qty,
    required this.price,
    this.discount,
    this.product,
    this.productSku,
  });

  /// Parser fleksibel: coba baca beberapa kemungkinan nama key.
  factory InitialStockItem.fromJson(Map<String, dynamic> j) {
    final productJ = _asMap(j['product']);
    final skuJ = _asMap(j['productSku']);

    final productId =
        j['product_id']?.toString() ??
        j['productId']?.toString() ??
        productJ['idProduct']?.toString() ??
        productJ['id_product']?.toString() ??
        '';

    final productSkuId =
        j['product_sku_id']?.toString() ??
        j['productSkuId']?.toString() ??
        skuJ['idProductSku']?.toString() ??
        skuJ['id_product_sku']?.toString() ??
        '';

    final parsedDiscount = (j['discount'] == null)
        ? null
        : _toInt(j['discount']);

    final hasProduct = productJ.isNotEmpty;
    final hasSku = skuJ.isNotEmpty;

    return InitialStockItem(
      productId: productId,
      productSkuId: productSkuId,
      qty: _toInt(j['qty']),
      price: _toInt(j['price']),
      discount: parsedDiscount,
      product: hasProduct ? Product.fromJson(productJ) : null,
      productSku: hasSku ? StockProductSku.fromJson(skuJ) : null,
    );
  }

  /// JSON untuk payload store / edit:
  /// {
  ///   "product_id": "...",
  ///   "product_sku_id": "...",
  ///   "qty": 100,
  ///   "price": 5000,
  ///   "discount": 0
  /// }
  Map<String, dynamic> toJson() {
    final map = <String, dynamic>{
      'product_id': productId,
      'product_sku_id': productSkuId,
      'qty': qty,
      'price': price,
    };

    if (discount != null) map['discount'] = discount;
    return map;
  }
}
