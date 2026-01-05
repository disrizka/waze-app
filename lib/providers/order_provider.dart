import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:wa_blast/core/provider_helper.dart';

import 'package:wa_blast/models/store_order_model.dart';

class OrderProvider extends ChangeNotifier {
  /// =========================
  /// CONFIG ENDPOINT
  /// =========================
  String _storeOrdersPath(
    String bizId, {
    required int page,
    required int limit,
  }) {
    return '/waveup/$bizId/store-order?page=$page&limit=$limit';
  }

  String _storeOrderDetailPath(String bizId, String idStoreOrder) {
    return '/waveup/$bizId/store-order/$idStoreOrder';
  }

  /// =========================
  /// STATE (LIST)
  /// =========================
  final List<StoreOrder> _orders = [];
  bool _loading = false;
  bool _loadingMore = false;
  String? _error;

  int _page = 1;
  bool _hasMore = true;

  PageMeta? _pageMeta;

  List<StoreOrder> get orders => List.unmodifiable(_orders);
  bool get loading => _loading;
  bool get loadingMore => _loadingMore;
  String? get error => _error;
  bool get hasMore => _hasMore;
  PageMeta? get pageMeta => _pageMeta;

  /// =========================
  /// STATE (DETAIL)
  /// =========================
  StoreOrder? _orderDetail;
  Map<String, dynamic>? _transactionDetail;
  bool _loadingDetail = false;
  String? _detailError;

  StoreOrder? get orderDetail => _orderDetail;
  Map<String, dynamic>? get transactionDetail => _transactionDetail;
  bool get loadingDetail => _loadingDetail;
  String? get detailError => _detailError;

  /// =========================
  /// INTERNAL HELPERS
  /// =========================
  void _setLoading(bool v) {
    _loading = v;
    notifyListeners();
  }

  void _setLoadingMore(bool v) {
    _loadingMore = v;
    notifyListeners();
  }

  void _setError(String? e) {
    _error = e;
    notifyListeners();
  }

  void _setLoadingDetail(bool v) {
    _loadingDetail = v;
    notifyListeners();
  }

  void _setDetailError(String? e) {
    _detailError = e;
    notifyListeners();
  }

  Future<String?> _requireBizId() async {
    final bizId = await BizIdCache.get();
    if (bizId == null || bizId.trim().isEmpty) {
      _setError('Business ID is not available.');
      if (kDebugMode) debugPrint('[OrderProvider] ❌ Business ID null/empty');
      return null;
    }
    return bizId.trim();
  }

  /// =========================
  /// PUBLIC API (LIST)
  /// =========================
  Future<void> fetchStoreOrders(
    BuildContext context, {
    required int page,
    required int limit,
    required bool append,
  }) async {
    final bizId = await _requireBizId();
    if (bizId == null) return;

    if (!append) {
      _page = 1;
      _hasMore = true;
      _pageMeta = null;
      _orders.clear();
      _setError(null);
      _setLoading(true);
    } else {
      if (_loadingMore || !_hasMore) return;
      _setError(null);
      _setLoadingMore(true);
    }

    try {
      final path = _storeOrdersPath(bizId, page: page, limit: limit);
      if (kDebugMode) debugPrint('[OrderProvider] GET $path');

      final result = await FetchHelper.fetchList<StoreOrder>(
        context: context,
        path: path,
        parser: (json) =>
            StoreOrder.fromJson((json as Map).cast<String, dynamic>()),
      );

      final items = result?.items ?? const <StoreOrder>[];
      _pageMeta = result?.page;

      if (!append) {
        _orders
          ..clear()
          ..addAll(items);
      } else {
        _orders.addAll(items);
      }

      _page = page;
      _hasMore = items.length >= limit;

      if (kDebugMode) {
        debugPrint(
          '[OrderProvider] page=$_page loaded=${items.length} totalNow=${_orders.length} hasMore=$_hasMore',
        );
      }

      notifyListeners();
    } catch (e, st) {
      _setError(e.toString());
      if (kDebugMode) {
        debugPrint('[OrderProvider] fetchStoreOrders ERROR: $e');
        debugPrint('$st');
      }
    } finally {
      if (!append) {
        _setLoading(false);
      } else {
        _setLoadingMore(false);
      }
    }
  }

  Future<void> refresh(BuildContext context, {required int limit}) async {
    await fetchStoreOrders(context, page: 1, limit: limit, append: false);
  }

  Future<void> loadNextPage(BuildContext context, {required int limit}) async {
    if (_loading || _loadingMore || !_hasMore) return;
    final nextPage = _page + 1;
    await fetchStoreOrders(context, page: nextPage, limit: limit, append: true);
  }

  /// =========================
  /// PUBLIC API (DETAIL)
  /// =========================
  Future<void> fetchStoreOrderDetail(
    BuildContext context, {
    required String idStoreOrder,
    bool clearBeforeFetch = false,
  }) async {
    final bizId = await _requireBizId();
    if (bizId == null) return;

    final id = idStoreOrder.trim();
    if (id.isEmpty) {
      _setDetailError('Store Order ID is not available.');
      return;
    }

    if (clearBeforeFetch) {
      _orderDetail = null;
      _transactionDetail = null;
    }

    _setDetailError(null);
    _setLoadingDetail(true);

    try {
      final path = _storeOrderDetailPath(bizId, id);
      if (kDebugMode) debugPrint('[OrderProvider] GET $path');

      // ✅ PENTING:
      // FetchHelper.fetchOne() akan mengirim parser(rawData),
      // di mana rawData = j['data'] (default dataKey).
      final payload = await FetchHelper.fetchOne<_StoreOrderDetailPayload>(
        context: context,
        path: path,
        parser: (dataJson) {
          // dataJson sudah = { store_order: {...}, transaction: {...} }
          final data = dataJson.cast<String, dynamic>();

          final storeOrderJson = (data['store_order'] as Map?)
              ?.cast<String, dynamic>();
          final transactionJson = (data['transaction'] as Map?)
              ?.cast<String, dynamic>();

          return _StoreOrderDetailPayload(
            order: storeOrderJson == null
                ? null
                : StoreOrder.fromJson(storeOrderJson),
            transaction: transactionJson,
          );
        },
      );

      _orderDetail = payload?.order;
      _transactionDetail = payload?.transaction;

      if (kDebugMode) {
        debugPrint(
          '[OrderProvider] detail loaded id=$id '
          'order=${_orderDetail?.idStoreOrder ?? "-"} '
          'tx=${_transactionDetail?['idTransaction'] ?? "-"}',
        );
      }

      notifyListeners();
    } catch (e, st) {
      _setDetailError(e.toString());
      if (kDebugMode) {
        debugPrint('[OrderProvider] fetchStoreOrderDetail ERROR: $e');
        debugPrint('$st');
      }
    } finally {
      _setLoadingDetail(false);
    }
  }

  /// =========================
  /// RESET
  /// =========================
  void reset() {
    _orders.clear();
    _loading = false;
    _loadingMore = false;
    _error = null;
    _page = 1;
    _hasMore = true;
    _pageMeta = null;

    _orderDetail = null;
    _transactionDetail = null;
    _loadingDetail = false;
    _detailError = null;

    notifyListeners();
  }
}

class _StoreOrderDetailPayload {
  final StoreOrder? order;
  final Map<String, dynamic>? transaction;

  const _StoreOrderDetailPayload({
    required this.order,
    required this.transaction,
  });
}
