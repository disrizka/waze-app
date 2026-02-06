part of '../../providers/purchase_provider.dart';

/// ===== CATALOG (per-SKU) khusus purchase =====
@immutable
class PosSku {
  final String skuId; // idProductSku (fallback: productId_code)
  final String skuCode; // code
  final int price; // harga retail / base
  final String productId; // idProduct
  final String productName; // name
  final String imageUrl; // url gambar
  final bool inStock; // dari isHide (dibalik)
  const PosSku({
    required this.skuId,
    required this.skuCode,
    required this.price,
    required this.productId,
    required this.productName,
    required this.imageUrl,
    this.inStock = true,
  });
}
