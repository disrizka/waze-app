// lib/providers/purchase_provider.dart
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:wa_blast/models/city_model.dart';
import 'package:wa_blast/models/product_model.dart' hide City;
import 'package:wa_blast/models/purchase_model.dart';

import 'package:wa_blast/models/supplier_model.dart';
import 'package:wa_blast/services/api_service.dart';

import 'package:wa_blast/providers/product_provider.dart' as catalog;

import '../core/provider_helper.dart';

/// Status order
enum PurchaseStatus { inProgress, completed, canceled }

/// Produk katalog (untuk tambah dari bottom sheet)

/// Baris item di order
class OrderLine {
  final String name;
  final int qty;
  final int price; // harga per item (IDR)
  final String note;
  final String imageUrl;

  const OrderLine({
    required this.name,
    required this.qty,
    required this.price,
    this.note = 'Note here',
    this.imageUrl =
        'https://images.unsplash.com/photo-1542831371-29b0f74f9713?w=200&q=60',
  });

  int get lineTotal => qty * price;

  OrderLine copyWith({
    String? name,
    int? qty,
    int? price,
    String? note,
    String? imageUrl,
  }) {
    return OrderLine(
      name: name ?? this.name,
      qty: qty ?? this.qty,
      price: price ?? this.price,
      note: note ?? this.note,
      imageUrl: imageUrl ?? this.imageUrl,
    );
  }
}

T _parseWithTrace<T>(
  Map<String, dynamic> json,
  T Function(Map<String, dynamic>) parser,
) {
  try {
    return parser(json);
  } catch (e, st) {
    debugPrint('[ParserTrace] Error saat parsing item: $e');
    debugPrintStack(stackTrace: st);
    debugPrint('[ParserTrace] Keys: ${json.keys.toList()}');
    json.forEach((k, v) {
      debugPrint('  - $k: ${v.runtimeType} -> $v');
    });
    rethrow; // biarkan ketangkap di catch luar
  }
}

/// Entitas purchase/order
class PurchaseItem {
  final String idTransaction; // <-- NEW
  final String code;
  final DateTime time;
  final int quantity;
  final int totalAmount;
  // kalau kamu sudah hapus status di UI, biarkan properti ini tetap ada atau hapus sekalian.
  final PurchaseStatus status;

  // Detail (tetap)
  final String servicedByName;
  final String servicedById;
  final String servicedByAvatarUrl;
  final double serviceFeePercent;
  final List<OrderLine> lines;

  const PurchaseItem({
    required this.idTransaction, // <-- NEW (wajib diisi)
    required this.code,
    required this.time,
    required this.quantity,
    required this.totalAmount,
    required this.status,
    required this.servicedByName,
    required this.servicedById,
    required this.servicedByAvatarUrl,
    required this.serviceFeePercent,
    required this.lines,
  });

  // ...
  PurchaseItem copyWith({
    String? idTransaction, // <-- NEW
    String? code,
    DateTime? time,
    int? quantity,
    int? totalAmount,
    PurchaseStatus? status,
    String? servicedByName,
    String? servicedById,
    String? servicedByAvatarUrl,
    double? serviceFeePercent,
    List<OrderLine>? lines,
  }) {
    return PurchaseItem(
      idTransaction: idTransaction ?? this.idTransaction, // <-- NEW
      code: code ?? this.code,
      time: time ?? this.time,
      quantity: quantity ?? this.quantity,
      totalAmount: totalAmount ?? this.totalAmount,
      status: status ?? this.status,
      servicedByName: servicedByName ?? this.servicedByName,
      servicedById: servicedById ?? this.servicedById,
      servicedByAvatarUrl: servicedByAvatarUrl ?? this.servicedByAvatarUrl,
      serviceFeePercent: serviceFeePercent ?? this.serviceFeePercent,
      lines: lines ?? this.lines,
    );
  }
}

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

class PurchaseProvider extends ChangeNotifier {
  // ====== SUPPLIERS STATE ======
  final List<Supplier> _suppliers = [];
  PageMeta? _pageSuppliers;
  bool _loadingSuppliers = false;
  String? _supplierError;

  List<Supplier> get suppliers => List.unmodifiable(_suppliers);
  PageMeta? get pageSuppliers => _pageSuppliers;
  bool get loadingSuppliers => _loadingSuppliers;
  String? get supplierError => _supplierError;

  // Detail
  Supplier? _supplierDetail;
  bool _loadingSupplierDetail = false;
  String? _supplierDetailError;

  Supplier? get supplierDetail => _supplierDetail;
  bool get loadingSupplierDetail => _loadingSupplierDetail;
  String? get supplierDetailError => _supplierDetailError;

  // Delete (GET remove)
  final Set<String> _deletingSupplierIds = {};
  String? _deleteSupplierError;

  Set<String> get deletingSupplierIds => _deletingSupplierIds;
  String? get deleteSupplierError => _deleteSupplierError;

  final List<City> _cities = [];
  PageMeta? _pageCities;
  bool _loadingCities = false;
  String? _citiesError;

  List<City> get cities => List.unmodifiable(_cities);
  PageMeta? get pageCities => _pageCities;
  bool get loadingCities => _loadingCities;
  String? get citiesError => _citiesError;

  // ====== Tambahkan di dalam class PurchaseProvider ======
  PurchaseDetail? _purchaseDetail;
  bool _loadingPurchaseDetail = false;
  String? _purchaseDetailError;

  PurchaseDetail? get purchaseDetail => _purchaseDetail;
  bool get loadingPurchaseDetail => _loadingPurchaseDetail;
  String? get purchaseDetailError => _purchaseDetailError;

  final List<PosSku> _catalogSkus = [];
  bool _loadingCatalog = false;
  String? _catalogError;

  List<PosSku> get skus => List.unmodifiable(_catalogSkus);
  bool get loadingSkus => _loadingCatalog;
  String? get catalogError => _catalogError;

  void _setLoadingCatalog(bool v) {
    _loadingCatalog = v;
    notifyListeners();
  }

  /// Ambil produk dari ProductProvider lalu map ke PosSku
  Future<void> loadCatalog(BuildContext context) async {
    _setLoadingCatalog(true);
    try {
      // muat products ke cache ProductProvider
      await context.read<catalog.ProductProvider>().fetchProducts(context);

      final prov = context.read<catalog.ProductProvider>();
      final products = prov.products;

      final List<PosSku> mapped = [];
      for (final p in products) {
        final productId = p.idProduct;
        final productName = p.name;
        final img =
            p.primaryImageUrl ??
            ((p.productImages?.isNotEmpty == true)
                ? p.productImages!.first.imagePath
                : '') ??
            '';
        final bool inStock = !(p.isHide == true);

        final skus = p.productSkus ?? const [];
        for (final s in skus) {
          final rawId = (s.idProductSku ?? '').toString();
          final skuCode = (s.code ?? '').toString();
          final safeId = rawId.isNotEmpty ? rawId : '${productId}_$skuCode';
          final price = (s.price ?? p.basePrice ?? 0);
          if (price <= 0) continue;

          mapped.add(
            PosSku(
              skuId: safeId,
              skuCode: skuCode,
              price: price,
              productId: productId,
              productName: productName,
              imageUrl: img,
              inStock: inStock,
            ),
          );
        }
      }

      _catalogSkus
        ..clear()
        ..addAll(mapped);
      _catalogError = null;
    } catch (e) {
      _catalogSkus.clear();
      _catalogError = e.toString();
    } finally {
      _setLoadingCatalog(false);
    }
  }

  /// Pakai data yang sudah ada di cache ProductProvider (tanpa request)
  void syncCatalogFromCache(BuildContext context) {
    final prov = context.read<catalog.ProductProvider>();
    final products = prov.products;

    final List<PosSku> mapped = [];
    for (final p in products) {
      final productId = p.idProduct;
      final productName = p.name;
      final img =
          p.primaryImageUrl ??
          ((p.productImages?.isNotEmpty == true)
              ? p.productImages!.first.imagePath
              : '') ??
          '';
      final bool inStock = !(p.isHide == true);

      final skus = p.productSkus ?? const [];
      for (final s in skus) {
        final rawId = (s.idProductSku ?? '').toString();
        final skuCode = (s.code ?? '').toString();
        final safeId = rawId.isNotEmpty ? rawId : '${productId}_$skuCode';
        final price = (s.price ?? p.basePrice ?? 0);
        if (price <= 0) continue;

        mapped.add(
          PosSku(
            skuId: safeId,
            skuCode: skuCode,
            price: price,
            productId: productId,
            productName: productName,
            imageUrl: img,
            inStock: inStock,
          ),
        );
      }
    }

    _catalogSkus
      ..clear()
      ..addAll(mapped);
    notifyListeners();
  }

  void _setLoadingPurchaseDetail(bool v) {
    _loadingPurchaseDetail = v;
    notifyListeners();
  }

  void _setPurchaseDetailError(String? msg) {
    _purchaseDetailError = msg;
    notifyListeners();
  }

  void _setCitiesError(String? msg) {
    _citiesError = msg;
    notifyListeners();
  }

  void _setLoadingCities(bool v) {
    _loadingCities = v;
    notifyListeners();
  }

  // =========================
  // ERROR UMUM (untuk submit purchase dll)
  // =========================
  String? _lastError;
  String? get lastError => _lastError;
  String? consumeLastError() {
    final e = _lastError;
    _lastError = null;
    return e;
  }

  Future<String?> _requireBizId() async {
    final bizId = await BizIdCache.get();
    if (bizId == null || bizId.isEmpty) {
      _lastError = 'Business ID is not available.';
      return null;
    }
    return bizId;
  }

  // ====== Setters (private) ======
  void _setLoading({bool? suppliers}) {
    if (suppliers != null) _loadingSuppliers = suppliers;
    notifyListeners();
  }

  void _setSupplierError(String? message) {
    _supplierError = message;
    notifyListeners();
  }

  void _setLoadingDetail(bool v) {
    _loadingSupplierDetail = v;
    notifyListeners();
  }

  void _setSupplierDetailError(String? msg) {
    _supplierDetailError = msg;
    notifyListeners();
  }

  void _setDeleting(String id, bool isDeleting) {
    if (isDeleting) {
      _deletingSupplierIds.add(id);
    } else {
      _deletingSupplierIds.remove(id);
    }
    notifyListeners();
  }

  void _setDeleteSupplierError(String? msg) {
    _deleteSupplierError = msg;
    notifyListeners();
  }

  // =========================
  // GET SUPPLIER LIST (API) - pakai FetchHelper
  // =========================
  Future<void> fetchSuppliers(BuildContext context) async {
    final sw = Stopwatch()..start();
    debugPrint('[fetchSuppliers] Start fetching suppliers...');

    final bizId = await BizIdCache.get();
    debugPrint('[fetchSuppliers] bizId: $bizId');

    if (bizId == null || bizId.isEmpty) {
      debugPrint('[fetchSuppliers] Business ID missing, clearing data.');
      _suppliers.clear();
      _pageSuppliers = null;
      _setSupplierError('Business ID is missing.');
      return;
    }

    _setSupplierError(null);
    _setLoading(suppliers: true);

    try {
      final path = '/waveup/$bizId/supplier';
      debugPrint('[fetchSuppliers] Request -> $path');

      // Pass parser yang dibungkus trace
      final result = await FetchHelper.fetchList<Supplier>(
        context: context,
        path: path,
        parser: (json) => _parseWithTrace(json, Supplier.fromJson),
      );

      if (result == null) {
        debugPrint('[fetchSuppliers] Result is null, clearing suppliers.');
        _suppliers.clear();
        _pageSuppliers = null;
        return;
      }

      debugPrint('[fetchSuppliers] Items: ${result.items.length}');
      _suppliers
        ..clear()
        ..addAll(result.items);

      _pageSuppliers = result.page;
      debugPrint('[fetchSuppliers] Page meta: $_pageSuppliers');
    } catch (e, st) {
      debugPrint('[fetchSuppliers] ERROR: $e');
      debugPrintStack(stackTrace: st);

      if ('$e'.contains('is not a subtype of type \'num\'')) {
        debugPrint(
          '[fetchSuppliers] Hint: Ada field number yang datang sebagai String.',
        );
        debugPrint(
          '[fetchSuppliers] Solusi: perkuat Supplier.fromJson pakai asInt/asDouble yang toleran String/num.',
        );
      }

      _suppliers.clear();
      _pageSuppliers = null;
      _setSupplierError(e.toString());
    } finally {
      _setLoading(suppliers: false);
      sw.stop();
      debugPrint('[fetchSuppliers] Finished in ${sw.elapsedMilliseconds} ms');
    }
  }

  // =========================
  // GET SUPPLIER DETAIL - pakai ApiJson.getMap
  // =========================
  Future<void> fetchSupplierDetail(
    BuildContext context,
    String supplierId,
  ) async {
    final bizId = await BizIdCache.get();
    if (bizId == null || bizId.isEmpty) {
      _supplierDetail = null;
      _setSupplierDetailError('Business ID is missing.');
      return;
    }

    _setSupplierDetailError(null);
    _setLoadingDetail(true);

    try {
      final path = '/waveup/$bizId/supplier/$supplierId';
      final jsonMap = await ApiJson.getMap(context, path);

      if (jsonMap == null ||
          (jsonMap['status'] as num?)?.toInt() != 200 ||
          jsonMap['data'] is! Map) {
        _supplierDetail = null;
        _setSupplierDetailError('Unexpected response format.');
        return;
      }

      _supplierDetail = Supplier.fromJson(
        jsonMap['data'] as Map<String, dynamic>,
      );
      notifyListeners();
    } catch (e) {
      _supplierDetail = null;
      _setSupplierDetailError(e.toString());
    } finally {
      _setLoadingDetail(false);
    }
  }

  /// GET CITIES: /waveup/{bizId}/city
  Future<void> fetchCities(BuildContext context) async {
    final bizId = await BizIdCache.get();
    if (bizId == null || bizId.isEmpty) {
      _cities..clear();
      _pageCities = null;
      _setCitiesError('Business ID is missing.');
      return;
    }

    _setCitiesError(null);
    _setLoadingCities(true);
    try {
      final result = await FetchHelper.fetchList<City>(
        context: context,
        path: '/waveup/$bizId/city',
        parser: City.fromJson,
      );

      if (result == null) {
        _cities.clear();
        _pageCities = null;
        return;
      }

      // optional: sort by province, then name
      result.items.sort((a, b) {
        final p = a.province.name.compareTo(b.province.name);
        return p != 0 ? p : a.name.compareTo(b.name);
      });

      _cities
        ..clear()
        ..addAll(result.items);
      _pageCities = result.page;
      notifyListeners();
    } catch (e) {
      _cities.clear();
      _pageCities = null;
      _setCitiesError(e.toString());
    } finally {
      _setLoadingCities(false);
    }
  }

  // =========================
  // REMOVE SUPPLIER (GET) - pakai ApiJson.getMap
  // =========================
  Future<bool> removeSupplier(BuildContext context, String supplierId) async {
    final bizId = await BizIdCache.get();
    if (bizId == null || bizId.isEmpty) {
      _setDeleteSupplierError('Business ID is missing.');
      return false;
    }

    _setDeleteSupplierError(null);
    _setDeleting(supplierId, true);

    try {
      final path = '/waveup/$bizId/supplier/remove/$supplierId';
      final jsonMap = await ApiJson.getMap(context, path);

      if (jsonMap == null || (jsonMap['status'] as num?)?.toInt() != 200) {
        _setDeleteSupplierError(
          (jsonMap?['message'] as String?) ?? 'Delete failed',
        );
        return false;
      }

      // sukses -> hapus dari cache list
      _suppliers.removeWhere((s) => s.idSupplier == supplierId);

      if (_supplierDetail?.idSupplier == supplierId) {
        _supplierDetail = null;
      }

      notifyListeners();
      return true;
    } catch (e) {
      _setDeleteSupplierError(e.toString());
      return false;
    } finally {
      _setDeleting(supplierId, false);
    }
  }

  // =========================
  // ADD / UPDATE SUPPLIER (POST) - pakai ApiJson.postMap
  // =========================

  /// Upload satu file logo supplier via ApiService.uploadFile(String path).
  /// Harapannya response:
  /// { "status": 200, "data": { "filename": "<stored-filename>" } }
  Future<String?> _uploadSupplierLogo(BuildContext context, File file) async {
    try {
      final body = await ApiService.uploadFile(file.path);
      if (body != null && body['status'] == 200) {
        final data = body['data'];
        if (data is Map<String, dynamic>) {
          final filename = data['filename']?.toString();
          if (filename != null && filename.isNotEmpty) return filename;
        }
        if (data is String && data.isNotEmpty) return data;
      }
    } catch (e) {
      debugPrint("[addSupplier] upload logo error: $e");
    }
    return null;
  }

  Future<bool> addSupplier({
    required BuildContext context,
    required String name,
    File? logoFile, // optional
    String? phone,
    String? email,
    required String cityId,
    String? address,
  }) async {
    final bizId = await BizIdCache.get();
    if (bizId == null || bizId.isEmpty) {
      _supplierDetailError = "Business ID is not available.";
      notifyListeners();
      return false;
    }

    String? logoFilename;
    if (logoFile != null) {
      logoFilename = await _uploadSupplierLogo(context, logoFile);
      if (logoFilename == null || logoFilename.isEmpty) {
        _supplierDetailError = "Failed to upload logo file.";
        notifyListeners();
        return false;
      }
    }

    final payload = <String, dynamic>{
      'name': name,
      'logo': logoFilename, // boleh null jika tidak upload
      'phone': phone,
      'email': email,
      'city_id': cityId,
      'address': address,
    }..removeWhere((k, v) => v == null);

    try {
      if (kDebugMode) {
        debugPrint("[addSupplier] Payload: ${jsonEncode(payload)}");
      }

      final j = await ApiJson.postMap(
        context,
        '/waveup/$bizId/supplier',
        payload,
        withAccessToken: true,
      );

      if (j == null) {
        _supplierDetailError = 'Empty response';
        notifyListeners();
        return false;
      }

      final status = (j['status'] as num?)?.toInt();
      if (status != 200) {
        _supplierDetailError =
            j['message']?.toString() ?? 'Unexpected response';
        notifyListeners();
        return false;
      }

      if (j['data'] is Map<String, dynamic>) {
        final created = Supplier.fromJson(j['data'] as Map<String, dynamic>);
        _suppliers.insert(0, created);
        _supplierDetail = created;
        notifyListeners();
      } else {
        // fallback refresh list
        await fetchSuppliers(context);
      }

      return true;
    } catch (e) {
      _supplierDetailError = '$e';
      notifyListeners();
      return false;
    }
  }

  Future<bool> updateSupplier({
    required BuildContext context,
    required String idSupplier,
    required String name,
    File? logoFile, // optional
    String? phone,
    String? email,
    required String cityId,
    String? address,
  }) async {
    final bizId = await BizIdCache.get();
    if (bizId == null || bizId.isEmpty) {
      _supplierDetailError = "Business ID is not available.";
      notifyListeners();
      return false;
    }

    String? logoFilename;
    if (logoFile != null) {
      logoFilename = await _uploadSupplierLogo(context, logoFile);
      if (logoFilename == null || logoFilename.isEmpty) {
        _supplierDetailError = "Failed to upload logo file.";
        notifyListeners();
        return false;
      }
    }

    final payload = <String, dynamic>{
      'name': name,
      if (logoFilename != null) 'logo': logoFilename, // hanya kirim jika ganti
      'phone': phone,
      'email': email,
      'city_id': cityId,
      'address': address,
    }..removeWhere((k, v) => v == null);

    try {
      final j = await ApiJson.postMap(
        context,
        '/waveup/$bizId/supplier/$idSupplier', // atau PUT jika backend mendukung
        payload,
        withAccessToken: true,
      );

      if (j == null) {
        _supplierDetailError = 'Empty response';
        notifyListeners();
        return false;
      }

      final status = (j['status'] as num?)?.toInt();
      if (status != 200) {
        _supplierDetailError =
            j['message']?.toString() ?? 'Unexpected response';
        notifyListeners();
        return false;
      }

      if (j['data'] is Map<String, dynamic>) {
        final updated = Supplier.fromJson(j['data'] as Map<String, dynamic>);
        final idx = _suppliers.indexWhere((e) => e.idSupplier == idSupplier);
        if (idx != -1) _suppliers[idx] = updated;
        _supplierDetail = updated;
        notifyListeners();
      } else {
        await fetchSuppliers(context);
      }

      return true;
    } catch (e) {
      _supplierDetailError = '$e';
      notifyListeners();
      return false;
    }
  }

  // =========================
  // PURCHASE: LIST
  // =========================

  Future<void> fetchPurchases(BuildContext context) async {
    final sw = Stopwatch()..start();
    debugPrint('[fetchPurchases] Start fetching purchases...');

    final bizId = await BizIdCache.get();
    debugPrint('[fetchPurchases] bizId: $bizId');

    if (bizId == null || bizId.isEmpty) {
      _items.clear();
      _pagePurchases = null;
      _setPurchaseError('Business ID is missing.');
      return;
    }

    _setPurchaseError(null);
    _setLoadingPurchases(true);

    try {
      final path = '/waveup/$bizId/transaction/purchase';
      debugPrint('[fetchPurchases] Request -> $path');

      final result = await FetchHelper.fetchList<PurchaseItem>(
        context: context,
        path: path,
        parser: (json) => _parseWithTrace(json, _purchaseItemFromApi),
      );

      if (result == null) {
        _items.clear();
        _pagePurchases = null;
        return;
      }

      _items
        ..clear()
        ..addAll(result.items);
      _pagePurchases = result.page;

      debugPrint('[fetchPurchases] Items: ${_items.length}');
      debugPrint('[fetchPurchases] Page: $_pagePurchases');
      notifyListeners();
    } catch (e, st) {
      debugPrint('[fetchPurchases] ERROR: $e');
      debugPrintStack(stackTrace: st);

      if ('$e'.contains('is not a subtype of type \'num\'')) {
        debugPrint(
          '[fetchPurchases] Hint: Ada field number datang sebagai String.',
        );
      }

      _items.clear();
      _pagePurchases = null;
      _setPurchaseError(e.toString());
    } finally {
      _setLoadingPurchases(false);
      sw.stop();
      debugPrint('[fetchPurchases] Finished in ${sw.elapsedMilliseconds} ms');
    }
  }

  /// GET detail purchase: /waveup/{bizId}/transaction/purchase/{idTransaction}
  Future<PurchaseDetail?> fetchPurchaseDetail(
    BuildContext context,
    String idTransaction,
  ) async {
    final bizId = await _requireBizId();
    if (bizId == null) return null;

    _setPurchaseDetailError(null);
    _setLoadingPurchaseDetail(true);
    try {
      final path = '/waveup/$bizId/transaction/purchase/$idTransaction';
      final j = await ApiJson.getMap(context, path);
      if (j == null ||
          (j['status'] as num?)?.toInt() != 200 ||
          j['data'] is! Map) {
        _setPurchaseDetailError('Unexpected response.');
        _purchaseDetail = null;
        return null;
      }
      final data = j['data'] as Map<String, dynamic>;
      _purchaseDetail = PurchaseDetail.fromJson(data);
      notifyListeners();
      return _purchaseDetail;
    } catch (e) {
      _setPurchaseDetailError(e.toString());
      _purchaseDetail = null;
      return null;
    } finally {
      _setLoadingPurchaseDetail(false);
    }
  }

  // =========================
  // PURCHASE: CREATE (POST)
  // =========================
  /// Kirim payload sesuai spesifikasi:
  /// {
  ///   "number": "", // optional kosong
  ///   "store_location_id": "...",
  ///   "note": "...",
  ///   "reference": "...",
  ///   "discount": 0,
  ///   "shipping_fee": 0,
  ///   "items": [
  ///     {
  ///       "product_id": "...",
  ///       "product_sku_id": "...",
  ///       "qty": 100,
  ///       "price": 5000
  ///     }
  ///   ]
  /// }
  // ===== GANTI SELURUH fungsi storePurchase DENGAN VERSI INI =====
  Future<bool> storePurchase(
    BuildContext context,
    Map<String, dynamic> payload,
  ) async {
    final sw = Stopwatch()..start();
    final bizId = await _requireBizId();
    if (bizId == null) return false;

    // Normalisasi tipe numerik supaya aman
    try {
      if (payload['discount'] is String) {
        payload['discount'] = int.tryParse(payload['discount']) ?? 0;
      }
      if (payload['shipping_fee'] is String) {
        payload['shipping_fee'] = int.tryParse(payload['shipping_fee']) ?? 0;
      }
      if (payload['items'] is List) {
        final items = payload['items'] as List;
        for (final it in items) {
          if (it is Map<String, dynamic>) {
            final q = it['qty'];
            final p = it['price'];
            if (q is String) it['qty'] = int.tryParse(q) ?? 0;
            if (p is String) it['price'] = int.tryParse(p) ?? 0;
          }
        }
      }
    } catch (_) {
      // abaikan
    }

    final path = '/waveup/$bizId/transaction/purchase';

    // 🔎 Log request
    if (kDebugMode) {
      debugPrint('────────────────────────────────────────');
      debugPrint('[storePurchase] ▶️ POST $path');
      debugPrint('[storePurchase] Payload: ${_prettyJson(payload)}');
    }

    try {
      final j = await ApiJson.postMap(
        context,
        path,
        payload,
        withAccessToken: true,
      );

      // 🔎 Log response dasar
      if (kDebugMode) {
        debugPrint('[storePurchase] ◀️ Raw response: ${_prettyJson(j)}');
      }

      if (j == null) {
        _lastError = 'Empty response';
        if (kDebugMode) {
          debugPrint('[storePurchase] ❌ Empty response dari server');
        }
        return false;
      }

      // Ambil status/message yang umum dipakai backend
      final status = (j['status'] as num?)?.toInt();
      final msg = j['msg']?.toString() ?? j['message']?.toString();

      if (kDebugMode) {
        debugPrint('[storePurchase] status: $status | message: $msg');
        final data = j['data'];
        if (data != null) {
          debugPrint(
            '[storePurchase] data keys: '
            '${data is Map ? (data as Map).keys.join(", ") : data.runtimeType}',
          );
        }
      }

      if (status != 200) {
        // Tangkap pesan error server (termasuk error SQL/trace jika ada)
        _lastError = msg ?? 'Failed to store purchase';
        if (kDebugMode) {
          // Jika backend kirim field "error"/"errors", log juga biar jelas
          final srvErr = j['error'] ?? j['errors'];
          if (srvErr != null) {
            debugPrint('[storePurchase] server error: ${_prettyJson(srvErr)}');
          }
          debugPrint('[storePurchase] ❌ Gagal simpan purchase');
        }
        return false;
      }

      if (kDebugMode) {
        debugPrint('[storePurchase] ✅ Berhasil simpan purchase');
      }
      return true;
    } catch (e, st) {
      _lastError = '$e';
      if (kDebugMode) {
        debugPrint('[storePurchase] EXCEPTION: $e');
        debugPrintStack(stackTrace: st);
      }
      return false;
    } finally {
      sw.stop();
      if (kDebugMode) {
        debugPrint(
          '[storePurchase] ⏱️ selesai dalam ${sw.elapsedMilliseconds} ms',
        );
        debugPrint('────────────────────────────────────────');
      }
    }
  }

  String _prettyJson(Object? j) {
    try {
      return const JsonEncoder.withIndent('  ').convert(j);
    } catch (_) {
      return j.toString();
    }
  }

  // Optional: flag agar UI bisa cek ketersediaan
  bool get respondsToUpdateSupplier => true;

  PurchaseStatus? _filter;

  // ====== Purchases (from API) ======
  final List<PurchaseItem> _items = [];
  PageMeta? _pagePurchases;
  bool _loadingPurchases = false;
  String? _purchaseError;

  List<PurchaseItem> get items => _filter == null
      ? List.unmodifiable(_items)
      : _items.where((e) => e.status == _filter).toList(growable: false);

  PageMeta? get pagePurchases => _pagePurchases;
  bool get loadingPurchases => _loadingPurchases;
  String? get purchaseError => _purchaseError;

  void _setPurchaseError(String? message) {
    _purchaseError = message;
    notifyListeners();
  }

  void _setLoadingPurchases(bool v) {
    _loadingPurchases = v;
    notifyListeners();
  }

  PurchaseStatus? get filter => _filter;

  // ====== Actions umum ======
  void setFilter(PurchaseStatus? status) {
    _filter = status;
    notifyListeners();
  }

  Future<void> refresh() async {
    await Future<void>.delayed(const Duration(milliseconds: 500));
    notifyListeners();
  }

  PurchaseItem? getByCode(String code) {
    try {
      return _items.firstWhere((e) => e.code == code);
    } catch (_) {
      return null;
    }
  }

  void updateStatus(String code, PurchaseStatus newStatus) {
    final idx = _items.indexWhere((e) => e.code == code);
    if (idx == -1) return;
    _items[idx] = _items[idx].copyWith(status: newStatus);
    notifyListeners();
  }

  // ====== Kontrol qty/baris ======
  void setLineQty(String code, int lineIndex, int qty) {
    final idx = _items.indexWhere((e) => e.code == code);
    if (idx == -1) return;

    final item = _items[idx];
    if (lineIndex < 0 || lineIndex >= item.lines.length) return;

    final newLines = List<OrderLine>.from(item.lines);
    final newQty = qty.clamp(0, 9999);

    if (newQty == 0) {
      newLines.removeAt(lineIndex);
    } else {
      newLines[lineIndex] = newLines[lineIndex].copyWith(qty: newQty);
    }

    final newTotalQty = newLines.fold<int>(0, (s, l) => s + l.qty);

    _items[idx] = item.copyWith(lines: newLines, quantity: newTotalQty);
    notifyListeners();
  }

  void incrementLineQty(String code, int lineIndex) {
    final item = getByCode(code);
    if (item == null || lineIndex < 0 || lineIndex >= item.lines.length) return;
    setLineQty(code, lineIndex, item.lines[lineIndex].qty + 1);
  }

  void decrementLineQty(String code, int lineIndex) {
    final item = getByCode(code);
    if (item == null || lineIndex < 0 || lineIndex >= item.lines.length) return;
    setLineQty(code, lineIndex, (item.lines[lineIndex].qty - 1).clamp(0, 9999));
  }

  int getQtyForProduct(String code, String productName) {
    final item = getByCode(code);
    if (item == null) return 0;
    final i = item.lines.indexWhere((l) => l.name == productName);
    return i == -1 ? 0 : item.lines[i].qty;
  }
}

PurchaseItem _purchaseItemFromApi(Map<String, dynamic> j) {
  final itemsJson =
      (j['items'] as List?)?.cast<Map<String, dynamic>>() ?? const [];

  final lines = itemsJson
      .map((it) {
        final qtyIn = _asInt(it['qty_in']);
        final qtyOut = _asInt(it['qty_out']);
        final qty = (qtyIn - qtyOut).clamp(0, 1 << 31);
        return OrderLine(
          name: (it['product_id']?.toString().isNotEmpty ?? false)
              ? it['product_id'].toString()
              : 'SKU',
          qty: qty,
          price: _asInt(it['price']),
          note: (it['transaction_reference']?.toString() ?? ''),
          imageUrl:
              'https://images.unsplash.com/photo-1542831371-29b0f74f9713?w=200&q=60',
        );
      })
      .toList(growable: false);

  final totalQty = lines.fold<int>(0, (s, l) => s + l.qty);

  return PurchaseItem(
    idTransaction: (j['idTransaction'] ?? j['id_transaction'] ?? '')
        .toString(), // <-- tambahkan ini
    code: j['number']?.toString() ?? '',
    time: _parseTime(j['order_at'], j['created_at']),
    quantity: totalQty,
    totalAmount: _asInt(j['amount']),
    status: _mapStatus(j['status']?.toString()),
    servicedByName: '-', // tidak tersedia di respons
    servicedById: '-', // tidak tersedia di respons
    servicedByAvatarUrl: '', // tidak tersedia di respons
    serviceFeePercent: 0.0, // tidak ada service fee di API ini
    lines: lines,
  );
}

int _asInt(dynamic v) {
  if (v == null) return 0;
  if (v is num) return v.toInt();
  if (v is String) return int.tryParse(v) ?? 0;
  return 0;
}

DateTime _parseTime(dynamic orderAt, dynamic createdAtStr) {
  // order_at: epoch detik
  final sec = _asInt(orderAt);
  if (sec > 0) return DateTime.fromMillisecondsSinceEpoch(sec * 1000);
  if (createdAtStr is String && createdAtStr.isNotEmpty) {
    try {
      return DateTime.parse(createdAtStr);
    } catch (_) {}
  }
  return DateTime.now();
}

PurchaseStatus _mapStatus(String? s) {
  switch ((s ?? '').toLowerCase()) {
    case 'completed':
      return PurchaseStatus.completed;
    case 'canceled':
      return PurchaseStatus.canceled;
    case 'pending':
    default:
      return PurchaseStatus.inProgress;
  }
}
