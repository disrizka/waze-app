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

/// =========================
/// MODELS - STOCK OPNAME
/// =========================

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
    int _toInt(dynamic v, {int fallback = 0}) {
      if (v is num) return v.toInt();
      return int.tryParse(v?.toString() ?? '') ?? fallback;
    }

    return StockOpnameItem(
      idStockOpnameItem: j['idStockOpnameItem']?.toString() ?? '',
      product: Product.fromJson(
        (j['product'] as Map?)?.cast<String, dynamic>() ?? const {},
      ),
      productSku: StockProductSku.fromJson(
        (j['productSku'] as Map?)?.cast<String, dynamic>() ?? const {},
      ),
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

  final String status; // contoh: "submitted", "UNADJUSTED"
  final String note;
  final String adjustmentStatus; // contoh: "NOT_ADJUSTED"

  final String createdAt; // "12-01-2026 11:04"
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
    int _toInt(dynamic v, {int fallback = 0}) {
      if (v is num) return v.toInt();
      return int.tryParse(v?.toString() ?? '') ?? fallback;
    }

    return StockOpname(
      idStockOpname: j['idStockOpname']?.toString() ?? '',
      storeLocation: StockStoreLocationLite.fromJson(
        (j['storeLocation'] as Map?)?.cast<String, dynamic>() ?? const {},
      ),
      product: Product.fromJson(
        (j['product'] as Map?)?.cast<String, dynamic>() ?? const {},
      ),
      productSku: StockProductSku.fromJson(
        (j['productSku'] as Map?)?.cast<String, dynamic>() ?? const {},
      ),
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

  Map<String, dynamic> toJson() => {
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
  final String status; // "success" / "skipped" / dll tergantung backend

  const StockOpnameBulkAdjustmentResult({
    required this.stockOpnameId,
    required this.productName,
    required this.skuCode,
    required this.variance,
    required this.status,
  });

  factory StockOpnameBulkAdjustmentResult.fromJson(Map<String, dynamic> j) {
    int _toInt(dynamic v, {int fallback = 0}) {
      if (v is num) return v.toInt();
      return int.tryParse(v?.toString() ?? '') ?? fallback;
    }

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
    int _toInt(dynamic v, {int fallback = 0}) {
      if (v is num) return v.toInt();
      return int.tryParse(v?.toString() ?? '') ?? fallback;
    }

    final list = (j['results'] as List? ?? const [])
        .whereType<Map>()
        .map(
          (e) => StockOpnameBulkAdjustmentResult.fromJson(
            Map<String, dynamic>.from(e.cast<String, dynamic>()),
          ),
        )
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
/// MODELS - TRANSACTION STOCK ADJUSTMENT
/// =========================

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

  final int orderAt; // unix timestamp (seconds)
  final int paymentMethod;

  final String createdAt; // ISO string
  final String updatedAt; // ISO string

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
    int _toInt(dynamic v, {int fallback = 0}) {
      if (v is num) return v.toInt();
      return int.tryParse(v?.toString() ?? '') ?? fallback;
    }

    return StockAdjustmentTransaction(
      idTransaction: j['idTransaction']?.toString() ?? '',
      storeLocationId: j['store_location_id']?.toString() ?? '',
      storeLocation: StockStoreLocationLite.fromJson(
        (j['store_location'] as Map?)?.cast<String, dynamic>() ?? const {},
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
  /// Bentuk response:
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
  void clearInitialStockDetail() {
    _initialStockDetail = null;
    _initialStockDetailError = null;
    notifyListeners();
  }

  // ============================================================
  // ✅ STOCK OPNAME (LIST + CREATE)
  // ============================================================

  /// --- LIST stock opname
  final List<StockOpname> _stockOpnames = [];
  bool _loadingStockOpnames = false;
  PageMeta? _pageStockOpnames;
  String? _stockOpnamesError;

  /// --- CREATE stock opname
  bool _creatingStockOpname = false;
  String? _createStockOpnameError;

  List<StockOpname> get stockOpnames => List.unmodifiable(_stockOpnames);
  bool get loadingStockOpnames => _loadingStockOpnames;
  PageMeta? get pageStockOpnames => _pageStockOpnames;
  String? get stockOpnamesError => _stockOpnamesError;

  bool get creatingStockOpname => _creatingStockOpname;
  String? get createStockOpnameError => _createStockOpnameError;

  bool get isStockOpnameEmpty => !_loadingStockOpnames && _stockOpnames.isEmpty;

  /// =========================
  /// FETCH: Stock Opname List
  /// =========================
  ///
  /// GET /waveup/:idBusiness/store-location/:idStoreLocation/stock-opname
  ///
  /// Response:
  /// {
  ///   "status": 200,
  ///   "data": [ {StockOpname}, ... ],
  ///   "page": {...}
  /// }
  Future<void> fetchStockOpnames(
    BuildContext context, {
    required String idStoreLocation,
    int? page,
    int? rowPerPage,
    bool append = false, // true kalau infinite scroll page>1
  }) async {
    final bizId = await BizIdCache.get();
    if (bizId == null || bizId.isEmpty) {
      if (!append) _stockOpnames.clear();
      _pageStockOpnames = null;
      _stockOpnamesError = "Business ID is not available.";
      _lastError = _stockOpnamesError;
      notifyListeners();
      return;
    }

    _loadingStockOpnames = true;
    _stockOpnamesError = null;
    notifyListeners();

    try {
      final buffer = StringBuffer(
        '/waveup/$bizId/store-location/$idStoreLocation/stock-opname',
      );

      final query = <String, String>{};
      if (page != null && page > 0) query['page'] = page.toString();
      if (rowPerPage != null && rowPerPage > 0) {
        query['row_per_page'] = rowPerPage.toString();
      }
      if (query.isNotEmpty) {
        buffer.write(
          '?' + query.entries.map((e) => '${e.key}=${e.value}').join('&'),
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
        return;
      }

      final status = (jsonMap['status'] as num?)?.toInt() ?? 0;
      if (status < 200 || status >= 300) {
        if (!append) _stockOpnames.clear();
        _pageStockOpnames = null;
        _stockOpnamesError =
            jsonMap['message']?.toString() ?? 'Failed to load stock opname.';
        _lastError = _stockOpnamesError;
        notifyListeners();
        return;
      }

      final pageJ = (jsonMap['page'] as Map?)?.cast<String, dynamic>();
      _pageStockOpnames = pageJ != null ? PageMeta.fromJson(pageJ) : null;

      final dataList = (jsonMap['data'] as List?) ?? const [];
      final parsed = dataList
          .whereType<Map>()
          .map(
            (e) => StockOpname.fromJson(
              Map<String, dynamic>.from(e.cast<String, dynamic>()),
            ),
          )
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
    } catch (e, st) {
      if (!append) _stockOpnames.clear();
      _pageStockOpnames = null;
      _stockOpnamesError = e.toString();
      _lastError = _stockOpnamesError;
      debugPrint('[StockProvider] fetchStockOpnames error: $e');
      debugPrint('$st');
      notifyListeners();
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

  /// =========================
  /// CREATE: Stock Opname
  /// =========================
  ///
  /// POST /waveup/:idBusiness/store-location/:idStoreLocation/stock-opname
  ///
  /// Payload:
  /// { "product_id": "...", "product_sku_id": "...", "qty": 20 }
  ///
  /// Response:
  /// { "status": 200, "data": { StockOpname } }
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
      _lastError = "Business ID is not available.";
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

      final dataJ = (map['data'] as Map?)?.cast<String, dynamic>() ?? const {};
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

  // Tambahkan di dalam class StockProvider (state + function)

  // ============================================================
  // ✅ NEW: STOCK OPNAME ADJUSTMENT (BULK)
  // ============================================================

  bool _adjustingStockOpnames = false;
  String? _stockOpnameAdjustmentError;
  StockOpnameBulkAdjustmentResponse? _lastStockOpnameAdjustment;

  bool get adjustingStockOpnames => _adjustingStockOpnames;
  String? get stockOpnameAdjustmentError => _stockOpnameAdjustmentError;
  StockOpnameBulkAdjustmentResponse? get lastStockOpnameAdjustment =>
      _lastStockOpnameAdjustment;

  /// =========================
  /// POST: Stock Opname Bulk Adjustment
  /// =========================
  ///
  /// POST /waveup/{idBusiness}/store-location/:idStoreLocation/stock-opname/bulk-adjustment
  ///
  /// Payload:
  /// {
  ///   "stock_opname_ids": ["..."],
  ///   "note": "Adjustment januari"
  /// }
  ///
  /// Response:
  /// {
  ///   "status": 200,
  ///   "message": "...",
  ///   "successCount": 1,
  ///   "skipCount": 0,
  ///   "results": [ ... ]
  /// }
  Future<StockOpnameBulkAdjustmentResponse?> stockOpnameBulkAdjustment({
    required BuildContext context,
    required String idStoreLocation,
    required List<String> stockOpnameIds,
    required String note,
    bool refreshListAfter = true,
  }) async {
    final bizId = await BizIdCache.get();
    if (bizId == null || bizId.isEmpty) {
      _stockOpnameAdjustmentError = "Business ID is not available.";
      _lastError = _stockOpnameAdjustmentError;
      notifyListeners();
      return null;
    }

    final storeId = idStoreLocation.trim();
    if (storeId.isEmpty) {
      _stockOpnameAdjustmentError = "Store location ID is not available.";
      _lastError = _stockOpnameAdjustmentError;
      notifyListeners();
      return null;
    }

    final ids = stockOpnameIds
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toList();

    if (ids.isEmpty) {
      _stockOpnameAdjustmentError = "Stock opname IDs cannot be empty.";
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
  // ✅ NEW: TRANSACTION STOCK ADJUSTMENT (LIST)
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

  /// =========================
  /// FETCH: Stock Adjustment List
  /// =========================
  ///
  /// GET /waveup/{idBusiness}/store-location/:idStoreLocation/transaction-adjustment
  ///
  /// Response:
  /// {
  ///   "status": 200,
  ///   "page": {...},
  ///   "data": [ {Transaction}, ... ]
  /// }
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
      _stockAdjustmentsError = "Business ID is not available.";
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
          '?' + query.entries.map((e) => '${e.key}=${e.value}').join('&'),
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

      final pageJ = (jsonMap['page'] as Map?)?.cast<String, dynamic>();
      _pageStockAdjustments = pageJ != null ? PageMeta.fromJson(pageJ) : null;

      final dataList = (jsonMap['data'] as List?) ?? const [];
      final parsed = dataList
          .whereType<Map>()
          .map(
            (e) => StockAdjustmentTransaction.fromJson(
              Map<String, dynamic>.from(e.cast<String, dynamic>()),
            ),
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
