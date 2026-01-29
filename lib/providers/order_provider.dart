// lib/providers/order_provider.dart
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'package:wa_blast/core/provider_helper.dart';
import 'package:wa_blast/models/store_order_model.dart';
import 'package:wa_blast/services/api_service.dart';

class OrderProvider extends ChangeNotifier {
  /// =========================
  /// CONFIG ENDPOINT
  /// =========================

  // Filter untuk list store order
  String? _search; // ✅ search filter (server-side)
  String? _status; // e.g. "ON_HOLD"
  DateTime? _startDate; // e.g. 2026-01-01
  DateTime? _endDate; // e.g. 2026-01-31
  String? _platformName; // e.g. "tiktok"

  // limit & page untuk infinite scroll (di-manage provider)
  int _page = 1;
  int _limit = 50; // default sesuai contoh user
  bool _hasMore = true;

  // simpan limit terakhir supaya action (accept) bisa refresh list tanpa nanya UI
  int _lastLimit = 50;

  String _fmtDate(DateTime d) {
    final y = d.year.toString().padLeft(4, '0');
    final m = d.month.toString().padLeft(2, '0');
    final day = d.day.toString().padLeft(2, '0');
    return '$y-$m-$day';
  }

  String _storeOrdersPath(
    String bizId, {
    required int page,
    required int limit,
  }) {
    // Base path (ApiService biasanya sudah prefix /api)
    final base = '/waveup/$bizId/store-order';

    final q = <String, String>{
      'page': page.toString(),
      'limit': limit.toString(),
    };

    // ✅ search
    final s = _search?.trim();
    if (s != null && s.isNotEmpty) q['search'] = s;

    // add filters (kalau ada)
    final st = _status?.trim();
    if (st != null && st.isNotEmpty) q['status'] = st;

    if (_startDate != null) q['start_date'] = _fmtDate(_startDate!);
    if (_endDate != null) q['end_date'] = _fmtDate(_endDate!);

    final pf = _platformName?.trim();
    if (pf != null && pf.isNotEmpty) q['platform_name'] = pf;

    // Build query aman (auto encode)
    final uri = Uri(path: base, queryParameters: q);
    return uri.toString();
  }

  String _storeOrderDetailPath(String bizId, String idStoreOrder) {
    return '/waveup/$bizId/store-order/$idStoreOrder';
  }

  String _acceptStoreOrderPath(String bizId) {
    return '/waveup/$bizId/store-order/accept';
  }

  /// =========================
  /// STATE (LIST)
  /// =========================
  final List<StoreOrder> _orders = [];
  bool _loading = false;
  bool _loadingMore = false;
  String? _error;

  PageMeta? _pageMeta;

  List<StoreOrder> get orders => List.unmodifiable(_orders);
  bool get loading => _loading;
  bool get loadingMore => _loadingMore;
  String? get error => _error;
  bool get hasMore => _hasMore;
  PageMeta? get pageMeta => _pageMeta;

  int get page => _page;
  int get limit => _limit;

  String? get search => _search;
  String? get status => _status;
  DateTime? get startDate => _startDate;
  DateTime? get endDate => _endDate;
  String? get platformName => _platformName;

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
  /// STATE (ACCEPT)
  /// =========================
  bool _accepting = false;
  String? _acceptError;

  bool get accepting => _accepting;
  String? get acceptError => _acceptError;

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

  void _setAccepting(bool v) {
    _accepting = v;
    notifyListeners();
  }

  void _setAcceptError(String? e) {
    _acceptError = e;
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

  bool _computeHasMore({
    required List<StoreOrder> items,
    required int effectiveLimit,
    PageMeta? meta,
    required int effectivePage,
  }) {
    // Prioritas: meta totalPages jika tersedia
    final current = meta?.currentPage;
    final total = meta?.totalPages;

    if (current != null && total != null && total > 0) {
      return current < total;
    }

    // Fallback: kalau item kurang dari limit, berarti kemungkinan habis
    return items.length >= effectiveLimit;
  }

  /// =========================
  /// FILTER API
  /// =========================

  /// ✅ Set filter list. Jika [autoRefresh]=true, akan refresh page 1.
  Future<void> setFilters(
    BuildContext context, {
    String? search,
    String? status,
    DateTime? startDate,
    DateTime? endDate,
    String? platformName,
    bool autoRefresh = true,
  }) async {
    _search = search;
    _status = status;
    _startDate = startDate;
    _endDate = endDate;
    _platformName = platformName;

    if (autoRefresh) {
      await refreshList(context);
    } else {
      notifyListeners();
    }
  }

  /// ✅ Reset semua filter (search/status/date/platform) lalu refresh.
  Future<void> resetFilters(
    BuildContext context, {
    bool autoRefresh = true,
  }) async {
    _search = null;
    _status = null;
    _startDate = null;
    _endDate = null;
    _platformName = null;

    if (autoRefresh) {
      await refreshList(context);
    } else {
      notifyListeners();
    }
  }

  /// Set limit list untuk infinite scroll.
  /// Biasanya dipanggil sebelum init/refresh.
  void setListLimit(int newLimit) {
    final v = newLimit <= 0 ? 50 : newLimit;
    _limit = v;
    _lastLimit = v;
    notifyListeners();
  }

  /// =========================
  /// PUBLIC API (LIST) - INFINITE SCROLL FRIENDLY
  /// =========================

  /// First load (page 1). UI cukup panggil ini.
  Future<void> initList(BuildContext context, {int? limit}) async {
    if (limit != null) setListLimit(limit);
    await _fetchStoreOrdersInternal(context, append: false);
  }

  /// ✅ Refresh list (page 1).
  /// dibuat OPTIONAL limit agar kompatibel dengan screen yang memanggil refreshList(context, limit: x)
  Future<void> refreshList(BuildContext context, {int? limit}) async {
    if (limit != null && limit > 0) {
      _limit = limit;
      _lastLimit = limit;
    }
    await _fetchStoreOrdersInternal(context, append: false);
  }

  /// ✅ Load next page (append) (tanpa limit param) — versi internal
  Future<void> loadNextPageInternal(BuildContext context) async {
    if (_loading || _loadingMore || !_hasMore) return;
    await _fetchStoreOrdersInternal(context, append: true);
  }

  /// =========================
  /// BACKWARD-COMPAT METHODS (INI YANG BIKIN UI KAMU GA ERROR)
  /// =========================

  /// ✅ UI kamu ada yang manggil: prov.refresh(context, limit: _limit)
  Future<void> refresh(BuildContext context, {required int limit}) async {
    _limit = limit <= 0 ? _limit : limit;
    _lastLimit = _limit;
    await _fetchStoreOrdersInternal(context, append: false);
  }

  /// ✅ UI kamu ada yang manggil: prov.loadNextPage(context, limit: _limit)
  Future<void> loadNextPage(BuildContext context, {required int limit}) async {
    if (_loading || _loadingMore || !_hasMore) return;
    _limit = limit <= 0 ? _limit : limit;
    _lastLimit = _limit;
    await _fetchStoreOrdersInternal(context, append: true);
  }

  /// =========================
  /// BACKWARD-COMPAT (kalau masih ada UI lama yang panggil signature ini)
  /// =========================
  Future<void> fetchStoreOrders(
    BuildContext context, {
    required int page,
    required int limit,
    required bool append,
  }) async {
    // tetap support, tapi sekarang tetap pakai filter + perbaikan effectivePage
    _limit = limit <= 0 ? _limit : limit;
    _lastLimit = _limit;

    if (!append) {
      _page = 1;
    } else {
      _page = page; // akan ditimpa oleh internal logic jika perlu
    }

    // internal fetch tetap jadi sumber kebenaran
    // "page" tetap dihormati untuk compat, tapi kalau append=false dipaksa ke 1
    await _fetchStoreOrdersInternal(
      context,
      append: append,
      overridePage: page,
    );
  }

  /// =========================
  /// INTERNAL FETCH (LIST)
  /// =========================
  Future<void> _fetchStoreOrdersInternal(
    BuildContext context, {
    required bool append,
    int? overridePage, // dipakai hanya untuk backward-compat
  }) async {
    final bizId = await _requireBizId();
    if (bizId == null) return;

    // effective page:
    // - append=false => selalu page 1
    // - append=true  => next page (atau overridePage kalau compat)
    final effectivePage = append ? (overridePage ?? (_page + 1)) : 1;

    final effectiveLimit = _limit <= 0 ? 50 : _limit;
    _lastLimit = effectiveLimit;

    if (!append) {
      if (_loading) return; // guard refresh paralel
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
      final path = _storeOrdersPath(
        bizId,
        page: effectivePage,
        limit: effectiveLimit,
      );
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

      // page: prefer meta currentPage jika ada
      _page = _pageMeta?.currentPage ?? effectivePage;

      _hasMore = _computeHasMore(
        items: items,
        effectiveLimit: effectiveLimit,
        meta: _pageMeta,
        effectivePage: _page,
      );

      if (kDebugMode) {
        debugPrint(
          '[OrderProvider] page=$_page loaded=${items.length} totalNow=${_orders.length} '
          'hasMore=$_hasMore limit=$effectiveLimit '
          'filters={search:${_search ?? "-"}, status:${_status ?? "-"}, '
          'start:${_startDate != null ? _fmtDate(_startDate!) : "-"}, '
          'end:${_endDate != null ? _fmtDate(_endDate!) : "-"}, '
          'platform:${_platformName ?? "-"}}',
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

      final payload = await FetchHelper.fetchOne<_StoreOrderDetailPayload>(
        context: context,
        path: path,
        parser: (dataJson) {
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
  /// PUBLIC API (ACCEPT ORDER)
  /// =========================
  Future<bool> acceptStoreOrder(
    BuildContext context, {
    required String orderId, // payload: {"order_id": "..."}
    bool refreshListOnSuccess = true,
    bool refreshDetailOnSuccess = true,
  }) async {
    final bizId = await _requireBizId();
    if (bizId == null) return false;

    final id = orderId.trim();
    if (id.isEmpty) {
      _setAcceptError('Order ID is not available.');
      return false;
    }

    if (_accepting) return false;

    final payload = <String, dynamic>{'order_id': id};

    _setAcceptError(null);
    _setAccepting(true);

    try {
      final path = _acceptStoreOrderPath(bizId);

      if (kDebugMode) {
        debugPrint('[OrderProvider] POST $path');
        debugPrint('[OrderProvider] accept payload: ${jsonEncode(payload)}');
      }

      final res = await ApiService.post(
        context,
        path,
        payload,
        withAccessToken: true,
      );

      final ok = res != null && res.statusCode >= 200 && res.statusCode < 300;

      if (kDebugMode) {
        debugPrint('[OrderProvider] accept code: ${res?.statusCode}');
        debugPrint('[OrderProvider] accept body: ${res?.body}');
      }

      if (!ok) {
        _setAcceptError(res?.body ?? 'Failed to accept store order');
        return false;
      }

      // Optional patch cache dari response
      try {
        final raw = res?.body;
        if (raw != null && raw.isNotEmpty) {
          final decoded = jsonDecode(raw);

          if (decoded is Map) {
            final root = decoded.cast<String, dynamic>();
            final data = (root['data'] as Map?)?.cast<String, dynamic>();

            final soMap =
                (data?['store_order'] as Map?)?.cast<String, dynamic>() ??
                data?.cast<String, dynamic>();

            if (soMap != null && soMap.isNotEmpty) {
              final updated = StoreOrder.fromJson(soMap);

              final idx = _orders.indexWhere(
                (o) =>
                    o.idStoreOrder == updated.idStoreOrder ||
                    o.idStoreOrder == id,
              );
              if (idx != -1) _orders[idx] = updated;

              if (_orderDetail?.idStoreOrder == updated.idStoreOrder ||
                  _orderDetail?.idStoreOrder == id) {
                _orderDetail = updated;
              }

              notifyListeners();
            }
          }
        }
      } catch (_) {
        // ignore
      }

      if (refreshDetailOnSuccess) {
        if (_orderDetail?.idStoreOrder == id) {
          await fetchStoreOrderDetail(
            context,
            idStoreOrder: id,
            clearBeforeFetch: false,
          );
        }
      }

      if (refreshListOnSuccess) {
        // refresh pakai limit terakhir (default 50) dan tetap bawa filters
        await refreshList(context, limit: _lastLimit);
      }

      return true;
    } catch (e, st) {
      _setAcceptError(e.toString());
      if (kDebugMode) {
        debugPrint('[OrderProvider] acceptStoreOrder ERROR: $e');
        debugPrint('$st');
      }
      return false;
    } finally {
      _setAccepting(false);
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
    _limit = 50;
    _hasMore = true;
    _pageMeta = null;

    _search = null;
    _status = null;
    _startDate = null;
    _endDate = null;
    _platformName = null;

    _orderDetail = null;
    _transactionDetail = null;
    _loadingDetail = false;
    _detailError = null;

    _accepting = false;
    _acceptError = null;

    _lastLimit = 50;

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
