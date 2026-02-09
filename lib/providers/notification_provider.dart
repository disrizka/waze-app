// lib/providers/notification_provider.dart
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart'; // <= tambahkan ini

import 'package:wa_blast/core/provider_helper.dart'; // FetchHelper, PageMeta
import 'package:wa_blast/services/api_service.dart'; // ApiJson / ApiService

part '../models/notification_models/notification_item.dart';

/// =========================
/// PROVIDER
/// =========================

class NotificationProvider with ChangeNotifier {
  // ===== List & pagination
  final List<NotificationItem> _items = [];
  PageMeta? _page;
  bool _loadingList = false;

  // ===== Detail
  NotificationItem? _detail;
  bool _loadingDetail = false;

  // ===== Unread count
  int _unreadCount = 0;
  bool _loadingUnread = false;

  // ===== Busy flags
  bool _marking = false; // global mark-as-read
  final Map<String, bool> _rowBusy = <String, bool>{};

  // ===== Error
  String? _lastError;

  // ===== Lifecycle guard
  bool _disposed = false;

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }

  /// Notifikasi aman: bila sedang fase build / bukan idle → tunda ke post-frame
  void _notifySafely() {
    if (_disposed) return;
    if (WidgetsBinding.instance.schedulerPhase == SchedulerPhase.idle) {
      // aman: di luar build
      notifyListeners();
    } else {
      // tunda: setelah frame selesai
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!_disposed) notifyListeners();
      });
    }
  }

  // ===== Getters
  List<NotificationItem> get notifications => List.unmodifiable(_items);
  PageMeta? get page => _page;
  bool get loadingList => _loadingList;

  NotificationItem? get notificationDetail => _detail;
  bool get loadingDetail => _loadingDetail;

  int get unreadCount => _unreadCount;
  bool get loadingUnread => _loadingUnread;

  bool get isMarking => _marking;
  Map<String, bool> get rowBusy => Map.unmodifiable(_rowBusy);

  String? get lastError => _lastError;

  // ===== Utils (internal)
  void _setLoading({
    bool? list,
    bool? detail,
    bool? unread,
    bool notify = true,
  }) {
    if (list != null) _loadingList = list;
    if (detail != null) _loadingDetail = detail;
    if (unread != null) _loadingUnread = unread;
    if (notify) _notifySafely();
  }

  void _setRowBusy(String id, bool v) {
    _rowBusy[id] = v;
    _notifySafely();
  }

  void _consumeAndLogError(Object e, [StackTrace? st]) {
    _lastError = e.toString();
    if (kDebugMode) {
      debugPrint("[NotificationProvider] exception: $e");
      if (st != null) debugPrint("$st");
    }
  }

  String _fmtErr(Map<String, dynamic>? j, String fallback) {
    return j?['msg']?.toString() ?? j?['message']?.toString() ?? fallback;
  }

  int indexOf(String id) => _items.indexWhere((e) => e.idNotification == id);

  NotificationItem? byId(String id) {
    final i = indexOf(id);
    return i >= 0 ? _items[i] : null;
  }

  void _upsert(NotificationItem n) {
    final i = indexOf(n.idNotification);
    if (i >= 0) {
      _items[i] = n;
    } else {
      _items.insert(0, n);
    }
  }

  bool get _pageHasNext {
    if (_page == null) return false;
    try {
      return _page!.currentPage < _page!.totalPages;
    } catch (_) {
      return false;
    }
  }

  int get _nextPageNumber {
    final cur = (_page?.currentPage ?? 0);
    return cur + 1;
  }

  int? get _rowPerPageOrNull {
    try {
      return _page?.rowPerPage;
    } catch (_) {
      return null;
    }
  }

  String _buildQuery(Map<String, String?> params) {
    final entries = params.entries
        .where((e) => e.value != null && e.value!.trim().isNotEmpty)
        .map(
          (e) =>
              '${Uri.encodeQueryComponent(e.key)}=${Uri.encodeQueryComponent(e.value!.trim())}',
        )
        .toList();
    return entries.isEmpty ? '' : '?${entries.join('&')}';
  }

  /// =========================
  /// 1) GET /notification
  /// =========================
  Future<void> fetchNotifications(
    BuildContext context, {
    String? query,
    int? page,
    int? perPage,
    bool? onlyUnread,
    String? targetType,
  }) async {
    _setLoading(list: true);
    try {
      final base = '/notification';
      final qp = _buildQuery({
        'q': query,
        'page': (page != null && page > 0) ? '$page' : null,
        'row_per_page': (perPage != null && perPage > 0) ? '$perPage' : null,
        'only_unread': (onlyUnread == true) ? '1' : null,
        'target_type': targetType,
      });

      final result = await FetchHelper.fetchList<NotificationItem>(
        context: context,
        path: '$base$qp',
        parser: NotificationItem.fromJson,
      );

      if (result == null) {
        _items.clear();
        _page = null;
        _notifySafely();
        return;
      }

      _items
        ..clear()
        ..addAll(result.items);
      _page = result.page;

      _notifySafely();
    } catch (e, st) {
      _consumeAndLogError(e, st);
    } finally {
      _setLoading(list: false);
    }
  }

  /// Ambil halaman berikutnya (pagination)
  Future<void> fetchMoreNotifications(BuildContext context) async {
    if (!_pageHasNext) return;

    const pageKey = '__notif_page_next__';
    _setRowBusy(pageKey, true);
    try {
      final nextPage = _nextPageNumber;
      final rpp = _rowPerPageOrNull;
      final qp = _buildQuery({
        'page': '$nextPage',
        'row_per_page': (rpp != null && rpp > 0) ? '$rpp' : null,
      });

      final path = '/notification$qp';

      final result = await FetchHelper.fetchList<NotificationItem>(
        context: context,
        path: path,
        parser: NotificationItem.fromJson,
      );

      if (result == null) return;

      _items.addAll(result.items);
      _page = result.page;
      _notifySafely();
    } catch (e, st) {
      _consumeAndLogError(e, st);
    } finally {
      _setRowBusy(pageKey, false);
    }
  }

  /// =========================
  /// 2) GET /notification/unread-count
  /// =========================
  Future<int> fetchUnreadCount(BuildContext context) async {
    _setLoading(unread: true);
    try {
      final j = await ApiJson.getMap(context, '/notification/unread-count');
      if (j == null) {
        _lastError = 'Null JSON response';
        _unreadCount = 0;
        _notifySafely();
        return 0;
      }

      if ((j['status'] as num?)?.toInt() != 200) {
        _lastError = _fmtErr(j, 'Failed to get unread count');
        _unreadCount = 0;
        _notifySafely();
        return 0;
      }

      // ==== baca field "unreadCount" (atau fallback lama)
      int c = 0;
      final raw1 = j['unreadCount'];
      if (raw1 is num) {
        c = raw1.toInt();
      } else {
        final data = j['data'];
        if (data is num) c = data.toInt();
        if (data is Map && data['count'] is num) {
          c = (data['count'] as num).toInt();
        }
      }

      _unreadCount = c;
      _notifySafely();
      return c;
    } catch (e, st) {
      _consumeAndLogError(e, st);
      _unreadCount = 0;
      _notifySafely();
      return 0;
    } finally {
      _setLoading(unread: false);
    }
  }

  /// =========================
  /// 3) GET /notification/:id
  /// =========================
  Future<NotificationItem?> fetchNotificationDetail(
    BuildContext context,
    String idNotification,
  ) async {
    final path = '/notification/$idNotification';
    if (kDebugMode) debugPrint("[NotificationProvider] 🌐 GET $path");

    _setLoading(detail: true);
    try {
      final j = await ApiJson.getMap(context, path);
      if (j == null) {
        _lastError = 'Null JSON response';
        return _detail;
      }
      if ((j['status'] as num?)?.toInt() != 200 ||
          j['data'] is! Map<String, dynamic>) {
        _lastError = _fmtErr(j, 'Failed to get notification detail');
        return _detail;
      }

      final data = j['data'] as Map<String, dynamic>;
      if (kDebugMode) {
        debugPrint("[NotificationProvider] detail raw: ${jsonEncode(data)}");
      }

      final next = NotificationItem.fromJson(data);
      _detail = next;

      _upsert(next);
      _notifySafely();
      return _detail;
    } catch (e, st) {
      _consumeAndLogError(e, st);
      return _detail;
    } finally {
      _setLoading(detail: false);
    }
  }

  /// =========================
  /// 4) POST /notification/:id/mark-as-read
  /// =========================
  Future<bool> markAsRead(BuildContext context, String idNotification) async {
    final path = '/notification/$idNotification/mark-as-read';

    _marking = true;
    _setRowBusy(idNotification, true);
    try {
      final j = await ApiJson.postMap(
        context,
        path,
        {}, // payload kosong
        withAccessToken: true,
      );

      final ok = j != null && (j['status'] as num?)?.toInt() == 200;
      if (!ok) {
        _lastError = _fmtErr(j, 'Failed to mark as read');
        return false;
      }

      final now = DateTime.now();
      final inList = byId(idNotification);
      if (inList != null && !inList.isRead) {
        final updated = inList.copyWith(isRead: true, readAt: now);
        _upsert(updated);
      }
      if (_detail?.idNotification == idNotification &&
          _detail?.isRead == false) {
        _detail = _detail!.copyWith(isRead: true, readAt: now);
      }

      if (_unreadCount > 0) _unreadCount -= 1;

      _notifySafely();
      return true;
    } catch (e, st) {
      _consumeAndLogError(e, st);
      return false;
    } finally {
      _marking = false;
      _setRowBusy(idNotification, false);
      _notifySafely();
    }
  }

  /// =========================
  /// Misc helpers
  /// =========================
  Future<void> refresh(BuildContext context) => fetchNotifications(context);

  bool openAction(NotificationItem n, BuildContext context) {
    final url = n.actionUrl?.trim();
    if (url == null || url.isEmpty) return false;
    // Implement di UI layer (route internal / url_launcher)
    return false;
  }

  String? consumeLastError() {
    final e = _lastError;
    _lastError = null;
    return e;
  }
}
