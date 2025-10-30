// lib/providers/report_provider.dart
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'package:wa_blast/core/provider_helper.dart'; // BizIdCache (juga dipakai di StoreProvider kalian)
import 'package:wa_blast/services/api_service.dart'; // ApiJson.getMap

/// ===============================================================
/// ENUM & UTIL
/// ===============================================================
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
}

/// ===============================================================
/// MODELS
/// ===============================================================
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
      'SalesReportItem(sku: $productSku, name: $productName, qty: $totalQty, rev: $totalRevenue)';
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

  @override
  String toString() =>
      'Summary(qty: $totalQty, revenue: $totalRevenue, label: $totalRevenueFormatted)';
}

@immutable
class SalesReportRange {
  final DateTime? startDate;
  final DateTime? endDate;

  const SalesReportRange({this.startDate, this.endDate});

  factory SalesReportRange.fromJson(Map<String, dynamic> j) {
    DateTime? _parse(String? s) {
      if (s == null || s.isEmpty) return null;
      // Format sample: "2025-09-30"
      return DateTime.tryParse(s);
    }

    return SalesReportRange(
      startDate: _parse(j['start_date']?.toString()),
      endDate: _parse(j['end_date']?.toString()),
    );
  }

  @override
  String toString() => 'Range($startDate → $endDate)';
}

/// ===============================================================
/// PROVIDER
/// ===============================================================
class ReportProvider with ChangeNotifier {
  ReportProvider({SalesPeriod initialPeriod = SalesPeriod.month})
    : _period = initialPeriod;

  // ---- State
  bool _loading = false;
  String? _lastError;

  // ---- Data
  SalesPeriod _period;
  SalesReportSummary? _summary;
  SalesReportRange? _range;
  final List<SalesReportItem> _items = [];

  // ---- Getters
  bool get isLoading => _loading;
  String? get lastError => _lastError;

  SalesPeriod get period => _period;
  SalesReportSummary? get summary => _summary;
  SalesReportRange? get range => _range;
  List<SalesReportItem> get items => List.unmodifiable(_items);

  int get totalQtyComputed =>
      _items.fold<int>(0, (acc, e) => acc + (e.totalQty));
  num get totalRevenueComputed =>
      _items.fold<num>(0, (acc, e) => acc + (e.totalRevenue));

  void _setLoading(bool v, {bool notify = true}) {
    _loading = v;
    if (notify) notifyListeners();
  }

  Future<String?> _requireBizId() async {
    final bizId = await BizIdCache.get();
    if (bizId == null || bizId.isEmpty) {
      _lastError = "Business ID is not available.";
      if (kDebugMode) {
        debugPrint("[ReportProvider] ❌ Business ID null/empty");
      }
      return null;
    }
    return bizId;
  }

  /// Ganti period saja tanpa auto-fetch (untuk UI toggle cepat).
  void setPeriod(SalesPeriod p, {bool notify = true}) {
    _period = p;
    if (notify) notifyListeners();
  }

  /// Ganti period dan langsung fetch.
  Future<bool> changePeriodAndFetch(BuildContext context, SalesPeriod p) async {
    _period = p;
    notifyListeners();
    return fetchSalesReport(context);
  }

  /// ===============================================================
  /// FETCH SALES REPORT
  /// GET waveup/{{idBusiness}}/report/sales?period=daily|month|year
  /// ===============================================================
  Future<bool> fetchSalesReport(BuildContext context) async {
    final bizId = await _requireBizId();
    if (bizId == null) {
      _clearData();
      notifyListeners();
      return false;
    }

    final path = '/waveup/$bizId/report/sales?period=${_period.query}';
    if (kDebugMode) debugPrint("[ReportProvider] 🌐 GET $path");

    _setLoading(true);
    try {
      final j = await ApiJson.getMap(context, path);
      if (j == null) {
        _lastError = 'Null JSON response';
        _clearData();
        return false;
      }

      final status = (j['status'] as num?)?.toInt() ?? 0;
      if (status != 200) {
        _lastError =
            j['msg']?.toString() ??
            j['message']?.toString() ??
            'Failed to get sales report';
        _clearData();
        return false;
      }

      // period dari server (opsional override agar sinkron)
      _period = SalesPeriodX.fromString(j['period']?.toString());

      // summary
      _summary = (j['summary'] is Map<String, dynamic>)
          ? SalesReportSummary.fromJson(j['summary'] as Map<String, dynamic>)
          : const SalesReportSummary(totalQty: 0, totalRevenue: 0);

      // range
      _range = SalesReportRange.fromJson({
        'start_date': j['start_date']?.toString(),
        'end_date': j['end_date']?.toString(),
      });

      // items
      final list = <SalesReportItem>[];
      final rawData = j['data'];
      if (rawData is List) {
        for (final it in rawData) {
          if (it is Map<String, dynamic>) {
            list.add(SalesReportItem.fromJson(it));
          }
        }
      }
      _items
        ..clear()
        ..addAll(list);

      if (kDebugMode) {
        debugPrint(
          "[ReportProvider] ✅ items=${_items.length} summary=${_summary?.toString()} range=${_range?.toString()}",
        );
      }

      notifyListeners();
      return true;
    } catch (e, st) {
      _lastError = e.toString();
      if (kDebugMode) {
        debugPrint("[ReportProvider] exception: $e");
        debugPrint("$st");
      }
      _clearData();
      return false;
    } finally {
      _setLoading(false);
    }
  }

  /// ===============================================================
  /// UTIL & MISC
  /// ===============================================================
  void _clearData() {
    _summary = null;
    _range = null;
    _items.clear();
  }

  Future<void> refresh(BuildContext context) => fetchSalesReport(context);

  /// Konsumsi error terakhir (untuk snackbar sekali pakai)
  String? consumeLastError() {
    final e = _lastError;
    _lastError = null;
    return e;
  }

  /// Sort helper (opsional bruk di UI)
  void sortByRevenueDesc() {
    _items.sort((a, b) => b.totalRevenue.compareTo(a.totalRevenue));
    notifyListeners();
  }

  void sortByQtyDesc() {
    _items.sort((a, b) => b.totalQty.compareTo(a.totalQty));
    notifyListeners();
  }

  void sortByNameAsc() {
    _items.sort(
      (a, b) =>
          a.productName.toLowerCase().compareTo(b.productName.toLowerCase()),
    );
    notifyListeners();
  }

  /// Filter sederhana untuk UI (non-mutating, hasil baru)
  List<SalesReportItem> filteredByQuery(String q) {
    final qq = q.trim().toLowerCase();
    if (qq.isEmpty) return items;
    return items
        .where((e) {
          return e.productName.toLowerCase().contains(qq) ||
              e.productSku.toLowerCase().contains(qq);
        })
        .toList(growable: false);
  }

  /// Ekspor CSV (pakai di share/save kalau perlu)
  String toCsv({bool includeHeader = true, String delimiter = ','}) {
    final b = StringBuffer();
    if (includeHeader) {
      b.writeln(
        [
          'period',
          'start_date',
          'end_date',
          'summary_total_qty',
          'summary_total_revenue',
          'summary_total_revenue_formatted',
        ].join(delimiter),
      );
    }

    final s = summary;
    final r = range;

    b.writeln(
      [
        period.query,
        r?.startDate?.toIso8601String() ?? '',
        r?.endDate?.toIso8601String() ?? '',
        s?.totalQty ?? 0,
        s?.totalRevenue ?? 0,
        s?.totalRevenueFormatted ?? '',
      ].join(delimiter),
    );

    // Detail rows
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

  /// Ekspor JSON ringkas (untuk debug/telemetry)
  String toCompactJson() {
    final map = {
      'period': period.query,
      'start_date': range?.startDate?.toIso8601String(),
      'end_date': range?.endDate?.toIso8601String(),
      'summary': summary?.toJson(),
      'data': items.map((e) => e.toJson()).toList(),
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
