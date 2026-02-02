// lib/providers/stock_provider.dart
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'package:wa_blast/core/provider_helper.dart';
import 'package:wa_blast/models/product_model.dart';
import 'package:wa_blast/services/api_service.dart';

/// ============================================================
/// HELPERS
/// ============================================================

int _toInt(dynamic v, {int fallback = 0}) {
  if (v is num) return v.toInt();
  return int.tryParse(v?.toString() ?? '') ?? fallback;
}

Map<String, dynamic> _asMap(dynamic v) {
  if (v is Map) return v.cast<String, dynamic>();
  return const <String, dynamic>{};
}

List<Map<String, dynamic>> _asMapList(dynamic v) {
  if (v is! List) return const <Map<String, dynamic>>[];
  return v
      .whereType<Map>()
      .map((e) => Map<String, dynamic>.from(e.cast<String, dynamic>()))
      .toList();
}

/// ============================================================
/// MODELS - STORE LOCATION (LITE)
/// ============================================================

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
    final cityJ = _asMap(j['city']);
    final provJ = _asMap(cityJ['province']);

    return StockStoreLocationLite(
      idStoreLocation: j['idStoreLocation']?.toString() ?? '',
      name: j['name']?.toString() ?? '',
      cityName: cityJ['name']?.toString(),
      provinceName: provJ['name']?.toString(),
    );
  }
}

/// ============================================================
/// MODELS - STOCK OPNAME
/// ============================================================

@immutable
class StockOpnameItem {
  final String idStockOpnameItem;
  final Product product;
  final StockProductSku productSku;

  final int countedQty;
  final int systemQty;
  final int variance;
  final String reason;

  const StockOpnameItem({
    required this.idStockOpnameItem,
    required this.product,
    required this.productSku,
    required this.countedQty,
    required this.systemQty,
    required this.variance,
    required this.reason,
  });

  factory StockOpnameItem.fromJson(Map<String, dynamic> j) {
    return StockOpnameItem(
      idStockOpnameItem: j['idStockOpnameItem']?.toString() ?? '',
      product: Product.fromJson(_asMap(j['product'])),
      productSku: StockProductSku.fromJson(_asMap(j['productSku'])),
      countedQty: _toInt(j['countedQty']),
      systemQty: _toInt(j['systemQty']),
      variance: _toInt(j['variance']),
      reason: j['reason']?.toString() ?? '',
    );
  }
}

@immutable
class StockOpname {
  final String idStockOpname;

  final StockStoreLocationLite storeLocation;
  final Product product;
  final StockProductSku productSku;

  final int systemQty;
  final int countedQty;
  final int variance;

  /// contoh: "submitted", "UNADJUSTED"
  final String status;

  final String note;

  /// contoh: "NOT_ADJUSTED"
  final String adjustmentStatus;

  /// contoh: "12-01-2026 11:04"
  final String createdAt;
  final String updatedAt;

  const StockOpname({
    required this.idStockOpname,
    required this.storeLocation,
    required this.product,
    required this.productSku,
    required this.systemQty,
    required this.countedQty,
    required this.variance,
    required this.status,
    required this.note,
    required this.adjustmentStatus,
    required this.createdAt,
    required this.updatedAt,
  });

  factory StockOpname.fromJson(Map<String, dynamic> j) {
    return StockOpname(
      idStockOpname: j['idStockOpname']?.toString() ?? '',
      storeLocation: StockStoreLocationLite.fromJson(
        _asMap(j['storeLocation']),
      ),
      product: Product.fromJson(_asMap(j['product'])),
      productSku: StockProductSku.fromJson(_asMap(j['productSku'])),
      systemQty: _toInt(j['systemQty']),
      countedQty: _toInt(j['countedQty']),
      variance: _toInt(j['variance']),
      status: j['status']?.toString() ?? '',
      note: j['note']?.toString() ?? '',
      adjustmentStatus: j['adjustmentStatus']?.toString() ?? '',
      createdAt: j['createdAt']?.toString() ?? '',
      updatedAt: j['updatedAt']?.toString() ?? '',
    );
  }
}

/// Payload untuk create stock opname
/// POST /waveup/:bizId/store-location/:storeLocationId/stock-opname
@immutable
class CreateStockOpnamePayload {
  final String productId;
  final String productSkuId;
  final int qty;

  const CreateStockOpnamePayload({
    required this.productId,
    required this.productSkuId,
    required this.qty,
  });

  Map<String, dynamic> toJson() => <String, dynamic>{
    'product_id': productId,
    'product_sku_id': productSkuId,
    'qty': qty,
  };
}

@immutable
class StockOpnameBulkAdjustmentResult {
  final String stockOpnameId;
  final String productName;
  final String skuCode;
  final int variance;

  /// "success" / "skipped" / dll tergantung backend
  final String status;

  const StockOpnameBulkAdjustmentResult({
    required this.stockOpnameId,
    required this.productName,
    required this.skuCode,
    required this.variance,
    required this.status,
  });

  factory StockOpnameBulkAdjustmentResult.fromJson(Map<String, dynamic> j) {
    return StockOpnameBulkAdjustmentResult(
      stockOpnameId: j['stockOpnameId']?.toString() ?? '',
      productName: j['productName']?.toString() ?? '',
      skuCode: j['skuCode']?.toString() ?? '',
      variance: _toInt(j['variance']),
      status: j['status']?.toString() ?? '',
    );
  }
}

@immutable
class StockOpnameBulkAdjustmentResponse {
  final int status;
  final String message;
  final int successCount;
  final int skipCount;
  final List<StockOpnameBulkAdjustmentResult> results;

  const StockOpnameBulkAdjustmentResponse({
    required this.status,
    required this.message,
    required this.successCount,
    required this.skipCount,
    required this.results,
  });

  factory StockOpnameBulkAdjustmentResponse.fromJson(Map<String, dynamic> j) {
    final resultsJ = _asMapList(j['results']);
    final list = resultsJ
        .map(StockOpnameBulkAdjustmentResult.fromJson)
        .toList();

    return StockOpnameBulkAdjustmentResponse(
      status: _toInt(j['status']),
      message: j['message']?.toString() ?? '',
      successCount: _toInt(j['successCount']),
      skipCount: _toInt(j['skipCount']),
      results: list,
    );
  }
}

/// ============================================================
/// MODELS - INITIAL STOCK (SKU + LIST + DETAIL)
/// ============================================================

/// Attribute SKU di konteks initial stock.
@immutable
class StockSkuAttribute {
  final String name;
  final String value;

  const StockSkuAttribute({required this.name, required this.value});

  factory StockSkuAttribute.fromJson(Map<String, dynamic> j) {
    return StockSkuAttribute(
      name: j['name']?.toString() ?? '',
      value: j['value']?.toString() ?? '',
    );
  }
}

/// Representasi SKU di initial stock.
@immutable
class StockProductSku {
  final String idProductSku;
  final String code;
  final int price;

  /// qty dari API bisa 0 / nullable
  final int? qty;

  final List<StockSkuAttribute> attributes;

  const StockProductSku({
    required this.idProductSku,
    required this.code,
    required this.price,
    this.qty,
    this.attributes = const [],
  });

  factory StockProductSku.fromJson(Map<String, dynamic> j) {
    final attrsJ = (j['attributes'] as List<dynamic>? ?? const <dynamic>[])
        .whereType<Map>()
        .map((e) => StockSkuAttribute.fromJson(e.cast<String, dynamic>()))
        .toList();

    final rawQty = j['qty'];
    final parsedQty = (rawQty is num)
        ? rawQty.toInt()
        : int.tryParse(rawQty?.toString() ?? '');

    final rawPrice = j['price'];
    final parsedPrice = (rawPrice is num)
        ? rawPrice.toInt()
        : int.tryParse(rawPrice?.toString() ?? '') ?? 0;

    return StockProductSku(
      idProductSku:
          j['idProductSku']?.toString() ??
          j['id_product_sku']?.toString() ??
          '',
      code: j['code']?.toString() ?? '',
      price: parsedPrice,
      qty: parsedQty,
      attributes: attrsJ,
    );
  }
}

/// Satu baris hasil GET /waveup/{businessId}/initial-stock
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

  factory InitialStockRow.fromJson(Map<String, dynamic> j) {
    return InitialStockRow(
      id: j['id']?.toString() ?? '',
      storeLocation: StockStoreLocationLite.fromJson(
        _asMap(j['storeLocation']),
      ),
      product: Product.fromJson(_asMap(j['product'])),
      productSku: StockProductSku.fromJson(_asMap(j['productSku'])),
      qty: _toInt(j['qty']),
      type: j['type']?.toString() ?? '',
      note: j['note']?.toString() ?? '',
      referenceType: j['referenceType']?.toString() ?? '',
    );
  }
}

/// Item di dalam dokumen initial stock (untuk detail & payload store/edit).
@immutable
class InitialStockItem {
  final String productId;
  final String productSkuId;
  final int qty;
  final int price;

  /// per item (optional)
  final int? discount;

  /// Optional: data lengkap kalau API detail mengembalikan product / sku
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
    final productJ = _asMap(j['product']);
    final skuJ = _asMap(j['productSku']);

    final productId =
        j['product_id']?.toString() ??
        j['productId']?.toString() ??
        productJ['idProduct']?.toString() ??
        productJ['id_product']?.toString() ??
        '';

    final productSkuId =
        j['product_sku_id']?.toString() ??
        j['productSkuId']?.toString() ??
        skuJ['idProductSku']?.toString() ??
        skuJ['id_product_sku']?.toString() ??
        '';

    final parsedDiscount = (j['discount'] == null)
        ? null
        : _toInt(j['discount']);

    final hasProduct = productJ.isNotEmpty;
    final hasSku = skuJ.isNotEmpty;

    return InitialStockItem(
      productId: productId,
      productSkuId: productSkuId,
      qty: _toInt(j['qty']),
      price: _toInt(j['price']),
      discount: parsedDiscount,
      product: hasProduct ? Product.fromJson(productJ) : null,
      productSku: hasSku ? StockProductSku.fromJson(skuJ) : null,
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

    if (discount != null) map['discount'] = discount;
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

  /// total / header discount (jika ada)
  final int? discount;

  final List<InitialStockItem> items;

  const InitialStockDetail({
    required this.id,
    required this.storeLocation,
    required this.note,
    required this.items,
    this.discount,
  });

  factory InitialStockDetail.fromJson(Map<String, dynamic> j) {
    final storeJ = _asMap(j['storeLocation']);

    final itemsJ = _asMapList(j['items']);
    final items = itemsJ.map(InitialStockItem.fromJson).toList();

    final parsedDiscount = (j['discount'] == null)
        ? null
        : _toInt(j['discount']);

    return InitialStockDetail(
      id: j['id']?.toString() ?? '',
      storeLocation: storeJ.isNotEmpty
          ? StockStoreLocationLite.fromJson(storeJ)
          : null,
      note: j['note']?.toString() ?? '',
      items: items,
      discount: parsedDiscount,
    );
  }
}

/// ============================================================
/// MODELS - TRANSACTION STOCK ADJUSTMENT
/// ============================================================

@immutable
class StockAdjustmentTransaction {
  final String idTransaction;
  final String storeLocationId;
  final StockStoreLocationLite storeLocation;

  final int type;
  final String number;
  final int storeId;

  final String note;
  final String reference;
  final String status;

  final int amount;
  final int discount;
  final int shippingFee;

  /// unix timestamp (seconds)
  final int orderAt;

  final int paymentMethod;

  /// ISO string
  final String createdAt;

  /// ISO string
  final String updatedAt;

  const StockAdjustmentTransaction({
    required this.idTransaction,
    required this.storeLocationId,
    required this.storeLocation,
    required this.type,
    required this.number,
    required this.storeId,
    required this.note,
    required this.reference,
    required this.status,
    required this.amount,
    required this.discount,
    required this.shippingFee,
    required this.orderAt,
    required this.paymentMethod,
    required this.createdAt,
    required this.updatedAt,
  });

  factory StockAdjustmentTransaction.fromJson(Map<String, dynamic> j) {
    return StockAdjustmentTransaction(
      idTransaction: j['idTransaction']?.toString() ?? '',
      storeLocationId: j['store_location_id']?.toString() ?? '',
      storeLocation: StockStoreLocationLite.fromJson(
        _asMap(j['store_location']),
      ),
      type: _toInt(j['type']),
      number: j['number']?.toString() ?? '',
      storeId: _toInt(j['store_id']),
      note: j['note']?.toString() ?? '',
      reference: j['reference']?.toString() ?? '',
      status: j['status']?.toString() ?? '',
      amount: _toInt(j['amount']),
      discount: _toInt(j['discount']),
      shippingFee: _toInt(j['shipping_fee']),
      orderAt: _toInt(j['order_at']),
      paymentMethod: _toInt(j['payment_method']),
      createdAt: j['created_at']?.toString() ?? '',
      updatedAt: j['updated_at']?.toString() ?? '',
    );
  }
}

/// ============================================================
/// PROVIDER
/// ============================================================

class StockProvider with ChangeNotifier {
  // ============================================================
  // INITIAL STOCK: LIST
  // ============================================================

  final List<InitialStockRow> _initialStocks = [];
  bool _loadingInitialStocks = false;
  PageMeta? _pageInitialStocks;
  String? _initialStocksError;

  List<InitialStockRow> get initialStocks => List.unmodifiable(_initialStocks);
  bool get loadingInitialStocks => _loadingInitialStocks;
  PageMeta? get pageInitialStocks => _pageInitialStocks;
  String? get initialStocksError => _initialStocksError;

  bool get isInitialStockEmpty =>
      !_loadingInitialStocks && _initialStocks.isEmpty;

  // ============================================================
  // INITIAL STOCK: DETAIL
  // ============================================================

  InitialStockDetail? _initialStockDetail;
  bool _loadingInitialStockDetail = false;
  String? _initialStockDetailError;

  InitialStockDetail? get initialStockDetail => _initialStockDetail;
  bool get loadingInitialStockDetail => _loadingInitialStockDetail;
  String? get initialStockDetailError => _initialStockDetailError;

  // ============================================================
  // ERROR (GLOBAL)
  // ============================================================

  String? _lastError;
  String? get lastError => _lastError;

  // ============================================================
  // FETCH: Initial Stock List
  // GET /waveup/{businessId}/initial-stock
  // ============================================================

  Future<void> fetchInitialStocks(
    BuildContext context, {
    int? page,
    int? rowPerPage,
  }) async {
    final bizId = await BizIdCache.get();
    if (bizId == null || bizId.isEmpty) {
      _initialStocks.clear();
      _pageInitialStocks = null;
      _initialStocksError = 'Business ID is not available.';
      _lastError = _initialStocksError;
      notifyListeners();
      return;
    }

    _loadingInitialStocks = true;
    _initialStocksError = null;
    notifyListeners();

    try {
      final buffer = StringBuffer('/waveup/$bizId/initial-stock');
      final query = <String, String>{};

      if (page != null && page > 0) query['page'] = page.toString();
      if (rowPerPage != null && rowPerPage > 0) {
        query['row_per_page'] = rowPerPage.toString();
      }

      if (query.isNotEmpty) {
        buffer.write(
          '?${query.entries.map((e) => '${e.key}=${e.value}').join('&')}',
        );
      }

      final path = buffer.toString();
      if (kDebugMode) debugPrint('[StockProvider] GET $path');

      final jsonMap = await ApiJson.getMap(context, path);

      if (jsonMap == null) {
        _initialStocks.clear();
        _pageInitialStocks = null;
        _initialStocksError = 'Failed to load initial stock.';
        _lastError = _initialStocksError;
        notifyListeners();
        return;
      }

      final status = (jsonMap['status'] as num?)?.toInt() ?? 0;
      if (status < 200 || status >= 300) {
        _initialStocks.clear();
        _pageInitialStocks = null;
        _initialStocksError =
            jsonMap['message']?.toString() ?? 'Failed to load initial stock.';
        _lastError = _initialStocksError;
        notifyListeners();
        return;
      }

      final pageJ = _asMap(jsonMap['page']);
      _pageInitialStocks = pageJ.isNotEmpty ? PageMeta.fromJson(pageJ) : null;

      final dataList = (jsonMap['data'] as List?) ?? const <dynamic>[];
      final parsed = dataList
          .whereType<Map>()
          .map((e) => InitialStockRow.fromJson(e.cast<String, dynamic>()))
          .toList();

      _initialStocks
        ..clear()
        ..addAll(parsed);

      _initialStocksError = null;
      _lastError = null;
      notifyListeners();
    } catch (e, st) {
      _initialStocks.clear();
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

  // ============================================================
  // FETCH: Initial Stock Detail
  // GET /waveup/{bizId}/initial-stock/:id
  // ============================================================

  Future<InitialStockDetail?> fetchInitialStockDetail(
    BuildContext context,
    String idInitialStock,
  ) async {
    final bizId = await BizIdCache.get();
    if (bizId == null || bizId.isEmpty) {
      _initialStockDetail = null;
      _initialStockDetailError = 'Business ID is not available.';
      _lastError = _initialStockDetailError;
      notifyListeners();
      return null;
    }

    _loadingInitialStockDetail = true;
    _initialStockDetailError = null;
    notifyListeners();

    try {
      final path = '/waveup/$bizId/initial-stock/$idInitialStock';
      if (kDebugMode) debugPrint('[StockProvider] GET $path');

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

      final dataJ = _asMap(jsonMap['data']);
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

  // ============================================================
  // STORE: Initial Stock
  // POST /waveup/:idBusiness/initial-stock
  // ============================================================

  Future<bool> createInitialStock({
    required BuildContext context,
    required String storeLocationId,
    required String note,
    int? discount, // header discount optional
    required List<InitialStockItem> items,
  }) async {
    final bizId = await BizIdCache.get();
    if (bizId == null || bizId.isEmpty) {
      _lastError = 'Business ID is not available.';
      return false;
    }

    final payload = <String, dynamic>{
      'store_location_id': storeLocationId,
      'note': note,
      'items': items.map((e) => e.toJson()).toList(),
    };

    if (discount != null) payload['discount'] = discount;

    try {
      if (kDebugMode) {
        debugPrint(
          '[StockProvider] CREATE initial stock payload: ${jsonEncode(payload)}',
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
      await fetchInitialStocks(context);
      return true;
    } catch (e, st) {
      _lastError = e.toString();
      debugPrint('[StockProvider] createInitialStock error: $e');
      debugPrint('$st');
      return false;
    }
  }

  // ============================================================
  // EDIT: Initial Stock
  // POST /waveup/:idBusiness/initial-stock/:id
  // ============================================================

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
      _lastError = 'Business ID is not available.';
      return false;
    }

    final payload = <String, dynamic>{
      'store_location_id': storeLocationId,
      'note': note,
      'items': items.map((e) => e.toJson()).toList(),
    };

    if (discount != null) payload['discount'] = discount;

    try {
      if (kDebugMode) {
        debugPrint(
          '[StockProvider] UPDATE initial stock payload: ${jsonEncode(payload)}',
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
  /// Clear detail dari memori (misal saat keluar dari halaman).
  /// Aman dipanggil dari dispose / pop route karena notify di-delay.
  void clearInitialStockDetail({bool notify = true}) {
    _initialStockDetail = null;
    _initialStockDetailError = null;

    if (!notify) return;

    // Hindari "widget tree locked" ketika dipanggil saat dispose/pop
    WidgetsBinding.instance.addPostFrameCallback((_) {
      // kalau provider sudah di-dispose, ini akan aman karena kita guard
      // (ChangeNotifier punya property "hasListeners" untuk cek ada listener)
      if (!hasListeners) return;
      notifyListeners();
    });
  }

  // ============================================================
  // STOCK OPNAME: LIST + CREATE
  // ============================================================

  final List<StockOpname> _stockOpnames = [];
  bool _loadingStockOpnames = false;
  PageMeta? _pageStockOpnames;
  String? _stockOpnamesError;

  bool _creatingStockOpname = false;
  String? _createStockOpnameError;

  List<StockOpname> get stockOpnames => List.unmodifiable(_stockOpnames);
  bool get loadingStockOpnames => _loadingStockOpnames;
  PageMeta? get pageStockOpnames => _pageStockOpnames;
  String? get stockOpnamesError => _stockOpnamesError;

  bool get creatingStockOpname => _creatingStockOpname;
  String? get createStockOpnameError => _createStockOpnameError;

  bool get isStockOpnameEmpty => !_loadingStockOpnames && _stockOpnames.isEmpty;

  /// GET /waveup/{idBusiness}/store-location/{idStoreLocation}/stock-opname
  /// Example:
  /// ?page=1&limit=10&adjustmentStatus=ADJUSTED&variance=zero
  Future<int> fetchStockOpnames(
    BuildContext context, {
    required String idStoreLocation,
    int? page,
    int? rowPerPage, // legacy (mapped to limit)
    int? limit, // preferred
    String? adjustmentStatus, // NOT_ADJUSTED / ADJUSTED
    String? variance, // minus / plus / zero
    bool append = false, // true kalau infinite scroll page>1
  }) async {
    final bizId = await BizIdCache.get();
    if (bizId == null || bizId.isEmpty) {
      if (!append) _stockOpnames.clear();
      _pageStockOpnames = null;
      _stockOpnamesError = 'Business ID is not available.';
      _lastError = _stockOpnamesError;
      notifyListeners();
      return 0;
    }

    _loadingStockOpnames = true;
    _stockOpnamesError = null;
    notifyListeners();

    try {
      final buffer = StringBuffer(
        '/waveup/$bizId/store-location/$idStoreLocation/stock-opname',
      );

      final query = <String, String>{};

      final p = page ?? 1;
      if (p > 0) query['page'] = p.toString();

      final resolvedLimit = (limit != null && limit > 0)
          ? limit
          : ((rowPerPage != null && rowPerPage > 0) ? rowPerPage : null);
      if (resolvedLimit != null) query['limit'] = resolvedLimit.toString();

      final adj = (adjustmentStatus ?? '').trim();
      if (adj.isNotEmpty) query['adjustmentStatus'] = adj;

      final varc = (variance ?? '').trim();
      if (varc.isNotEmpty) query['variance'] = varc;

      if (query.isNotEmpty) {
        buffer.write(
          '?${query.entries.map((e) => '${e.key}=${e.value}').join('&')}',
        );
      }

      final path = buffer.toString();
      if (kDebugMode) debugPrint('[StockProvider] GET $path');

      final jsonMap = await ApiJson.getMap(context, path);

      if (jsonMap == null) {
        if (!append) _stockOpnames.clear();
        _pageStockOpnames = null;
        _stockOpnamesError = 'Failed to load stock opname.';
        _lastError = _stockOpnamesError;
        notifyListeners();
        return 0;
      }

      final status = (jsonMap['status'] as num?)?.toInt() ?? 0;
      if (status < 200 || status >= 300) {
        if (!append) _stockOpnames.clear();
        _pageStockOpnames = null;
        _stockOpnamesError =
            jsonMap['message']?.toString() ?? 'Failed to load stock opname.';
        _lastError = _stockOpnamesError;
        notifyListeners();
        return 0;
      }

      final pageJ = _asMap(jsonMap['page']);
      _pageStockOpnames = pageJ.isNotEmpty ? PageMeta.fromJson(pageJ) : null;

      final dataList = (jsonMap['data'] as List?) ?? const <dynamic>[];
      final parsed = dataList
          .whereType<Map>()
          .map((e) => StockOpname.fromJson(e.cast<String, dynamic>()))
          .toList();

      if (!append) {
        _stockOpnames
          ..clear()
          ..addAll(parsed);
      } else {
        _stockOpnames.addAll(parsed);
      }

      _stockOpnamesError = null;
      _lastError = null;
      notifyListeners();

      return parsed.length;
    } catch (e, st) {
      if (!append) _stockOpnames.clear();
      _pageStockOpnames = null;
      _stockOpnamesError = e.toString();
      _lastError = _stockOpnamesError;
      debugPrint('[StockProvider] fetchStockOpnames error: $e');
      debugPrint('$st');
      notifyListeners();
      return 0;
    } finally {
      _loadingStockOpnames = false;
      notifyListeners();
    }
  }

  Future<void> refreshStockOpnames(
    BuildContext context, {
    required String idStoreLocation,
  }) async {
    await fetchStockOpnames(context, idStoreLocation: idStoreLocation);
  }

  /// POST /waveup/{idBusiness}/store-location/{idStoreLocation}/stock-opname
  /// Payload: { "product_id": "...", "product_sku_id": "...", "qty": 20 }
  Future<StockOpname?> createStockOpname({
    required BuildContext context,
    required String idStoreLocation,
    required String productId,
    required String productSkuId,
    required int qty,
    bool refreshListAfter = true,
  }) async {
    final bizId = await BizIdCache.get();
    if (bizId == null || bizId.isEmpty) {
      _lastError = 'Business ID is not available.';
      _createStockOpnameError = _lastError;
      notifyListeners();
      return null;
    }

    _creatingStockOpname = true;
    _createStockOpnameError = null;
    notifyListeners();

    final payload = CreateStockOpnamePayload(
      productId: productId,
      productSkuId: productSkuId,
      qty: qty,
    ).toJson();

    try {
      if (kDebugMode) {
        debugPrint(
          '[StockProvider] CREATE stock opname payload: ${jsonEncode(payload)}',
        );
      }

      final path =
          '/waveup/$bizId/store-location/$idStoreLocation/stock-opname';

      final res = await ApiService.post(
        context,
        path,
        payload,
        withAccessToken: true,
      );

      if (kDebugMode && res != null) {
        debugPrint('[StockProvider] CREATE status: ${res.statusCode}');
        debugPrint('[StockProvider] CREATE body  : ${res.body}');
      }

      final ok = res != null && res.statusCode >= 200 && res.statusCode < 300;
      if (!ok) {
        _createStockOpnameError =
            'Failed to create stock opname: ${res?.statusCode} ${res?.body}';
        _lastError = _createStockOpnameError;
        notifyListeners();
        return null;
      }

      final decoded = jsonDecode(res!.body);
      final map = (decoded is Map) ? decoded.cast<String, dynamic>() : null;

      if (map == null) {
        _createStockOpnameError = 'Invalid response body';
        _lastError = _createStockOpnameError;
        notifyListeners();
        return null;
      }

      final status = (map['status'] as num?)?.toInt() ?? 0;
      if (status < 200 || status >= 300) {
        _createStockOpnameError =
            map['message']?.toString() ?? 'Failed to create stock opname.';
        _lastError = _createStockOpnameError;
        notifyListeners();
        return null;
      }

      final dataJ = _asMap(map['data']);
      final created = StockOpname.fromJson(dataJ);

      _createStockOpnameError = null;
      _lastError = null;
      notifyListeners();

      if (refreshListAfter) {
        await fetchStockOpnames(
          context,
          idStoreLocation: idStoreLocation,
          append: false,
        );
      }

      return created;
    } catch (e, st) {
      _createStockOpnameError = e.toString();
      _lastError = _createStockOpnameError;
      debugPrint('[StockProvider] createStockOpname error: $e');
      debugPrint('$st');
      notifyListeners();
      return null;
    } finally {
      _creatingStockOpname = false;
      notifyListeners();
    }
  }

  Future<bool> createStockOpnameOk({
    required BuildContext context,
    required String idStoreLocation,
    required String productId,
    required String productSkuId,
    required int qty,
    bool refreshListAfter = true,
  }) async {
    final created = await createStockOpname(
      context: context,
      idStoreLocation: idStoreLocation,
      productId: productId,
      productSkuId: productSkuId,
      qty: qty,
      refreshListAfter: refreshListAfter,
    );
    return created != null;
  }

  void clearStockOpnameList() {
    _stockOpnames.clear();
    _pageStockOpnames = null;
    _stockOpnamesError = null;
    notifyListeners();
  }

  // ============================================================
  // STOCK OPNAME: BULK ADJUSTMENT
  // ============================================================

  bool _adjustingStockOpnames = false;
  String? _stockOpnameAdjustmentError;
  StockOpnameBulkAdjustmentResponse? _lastStockOpnameAdjustment;

  bool get adjustingStockOpnames => _adjustingStockOpnames;
  String? get stockOpnameAdjustmentError => _stockOpnameAdjustmentError;
  StockOpnameBulkAdjustmentResponse? get lastStockOpnameAdjustment =>
      _lastStockOpnameAdjustment;

  /// POST /waveup/{idBusiness}/store-location/{idStoreLocation}/stock-opname/bulk-adjustment
  /// Payload:
  /// { "stock_opname_ids": ["..."], "note": "Adjustment januari" }
  Future<StockOpnameBulkAdjustmentResponse?> stockOpnameBulkAdjustment({
    required BuildContext context,
    required String idStoreLocation,
    required List<String> stockOpnameIds,
    required String note,
    bool refreshListAfter = true,
  }) async {
    final bizId = await BizIdCache.get();
    if (bizId == null || bizId.isEmpty) {
      _stockOpnameAdjustmentError = 'Business ID is not available.';
      _lastError = _stockOpnameAdjustmentError;
      notifyListeners();
      return null;
    }

    final storeId = idStoreLocation.trim();
    if (storeId.isEmpty) {
      _stockOpnameAdjustmentError = 'Store location ID is not available.';
      _lastError = _stockOpnameAdjustmentError;
      notifyListeners();
      return null;
    }

    final ids = stockOpnameIds
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toList();

    if (ids.isEmpty) {
      _stockOpnameAdjustmentError = 'Stock opname IDs cannot be empty.';
      _lastError = _stockOpnameAdjustmentError;
      notifyListeners();
      return null;
    }

    _adjustingStockOpnames = true;
    _stockOpnameAdjustmentError = null;
    _lastStockOpnameAdjustment = null;
    notifyListeners();

    final payload = <String, dynamic>{
      'stock_opname_ids': ids,
      'note': note.trim(),
    };

    try {
      final path =
          '/waveup/$bizId/store-location/$storeId/stock-opname/bulk-adjustment';

      if (kDebugMode) {
        debugPrint('[StockProvider] POST $path');
        debugPrint('[StockProvider] payload: ${jsonEncode(payload)}');
      }

      final res = await ApiService.post(
        context,
        path,
        payload,
        withAccessToken: true,
      );

      if (kDebugMode && res != null) {
        debugPrint('[StockProvider] ADJUST status: ${res.statusCode}');
        debugPrint('[StockProvider] ADJUST body  : ${res.body}');
      }

      final ok = res != null && res.statusCode >= 200 && res.statusCode < 300;
      if (!ok) {
        _stockOpnameAdjustmentError =
            'Failed to adjust stock opname: ${res?.statusCode} ${res?.body}';
        _lastError = _stockOpnameAdjustmentError;
        notifyListeners();
        return null;
      }

      final decoded = jsonDecode(res!.body);
      final map = (decoded is Map) ? decoded.cast<String, dynamic>() : null;

      if (map == null) {
        _stockOpnameAdjustmentError = 'Invalid response body';
        _lastError = _stockOpnameAdjustmentError;
        notifyListeners();
        return null;
      }

      final status = (map['status'] as num?)?.toInt() ?? 0;
      if (status < 200 || status >= 300) {
        _stockOpnameAdjustmentError =
            map['message']?.toString() ?? 'Failed to adjust stock opname.';
        _lastError = _stockOpnameAdjustmentError;
        notifyListeners();
        return null;
      }

      final parsed = StockOpnameBulkAdjustmentResponse.fromJson(map);

      _stockOpnameAdjustmentError = null;
      _lastError = null;
      _lastStockOpnameAdjustment = parsed;
      notifyListeners();

      if (refreshListAfter) {
        await fetchStockOpnames(
          context,
          idStoreLocation: storeId,
          page: 1,
          rowPerPage: 50,
          append: false,
        );
      }

      return parsed;
    } catch (e, st) {
      _stockOpnameAdjustmentError = e.toString();
      _lastError = _stockOpnameAdjustmentError;
      debugPrint('[StockProvider] stockOpnameBulkAdjustment error: $e');
      debugPrint('$st');
      notifyListeners();
      return null;
    } finally {
      _adjustingStockOpnames = false;
      notifyListeners();
    }
  }

  /// Optional helper: reset result/error
  void clearStockOpnameAdjustmentState() {
    _stockOpnameAdjustmentError = null;
    _lastStockOpnameAdjustment = null;
    notifyListeners();
  }

  // ============================================================
  // TRANSACTION STOCK ADJUSTMENT: LIST
  // ============================================================

  final List<StockAdjustmentTransaction> _stockAdjustments = [];
  bool _loadingStockAdjustments = false;
  PageMeta? _pageStockAdjustments;
  String? _stockAdjustmentsError;

  List<StockAdjustmentTransaction> get stockAdjustments =>
      List.unmodifiable(_stockAdjustments);

  bool get loadingStockAdjustments => _loadingStockAdjustments;
  PageMeta? get pageStockAdjustments => _pageStockAdjustments;
  String? get stockAdjustmentsError => _stockAdjustmentsError;

  bool get isStockAdjustmentsEmpty =>
      !_loadingStockAdjustments && _stockAdjustments.isEmpty;

  /// GET /waveup/{idBusiness}/store-location/{idStoreLocation}/transaction-adjustment
  Future<void> fetchStockAdjustments(
    BuildContext context, {
    required String idStoreLocation,
    int? page,
    int? rowPerPage,
    bool append = false,
  }) async {
    final bizId = await BizIdCache.get();
    if (bizId == null || bizId.isEmpty) {
      if (!append) _stockAdjustments.clear();
      _pageStockAdjustments = null;
      _stockAdjustmentsError = 'Business ID is not available.';
      _lastError = _stockAdjustmentsError;
      notifyListeners();
      return;
    }

    _loadingStockAdjustments = true;
    _stockAdjustmentsError = null;
    notifyListeners();

    try {
      final buffer = StringBuffer(
        '/waveup/$bizId/store-location/$idStoreLocation/transaction-adjustment',
      );

      final query = <String, String>{};
      if (page != null && page > 0) query['page'] = page.toString();
      if (rowPerPage != null && rowPerPage > 0) {
        query['row_per_page'] = rowPerPage.toString();
      }

      if (query.isNotEmpty) {
        buffer.write(
          '?${query.entries.map((e) => '${e.key}=${e.value}').join('&')}',
        );
      }

      final path = buffer.toString();
      if (kDebugMode) debugPrint('[StockProvider] GET $path');

      final jsonMap = await ApiJson.getMap(context, path);

      if (jsonMap == null) {
        if (!append) _stockAdjustments.clear();
        _pageStockAdjustments = null;
        _stockAdjustmentsError = 'Failed to load stock adjustment.';
        _lastError = _stockAdjustmentsError;
        notifyListeners();
        return;
      }

      final status = (jsonMap['status'] as num?)?.toInt() ?? 0;
      if (status < 200 || status >= 300) {
        if (!append) _stockAdjustments.clear();
        _pageStockAdjustments = null;
        _stockAdjustmentsError =
            jsonMap['message']?.toString() ??
            'Failed to load stock adjustment.';
        _lastError = _stockAdjustmentsError;
        notifyListeners();
        return;
      }

      final pageJ = _asMap(jsonMap['page']);
      _pageStockAdjustments = pageJ.isNotEmpty
          ? PageMeta.fromJson(pageJ)
          : null;

      final dataList = (jsonMap['data'] as List?) ?? const <dynamic>[];
      final parsed = dataList
          .whereType<Map>()
          .map(
            (e) =>
                StockAdjustmentTransaction.fromJson(e.cast<String, dynamic>()),
          )
          .toList();

      if (!append) {
        _stockAdjustments
          ..clear()
          ..addAll(parsed);
      } else {
        _stockAdjustments.addAll(parsed);
      }

      _stockAdjustmentsError = null;
      _lastError = null;
      notifyListeners();
    } catch (e, st) {
      if (!append) _stockAdjustments.clear();
      _pageStockAdjustments = null;
      _stockAdjustmentsError = e.toString();
      _lastError = _stockAdjustmentsError;
      debugPrint('[StockProvider] fetchStockAdjustments error: $e');
      debugPrint('$st');
      notifyListeners();
    } finally {
      _loadingStockAdjustments = false;
      notifyListeners();
    }
  }

  Future<void> refreshStockAdjustments(
    BuildContext context, {
    required String idStoreLocation,
  }) async {
    await fetchStockAdjustments(context, idStoreLocation: idStoreLocation);
  }

  void clearStockAdjustments() {
    _stockAdjustments.clear();
    _pageStockAdjustments = null;
    _stockAdjustmentsError = null;
    notifyListeners();
  }
}
