// lib/providers/stock_provider.dart
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'package:wa_blast/core/provider_helper.dart';
import 'package:wa_blast/constants/api_constant.dart';
import 'package:wa_blast/models/product_models/product_model.dart';
import 'package:wa_blast/services/api_service.dart';

part '../models/stock_models/create_stock_opname_payload.dart';
part '../models/stock_models/initial_stock_detail.dart';
part '../models/stock_models/initial_stock_item.dart';
part '../models/stock_models/initial_stock_row.dart';
part '../models/stock_models/stock_adjustment_transaction.dart';
part '../models/stock_models/stock_opname.dart';
part '../models/stock_models/stock_opname_bulk_adjustment_response.dart';
part '../models/stock_models/stock_opname_bulk_adjustment_result.dart';
part '../models/stock_models/stock_opname_item.dart';
part '../models/stock_models/stock_product_sku.dart';
part '../models/stock_models/stock_sku_attribute.dart';
part '../models/stock_models/stock_store_location_lite.dart';

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

  Future<int> fetchInitialStocks(
    BuildContext context, {
    int? page,
    int? rowPerPage,
    int? limit,
    String? search,
    String? storeLocationId,
    String? dateFrom,
    String? dateTo,
    bool append = false,
  }) async {
    final bizId = await BizIdCache.get();
    if (bizId == null || bizId.isEmpty) {
      if (!append) _initialStocks.clear();
      _pageInitialStocks = null;
      _initialStocksError = 'Business ID is not available.';
      _lastError = _initialStocksError;
      notifyListeners();
      return 0;
    }

    _loadingInitialStocks = true;
    _initialStocksError = null;
    notifyListeners();

    try {
      final buffer = StringBuffer('/waveup/$bizId/initial-stock');
      final query = <String, String>{};

      if (page != null && page > 0) query['page'] = page.toString();
      final effectiveLimit = (limit ?? rowPerPage);
      if (effectiveLimit != null && effectiveLimit > 0) {
        query['row_per_page'] = effectiveLimit.toString();
      }
      if ((search ?? '').trim().isNotEmpty) {
        query['search'] = search!.trim();
      }
      if ((storeLocationId ?? '').trim().isNotEmpty) {
        query['store_location_id'] = storeLocationId!.trim();
      }
      if ((dateFrom ?? '').trim().isNotEmpty) {
        query['date_from'] = dateFrom!.trim();
      }
      if ((dateTo ?? '').trim().isNotEmpty) {
        query['date_to'] = dateTo!.trim();
      }

      if (query.isNotEmpty) {
        buffer.write('?${Uri(queryParameters: query).query}');
      }

      final path = buffer.toString();
      if (kDebugMode) debugPrint('[StockProvider] GET $path');

      final jsonMap = await ApiJson.getMap(
        context,
        path,
      ).timeout(const Duration(seconds: 30), onTimeout: () => null);

      if (jsonMap == null) {
        if (!append) _initialStocks.clear();
        _pageInitialStocks = null;
        _initialStocksError = 'Failed to load initial stock.';
        _lastError = _initialStocksError;
        notifyListeners();
        return 0;
      }

      final status = (jsonMap['status'] as num?)?.toInt() ?? 0;
      if (status < 200 || status >= 300) {
        if (!append) _initialStocks.clear();
        _pageInitialStocks = null;
        _initialStocksError =
            jsonMap['message']?.toString() ?? 'Failed to load initial stock.';
        _lastError = _initialStocksError;
        notifyListeners();
        return 0;
      }

      final pageJ = _asMap(jsonMap['page']);
      _pageInitialStocks = pageJ.isNotEmpty ? PageMeta.fromJson(pageJ) : null;

      final dataList = (jsonMap['data'] as List?) ?? const <dynamic>[];
      final parsed = dataList
          .whereType<Map>()
          .map((e) => InitialStockRow.fromJson(e.cast<String, dynamic>()))
          .toList();

      if (append) {
        _initialStocks.addAll(parsed);
      } else {
        _initialStocks
          ..clear()
          ..addAll(parsed);
      }

      _initialStocksError = null;
      _lastError = null;
      notifyListeners();
      return parsed.length;
    } catch (e, st) {
      if (!append) _initialStocks.clear();
      _pageInitialStocks = null;
      _initialStocksError = e.toString();
      _lastError = _initialStocksError;
      debugPrint('[StockProvider] fetchInitialStocks error: $e');
      debugPrint('$st');
      notifyListeners();
      return 0;
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
      if (kDebugMode) {
        debugPrint('[StockProvider] GET $path');
        debugPrint('[StockProvider] GET ${ApiConstant.baseUrl}$path');
      }

      final jsonMap = await ApiJson.getMap(
        context,
        path,
      ).timeout(const Duration(seconds: 30), onTimeout: () => null);

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
