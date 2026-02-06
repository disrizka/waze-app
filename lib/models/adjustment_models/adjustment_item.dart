part of '../../providers/adjustment_provider.dart';

@immutable
class AdjustmentItem {
  final String productId;
  final String productSkuId;

  final Product? product;
  final AdjustmentProductSku? productSku;

  final int qtyIn;
  final int qtyOut;

  const AdjustmentItem({
    required this.productId,
    required this.productSkuId,
    this.product,
    this.productSku,
    required this.qtyIn,
    required this.qtyOut,
  });

  factory AdjustmentItem.fromJson(Map<String, dynamic> j) {
    final productJ = _asMap(j['product']);
    final skuJ = _asMap(j['product_sku']);

    return AdjustmentItem(
      productId: _asString(j['product_id']),
      productSkuId: _asString(j['product_sku_id']),
      product: productJ != null ? Product.fromJson(productJ) : null,
      productSku: skuJ != null ? AdjustmentProductSku.fromJson(skuJ) : null,
      qtyIn: _asInt(j['qty_in']),
      qtyOut: _asInt(j['qty_out']),
    );
  }

  int get netQty => qtyIn - qtyOut;
}
