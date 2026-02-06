part of '../../providers/adjustment_provider.dart';

/// Payload create adjustment (items)
@immutable
class CreateAdjustmentItemPayload {
  final String productId;
  final String productSkuId;
  final int qty;

  const CreateAdjustmentItemPayload({
    required this.productId,
    required this.productSkuId,
    required this.qty,
  });

  Map<String, dynamic> toJson() => {
    'product_id': productId,
    'product_sku_id': productSkuId,
    'qty': qty,
  };
}
