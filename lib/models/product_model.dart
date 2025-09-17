import 'package:flutter/material.dart';

@immutable
class ProductBrand {
  final String idProductBrand;
  final String name;

  const ProductBrand({required this.idProductBrand, required this.name});

  String get id => idProductBrand; // alias agar UI bisa pakai .id

  factory ProductBrand.fromJson(Map<String, dynamic> j) => ProductBrand(
    idProductBrand: j['idProductBrand']?.toString() ?? '',
    name: j['name']?.toString() ?? '',
  );
}

@immutable
class ProductCategory {
  final String idProductCategory;
  final String name;

  const ProductCategory({required this.idProductCategory, required this.name});

  String get id => idProductCategory;

  factory ProductCategory.fromJson(Map<String, dynamic> j) => ProductCategory(
    idProductCategory: j['idProductCategory']?.toString() ?? '',
    name: j['name']?.toString() ?? '',
  );
}

@immutable
class ProductImage {
  final String idProductImage;
  final String image; // filename
  final String imagePath; // full url
  final int position;

  const ProductImage({
    required this.idProductImage,
    required this.image,
    required this.imagePath,
    required this.position,
  });

  factory ProductImage.fromJson(Map<String, dynamic> j) => ProductImage(
    idProductImage: j['idProductImage']?.toString() ?? '',
    image: j['image']?.toString() ?? '',
    imagePath: j['imagePath']?.toString() ?? '',
    position: (j['position'] is num) ? (j['position'] as num).toInt() : 0,
  );
}

@immutable
class ProductPrice {
  final String idProductPrice;
  final int minQty;
  final int price;

  const ProductPrice({
    required this.idProductPrice,
    required this.minQty,
    required this.price,
  });

  factory ProductPrice.fromJson(Map<String, dynamic> j) => ProductPrice(
    idProductPrice: j['idProductPrice']?.toString() ?? '',
    minQty: (j['minQty'] is num) ? (j['minQty'] as num).toInt() : 0,
    price: (j['price'] is num) ? (j['price'] as num).toInt() : 0,
  );
}

@immutable
class SkuAttribute {
  final String name;
  final String value;
  const SkuAttribute({required this.name, required this.value});

  factory SkuAttribute.fromJson(Map<String, dynamic> j) => SkuAttribute(
    name: j['name']?.toString() ?? '',
    value: j['value']?.toString() ?? '',
  );
}

@immutable
class ProductSku {
  final String idProductSku;
  final String code;
  final int price;
  final List<SkuAttribute> attributes;

  const ProductSku({
    required this.idProductSku,
    required this.code,
    required this.price,
    this.attributes = const [],
  });

  factory ProductSku.fromJson(Map<String, dynamic> j) => ProductSku(
    idProductSku: j['idProductSku']?.toString() ?? '',
    code: j['code']?.toString() ?? '',
    price: (j['price'] is num) ? (j['price'] as num).toInt() : 0,
    attributes: (j['attributes'] is List)
        ? (j['attributes'] as List)
              .whereType<Map<String, dynamic>>()
              .map(SkuAttribute.fromJson)
              .toList(growable: false)
        : List<SkuAttribute>.empty(growable: false),
  );
}

@immutable
class Product {
  final String idProduct;
  final String name;
  final String description;
  final bool isHide;
  final ProductBrand? productBrand;
  final ProductCategory? productCategory;
  final List<ProductImage> productImages;
  final List<ProductSku> productSkus;
  final List<ProductPrice> productPrices;

  const Product({
    required this.idProduct,
    required this.name,
    required this.description,
    required this.isHide,
    required this.productBrand,
    required this.productCategory,
    required this.productImages,
    required this.productSkus,
    required this.productPrices,
  });

  factory Product.fromJson(Map<String, dynamic> j) {
    final pricesListRaw = (j['productPrices'] is List)
        ? j['productPrices']
        : (j['prices'] is List)
        ? j['prices']
        : const [];

    final productPrices = (pricesListRaw as List)
        .whereType<Map<String, dynamic>>()
        .map(ProductPrice.fromJson)
        .toList(growable: false);

    return Product(
      idProduct: j['idProduct']?.toString() ?? '',
      name: j['name']?.toString() ?? '',
      description: j['description']?.toString() ?? '',
      isHide: j['isHide'] == true,
      productBrand: (j['productBrand'] is Map<String, dynamic>)
          ? ProductBrand.fromJson(j['productBrand'] as Map<String, dynamic>)
          : null,
      productCategory: (j['productCategory'] is Map<String, dynamic>)
          ? ProductCategory.fromJson(
              j['productCategory'] as Map<String, dynamic>,
            )
          : null,
      productImages: (j['productImages'] is List)
          ? (j['productImages'] as List)
                .whereType<Map<String, dynamic>>()
                .map(ProductImage.fromJson)
                .toList(growable: false)
          : List<ProductImage>.empty(growable: false),
      productSkus: (j['productSkus'] is List)
          ? (j['productSkus'] as List)
                .whereType<Map<String, dynamic>>()
                .map(ProductSku.fromJson)
                .toList(growable: false)
          : List<ProductSku>.empty(growable: false),
      productPrices: productPrices,
    );
  }

  String? get primaryImageUrl {
    if (productImages.isEmpty) return null;
    final sorted = [...productImages]
      ..sort((a, b) => a.position.compareTo(b.position));
    return (sorted.first.imagePath.isNotEmpty) ? sorted.first.imagePath : null;
  }

  int? get basePrice {
    if (productSkus.isNotEmpty) return productSkus.first.price;
    if (productPrices.isNotEmpty) {
      final sorted = [...productPrices]
        ..sort((a, b) => a.minQty.compareTo(b.minQty));
      return sorted.first.price;
    }
    return null;
  }
}
