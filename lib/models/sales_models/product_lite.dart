part of '../../providers/sales_provider.dart';

@immutable
class ProductLite {
  final String idProduct;
  final String name;
  final String? imagePath;
  final String? brand;
  final String? category;

  const ProductLite({
    required this.idProduct,
    required this.name,
    this.imagePath,
    this.brand,
    this.category,
  });

  factory ProductLite.fromJson(Map<String, dynamic> j) {
    String? img() {
      final imgs = j['productImages'];
      if (imgs is List && imgs.isNotEmpty && imgs.first is Map) {
        return (imgs.first['imagePath'] ?? '').toString();
      }
      return null;
    }

    return ProductLite(
      idProduct: (j['idProduct'] ?? '').toString(),
      name: (j['name'] ?? '').toString(),
      imagePath: img(),
      brand: (j['productBrand'] is Map)
          ? ((j['productBrand']['name'] ?? '').toString())
          : null,
      category: (j['productCategory'] is Map)
          ? ((j['productCategory']['name'] ?? '').toString())
          : null,
    );
  }
}
