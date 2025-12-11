// lib/providers/stock_provider.dart
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'package:wa_blast/core/provider_helper.dart';
import 'package:wa_blast/models/product_model.dart';
import 'package:wa_blast/services/api_service.dart';

/// =========================
/// MODELS
/// =========================

/// Store location versi ringan untuk initial stock.
@immutable
class StockStoreLocationLite {
  final String idStoreLocation;
  final String name;
  final String? cityName;
  final String? provinceName;

  const StockStoreLocationLite({
    required this.idStoreLocation,
    required this.name,
    this.cityName,
    this.provinceName,
  });

  factory StockStoreLocationLite.fromJson(Map<String, dynamic> j) {
    final cityJ = (j['city'] as Map?)?.cast<String, dynamic>();
    final provJ = (cityJ?['province'] as Map?)?.cast<String, dynamic>();

    return StockStoreLocationLite(
      idStoreLocation: j['idStoreLocation']?.toString() ?? '',
      name: j['name']?.toString() ?? '',
      cityName: cityJ?['name']?.toString(),
      provinceName: provJ?['name']?.toString(),
    );
  }
}

/// Attribute SKU di konteks initial stock.
@immutable
class StockSkuAttribute {
  final String name;
  final String value;

  const StockSkuAttribute({required this.name, required this.value});

  factory StockSkuAttribute.fromJson(Map<String, dynamic> j) =>
      StockSkuAttribute(
        name: j['name']?.toString() ?? '',
        value: j['value']?.toString() ?? '',
      );
}

/// Representasi SKU di initial stock.
@immutable
class StockProductSku {
  final String idProductSku;
  final String code;
  final int price;
  final int? qty; // qty dari API bisa 0 / nullable
  final List<StockSkuAttribute> attributes;

  const StockProductSku({
    required this.idProductSku,
    required this.code,
    required this.price,
    this.qty,
    this.attributes = const [],
  });

  factory StockProductSku.fromJson(Map<String, dynamic> j) {
    final attrs = (j['attributes'] as List<dynamic>? ?? const [])
        .whereType<Map>()
        .map(
          (e) => StockSkuAttribute.fromJson(
            Map<String, dynamic>.from(e.cast<String, dynamic>()),
          ),
        )
        .toList();

    final rawQty = j['qty'];
    final parsedQty = (rawQty is num)
        ? rawQty.toInt()
        : int.tryParse(rawQty?.toString() ?? '');

    return StockProductSku(
      idProductSku:
          j['idProductSku']?.toString() ??
          j['id_product_sku']?.toString() ??
          '',
      code: j['code']?.toString() ?? '',
      price: (j['price'] is num)
          ? (j['price'] as num).toInt()
          : int.tryParse('${j['price']}') ?? 0,
      qty: parsedQty,
      attributes: attrs,
    );
  }
}

/// SATU baris hasil GET /waveup/{businessId}/initial-stock
/// (berdasarkan contoh response yang kamu kirim).
@immutable
class InitialStockRow {
  final String id;
  final StockStoreLocationLite storeLocation;
  final Product product;
  final StockProductSku productSku;
  final int qty;
  final String type; // "initial_stock"
  final String note;
  final String referenceType; // "initial_stock"

  const InitialStockRow({
    required this.id,
    required this.storeLocation,
    required this.product,
    required this.productSku,
    required this.qty,
    required this.type,
    required this.note,
    required this.referenceType,
  });

  factory InitialStockRow.fromJson(Map<String, dynamic> j) => InitialStockRow(
    id: j['id']?.toString() ?? '',
    storeLocation: StockStoreLocationLite.fromJson(
      (j['storeLocation'] as Map?)?.cast<String, dynamic>() ?? const {},
    ),
    product: Product.fromJson(
      (j['product'] as Map?)?.cast<String, dynamic>() ?? const {},
    ),
    productSku: StockProductSku.fromJson(
      (j['productSku'] as Map?)?.cast<String, dynamic>() ?? const {},
    ),
    qty: (j['qty'] is num)
        ? (j['qty'] as num).toInt()
        : int.tryParse('${j['qty']}') ?? 0,
    type: j['type']?.toString() ?? '',
    note: j['note']?.toString() ?? '',
    referenceType: j['referenceType']?.toString() ?? '',
  );
}

/// Item di dalam dokumen initial stock (untuk detail & payload store/edit).
@immutable
class InitialStockItem {
  final String productId;
  final String productSkuId;
  final int qty;
  final int price;
  final int? discount; // per item (optional)

  // Optional: data lengkap kalau API detail mengembalikan product / sku
  final Product? product;
  final StockProductSku? productSku;

  const InitialStockItem({
    required this.productId,
    required this.productSkuId,
    required this.qty,
    required this.price,
    this.discount,
    this.product,
    this.productSku,
  });

  /// Parser fleksibel: coba baca beberapa kemungkinan nama key.
  factory InitialStockItem.fromJson(Map<String, dynamic> j) {
    final productJ = (j['product'] as Map?)?.cast<String, dynamic>();
    final skuJ = (j['productSku'] as Map?)?.cast<String, dynamic>();

    final productId =
        j['product_id']?.toString() ??
        j['productId']?.toString() ??
        productJ?['idProduct']?.toString() ??
        productJ?['id_product']?.toString() ??
        '';

    final productSkuId =
        j['product_sku_id']?.toString() ??
        j['productSkuId']?.toString() ??
        skuJ?['idProductSku']?.toString() ??
        skuJ?['id_product_sku']?.toString() ??
        '';

    final rawDiscount = j['discount'];
    final parsedDiscount = (rawDiscount is num)
        ? rawDiscount.toInt()
        : int.tryParse(rawDiscount?.toString() ?? '');

    return InitialStockItem(
      productId: productId,
      productSkuId: productSkuId,
      qty: (j['qty'] is num)
          ? (j['qty'] as num).toInt()
          : int.tryParse('${j['qty']}') ?? 0,
      price: (j['price'] is num)
          ? (j['price'] as num).toInt()
          : int.tryParse('${j['price']}') ?? 0,
      discount: parsedDiscount,
      product: productJ != null ? Product.fromJson(productJ) : null,
      productSku: skuJ != null ? StockProductSku.fromJson(skuJ) : null,
    );
  }

  /// JSON untuk payload store / edit:
  /// {
  ///   "product_id": "...",
  ///   "product_sku_id": "...",
  ///   "qty": 100,
  ///   "price": 5000,
  ///   "discount": 0
  /// }
  Map<String, dynamic> toJson() {
    final map = <String, dynamic>{
      'product_id': productId,
      'product_sku_id': productSkuId,
      'qty': qty,
      'price': price,
    };

    if (discount != null) {
      map['discount'] = discount;
    }

    return map;
  }
}

/// Dokumen detail initial stock (/initial-stock/:id).
/// Bentuk pastinya belum kamu kirim, jadi ini dibuat cukup fleksibel.
@immutable
class InitialStockDetail {
  final String id;
  final StockStoreLocationLite? storeLocation;
  final String note;
  final int? discount; // total / header discount (jika ada)
  final List<InitialStockItem> items;

  const InitialStockDetail({
    required this.id,
    required this.storeLocation,
    required this.note,
    required this.items,
    this.discount,
  });

  factory InitialStockDetail.fromJson(Map<String, dynamic> j) {
    final storeJ = (j['storeLocation'] as Map?)?.cast<String, dynamic>();

    final itemsJ = (j['items'] as List?) ?? const [];
    final items = itemsJ
        .whereType<Map>()
        .map(
          (e) => InitialStockItem.fromJson(
            Map<String, dynamic>.from(e.cast<String, dynamic>()),
          ),
        )
        .toList();

    final rawDiscount = j['discount'];
    final parsedDiscount = (rawDiscount is num)
        ? rawDiscount.toInt()
        : int.tryParse(rawDiscount?.toString() ?? '');

    return InitialStockDetail(
      id: j['id']?.toString() ?? '',
      storeLocation: storeJ != null
          ? StockStoreLocationLite.fromJson(storeJ)
          : null,
      note: j['note']?.toString() ?? '',
      items: items,
      discount: parsedDiscount,
    );
  }
}

/// =========================
/// PROVIDER
/// =========================

class StockProvider with ChangeNotifier {
  /// --- LIST initial stock (GET /waveup/{bizId}/initial-stock)
  final List<InitialStockRow> _initialStocks = [];
  bool _loadingInitialStocks = false;
  PageMeta? _pageInitialStocks;
  String? _initialStocksError;

  /// --- DETAIL initial stock (GET /waveup/{bizId}/initial-stock/:id)
  InitialStockDetail? _initialStockDetail;
  bool _loadingInitialStockDetail = false;
  String? _initialStockDetailError;

  /// --- Error umum (kalau mau dipakai global)
  String? _lastError;

  // ===== Getters =====

  List<InitialStockRow> get initialStocks => List.unmodifiable(_initialStocks);

  bool get loadingInitialStocks => _loadingInitialStocks;
  PageMeta? get pageInitialStocks => _pageInitialStocks;
  String? get initialStocksError => _initialStocksError;

  InitialStockDetail? get initialStockDetail => _initialStockDetail;
  bool get loadingInitialStockDetail => _loadingInitialStockDetail;
  String? get initialStockDetailError => _initialStockDetailError;

  String? get lastError => _lastError;

  bool get isInitialStockEmpty =>
      !_loadingInitialStocks && _initialStocks.isEmpty;

  /// =========================
  /// FETCH: Initial Stock List
  /// =========================
  ///
  /// GET /waveup/{businessId}/initial-stock
  ///
  /// Bentuk response (dari kamu):
  /// {
  ///   "status": 200,
  ///   "page": {...},
  ///   "data": [ { InitialStockRow }, ... ]
  /// }
  Future<void> fetchInitialStocks(
    BuildContext context, {
    int? page,
    int? rowPerPage,
  }) async {
    final bizId = await BizIdCache.get();
    if (bizId == null || bizId.isEmpty) {
      _initialStocks..clear();
      _pageInitialStocks = null;
      _initialStocksError = "Business ID is not available.";
      _lastError = _initialStocksError;
      notifyListeners();
      return;
    }

    _loadingInitialStocks = true;
    _initialStocksError = null;
    notifyListeners();

    try {
      // Kalau mau pakai query page/row_per_page:
      final buffer = StringBuffer('/waveup/$bizId/initial-stock');
      final query = <String, String>{};
      if (page != null && page > 0) {
        query['page'] = page.toString();
      }
      if (rowPerPage != null && rowPerPage > 0) {
        query['row_per_page'] = rowPerPage.toString();
      }
      if (query.isNotEmpty) {
        buffer.write(
          '?' + query.entries.map((e) => '${e.key}=${e.value}').join('&'),
        );
      }

      final path = buffer.toString();
      if (kDebugMode) {
        debugPrint('[StockProvider] GET $path');
      }

      final jsonMap = await ApiJson.getMap(context, path);

      if (jsonMap == null) {
        _initialStocks..clear();
        _pageInitialStocks = null;
        _initialStocksError = 'Failed to load initial stock.';
        _lastError = _initialStocksError;
        notifyListeners();
        return;
      }

      final status = (jsonMap['status'] as num?)?.toInt() ?? 0;
      if (status < 200 || status >= 300) {
        _initialStocks..clear();
        _pageInitialStocks = null;
        _initialStocksError =
            jsonMap['message']?.toString() ?? 'Failed to load initial stock.';
        _lastError = _initialStocksError;
        notifyListeners();
        return;
      }

      final pageJ = (jsonMap['page'] as Map?)?.cast<String, dynamic>();
      if (pageJ != null) {
        _pageInitialStocks = PageMeta.fromJson(pageJ);
      } else {
        _pageInitialStocks = null;
      }

      final dataList = (jsonMap['data'] as List?) ?? const [];
      final parsed = dataList
          .whereType<Map>()
          .map(
            (e) => InitialStockRow.fromJson(
              Map<String, dynamic>.from(e.cast<String, dynamic>()),
            ),
          )
          .toList();

      _initialStocks
        ..clear()
        ..addAll(parsed);

      _initialStocksError = null;
      _lastError = null;
      notifyListeners();
    } catch (e, st) {
      _initialStocks..clear();
      _pageInitialStocks = null;
      _initialStocksError = e.toString();
      _lastError = _initialStocksError;
      debugPrint('[StockProvider] fetchInitialStocks error: $e');
      debugPrint('$st');
      notifyListeners();
    } finally {
      _loadingInitialStocks = false;
      notifyListeners();
    }
  }

  Future<void> refreshInitialStocks(BuildContext context) async {
    await fetchInitialStocks(context);
  }

  /// =========================
  /// FETCH: Initial Stock Detail
  /// =========================
  ///
  /// GET /waveup/{bizId}/initial-stock/:id
  Future<InitialStockDetail?> fetchInitialStockDetail(
    BuildContext context,
    String idInitialStock,
  ) async {
    final bizId = await BizIdCache.get();
    if (bizId == null || bizId.isEmpty) {
      _initialStockDetail = null;
      _initialStockDetailError = "Business ID is not available.";
      _lastError = _initialStockDetailError;
      notifyListeners();
      return null;
    }

    _loadingInitialStockDetail = true;
    _initialStockDetailError = null;
    notifyListeners();

    try {
      final path = '/waveup/$bizId/initial-stock/$idInitialStock';
      if (kDebugMode) {
        debugPrint('[StockProvider] GET $path');
      }

      final jsonMap = await ApiJson.getMap(context, path);

      if (jsonMap == null) {
        _initialStockDetail = null;
        _initialStockDetailError = 'Empty response';
        _lastError = _initialStockDetailError;
        notifyListeners();
        return null;
      }

      final status = (jsonMap['status'] as num?)?.toInt() ?? 0;
      if (status < 200 || status >= 300) {
        _initialStockDetail = null;
        _initialStockDetailError =
            jsonMap['message']?.toString() ??
            'Failed to load initial stock detail.';
        _lastError = _initialStockDetailError;
        notifyListeners();
        return null;
      }

      final dataJ =
          (jsonMap['data'] as Map?)?.cast<String, dynamic>() ?? const {};
      if (kDebugMode) {
        debugPrint('[StockProvider] detail data: ${jsonEncode(dataJ)}');
      }

      final detail = InitialStockDetail.fromJson(dataJ);
      _initialStockDetail = detail;
      _initialStockDetailError = null;
      _lastError = null;
      notifyListeners();
      return detail;
    } catch (e, st) {
      _initialStockDetail = null;
      _initialStockDetailError = e.toString();
      _lastError = _initialStockDetailError;
      debugPrint('[StockProvider] fetchInitialStockDetail error: $e');
      debugPrint('$st');
      notifyListeners();
      return null;
    } finally {
      _loadingInitialStockDetail = false;
      notifyListeners();
    }
  }

  /// =========================
  /// STORE: Initial Stock
  /// =========================
  ///
  /// POST /waveup/:idBusiness/initial-stock
  ///
  /// Payload:
  /// {
  ///   "store_location_id": "...",
  ///   "note": "...",
  ///   "discount": 3500,
  ///   "items": [ InitialStockItem.toJson(), ... ]
  /// }
  Future<bool> createInitialStock({
    required BuildContext context,
    required String storeLocationId,
    required String note,
    int? discount, // header discount optional
    required List<InitialStockItem> items,
  }) async {
    final bizId = await BizIdCache.get();
    if (bizId == null || bizId.isEmpty) {
      _lastError = "Business ID is not available.";
      return false;
    }

    final payload = <String, dynamic>{
      'store_location_id': storeLocationId,
      'note': note,
      'items': items.map((e) => e.toJson()).toList(),
    };

    if (discount != null) {
      payload['discount'] = discount;
    }

    try {
      if (kDebugMode) {
        debugPrint(
          '[StockProvider] CREATE initial stock payload: '
          '${jsonEncode(payload)}',
        );
      }

      final res = await ApiService.post(
        context,
        '/waveup/$bizId/initial-stock',
        payload,
        withAccessToken: true,
      );

      if (res != null) {
        debugPrint('[StockProvider] CREATE status: ${res.statusCode}');
        debugPrint('[StockProvider] CREATE body  : ${res.body}');
      }

      final ok = res != null && res.statusCode >= 200 && res.statusCode < 300;

      if (!ok) {
        _lastError =
            'Failed to create initial stock: ${res?.statusCode} ${res?.body}';
        return false;
      }

      _lastError = null;
      // Setelah berhasil, refresh list initial stock
      await fetchInitialStocks(context);
      return true;
    } catch (e, st) {
      _lastError = e.toString();
      debugPrint('[StockProvider] createInitialStock error: $e');
      debugPrint('$st');
      return false;
    }
  }

  /// =========================
  /// EDIT: Initial Stock
  /// =========================
  ///
  /// POST /waveup/:idBusiness/initial-stock/:id
  ///
  /// Payload:
  /// {
  ///   "store_location_id": "...",
  ///   "note": "...",
  ///   "items": [
  ///     { "product_id": "...", "product_sku_id": "...", "qty": 50, "price": 100000 },
  ///     ...
  ///   ]
  /// }
  ///
  /// (kalau mau pakai per-item discount juga tinggal isi di InitialStockItem)
  Future<bool> updateInitialStock({
    required BuildContext context,
    required String idInitialStock,
    required String storeLocationId,
    required String note,
    required List<InitialStockItem> items,
    int? discount,
  }) async {
    final bizId = await BizIdCache.get();
    if (bizId == null || bizId.isEmpty) {
      _lastError = "Business ID is not available.";
      return false;
    }

    final payload = <String, dynamic>{
      'store_location_id': storeLocationId,
      'note': note,
      'items': items.map((e) => e.toJson()).toList(),
    };

    if (discount != null) {
      payload['discount'] = discount;
    }

    try {
      if (kDebugMode) {
        debugPrint(
          '[StockProvider] UPDATE initial stock payload: '
          '${jsonEncode(payload)}',
        );
      }

      final res = await ApiService.post(
        context,
        '/waveup/$bizId/initial-stock/$idInitialStock',
        payload,
        withAccessToken: true,
      );

      if (res != null) {
        debugPrint('[StockProvider] UPDATE status: ${res.statusCode}');
        debugPrint('[StockProvider] UPDATE body  : ${res.body}');
      }

      final ok = res != null && res.statusCode >= 200 && res.statusCode < 300;

      if (!ok) {
        _lastError =
            'Failed to update initial stock: ${res?.statusCode} ${res?.body}';
        return false;
      }

      _lastError = null;

      // Refresh list + detail yang lagi dibuka (kalau id sama)
      await fetchInitialStocks(context);
      if (_initialStockDetail?.id == idInitialStock) {
        await fetchInitialStockDetail(context, idInitialStock);
      }

      return true;
    } catch (e, st) {
      _lastError = e.toString();
      debugPrint('[StockProvider] updateInitialStock error: $e');
      debugPrint('$st');
      return false;
    }
  }

  /// Clear detail dari memori (misal saat keluar dari halaman).
  void clearInitialStockDetail() {
    _initialStockDetail = null;
    _initialStockDetailError = null;
    notifyListeners();
  }
}
