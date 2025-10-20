// lib/providers/product_provider.dart
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:wa_blast/core/provider_helper.dart';
import 'package:wa_blast/models/product_model.dart';
import 'package:wa_blast/services/api_service.dart';

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

// ====== Tambahkan di area MODELS (mis. setelah NewImage) ======

@immutable
class InventoryAttr {
  final String name;
  final String value;
  const InventoryAttr({required this.name, required this.value});

  factory InventoryAttr.fromJson(Map<String, dynamic> j) => InventoryAttr(
    name: j['name']?.toString() ?? '',
    value: j['value']?.toString() ?? '',
  );
}

@immutable
class InventoryProductSku {
  final String idProductSku;
  final String code;
  final int price;
  final List<InventoryAttr> attributes;

  const InventoryProductSku({
    required this.idProductSku,
    required this.code,
    required this.price,
    required this.attributes,
  });

  factory InventoryProductSku.fromJson(Map<String, dynamic> j) =>
      InventoryProductSku(
        idProductSku: j['idProductSku']?.toString() ?? '',
        code: j['code']?.toString() ?? '',
        price: (j['price'] is num)
            ? (j['price'] as num).toInt()
            : int.tryParse('${j['price']}') ?? 0,
        attributes: (j['attributes'] as List<dynamic>? ?? const [])
            .whereType<Map<String, dynamic>>()
            .map(InventoryAttr.fromJson)
            .toList(),
      );
}

@immutable
class InventoryStoreLocationLite {
  final String idStoreLocation;
  final String name;

  const InventoryStoreLocationLite({
    required this.idStoreLocation,
    required this.name,
  });

  factory InventoryStoreLocationLite.fromJson(Map<String, dynamic> j) =>
      InventoryStoreLocationLite(
        idStoreLocation: j['idStoreLocation']?.toString() ?? '',
        name: j['name']?.toString() ?? '',
      );
}

/// Item riwayat per transaksi inventory.
@immutable
class InventoryHistoryItem {
  final DateTime createdAt;
  final DateTime updatedAt;
  final String note;
  final int qty;
  final String referenceId;
  final String referenceType; // e.g. "purchase"
  final String source; // e.g. "transaction"
  final String type; // e.g. "purchase"
  final Product product; // pakai model Product yang sudah ada
  final InventoryProductSku productSku;
  final InventoryStoreLocationLite storeLocation;

  const InventoryHistoryItem({
    required this.createdAt,
    required this.updatedAt,
    required this.note,
    required this.qty,
    required this.referenceId,
    required this.referenceType,
    required this.source,
    required this.type,
    required this.product,
    required this.productSku,
    required this.storeLocation,
  });

  factory InventoryHistoryItem.fromJson(Map<String, dynamic> j) =>
      InventoryHistoryItem(
        createdAt:
            DateTime.tryParse(j['createdAt']?.toString() ?? '') ??
            DateTime.fromMillisecondsSinceEpoch(0),
        updatedAt:
            DateTime.tryParse(j['updatedAt']?.toString() ?? '') ??
            DateTime.fromMillisecondsSinceEpoch(0),
        note: j['note']?.toString() ?? '',
        qty: (j['qty'] is num)
            ? (j['qty'] as num).toInt()
            : int.tryParse('${j['qty']}') ?? 0,
        referenceId: j['referenceId']?.toString() ?? '',
        referenceType: j['referenceType']?.toString() ?? '',
        source: j['source']?.toString() ?? '',
        type: j['type']?.toString() ?? '',
        product: Product.fromJson(
          (j['product'] as Map?)?.cast<String, dynamic>() ?? const {},
        ),
        productSku: InventoryProductSku.fromJson(
          (j['productSku'] as Map?)?.cast<String, dynamic>() ?? const {},
        ),
        storeLocation: InventoryStoreLocationLite.fromJson(
          (j['storeLocation'] as Map?)?.cast<String, dynamic>() ?? const {},
        ),
      );
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

  // NEW: error khusus produk
  String? _productError;
  String? get productError => _productError;

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

  // --- Inventory History
  final List<InventoryHistoryItem> _inventoryHistory = [];
  bool _loadingInventoryHistory = false;
  PageMeta? _pageInventoryHistory;
  String? _inventoryHistoryError;

  List<InventoryHistoryItem> get inventoryHistory =>
      List.unmodifiable(_inventoryHistory);
  bool get loadingInventoryHistory => _loadingInventoryHistory;
  PageMeta? get pageInventoryHistory => _pageInventoryHistory;
  String? get inventoryHistoryError => _inventoryHistoryError;

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
  /// FETCH FUNCTIONS (pakai helper)
  /// =========================

  Future<void> fetchProducts(BuildContext context) async {
    final bizId = await BizIdCache.get();
    if (bizId == null || bizId.isEmpty) {
      _products.clear();
      _pageProducts = null;
      _productError = "Business ID is not available.";
      notifyListeners();
      return;
    }

    _productError = null; // NEW: clear error
    _setLoading(products: true);
    try {
      final result = await FetchHelper.fetchList<Product>(
        context: context,
        path: '/waveup/$bizId/product/search',
        parser: Product.fromJson,
      );

      if (result == null) {
        _products.clear();
        _pageProducts = null;
        _productError = 'Failed to load products.'; // NEW
        notifyListeners(); // NEW
        return;
      }

      _products
        ..clear()
        ..addAll(result.items);
      _pageProducts = result.page;
      _productError = null; // success
      notifyListeners(); // reflect new data
    } catch (e) {
      _products.clear();
      _pageProducts = null;
      _productError = e.toString(); // NEW
      notifyListeners(); // NEW
    } finally {
      _setLoading(products: false);
    }
  }

  Future<void> fetchProductBrands(BuildContext context) async {
    final bizId = await BizIdCache.get();
    if (bizId == null || bizId.isEmpty) {
      _brands.clear();
      notifyListeners();
      return;
    }

    _setLoading(brands: true);
    try {
      final result = await FetchHelper.fetchList<ProductBrand>(
        context: context,
        path: '/waveup/$bizId/product-brand',
        parser: ProductBrand.fromJson,
      );

      if (result == null) {
        _brands.clear();
        _pageBrands = null;
        return;
      }

      _brands
        ..clear()
        ..addAll(result.items);
      _pageBrands = result.page;
    } finally {
      _setLoading(brands: false);
    }
  }

  Future<void> fetchProductCategories(BuildContext context) async {
    final bizId = await BizIdCache.get();
    if (bizId == null || bizId.isEmpty) {
      _categories.clear();
      notifyListeners();
      return;
    }

    _setLoading(categories: true);
    try {
      final result = await FetchHelper.fetchList<ProductCategory>(
        context: context,
        path: '/waveup/$bizId/product-category',
        parser: ProductCategory.fromJson,
      );

      if (result == null) {
        _categories.clear();
        _pageCategories = null;
        return;
      }

      _categories
        ..clear()
        ..addAll(result.items);
      _pageCategories = result.page;
    } finally {
      _setLoading(categories: false);
    }
  }

  // === Aliases biar cocok dengan UI picker ===
  Future<void> loadProducts(BuildContext context) => fetchProducts(context);

  Future<void> loadProductsIfEmpty(BuildContext context) async {
    if (!_loadingProducts && _products.isEmpty) {
      await fetchProducts(context);
    }
  }

  // ====== Tambahkan method di class ProductProvider (bagian FETCH FUNCTIONS) ======

  Future<void> fetchInventoryHistory(BuildContext context) async {
    final bizId = await BizIdCache.get();
    if (bizId == null || bizId.isEmpty) {
      _inventoryHistory..clear();
      _pageInventoryHistory = null;
      _inventoryHistoryError = "Business ID is not available.";
      notifyListeners();
      return;
    }

    _inventoryHistoryError = null;
    _loadingInventoryHistory = true;
    notifyListeners();

    try {
      final result = await FetchHelper.fetchList<InventoryHistoryItem>(
        context: context,
        path: '/waveup/$bizId/product/history/inventory-transaction/all',
        parser: InventoryHistoryItem.fromJson,
      );

      if (result == null) {
        _inventoryHistory..clear();
        _pageInventoryHistory = null;
        _inventoryHistoryError = 'Failed to load inventory history.';
        notifyListeners();
        return;
      }

      _inventoryHistory
        ..clear()
        ..addAll(result.items);
      _pageInventoryHistory = result.page;
      _inventoryHistoryError = null;
      notifyListeners();
    } catch (e, st) {
      _inventoryHistory..clear();
      _pageInventoryHistory = null;
      _inventoryHistoryError = e.toString();
      debugPrint('[fetchInventoryHistory] Exception: $e');
      debugPrint('$st');
      notifyListeners();
    } finally {
      _loadingInventoryHistory = false;
      notifyListeners();
    }
  }

  /// Optional helper kalau mau lazy load
  Future<void> loadInventoryHistoryIfEmpty(BuildContext context) async {
    if (!_loadingInventoryHistory && _inventoryHistory.isEmpty) {
      await fetchInventoryHistory(context);
    }
  }

  Future<Product?> fetchProductDetail(
    BuildContext context,
    String idProduct, {
    bool preferCache = true,
  }) async {
    final bizId = await BizIdCache.get();
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
      final jsonMap = await ApiJson.getMap(context, path);

      if (jsonMap == null) {
        _lastError = 'Null JSON response';
        debugPrint("[fetchProductDetail] ❌ Response is null");
        return _productDetail;
      }

      if (jsonMap['status'] != 200 ||
          jsonMap['data'] is! Map<String, dynamic>) {
        _lastError = 'Failed to get product detail';
        debugPrint(
          "[fetchProductDetail] ❌ Invalid status/data (status=${jsonMap['status']})",
        );
        return _productDetail;
      }

      final rawData = jsonMap['data'] as Map<String, dynamic>;
      debugPrint("[fetchProductDetail] 📦 Full data: ${jsonEncode(rawData)}");

      final fresh = Product.fromJson(rawData);
      debugPrint(
        "[fetchProductDetail] ✅ Parsed product: ${fresh.idProduct} - ${fresh.name}",
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
    final bizId = await BizIdCache.get();
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
    final bizId = await BizIdCache.get();
    if (bizId == null || bizId.isEmpty) {
      _lastError = "Business ID is not available.";
      return false;
    }

    try {
      final payload = {'name': name};
      final j = await ApiJson.postMap(
        context,
        '/waveup/$bizId/product-brand',
        payload,
        withAccessToken: true,
      );

      final ok = j != null && (j['status'] as int?) == 200;
      if (ok) {
        await fetchProductBrands(context);
        return true;
      } else {
        _lastError = 'Failed to add brand: ${j?['message'] ?? '-'}';
      }
    } catch (e) {
      _lastError = "$e";
    }
    return false;
  }

  Future<bool> addProductCategory(BuildContext context, String name) async {
    final bizId = await BizIdCache.get();
    if (bizId == null || bizId.isEmpty) {
      _lastError = "Business ID is not available.";
      return false;
    }

    try {
      final payload = {'name': name};
      final j = await ApiJson.postMap(
        context,
        '/waveup/$bizId/product-category',
        payload,
        withAccessToken: true,
      );

      final ok = j != null && (j['status'] as int?) == 200;
      if (ok) {
        await fetchProductCategories(context);
        return true;
      } else {
        _lastError = 'Failed to add category: ${j?['message'] ?? '-'}';
      }
    } catch (e) {
      _lastError = "$e";
      debugPrint("[addProductCategory] Exception: $e");
    }
    return false;
  }

  // === CREATE (no fetch) ===

  Future<ProductBrand?> createBrandNoFetch(
    BuildContext context,
    String name, {
    bool insertIntoProvider = true,
  }) async {
    final bizId = await BizIdCache.get();
    if (bizId == null || bizId.isEmpty) {
      _lastError = "Business ID is not available.";
      return null;
    }

    try {
      final j = await ApiJson.postMap(context, '/waveup/$bizId/product-brand', {
        'name': name,
      }, withAccessToken: true);
      if (j == null || (j['status'] as int?) != 200) {
        _lastError = 'Failed to add brand: ${j?['message'] ?? '-'}';
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
    final bizId = await BizIdCache.get();
    if (bizId == null || bizId.isEmpty) {
      _lastError = "Business ID is not available.";
      return null;
    }

    try {
      final j = await ApiJson.postMap(
        context,
        '/waveup/$bizId/product-category',
        {'name': name},
        withAccessToken: true,
      );
      if (j == null || (j['status'] as int?) != 200) {
        _lastError = 'Failed to add category: ${j?['message'] ?? '-'}';
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

  /// =========================
  /// EDIT / UPDATE
  /// =========================

  Future<bool> updateProductBrand(
    BuildContext context,
    String brandId,
    String name,
  ) async {
    final bizId = await BizIdCache.get();
    if (bizId == null || bizId.isEmpty) {
      _lastError = "Business ID is not available.";
      return false;
    }

    try {
      final j = await ApiJson.postMap(
        context,
        '/waveup/$bizId/product-brand/$brandId',
        {'name': name},
        withAccessToken: true,
      );

      final ok = j != null && (j['status'] as int?) == 200;
      if (ok) {
        await fetchProductBrands(context);
        return true;
      } else {
        _lastError = 'Failed to update brand: ${j?['message'] ?? '-'}';
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
    final bizId = await BizIdCache.get();
    if (bizId == null || bizId.isEmpty) {
      _lastError = "Business ID is not available.";
      return false;
    }

    try {
      final j = await ApiJson.postMap(
        context,
        '/waveup/$bizId/product-category/$categoryId',
        {'name': name},
        withAccessToken: true,
      );

      final ok = j != null && (j['status'] as int?) == 200;
      if (ok) {
        await fetchProductCategories(context);
        return true;
      } else {
        _lastError = 'Failed to update category: ${j?['message'] ?? '-'}';
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
    final bizId = await BizIdCache.get();
    if (bizId == null || bizId.isEmpty) {
      _lastError = "Business ID is not available.";
      return false;
    }

    try {
      final payload = {
        'name': name,
        'description': description,
        'product_brand_id': productBrandId,
        'product_category_id': productCategoryId,
        'images': images.map((e) => e.toJson()).toList(),
        'skus': skus.map((e) => e.toJson()).toList(),
        'prices': prices.map((e) => e.toJson()).toList(),
      };

      if (kDebugMode) {
        debugPrint('[ProductProvider] UPDATE payload: ${jsonEncode(payload)}');
      }

      final res = await ApiService.post(
        context,
        '/waveup/$bizId/product/$idProduct',
        payload,
        withAccessToken: true,
      );

      final ok = res != null && res.statusCode >= 200 && res.statusCode < 300;

      if (kDebugMode) {
        debugPrint('[ProductProvider] UPDATE status: ${res?.statusCode}');
        debugPrint('[ProductProvider] UPDATE body  : ${res?.body}');
      }

      if (ok) {
        await fetchProducts(context);
        if (_productDetail?.idProduct == idProduct) {
          await fetchProductDetail(context, idProduct, preferCache: false);
        } else {
          _detailCache.remove(idProduct);
        }
        return true;
      } else {
        _lastError = res?.body ?? 'Failed to update product';
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
    final bizId = await BizIdCache.get();
    if (bizId == null || bizId.isEmpty) {
      _lastError = "Business ID is not available.";
      return false;
    }

    try {
      final path = '/waveup/$bizId/product/remove/$idProduct';
      debugPrint("[deleteProduct] GET $path");

      final jsonMap = await ApiJson.getMap(context, path);

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
        await fetchProducts(context);

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
    final bizId = await BizIdCache.get();
    if (bizId == null || bizId.isEmpty) {
      _lastError = "Business ID is not available.";
      return false;
    }

    try {
      final path = '/waveup/$bizId/product-brand/remove/$brandId';
      debugPrint("[deleteProductBrand] GET $path");

      final jsonMap = await ApiJson.getMap(context, path);

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
        _brands.removeWhere((b) => b.id == brandId);
        notifyListeners();

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
    final bizId = await BizIdCache.get();
    if (bizId == null || bizId.isEmpty) {
      _lastError = "Business ID is not available.";
      return false;
    }

    try {
      final path = '/waveup/$bizId/product-category/remove/$categoryId';
      debugPrint("[deleteProductCategory] GET $path");

      final jsonMap = await ApiJson.getMap(context, path);

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
        _categories.removeWhere((c) => c.id == categoryId);
        notifyListeners();

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

  /// =========================
  /// PAYLOAD EXACT (untuk case khusus)
  /// =========================

  Future<bool> addProductExactPayload({
    required BuildContext context,
    required String name,
    required String description,
    required String productBrandId,
    required String productCategoryId,
    required List<Map<String, dynamic>>
    images, // [{"image": "...", "position": 1}]
    required List<Map<String, dynamic>> skus,
    required List<Map<String, dynamic>>? prices, // null jika multi price off
  }) async {
    final bizId = await BizIdCache.get();
    if (bizId == null || bizId.isEmpty) {
      _lastError = "Business ID is not available.";
      return false;
    }

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
        await fetchProducts(context);
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

  /// =========================
  /// MISC
  /// =========================

  Future<void> refresh(
    BuildContext context, {
    bool products = true,
    bool brands = true,
    bool categories = true,
    bool inventoryHistory = false,
  }) async {
    final futures = <Future<void>>[];
    if (products) futures.add(fetchProducts(context));
    if (brands) futures.add(fetchProductBrands(context));
    if (categories) futures.add(fetchProductCategories(context));
    if (inventoryHistory) futures.add(fetchInventoryHistory(context));
    await Future.wait(futures);
  }

  void clearProductDetail({String? id}) {
    if (id != null) _detailCache.remove(id);
    _productDetail = null;
    notifyListeners();
  }
}
