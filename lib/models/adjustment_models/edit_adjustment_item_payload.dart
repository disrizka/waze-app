part of '../../providers/adjustment_provider.dart';

/// Payload edit adjustment (items)
@immutable
class EditAdjustmentItemPayload {
  final String productId;
  final String productSkuId;
  final int qty;

  /// mode: "set" | "add" | "sub" (sesuai backend kamu)
  final String mode;

  const EditAdjustmentItemPayload({
    required this.productId,
    required this.productSkuId,
    required this.qty,
    required this.mode,
  });

  Map<String, dynamic> toJson() => {
    'product_id': productId,
    'product_sku_id': productSkuId,
    'qty': qty,
    'mode': mode,
  };
}
