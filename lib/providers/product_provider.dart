import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:wa_blast/services/api_service.dart';

/// =========================
/// MODELS (API GET PARSING)
/// =========================

@immutable
class PageMeta {
  final int currentPage;
  final int rowPerPage;
  final int totalPages;
  final int totalRows;

  const PageMeta({
    required this.currentPage,
    required this.rowPerPage,
    required this.totalPages,
    required this.totalRows,
  });

  factory PageMeta.fromJson(Map<String, dynamic> j) => PageMeta(
    currentPage: (j['current_page'] ?? 0) as int,
    rowPerPage: (j['row_per_page'] ?? 0) as int,
    totalPages: (j['total_pages'] ?? 0) as int,
    totalRows: (j['total_rows'] ?? 0) as int,
  );
}

@immutable
class ProductBrand {
  final String idProductBrand;
  final String name;

  const ProductBrand({required this.idProductBrand, required this.name});

  String get id => idProductBrand; // ✅ alias agar UI bisa pakai .id

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

  String get id => idProductCategory; // (opsional) konsistensi

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
    position: (j['position'] is num)
        ? (j['position'] as num).toInt()
        : 0, // ✅ aman
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
    minQty: (j['minQty'] is num) ? (j['minQty'] as num).toInt() : 0, // ✅ aman
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
  final List<SkuAttribute> attributes; // ✅ tambahkan

  const ProductSku({
    required this.idProductSku,
    required this.code,
    required this.price,
    this.attributes = const [],
  });

  factory ProductSku.fromJson(Map<String, dynamic> j) => ProductSku(
    idProductSku: j['idProductSku']?.toString() ?? '',
    code: j['code'] ?? '',
    price: (j['price'] is num) ? (j['price'] as num).toInt() : 0,
    attributes: (j['attributes'] is List)
        ? (j['attributes'] as List)
              .whereType<Map<String, dynamic>>()
              .map(SkuAttribute.fromJson)
              .toList(growable: false)
        : const <SkuAttribute>[],
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
      name: j['name'] ?? '',
      description: j['description'] ?? '',
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
          : const <ProductImage>[],
      productSkus: (j['productSkus'] is List)
          ? (j['productSkus'] as List)
                .whereType<Map<String, dynamic>>()
                .map(ProductSku.fromJson)
                .toList(growable: false)
          : const <ProductSku>[],
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

/// =========================
/// MODELS (CREATE PAYLOAD)
/// =========================

@immutable
class NewSkuAttribute {
  final String name;
  final String value;
  const NewSkuAttribute({required this.name, required this.value});

  Map<String, dynamic> toJson() => {'name': name, 'value': value};
}

@immutable
class NewSku {
  final String code;
  final int price;
  final List<NewSkuAttribute> attributes;
  const NewSku({
    required this.code,
    required this.price,
    this.attributes = const [],
  });

  Map<String, dynamic> toJson() => {
    'code': code,
    'price': price,
    'attributes': attributes.map((e) => e.toJson()).toList(),
  };
}

@immutable
class NewPrice {
  final int minQty;
  final int price;
  const NewPrice({required this.minQty, required this.price});

  Map<String, dynamic> toJson() => {'min_qty': minQty, 'price': price};
}

@immutable
class NewImage {
  final String filename; // value from /file/upload -> data.filename
  final int position;
  const NewImage({required this.filename, required this.position});

  Map<String, dynamic> toJson() => {'image': filename, 'position': position};
}

/// =========================
/// PROVIDER
/// =========================

class ProductProvider with ChangeNotifier {
  // --- Products
  final List<Product> _products = [];
  bool _loadingProducts = false;
  PageMeta? _pageProducts;

  // --- Product Detail
  Product? _productDetail;
  bool _loadingDetail = false;
  final Map<String, Product> _detailCache = {}; // cache per id

  Product? get productDetail => _productDetail;
  bool get loadingDetail => _loadingDetail;

  // --- Brands
  final List<ProductBrand> _brands = [];
  bool _loadingBrands = false;
  PageMeta? _pageBrands;

  // --- Categories
  final List<ProductCategory> _categories = [];
  bool _loadingCategories = false;
  PageMeta? _pageCategories;

  String? _lastError;
  String? _cachedBizId;

  List<Product> get products => List.unmodifiable(_products);
  List<ProductBrand> get brands => List.unmodifiable(_brands);
  List<ProductCategory> get categories => List.unmodifiable(_categories);

  bool get loadingProducts => _loadingProducts;
  bool get loadingBrands => _loadingBrands;
  bool get loadingCategories => _loadingCategories;

  PageMeta? get pageProducts => _pageProducts;
  PageMeta? get pageBrands => _pageBrands;
  PageMeta? get pageCategories => _pageCategories;

  bool get isEmpty =>
      _products.isEmpty && _brands.isEmpty && _categories.isEmpty;

  String? get lastError => _lastError;

  /// =========================
  /// HELPERS
  /// =========================

  Future<String?> _getBusinessId({bool refresh = false}) async {
    if (!refresh && _cachedBizId != null && _cachedBizId!.isNotEmpty) {
      return _cachedBizId;
    }
    final prefs = await SharedPreferences.getInstance();
    final v = prefs.getString('activeBizId');
    _cachedBizId = v;
    return v;
  }

  Future<Map<String, dynamic>?> _getJson(
    BuildContext context, {
    required String path,
  }) async {
    try {
      final res = await ApiService.get(context, path, withAccessToken: true);
      if (res == null || res.body.isEmpty) return null;
      final decoded = json.decode(res.body);
      if (decoded is Map<String, dynamic>) return decoded;
    } catch (e) {
      _lastError = "$e";
      debugPrint("[ProductProvider] GET $path error: $e");
    }
    return null;
  }

  void _setLoading({
    bool? products,
    bool? brands,
    bool? categories,
    bool? detail,
    bool notify = true,
  }) {
    if (products != null) _loadingProducts = products;
    if (brands != null) _loadingBrands = brands;
    if (categories != null) _loadingCategories = categories;
    if (detail != null) _loadingDetail = detail;
    if (notify) notifyListeners();
  }

  /// =========================
  /// FETCH FUNCTIONS
  /// =========================

  Future<void> fetchProducts(BuildContext context) async {
    final bizId = await _getBusinessId();
    if (bizId == null || bizId.isEmpty) {
      _products.clear();
      notifyListeners();
      return;
    }

    _setLoading(products: true);
    try {
      final jsonMap = await _getJson(context, path: '/waveup/$bizId/product');
      if (jsonMap == null ||
          jsonMap['status'] != 200 ||
          jsonMap['data'] is! List) {
        _products.clear();
        _pageProducts = null;
        return;
      }
      final list = (jsonMap['data'] as List).whereType<Map<String, dynamic>>();
      final parsed = list.map(Product.fromJson).toList(growable: false);

      _products
        ..clear()
        ..addAll(parsed);
      _pageProducts = (jsonMap['page'] is Map<String, dynamic>)
          ? PageMeta.fromJson(jsonMap['page'] as Map<String, dynamic>)
          : null;
    } finally {
      _setLoading(products: false);
    }
  }

  Future<void> fetchProductBrands(BuildContext context) async {
    final bizId = await _getBusinessId();
    if (bizId == null || bizId.isEmpty) {
      _brands.clear();
      notifyListeners();
      return;
    }

    _setLoading(brands: true);
    try {
      final jsonMap = await _getJson(
        context,
        path: '/waveup/$bizId/product-brand',
      );
      if (jsonMap == null ||
          jsonMap['status'] != 200 ||
          jsonMap['data'] is! List) {
        _brands.clear();
        _pageBrands = null;
        return;
      }
      final list = (jsonMap['data'] as List).whereType<Map<String, dynamic>>();
      final parsed = list.map(ProductBrand.fromJson).toList(growable: false);

      _brands
        ..clear()
        ..addAll(parsed);
      _pageBrands = (jsonMap['page'] is Map<String, dynamic>)
          ? PageMeta.fromJson(jsonMap['page'] as Map<String, dynamic>)
          : null;
    } finally {
      _setLoading(brands: false);
    }
  }

  Future<void> fetchProductCategories(BuildContext context) async {
    final bizId = await _getBusinessId();
    if (bizId == null || bizId.isEmpty) {
      _categories.clear();
      notifyListeners();
      return;
    }

    _setLoading(categories: true);
    try {
      final jsonMap = await _getJson(
        context,
        path: '/waveup/$bizId/product-category',
      );
      if (jsonMap == null ||
          jsonMap['status'] != 200 ||
          jsonMap['data'] is! List) {
        _categories.clear();
        _pageCategories = null;
        return;
      }
      final list = (jsonMap['data'] as List).whereType<Map<String, dynamic>>();
      final parsed = list.map(ProductCategory.fromJson).toList(growable: false);

      _categories
        ..clear()
        ..addAll(parsed);
      _pageCategories = (jsonMap['page'] is Map<String, dynamic>)
          ? PageMeta.fromJson(jsonMap['page'] as Map<String, dynamic>)
          : null;
    } finally {
      _setLoading(categories: false);
    }
  }

  Future<Product?> fetchProductDetail(
    BuildContext context,
    String idProduct, {
    bool preferCache = true,
  }) async {
    final bizId = await _getBusinessId();
    if (bizId == null || bizId.isEmpty) {
      _lastError = "Business ID is not available.";
      debugPrint("[fetchProductDetail] ❌ Business ID null/empty");
      return null;
    }

    try {
      if (preferCache && _detailCache.containsKey(idProduct)) {
        _productDetail = _detailCache[idProduct];
        debugPrint("[fetchProductDetail] ✅ Cache hit for id=$idProduct");
        notifyListeners();
      } else {
        debugPrint("[fetchProductDetail] 🔍 Cache miss for id=$idProduct");
      }

      final path = '/waveup/$bizId/product/$idProduct';
      debugPrint("[fetchProductDetail] 🌐 GET $path");

      _setLoading(detail: true);
      final jsonMap = await _getJson(context, path: path);

      if (jsonMap == null) {
        _lastError = 'Null JSON response';
        debugPrint("[fetchProductDetail] ❌ Response is null");
        return _productDetail;
      }

      if (jsonMap['status'] != 200 ||
          jsonMap['data'] is! Map<String, dynamic>) {
        _lastError = 'Failed to get product detail';
        debugPrint(
          "[fetchProductDetail] ❌ Invalid status/data "
          "(status=${jsonMap['status']})",
        );
        return _productDetail;
      }

      // 🔹 print semua data mentah dari API
      final rawData = jsonMap['data'] as Map<String, dynamic>;
      debugPrint("[fetchProductDetail] 📦 Full data: ${jsonEncode(rawData)}");

      final fresh = Product.fromJson(rawData);
      debugPrint(
        "[fetchProductDetail] ✅ Parsed product: "
        "${fresh.idProduct} - ${fresh.name}",
      );

      _productDetail = fresh;
      _detailCache[idProduct] = fresh;
      notifyListeners();
      return fresh;
    } catch (e, st) {
      _lastError = '$e';
      debugPrint("[fetchProductDetail] ❌ Exception: $e");
      debugPrint("$st");
      return _productDetail;
    } finally {
      _setLoading(detail: false);
      debugPrint("[fetchProductDetail] 🔄 Done (loading=false)");
    }
  }

  /// =========================
  /// UPLOAD & CREATE
  /// =========================

  /// Upload 1 file gambar ke /file/upload, return filename dari response (data.filename)
  Future<String?> uploadProductImage(BuildContext context, File file) async {
    final body = await ApiService.uploadFile(file.path);

    if (body != null &&
        body['status'] == 200 &&
        body['data'] is Map<String, dynamic>) {
      final data = body['data'] as Map<String, dynamic>;
      return data['filename']?.toString();
    }

    return null;
  }

  Future<bool> addProduct({
    required BuildContext context,
    required String name,
    required String description,
    required String productBrandId,
    required String productCategoryId,
    required List<NewImage> images,
    required List<NewSku> skus,
    required List<NewPrice> prices,
  }) async {
    final bizId = await _getBusinessId();
    if (bizId == null || bizId.isEmpty) {
      _lastError = "Business ID is not available.";
      return false;
    }

    final payload = {
      'name': name,
      'description': description,
      'product_brand_id': productBrandId,
      'product_category_id': productCategoryId,
      'images': images.map((e) => e.toJson()).toList(),
      'skus': skus.map((e) => e.toJson()).toList(),
      'prices': prices.map((e) => e.toJson()).toList(),
    };

    try {
      // 👀 Debug payload
      debugPrint("[addProduct] Payload: ${jsonEncode(payload)}");

      final res = await ApiService.post(
        context,
        '/waveup/$bizId/product',
        payload,
        withAccessToken: true,
      );

      if (res != null) {
        debugPrint("[addProduct] Response Code: ${res.statusCode}");
        debugPrint("[addProduct] Response Body: ${res.body}");
      } else {
        debugPrint("[addProduct] Response is null");
      }

      final ok = res != null && res.statusCode >= 200 && res.statusCode < 300;
      if (!ok) {
        _lastError = 'Failed to add product: ${res?.statusCode} ${res?.body}';
      } else {
        // refresh list products setelah create
        await fetchProducts(context);
      }
      return ok;
    } catch (e) {
      _lastError = '$e';
      debugPrint("[addProduct] Exception: $e");
      return false;
    }
  }

  Future<bool> addProductBrand(BuildContext context, String name) async {
    final bizId = await _getBusinessId();
    if (bizId == null || bizId.isEmpty) {
      _lastError = "Business ID is not available.";
      return false;
    }

    try {
      final payload = {'name': name};
      final res = await ApiService.post(
        context,
        '/waveup/$bizId/product-brand',
        payload,
      );

      final ok = res != null && res.statusCode >= 200 && res.statusCode < 300;
      if (ok) {
        await fetchProductBrands(context);
        return true;
      } else {
        _lastError = 'Failed to add brand: ${res?.statusCode}';
      }
    } catch (e) {
      _lastError = "$e";
    }
    return false;
  }

  Future<bool> addProductCategory(BuildContext context, String name) async {
    final bizId = await _getBusinessId();
    if (bizId == null || bizId.isEmpty) {
      _lastError = "Business ID is not available.";
      return false;
    }

    try {
      final payload = {'name': name};

      // Debug biar gampang trace
      debugPrint("[addProductCategory] Payload: ${jsonEncode(payload)}");

      final res = await ApiService.post(
        context,
        '/waveup/$bizId/product-category',
        payload,
        // samakan dengan addProductBrand (tanpa withAccessToken explicit jika default sudah handle)
      );

      if (res != null) {
        debugPrint("[addProductCategory] Response Code: ${res.statusCode}");
        debugPrint("[addProductCategory] Response Body: ${res.body}");
      } else {
        debugPrint("[addProductCategory] Response is null");
      }

      final ok = res != null && res.statusCode >= 200 && res.statusCode < 300;
      if (ok) {
        await fetchProductCategories(context);
        return true;
      } else {
        _lastError = 'Failed to add category: ${res?.statusCode} ${res?.body}';
      }
    } catch (e) {
      _lastError = "$e";
      debugPrint("[addProductCategory] Exception: $e");
    }
    return false;
  }

  //EDIT

  Future<bool> updateProductBrand(
    BuildContext context,
    String brandId,
    String name,
  ) async {
    final bizId = await _getBusinessId();
    if (bizId == null || bizId.isEmpty) {
      _lastError = "Business ID is not available.";
      return false;
    }

    try {
      final payload = {'name': name};
      debugPrint("[updateProductBrand] Payload: ${jsonEncode(payload)}");

      // Pakai ApiService.put jika tersedia; jika tidak, ganti ke post
      // dengan method override sesuai server-mu.
      final res = await ApiService.post(
        context,
        '/waveup/$bizId/product-brand/$brandId',
        payload,
        withAccessToken: true,
      );

      if (res != null) {
        debugPrint("[updateProductBrand] Response Code: ${res.statusCode}");
        debugPrint("[updateProductBrand] Response Body: ${res.body}");
      } else {
        debugPrint("[updateProductBrand] Response is null");
      }

      final ok = res != null && res.statusCode >= 200 && res.statusCode < 300;
      if (ok) {
        await fetchProductBrands(context); // refresh list
        return true;
      } else {
        _lastError = 'Failed to update brand: ${res?.statusCode} ${res?.body}';
      }
    } catch (e) {
      _lastError = "$e";
      debugPrint("[updateProductBrand] Exception: $e");
    }
    return false;
  }

  Future<bool> updateProductCategory(
    BuildContext context,
    String categoryId,
    String name,
  ) async {
    final bizId = await _getBusinessId();
    if (bizId == null || bizId.isEmpty) {
      _lastError = "Business ID is not available.";
      return false;
    }

    try {
      final payload = {'name': name};
      debugPrint("[updateProductCategory] Payload: ${jsonEncode(payload)}");

      // Jika punya ApiService.put gunakan ini:
      final res = await ApiService.post(
        context,
        '/waveup/$bizId/product-category/$categoryId',
        payload,
        withAccessToken: true,
      );

      if (res != null) {
        debugPrint("[updateProductCategory] Code: ${res.statusCode}");
        debugPrint("[updateProductCategory] Body: ${res.body}");
      } else {
        debugPrint("[updateProductCategory] Response is null");
      }

      final ok = res != null && res.statusCode >= 200 && res.statusCode < 300;
      if (ok) {
        await fetchProductCategories(context);
        return true;
      } else {
        _lastError =
            'Failed to update category: ${res?.statusCode} ${res?.body}';
      }
    } catch (e) {
      _lastError = "$e";
      debugPrint("[updateProductCategory] Exception: $e");
    }
    return false;
  }

  Future<bool> updateProduct({
    required BuildContext context,
    required String idProduct,
    required String name,
    required String description,
    required String productBrandId,
    required String productCategoryId,
    required List<NewImage> images,
    required List<NewSku> skus,
    required List<NewPrice> prices,
  }) async {
    try {
      final bizId = await _getBusinessId();
      if (bizId == null || bizId.isEmpty) {
        _lastError = "Business ID is not available.";
        return false;
      }

      final payload = {
        'name': name,
        'description': description,
        'product_brand_id': productBrandId,
        'product_category_id': productCategoryId,
        // payload sama dengan add product:
        'images': images.map((e) => e.toJson()).toList(),
        'skus': skus.map((e) => e.toJson()).toList(),
        'prices': prices.map((e) => e.toJson()).toList(),
      };

      if (kDebugMode) {
        // Debug payload
        debugPrint('[ProductProvider] UPDATE payload: ${jsonEncode(payload)}');
      }

      final res = await ApiService.post(
        context,
        '/waveup/$bizId/product/$idProduct',
        payload,
        withAccessToken: true,
      );

      if (kDebugMode) {
        // Debug response (sesuaikan properti res yang tersedia di ApiService kamu)
        debugPrint('[ProductProvider] UPDATE status: ${res.statusCode}');
        debugPrint('[ProductProvider] UPDATE body  : ${res.body}');
      }

      final ok = res != null && res.statusCode >= 200 && res.statusCode < 300;

      if (ok) {
        // refresh list agar UI terbaru
        await fetchProducts(context);

        // refresh detail bila yang sedang dibuka adalah produk yang sama
        if (_productDetail?.idProduct == idProduct) {
          await fetchProductDetail(context, idProduct, preferCache: false);
        } else {
          // setidaknya invalidasi cache id ini
          _detailCache.remove(idProduct);
        }
        return true;
      } else {
        _lastError = res.body ?? 'Failed to update product';
        return false;
      }
    } catch (e) {
      _lastError = e.toString();
      if (kDebugMode) {
        debugPrint('[ProductProvider] UPDATE error: $e');
      }
      return false;
    }
  }

  /// =========================
  /// DELETE FUNCTIONS
  /// =========================

  Future<bool> deleteProduct(BuildContext context, String idProduct) async {
    final bizId = await _getBusinessId();
    if (bizId == null || bizId.isEmpty) {
      _lastError = "Business ID is not available.";
      return false;
    }

    try {
      final path = '/waveup/$bizId/product/remove/$idProduct';
      debugPrint("[deleteProduct] GET $path");

      final jsonMap = await _getJson(context, path: path);

      if (jsonMap == null) {
        _lastError = 'Empty response';
        return false;
      }

      final apiStatus = (jsonMap['status'] is num)
          ? (jsonMap['status'] as num).toInt()
          : -1;
      final message = jsonMap['message']?.toString();

      debugPrint("[deleteProduct] body: $jsonMap");

      if (apiStatus == 200) {
        // refresh list product setelah delete
        await fetchProducts(context);

        // bersihkan cache detail bila yang dihapus adalah yg sedang dibuka
        _detailCache.remove(idProduct);
        if (_productDetail?.idProduct == idProduct) {
          _productDetail = null;
          notifyListeners();
        }
        return true;
      } else {
        _lastError = message ?? 'Failed to delete product';
        return false;
      }
    } catch (e) {
      _lastError = e.toString();
      debugPrint("[deleteProduct] Exception: $e");
      return false;
    }
  }

  Future<bool> deleteProductBrand(BuildContext context, String brandId) async {
    final bizId = await _getBusinessId();
    if (bizId == null || bizId.isEmpty) {
      _lastError = "Business ID is not available.";
      return false;
    }

    try {
      final path = '/waveup/$bizId/product-brand/remove/$brandId';
      debugPrint("[deleteProductBrand] GET $path");

      final jsonMap = await _getJson(context, path: path);

      if (jsonMap == null) {
        _lastError = 'Empty response';
        return false;
      }

      final apiStatus = (jsonMap['status'] is num)
          ? (jsonMap['status'] as num).toInt()
          : -1;
      final message = jsonMap['message']?.toString();
      debugPrint("[deleteProductBrand] body: $jsonMap");

      if (apiStatus == 200) {
        // Optimistic update: hapus dari list lokal
        _brands.removeWhere((b) => b.id == brandId);
        notifyListeners();

        // Refresh dari server biar sinkron
        await fetchProductBrands(context);
        return true;
      } else {
        _lastError = message ?? 'Failed to delete brand';
        return false;
      }
    } catch (e) {
      _lastError = e.toString();
      debugPrint("[deleteProductBrand] Exception: $e");
      return false;
    }
  }

  Future<bool> deleteProductCategory(
    BuildContext context,
    String categoryId,
  ) async {
    final bizId = await _getBusinessId();
    if (bizId == null || bizId.isEmpty) {
      _lastError = "Business ID is not available.";
      return false;
    }

    try {
      final path = '/waveup/$bizId/product-category/remove/$categoryId';
      debugPrint("[deleteProductCategory] GET $path");

      final jsonMap = await _getJson(context, path: path);

      if (jsonMap == null) {
        _lastError = 'Empty response';
        return false;
      }

      final apiStatus = (jsonMap['status'] is num)
          ? (jsonMap['status'] as num).toInt()
          : -1;
      final message = jsonMap['message']?.toString();
      debugPrint("[deleteProductCategory] body: $jsonMap");

      if (apiStatus == 200) {
        // Optimistic update: hapus dari list lokal
        _categories.removeWhere((c) => c.id == categoryId);
        notifyListeners();

        // Refresh dari server biar sinkron
        await fetchProductCategories(context);
        return true;
      } else {
        _lastError = message ?? 'Failed to delete category';
        return false;
      }
    } catch (e) {
      _lastError = e.toString();
      debugPrint("[deleteProductCategory] Exception: $e");
      return false;
    }
  }

  // === ProductProvider: tambahkan di bagian "UPLOAD & CREATE" (atau tepat sebelum EDIT) ===

  Future<ProductBrand?> createBrandNoFetch(
    BuildContext context,
    String name, {
    bool insertIntoProvider = true,
  }) async {
    final bizId = await _getBusinessId();
    if (bizId == null || bizId.isEmpty) {
      _lastError = "Business ID is not available.";
      return null;
    }

    try {
      final payload = {'name': name};
      final res = await ApiService.post(
        context,
        '/waveup/$bizId/product-brand',
        payload,
        withAccessToken: true,
      );

      if (res == null || res.body.isEmpty) return null;
      final j = json.decode(res.body);
      if (j is! Map || (j['status'] as int?) != 200) {
        _lastError = 'Failed to add brand: ${res.statusCode} ${res.body}';
        return null;
      }
      final data = j['data'] as Map<String, dynamic>?;
      if (data == null) return null;

      final created = ProductBrand.fromJson(data);

      if (insertIntoProvider) {
        _brands.add(created);
        notifyListeners();
      }

      return created;
    } catch (e) {
      _lastError = '$e';
      return null;
    }
  }

  Future<ProductCategory?> createCategoryNoFetch(
    BuildContext context,
    String name, {
    bool insertIntoProvider = true,
  }) async {
    final bizId = await _getBusinessId();
    if (bizId == null || bizId.isEmpty) {
      _lastError = "Business ID is not available.";
      return null;
    }

    try {
      final payload = {'name': name};
      final res = await ApiService.post(
        context,
        '/waveup/$bizId/product-category',
        payload,
        withAccessToken: true,
      );

      if (res == null || res.body.isEmpty) return null;
      final j = json.decode(res.body);
      if (j is! Map || (j['status'] as int?) != 200) {
        _lastError = 'Failed to add category: ${res.statusCode} ${res.body}';
        return null;
      }
      final data = j['data'] as Map<String, dynamic>?;
      if (data == null) return null;

      final created = ProductCategory.fromJson(data);

      if (insertIntoProvider) {
        _categories.add(created);
        notifyListeners();
      }

      return created;
    } catch (e) {
      _lastError = '$e';
      return null;
    }
  }

  Future<bool> addProductExactPayload({
    required BuildContext context,
    required String name,
    required String description,
    required String productBrandId,
    required String productCategoryId,
    required List<Map<String, dynamic>>
    images, // [{"image": "...", "position": 1}]
    required List<Map<String, dynamic>> skus, // lihat _onSubmit di bawah
    required List<Map<String, dynamic>>? prices, // null jika multi price off
  }) async {
    final bizId = await _getBusinessId();
    if (bizId == null || bizId.isEmpty) {
      _lastError = "Business ID is not available.";
      return false;
    }

    // payload persis seperti spesifikasi
    final payload = <String, dynamic>{
      'name': name,
      'description': description,
      'product_brand_id': productBrandId,
      'product_category_id': productCategoryId,
      'images': images,
      'skus': skus,
      'prices': prices, // boleh null
    };

    try {
      debugPrint("[addProductExactPayload] Payload: ${jsonEncode(payload)}");

      final res = await ApiService.post(
        context,
        '/waveup/$bizId/product',
        payload,
        withAccessToken: true,
      );

      if (res != null) {
        debugPrint("[addProductExactPayload] Code: ${res.statusCode}");
        debugPrint("[addProductExactPayload] Body: ${res.body}");
      } else {
        debugPrint("[addProductExactPayload] Response is null");
      }

      final ok = res != null && res.statusCode >= 200 && res.statusCode < 300;
      if (ok) {
        await fetchProducts(
          context,
        ); // refresh list agar layar utama up-to-date
        return true;
      } else {
        _lastError = 'Failed to add product: ${res?.statusCode} ${res?.body}';
        return false;
      }
    } catch (e) {
      _lastError = '$e';
      debugPrint("[addProductExactPayload] Exception: $e");
      return false;
    }
  }

  /// Refresh fleksibel
  Future<void> refresh(
    BuildContext context, {
    bool products = true,
    bool brands = true,
    bool categories = true,
  }) async {
    final futures = <Future<void>>[];
    if (products) futures.add(fetchProducts(context));
    if (brands) futures.add(fetchProductBrands(context));
    if (categories) futures.add(fetchProductCategories(context));
    await Future.wait(futures);
  }

  void clearProductDetail({String? id}) {
    if (id != null) _detailCache.remove(id);
    _productDetail = null;
    notifyListeners();
  }
}
