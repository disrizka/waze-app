part of '../../providers/stock_provider.dart';

/// Payload untuk create stock opname
/// POST /waveup/:bizId/store-location/:storeLocationId/stock-opname
@immutable
class CreateStockOpnamePayload {
  final String productId;
  final String productSkuId;
  final int qty;

  const CreateStockOpnamePayload({
    required this.productId,
    required this.productSkuId,
    required this.qty,
  });

  Map<String, dynamic> toJson() => <String, dynamic>{
    'product_id': productId,
    'product_sku_id': productSkuId,
    'qty': qty,
  };
}
