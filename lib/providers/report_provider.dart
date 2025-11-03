// ReportProvider terpadu untuk Sales, Purchase, dan Revenue
// - Menyimpan state per-kind (sales/purchase/revenue) agar tidak saling menimpa.
// - Period: daily, month, year
// - Endpoint: /waveup/{bizId}/report/{sales|purchase|revenue}?period=...
//
// Catatan:
// - Bergantung pada: BizIdCache & ApiJson.getMap (sesuai project kamu)
// - App tidak perlu punya provider terpisah; cukup satu ReportProvider ini.

import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'package:wa_blast/core/provider_helper.dart'; // BizIdCache
import 'package:wa_blast/services/api_service.dart'; // ApiJson.getMap

/// Jenis report yang ditampilkan di UI (tab).
enum ReportKind { sales, purchase, revenue }

extension ReportKindX on ReportKind {
  String get pathSegment => switch (this) {
    ReportKind.sales => 'sales',
    ReportKind.purchase => 'purchase',
    ReportKind.revenue => 'revenue',
  };

  String get label => switch (this) {
    ReportKind.sales => 'Sales',
    ReportKind.purchase => 'Purchase',
    ReportKind.revenue => 'Revenue',
  };
}

/// Period report sesuai API.
enum SalesPeriod { daily, month, year }

extension SalesPeriodX on SalesPeriod {
  String get query => switch (this) {
    SalesPeriod.daily => 'daily',
    SalesPeriod.month => 'month',
    SalesPeriod.year => 'year',
  };

  static SalesPeriod fromString(String? v) {
    switch ((v ?? '').toLowerCase()) {
      case 'daily':
        return SalesPeriod.daily;
      case 'year':
        return SalesPeriod.year;
      case 'month':
      default:
        return SalesPeriod.month;
    }
  }

  String get label => switch (this) {
    SalesPeriod.daily => '1 Hari',
    SalesPeriod.month => '1 Bulan',
    SalesPeriod.year => '1 Tahun',
  };
}

/// ================== MODELS (bentuk respons kamu) ==================
@immutable
class SalesReportItem {
  final String productSku;
  final String productName;
  final int totalQty;
  final num totalRevenue;
  final String? revenueFormatted;

  const SalesReportItem({
    required this.productSku,
    required this.productName,
    required this.totalQty,
    required this.totalRevenue,
    this.revenueFormatted,
  });

  factory SalesReportItem.fromJson(Map<String, dynamic> j) => SalesReportItem(
    productSku: (j['product_sku'] ?? '').toString(),
    productName: (j['product_name'] ?? '').toString(),
    totalQty: (j['total_qty'] as num?)?.toInt() ?? 0,
    totalRevenue: (j['total_revenue'] as num?) ?? 0,
    revenueFormatted: j['revenue_formatted']?.toString(),
  );

  Map<String, dynamic> toJson() => {
    'product_sku': productSku,
    'product_name': productName,
    'total_qty': totalQty,
    'total_revenue': totalRevenue,
    'revenue_formatted': revenueFormatted,
  };

  @override
  String toString() =>
      'Item(sku: $productSku, name: $productName, qty: $totalQty, rev: $totalRevenue)';
}

@immutable
class SalesReportSummary {
  final int totalQty;
  final num totalRevenue;
  final String? totalRevenueFormatted;

  const SalesReportSummary({
    required this.totalQty,
    required this.totalRevenue,
    this.totalRevenueFormatted,
  });

  factory SalesReportSummary.fromJson(Map<String, dynamic> j) =>
      SalesReportSummary(
        totalQty: (j['total_qty'] as num?)?.toInt() ?? 0,
        totalRevenue: (j['total_revenue'] as num?) ?? 0,
        totalRevenueFormatted: j['total_revenue_formatted']?.toString(),
      );

  Map<String, dynamic> toJson() => {
    'total_qty': totalQty,
    'total_revenue': totalRevenue,
    'total_revenue_formatted': totalRevenueFormatted,
  };
}

@immutable
class SalesReportRange {
  final DateTime? startDate;
  final DateTime? endDate;

  const SalesReportRange({this.startDate, this.endDate});

  factory SalesReportRange.fromJson(Map<String, dynamic> j) {
    DateTime? _parse(String? s) {
      if (s == null || s.isEmpty) return null;
      // Format contoh: "2025-11-03"
      return DateTime.tryParse(s);
    }

    return SalesReportRange(
      startDate: _parse(j['start_date']?.toString()),
      endDate: _parse(j['end_date']?.toString()),
    );
  }

  Map<String, dynamic> toJson() => {
    'start_date': startDate?.toIso8601String(),
    'end_date': endDate?.toIso8601String(),
  };

  @override
  String toString() => 'Range($startDate → $endDate)';
}

/// State per-kind agar data tiap tab tidak saling menimpa.
class _ReportState {
  SalesPeriod period;
  bool isLoading;
  String? lastError;
  SalesReportSummary? summary;
  SalesReportRange? range;
  final List<SalesReportItem> items;

  _ReportState({
    this.period = SalesPeriod.month,
    this.isLoading = false,
    this.lastError,
    this.summary,
    this.range,
    List<SalesReportItem>? items,
  }) : items = items ?? <SalesReportItem>[];

  void clear() {
    summary = null;
    range = null;
    items.clear();
  }

  Map<String, dynamic> toCompactMap(ReportKind kind) => {
    'kind': kind.pathSegment,
    'period': period.query,
    'range': range?.toJson(),
    'summary': summary?.toJson(),
    'count': items.length,
  };
}

/// ================== PROVIDER ==================
class ReportProvider with ChangeNotifier {
  ReportProvider({
    ReportKind initialKind = ReportKind.sales,
    SalesPeriod initialPeriod = SalesPeriod.month,
  }) : _currentKind = initialKind {
    // Inisialisasi 3 state
    for (final k in ReportKind.values) {
      _states[k] = _ReportState(
        period: k == initialKind ? initialPeriod : SalesPeriod.month,
      );
    }
  }

  // Kind aktif (tab yang sedang dilihat)
  ReportKind _currentKind;
  final Map<ReportKind, _ReportState> _states = {};

  /// ===== Getters umum untuk UI aktif (current kind) =====
  ReportKind get currentKind => _currentKind;

  SalesPeriod get period => _states[_currentKind]!.period;
  bool get isLoading => _states[_currentKind]!.isLoading;
  String? get lastError => _states[_currentKind]!.lastError;
  SalesReportSummary? get summary => _states[_currentKind]!.summary;
  SalesReportRange? get range => _states[_currentKind]!.range;
  List<SalesReportItem> get items =>
      List.unmodifiable(_states[_currentKind]!.items);

  // ===== Getter per-kind (kalau UI tab mau akses spesifik) =====
  SalesPeriod periodOf(ReportKind k) => _states[k]!.period;
  bool isLoadingOf(ReportKind k) => _states[k]!.isLoading;
  String? lastErrorOf(ReportKind k) => _states[k]!.lastError;
  SalesReportSummary? summaryOf(ReportKind k) => _states[k]!.summary;
  SalesReportRange? rangeOf(ReportKind k) => _states[k]!.range;
  List<SalesReportItem> itemsOf(ReportKind k) =>
      List.unmodifiable(_states[k]!.items);

  /// ===== Helpers =====
  void _setLoading(ReportKind k, bool v) {
    _states[k]!.isLoading = v;
    notifyListeners();
  }

  void _setError(ReportKind k, String? e) {
    _states[k]!.lastError = e;
    notifyListeners();
  }

  Future<String?> _requireBizId() async {
    final bizId = await BizIdCache.get();
    if (bizId == null || bizId.isEmpty) {
      _setError(_currentKind, "Business ID is not available.");
      if (kDebugMode) debugPrint("[ReportProvider] ❌ Business ID null/empty");
      return null;
    }
    return bizId;
  }

  /// ===== Mutators =====
  /// Pindah tab/kind.
  void setKind(ReportKind k, {bool notify = true}) {
    _currentKind = k;
    if (notify) notifyListeners();
  }

  /// Ganti period untuk kind tertentu (default: current).
  void setPeriod(SalesPeriod p, {ReportKind? forKind, bool notify = true}) {
    final k = forKind ?? _currentKind;
    _states[k]!.period = p;
    if (notify) notifyListeners();
  }

  /// Shortcut: ganti kind & langsung fetch.
  Future<bool> changeKindAndFetch(BuildContext context, ReportKind k) async {
    setKind(k);
    return fetch(context, kind: k);
  }

  /// Shortcut: ganti period (untuk current) & fetch.
  Future<bool> changePeriodAndFetch(BuildContext context, SalesPeriod p) async {
    setPeriod(p);
    return fetch(context);
  }

  /// ===== FETCH (inti) =====
  /// GET /waveup/{bizId}/report/{kind}?period=daily|month|year
  Future<bool> fetch(BuildContext context, {ReportKind? kind}) async {
    final k = kind ?? _currentKind;
    final state = _states[k]!;
    final bizId = await _requireBizId();
    if (bizId == null) {
      state.clear();
      notifyListeners();
      return false;
    }

    final path =
        '/waveup/$bizId/report/${k.pathSegment}?period=${state.period.query}';
    if (kDebugMode) debugPrint("[ReportProvider] 🌐 GET $path");

    _setLoading(k, true);
    try {
      final j = await ApiJson.getMap(context, path);
      if (j == null) {
        _setError(k, 'Null JSON response');
        state.clear();
        return false;
      }

      final status = (j['status'] as num?)?.toInt() ?? 0;
      if (status != 200) {
        final msg =
            j['msg']?.toString() ??
            j['message']?.toString() ??
            'Failed to get ${k.label.toLowerCase()} report';
        _setError(k, msg);
        state.clear();
        return false;
      }

      // Sinkronisasi period dari server (opsional)
      state.period = SalesPeriodX.fromString(j['period']?.toString());

      // Range & Summary
      state.summary = (j['summary'] is Map<String, dynamic>)
          ? SalesReportSummary.fromJson(j['summary'] as Map<String, dynamic>)
          : const SalesReportSummary(totalQty: 0, totalRevenue: 0);

      state.range = SalesReportRange.fromJson({
        'start_date': j['start_date']?.toString(),
        'end_date': j['end_date']?.toString(),
      });

      // Items
      state.items..clear();
      final raw = j['data'];
      if (raw is List) {
        for (final e in raw) {
          if (e is Map<String, dynamic>) {
            state.items.add(SalesReportItem.fromJson(e));
          }
        }
      }

      if (kDebugMode) {
        debugPrint(
          "[ReportProvider] ✅ ${k.label} items=${state.items.length} "
          "summary=${state.summary?.toJson()} range=${state.range?.toJson()}",
        );
      }

      _setError(k, null);
      notifyListeners();
      return true;
    } catch (e, st) {
      _setError(k, e.toString());
      if (kDebugMode) {
        debugPrint("[ReportProvider] exception: $e");
        debugPrint("$st");
      }
      _states[k]!.clear();
      return false;
    } finally {
      _setLoading(k, false);
    }
  }

  /// Refresh untuk current kind.
  Future<void> refresh(BuildContext context) => fetch(context);

  /// Ambil & reset error untuk current kind (sekali pakai).
  String? consumeLastError({ReportKind? forKind}) {
    final k = forKind ?? _currentKind;
    final e = _states[k]!.lastError;
    _states[k]!.lastError = null;
    return e;
  }

  /// Sorting helper (untuk current kind)
  void sortByRevenueDesc() {
    _states[_currentKind]!.items.sort(
      (a, b) => b.totalRevenue.compareTo(a.totalRevenue),
    );
    notifyListeners();
  }

  void sortByQtyDesc() {
    _states[_currentKind]!.items.sort(
      (a, b) => b.totalQty.compareTo(a.totalQty),
    );
    notifyListeners();
  }

  void sortByNameAsc() {
    _states[_currentKind]!.items.sort(
      (a, b) =>
          a.productName.toLowerCase().compareTo(b.productName.toLowerCase()),
    );
    notifyListeners();
  }

  /// Filter non-mutating untuk current kind
  List<SalesReportItem> filteredByQuery(String q, {ReportKind? forKind}) {
    final k = forKind ?? _currentKind;
    final qq = q.trim().toLowerCase();
    if (qq.isEmpty) return List.unmodifiable(_states[k]!.items);
    return _states[k]!.items
        .where(
          (e) =>
              e.productName.toLowerCase().contains(qq) ||
              e.productSku.toLowerCase().contains(qq),
        )
        .toList(growable: false);
  }

  /// Ekspor CSV (hanya summary & detail untuk kind aktif)
  String toCsv({
    ReportKind? forKind,
    bool includeHeader = true,
    String delimiter = ',',
  }) {
    final k = forKind ?? _currentKind;
    final s = _states[k]!.summary;
    final r = _states[k]!.range;
    final items = _states[k]!.items;

    final b = StringBuffer();

    if (includeHeader) {
      b.writeln(
        [
          'kind',
          'period',
          'start_date',
          'end_date',
          'summary_total_qty',
          'summary_total_revenue',
          'summary_total_revenue_formatted',
        ].join(delimiter),
      );
    }

    b.writeln(
      [
        k.pathSegment,
        _states[k]!.period.query,
        r?.startDate?.toIso8601String() ?? '',
        r?.endDate?.toIso8601String() ?? '',
        s?.totalQty ?? 0,
        s?.totalRevenue ?? 0,
        s?.totalRevenueFormatted ?? '',
      ].join(delimiter),
    );

    b.writeln();
    b.writeln(
      [
        'product_sku',
        'product_name',
        'total_qty',
        'total_revenue',
        'revenue_formatted',
      ].join(delimiter),
    );

    for (final it in items) {
      b.writeln(
        [
          it.productSku,
          _escapeCsv(it.productName, delimiter),
          it.totalQty,
          it.totalRevenue,
          it.revenueFormatted ?? '',
        ].join(delimiter),
      );
    }
    return b.toString();
  }

  /// Debug JSON ringkas (per-kind)
  String toCompactJson({ReportKind? forKind}) {
    final k = forKind ?? _currentKind;
    final state = _states[k]!;
    final map = {
      'kind': k.pathSegment,
      'period': state.period.query,
      'start_date': state.range?.startDate?.toIso8601String(),
      'end_date': state.range?.endDate?.toIso8601String(),
      'summary': state.summary?.toJson(),
      'data': state.items.map((e) => e.toJson()).toList(),
    };
    return jsonEncode(map);
  }

  String _escapeCsv(String v, String delimiter) {
    final needQuote =
        v.contains(delimiter) || v.contains('"') || v.contains('\n');
    if (!needQuote) return v;
    final escaped = v.replaceAll('"', '""');
    return '"$escaped"';
  }
}
