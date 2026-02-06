part of '../../providers/sales_provider.dart';

/// Representasi 1 SKU yang bisa dijual (ringan untuk cart)
/// Representasi 1 SKU yang bisa dijual (ringan untuk cart)
class PosSku {
  final String skuId; // idProductSku -> untuk payload
  final String skuUuid; // uuid -> untuk dedupe/identity di cart
  final String skuCode; // code -> untuk ditampilkan di UI

  final int price; // harga retail
  final String productId; // idProduct
  final String productName; // name
  final String imageUrl; // url gambar (ambil dari product.primaryImageUrl)
  final bool inStock; // sementara: !product.isHide

  const PosSku({
    required this.skuId,
    required this.skuUuid,
    required this.skuCode,
    required this.price,
    required this.productId,
    required this.productName,
    required this.imageUrl,
    this.inStock = true,
  });
}
