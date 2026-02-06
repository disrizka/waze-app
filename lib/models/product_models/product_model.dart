import 'package:flutter/material.dart';

@immutable
class ProductBrand {
  final String idProductBrand;
  final String name;

  const ProductBrand({required this.idProductBrand, required this.name});

  String get id => idProductBrand;

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
  final String image;
  final String imagePath;
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
    minQty: (j['minQty'] is num)
        ? (j['minQty'] as num).toInt()
        : int.tryParse('${j['minQty'] ?? 0}') ?? 0,
    price: (j['price'] is num)
        ? (j['price'] as num).toInt()
        : int.tryParse('${j['price'] ?? 0}') ?? 0,
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

/// Item untuk currentStock di SKU (ringan, sesuai response)
@immutable
class SkuCurrentStock {
  final DateTime createdAt;
  final DateTime updatedAt;
  final String note;
  final int qty;
  final String type;
  final StoreLocation? storeLocation;

  const SkuCurrentStock({
    required this.createdAt,
    required this.updatedAt,
    required this.note,
    required this.qty,
    required this.type,
    required this.storeLocation,
  });

  factory SkuCurrentStock.fromJson(Map<String, dynamic> j) => SkuCurrentStock(
    createdAt:
        DateTime.tryParse(j['createdAt']?.toString() ?? '') ??
        DateTime.fromMillisecondsSinceEpoch(0),
    updatedAt:
        DateTime.tryParse(j['updatedAt']?.toString() ?? '') ??
        DateTime.fromMillisecondsSinceEpoch(0),
    note: j['note']?.toString() ?? '',
    qty: (j['qty'] is num)
        ? (j['qty'] as num).toInt()
        : int.tryParse('${j['qty'] ?? 0}') ?? 0,
    type: j['type']?.toString() ?? '',
    storeLocation: (j['storeLocation'] is Map<String, dynamic>)
        ? StoreLocation.fromJson(j['storeLocation'] as Map<String, dynamic>)
        : null,
  );
}

@immutable
class ProductSku {
  /// NEW
  final String uuid;

  final String idProductSku;
  final String code;
  final int price;
  final List<SkuAttribute> attributes;

  /// stok summary dari API: qty / stock_qty
  final int? stockQty;

  /// NEW (opsional): detail stok per store
  final List<SkuCurrentStock> currentStock;

  const ProductSku({
    required this.uuid,
    required this.idProductSku,
    required this.code,
    required this.price,
    this.attributes = const [],
    this.stockQty,
    this.currentStock = const [],
  });

  factory ProductSku.fromJson(Map<String, dynamic> j) => ProductSku(
    uuid: j['uuid']?.toString() ?? '',
    idProductSku: j['idProductSku']?.toString() ?? '',
    code: j['code']?.toString() ?? '',
    price: (j['price'] is num)
        ? (j['price'] as num).toInt()
        : int.tryParse('${j['price'] ?? 0}') ?? 0,

    stockQty: (j['qty'] is num)
        ? (j['qty'] as num).toInt()
        : (j['stock_qty'] is num)
        ? (j['stock_qty'] as num).toInt()
        : int.tryParse('${j['qty'] ?? j['stock_qty'] ?? 0}') ?? 0,

    attributes: (j['attributes'] is List)
        ? (j['attributes'] as List)
              .whereType<Map<String, dynamic>>()
              .map(SkuAttribute.fromJson)
              .toList(growable: false)
        : const <SkuAttribute>[],

    currentStock: (j['currentStock'] is List)
        ? (j['currentStock'] as List)
              .whereType<Map<String, dynamic>>()
              .map(SkuCurrentStock.fromJson)
              .toList(growable: false)
        : const <SkuCurrentStock>[],
  );
}

/// =========================
/// Tambahan: StoreLocation → City → Province
/// =========================

@immutable
class StoreLocation {
  final String idStoreLocation;
  final String name;
  final City? city;

  const StoreLocation({
    required this.idStoreLocation,
    required this.name,
    this.city,
  });

  factory StoreLocation.fromJson(Map<String, dynamic> j) => StoreLocation(
    idStoreLocation:
        (j['idStoreLocation'] ?? j['id_store_location'] ?? j['id'])
            ?.toString() ??
        '',
    name: j['name']?.toString() ?? '',
    city: (j['city'] is Map<String, dynamic>)
        ? City.fromJson(j['city'] as Map<String, dynamic>)
        : null,
  );
}

@immutable
class City {
  final String id;
  final String name;
  final Province? province;

  const City({required this.id, required this.name, this.province});

  factory City.fromJson(Map<String, dynamic> j) => City(
    id: j['id']?.toString() ?? '',
    name: j['name']?.toString() ?? '',
    province: (j['province'] is Map<String, dynamic>)
        ? Province.fromJson(j['province'] as Map<String, dynamic>)
        : null,
  );
}

@immutable
class Province {
  final String id;
  final String name;

  const Province({required this.id, required this.name});

  factory Province.fromJson(Map<String, dynamic> j) => Province(
    id: j['id']?.toString() ?? '',
    name: j['name']?.toString() ?? '',
  );
}

@immutable
class Product {
  /// NEW
  final String uuid;

  final String idProduct;
  final String name;
  final String description;
  final bool isHide;
  final ProductBrand? productBrand;
  final ProductCategory? productCategory;
  final List<ProductImage> productImages;
  final List<ProductSku> productSkus;
  final List<ProductPrice> productPrices;

  final StoreLocation? storeLocation;

  const Product({
    required this.uuid,
    required this.idProduct,
    required this.name,
    required this.description,
    required this.isHide,
    required this.productBrand,
    required this.productCategory,
    required this.productImages,
    required this.productSkus,
    required this.productPrices,
    this.storeLocation,
  });

  factory Product.fromJson(Map<String, dynamic> j) {
    final pricesListRaw = (j['productPrices'] is List)
        ? j['productPrices']
        : (j['prices'] is List)
        ? j['prices']
        : (j['product_prices'] is List)
        ? j['product_prices']
        : const [];

    final productPrices = (pricesListRaw as List)
        .whereType<Map<String, dynamic>>()
        .map(ProductPrice.fromJson)
        .toList(growable: false);

    final storeRaw = (j['storeLocation'] is Map<String, dynamic>)
        ? j['storeLocation'] as Map<String, dynamic>
        : (j['store_location'] is Map<String, dynamic>)
        ? j['store_location'] as Map<String, dynamic>
        : null;

    return Product(
      uuid: j['uuid']?.toString() ?? '',
      idProduct:
          j['idProduct']?.toString() ?? j['id_product']?.toString() ?? '',
      name: j['name']?.toString() ?? '',
      description: j['description']?.toString() ?? '',
      isHide: j['isHide'] == true || j['is_hide'] == true || j['is_hide'] == 1,
      productBrand: (j['productBrand'] is Map<String, dynamic>)
          ? ProductBrand.fromJson(j['productBrand'] as Map<String, dynamic>)
          : (j['product_brand'] is Map<String, dynamic>)
          ? ProductBrand.fromJson(j['product_brand'] as Map<String, dynamic>)
          : null,
      productCategory: (j['productCategory'] is Map<String, dynamic>)
          ? ProductCategory.fromJson(
              j['productCategory'] as Map<String, dynamic>,
            )
          : (j['product_category'] is Map<String, dynamic>)
          ? ProductCategory.fromJson(
              j['product_category'] as Map<String, dynamic>,
            )
          : null,
      productImages: (j['productImages'] is List)
          ? (j['productImages'] as List)
                .whereType<Map<String, dynamic>>()
                .map(ProductImage.fromJson)
                .toList(growable: false)
          : (j['product_images'] is List)
          ? (j['product_images'] as List)
                .whereType<Map<String, dynamic>>()
                .map(ProductImage.fromJson)
                .toList(growable: false)
          : List<ProductImage>.empty(growable: false),
      productSkus: (j['productSkus'] is List)
          ? (j['productSkus'] as List)
                .whereType<Map<String, dynamic>>()
                .map(ProductSku.fromJson)
                .toList(growable: false)
          : (j['product_skus'] is List)
          ? (j['product_skus'] as List)
                .whereType<Map<String, dynamic>>()
                .map(ProductSku.fromJson)
                .toList(growable: false)
          : List<ProductSku>.empty(growable: false),
      productPrices: productPrices,
      storeLocation: (storeRaw == null)
          ? null
          : StoreLocation.fromJson(storeRaw),
    );
  }

  int get totalStockQty {
    if (productSkus.isEmpty) return 0;
    var total = 0;
    for (final sku in productSkus) {
      total += sku.stockQty ?? 0;
    }
    return total;
  }

  bool get isOutOfStock => totalStockQty <= 0;

  String? get primaryImageUrl {
    if (productImages.isEmpty) return null;
    final sorted = [...productImages]
      ..sort((a, b) => a.position.compareTo(b.position));
    return (sorted.first.imagePath.isNotEmpty) ? sorted.first.imagePath : null;
  }

  int? get basePrice {
    if (productSkus.isNotEmpty) {
      final prices = productSkus.map((s) => s.price).toList()..sort();
      return prices.first;
    }
    if (productPrices.isNotEmpty) {
      final sorted = [...productPrices]
        ..sort((a, b) => a.minQty.compareTo(b.minQty));
      return sorted.first.price;
    }
    return null;
  }
}
