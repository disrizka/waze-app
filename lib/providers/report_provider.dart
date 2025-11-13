// lib/providers/report_provider.dart
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:wa_blast/services/api_service.dart';

/// ===============================
/// ENUM & EXTENSIONS
/// ===============================

enum ReportDomain { sales, purchase }

enum ReportTarget { customer, product, category, brand, period }

extension ReportTargetLabelX on ReportTarget {
  String get label {
    switch (this) {
      case ReportTarget.customer:
        return 'Customer';
      case ReportTarget.product:
        return 'Product';
      case ReportTarget.category:
        return 'Category';
      case ReportTarget.brand:
        return 'Brand';
      case ReportTarget.period:
        return 'Period';
    }
  }
}

enum ReportPeriod { day, week, month, year }

extension ReportPeriodQueryX on ReportPeriod {
  String get query {
    switch (this) {
      case ReportPeriod.day:
        return 'daily';
      case ReportPeriod.week:
        return 'week';
      case ReportPeriod.month:
        return 'month';
      case ReportPeriod.year:
        return 'year';
    }
  }
}

/// ===============================
/// DATA MODELS
/// ===============================

@immutable
class EntityReportItem {
  final String label; // nama: customer/supplier/brand/category/product
  final String? sku; // product_sku (opsional)
  final String? phone; // phone (opsional)
  final int totalTransactions;
  final int totalQty;
  final num totalRevenue; // purchase: total_cost (dinormalisasi)
  final String? revenueFormatted;
  final num? avgTransaction; // avg_price / avg_transaction (dinormalisasi)
  final String? avgTransactionFormatted;

  const EntityReportItem({
    required this.label,
    this.sku,
    this.phone,
    required this.totalTransactions,
    required this.totalQty,
    required this.totalRevenue,
    this.revenueFormatted,
    this.avgTransaction,
    this.avgTransactionFormatted,
  });

  EntityReportItem copyWith({
    String? label,
    String? sku,
    String? phone,
    int? totalTransactions,
    int? totalQty,
    num? totalRevenue,
    String? revenueFormatted,
    num? avgTransaction,
    String? avgTransactionFormatted,
  }) {
    return EntityReportItem(
      label: label ?? this.label,
      sku: sku ?? this.sku,
      phone: phone ?? this.phone,
      totalTransactions: totalTransactions ?? this.totalTransactions,
      totalQty: totalQty ?? this.totalQty,
      totalRevenue: totalRevenue ?? this.totalRevenue,
      revenueFormatted: revenueFormatted ?? this.revenueFormatted,
      avgTransaction: avgTransaction ?? this.avgTransaction,
      avgTransactionFormatted:
          avgTransactionFormatted ?? this.avgTransactionFormatted,
    );
  }
}

@immutable
class PeriodSeriesItem {
  final String period; // contoh "2025-08-01" / "2025-11" / "2025-W46"
  final int totalTransactions;
  final int totalQty;
  final num totalRevenue; // purchase: total_cost (dinormalisasi)
  final String? revenueFormatted;

  const PeriodSeriesItem({
    required this.period,
    required this.totalTransactions,
    required this.totalQty,
    required this.totalRevenue,
    this.revenueFormatted,
  });
}

@immutable
class ReportSummary {
  final int? totalTransactions; // opsional
  final int? totalQty; // opsional
  final num? totalRevenue; // purchase: total_cost
  final String? totalRevenueFormatted;

  // optional counts
  final int? totalProducts;
  final int? totalCategories;
  final int? totalBrands;
  final int? totalSuppliers;
  final int? totalCustomers;

  const ReportSummary({
    this.totalTransactions,
    this.totalQty,
    this.totalRevenue,
    this.totalRevenueFormatted,
    this.totalProducts,
    this.totalCategories,
    this.totalBrands,
    this.totalSuppliers,
    this.totalCustomers,
  });
}

@immutable
class ReportRange {
  final DateTime? startDate;
  final DateTime? endDate;
  const ReportRange({this.startDate, this.endDate});
}

/// ===============================
/// PROVIDER
/// ===============================
class ReportProviderV2 with ChangeNotifier {
  bool _loading = false;
  bool get isLoading => _loading;

  // hasil untuk UI: campuran EntityReportItem / PeriodSeriesItem
  List<dynamic> _items = const [];
  List<dynamic> get items => _items;

  ReportSummary? _summary;
  ReportSummary? get summary => _summary;

  ReportRange? _range;
  ReportRange? get range => _range;

  late ReportPeriod _period; // period terakhir yang DI-REQUEST
  ReportPeriod get period => _period;

  String? _activeBizId;

  Future<void> _ensureActiveBizId() async {
    if (_activeBizId != null && _activeBizId!.isNotEmpty) return;
    final prefs = await SharedPreferences.getInstance();
    _activeBizId = (prefs.getString('activeBizId') ?? '').trim();
  }

  // Panggil ini setelah user ganti business (opsional, biar instant sinkron)
  Future<void> refreshActiveBizId() async {
    final prefs = await SharedPreferences.getInstance();
    _activeBizId = (prefs.getString('activeBizId') ?? '').trim();
  }

  /// Helper supaya di UI bisa `ReportProviderV2.of(context)`
  static ReportProviderV2 of(BuildContext context, {bool listen = false}) =>
      Provider.of<ReportProviderV2>(context, listen: listen);

  // =========================
  // Public API
  // =========================

  Future<void> fetchSales(
    BuildContext context, {
    required ReportTarget target,
    required ReportPeriod period,
    bool force = false,
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    await _ensureActiveBizId();
    _period = period;
    final path = _endpointFor(ReportDomain.sales, target);
    final query = _buildQuery(period, startDate, endDate);
    await _runFetch(context, path, query, ReportDomain.sales, target);
  }

  Future<void> fetchPurchase(
    BuildContext context, {
    required ReportTarget target,
    required ReportPeriod period,
    bool force = false,
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    _period = period;
    final path = _endpointFor(ReportDomain.purchase, target);
    final query = _buildQuery(period, startDate, endDate);
    await _runFetch(context, path, query, ReportDomain.purchase, target);
  }

  Future<void> fetchByPeriod(
    BuildContext context, {
    required ReportDomain domain,
    required ReportPeriod period,
    required DateTime startDate,
    required DateTime endDate,
    bool force = false,
  }) async {
    _period = period;
    final path = _endpointFor(domain, ReportTarget.period);
    final query = _buildQuery(period, startDate, endDate);
    await _runFetch(context, path, query, domain, ReportTarget.period);
  }

  // =========================
  // Fetch & Mapping (PAKAI ApiService.get)
  // =========================

  Future<void> _runFetch(
    BuildContext context,
    String path,
    Map<String, String> query,
    ReportDomain domain,
    ReportTarget target,
  ) async {
    _setLoading(true);
    try {
      // susun endpoint + query string manual
      final uri = _appendQuery(path, query);

      final res = await ApiService.get(context, uri, withAccessToken: true);
      final raw = res.body;

      if (kDebugMode) {
        debugPrint('[ReportProviderV2] GET $uri ◀︎ ${res.statusCode}');
        debugPrint(raw.length > 800 ? '${raw.substring(0, 800)}…' : raw);
      }

      Map<String, dynamic> map = {};
      try {
        final decoded = json.decode(raw);
        if (decoded is Map<String, dynamic>) {
          map = decoded;
        } else {
          // backend kirim list mentah? bungkus agar aman
          map = {'data': decoded};
        }
      } catch (e) {
        // kalau body bukan JSON valid, anggap kosong
        map = {};
      }

      // range (opsional)
      _range = ReportRange(
        startDate: _parseDate(asStr(map['start_date'])),
        endDate: _parseDate(asStr(map['end_date'])),
      );

      // summary (opsional)
      _summary = _parseSummary(map['summary'], domain);

      // data utama
      final List dataList = (map['data'] is List)
          ? (map['data'] as List)
          : const [];

      if (target == ReportTarget.period) {
        _items = dataList
            .map((e) => _toPeriodItem(e, domain))
            .whereType<PeriodSeriesItem>()
            .toList(growable: false);
      } else {
        _items = dataList
            .map((e) => _toEntityItem(e, domain, target))
            .whereType<EntityReportItem>()
            .toList(growable: false);
      }
    } catch (e, st) {
      if (kDebugMode) {
        debugPrint('ReportProviderV2 fetch error: $e\n$st');
      }
      // fallback supaya UI aman
      _items = const [];
      _summary = const ReportSummary(
        totalTransactions: 0,
        totalQty: 0,
        totalRevenue: 0,
        totalRevenueFormatted: 'Rp 0',
      );
    } finally {
      _setLoading(false);
    }
  }

  // =========================
  // Endpoint resolver (ubah sesuai backend-mu)
  // =========================
  String _endpointFor(ReportDomain domain, ReportTarget target) {
    // prefix wajib: /waveup/{idBusiness}
    final bizId = (_activeBizId ?? '').trim();
    final prefix = '/waveup/${bizId.isNotEmpty ? bizId : '-'}';

    // base lama tetap dipakai setelah prefix
    final base = domain == ReportDomain.sales
        ? '$prefix/report/sales'
        : '$prefix/report/purchase';

    switch (target) {
      case ReportTarget.category:
        return '$base/category';
      case ReportTarget.brand:
        return '$base/brand';
      case ReportTarget.product:
        return '$base/product';
      case ReportTarget.customer:
        return domain == ReportDomain.sales
            ? '$base/customer'
            : '$base/supplier';
      case ReportTarget.period:
        return '$base/period';
    }
  }

  String _appendQuery(String endpoint, Map<String, String> q) {
    if (q.isEmpty) return endpoint;
    final buf = StringBuffer(endpoint);
    buf.write(endpoint.contains('?') ? '&' : '?');
    bool first = true;
    q.forEach((k, v) {
      if (!first) buf.write('&');
      first = false;
      buf.write(Uri.encodeQueryComponent(k));
      buf.write('=');
      buf.write(Uri.encodeQueryComponent(v));
    });
    return buf.toString();
  }

  Map<String, String> _buildQuery(
    ReportPeriod period,
    DateTime? sd,
    DateTime? ed,
  ) {
    final q = <String, String>{'period': period.query};
    if (sd != null) q['start_date'] = _fmtDate(sd);
    if (ed != null) q['end_date'] = _fmtDate(ed);
    return q;
  }

  // =========================
  // Mapping helpers
  // =========================

  EntityReportItem? _toEntityItem(
    dynamic raw,
    ReportDomain domain,
    ReportTarget target,
  ) {
    if (raw is! Map) return null;
    final m = raw as Map;

    String label = '';
    String? sku;
    String? phone;
    int totalTx = 0;
    final int totalQty = asInt(m['total_qty']);
    num totalRev = 0;
    String? revFmt;
    num? avgTx;
    String? avgTxFmt;

    switch (target) {
      case ReportTarget.category:
        // contoh response: category_name, total_qty, total_revenue, revenue_formatted
        label = asStr(m['category_name']) ?? 'Unknown Category';
        totalRev = _pickRevenueOrCost(m, domain);
        revFmt = _pickRevenueFmtOrCostFmt(m, domain);
        totalTx = asInt(m['total_transactions']); // mungkin tidak ada
        break;

      case ReportTarget.brand:
        label = asStr(m['brand_name']) ?? 'Unknown Brand';
        totalRev = _pickRevenueOrCost(m, domain);
        revFmt = _pickRevenueFmtOrCostFmt(m, domain);
        totalTx = asInt(m['total_transactions']);
        break;

      case ReportTarget.product:
        label = asStr(m['product_name']) ?? 'Unknown Product';
        sku = _emptyToNull(asStr(m['product_sku']));
        totalRev = _pickRevenueOrCost(m, domain);
        revFmt = _pickRevenueFmtOrCostFmt(m, domain);
        totalTx = asInt(
          m['total_transactions'],
        ); // sering tidak ada di list product
        avgTx = _pickAvg(m);
        avgTxFmt =
            asStr(m['avg_price_formatted']) ??
            asStr(m['avg_transaction_formatted']);
        break;

      case ReportTarget.customer:
        // sales: customer; purchase: supplier
        label =
            asStr(m['customer_name']) ??
            asStr(m['supplier_name']) ??
            asStr(m['name']) ??
            asStr(m['label']) ??
            'Unknown';
        phone = _emptyToNull(
          asStr(m['customer_phone']) ??
              asStr(m['supplier_phone']) ??
              asStr(m['phone']),
        );
        totalRev = _pickRevenueOrCost(m, domain);
        revFmt = _pickRevenueFmtOrCostFmt(m, domain);
        totalTx = asInt(m['total_transactions']);
        avgTx = _pickAvg(m);
        avgTxFmt = asStr(m['avg_transaction_formatted']);
        break;

      case ReportTarget.period:
        // tidak dipakai di entity mapper
        break;
    }

    return EntityReportItem(
      label: label,
      sku: sku,
      phone: phone,
      totalTransactions: totalTx,
      totalQty: totalQty,
      totalRevenue: totalRev,
      revenueFormatted: revFmt,
      avgTransaction: avgTx,
      avgTransactionFormatted: avgTxFmt,
    );
  }

  PeriodSeriesItem? _toPeriodItem(dynamic raw, ReportDomain domain) {
    if (raw is! Map) return null;
    final m = raw as Map;

    return PeriodSeriesItem(
      period: asStr(m['period']) ?? '',
      totalTransactions: asInt(m['total_transactions']),
      totalQty: asInt(m['total_qty']),
      totalRevenue: _pickRevenueOrCost(m, domain),
      revenueFormatted: _pickRevenueFmtOrCostFmt(m, domain),
    );
  }

  ReportSummary? _parseSummary(dynamic raw, ReportDomain domain) {
    if (raw is! Map) return null;
    final m = raw as Map;

    final totalRevenue = _pickSummaryRevenueOrCost(m, domain);
    final totalRevenueFormatted = _pickSummaryRevenueFmtOrCostFmt(m, domain);

    return ReportSummary(
      totalTransactions: asInt(m['total_transactions']),
      totalQty: asInt(m['total_qty']),
      totalRevenue: totalRevenue,
      totalRevenueFormatted: totalRevenueFormatted,
      totalProducts: asInt(m['total_products']),
      totalBrands: asInt(m['total_brands']),
      totalCategories: asInt(m['total_categories']),
      totalSuppliers: asInt(m['total_suppliers']),
      totalCustomers: asInt(m['total_customers']),
    );
  }

  // =========================
  // Utils
  // =========================
  void _setLoading(bool v) {
    if (_loading == v) return;
    _loading = v;
    notifyListeners();
  }

  static String _fmtDate(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  static DateTime? _parseDate(String? s) {
    if (s == null || s.trim().isEmpty) return null;
    try {
      return DateTime.parse(s);
    } catch (_) {
      return null;
    }
  }

  // ---- pickers untuk revenue/cost + formatted ----
  static num _pickRevenueOrCost(Map m, ReportDomain domain) {
    if (domain == ReportDomain.purchase) {
      // prioritaskan cost, fallback revenue
      return asNum(m['total_cost'], fallback: asNum(m['total_revenue']));
    }
    return asNum(m['total_revenue'], fallback: asNum(m['total_cost']));
  }

  static String? _pickRevenueFmtOrCostFmt(Map m, ReportDomain domain) {
    if (domain == ReportDomain.purchase) {
      return asStr(m['cost_formatted']) ??
          asStr(m['total_cost_formatted']) ??
          asStr(m['revenue_formatted']);
    }
    return asStr(m['revenue_formatted']) ??
        asStr(m['total_revenue_formatted']) ??
        asStr(m['cost_formatted']);
  }

  static num? _pickAvg(Map m) {
    if (m['avg_price'] != null) return asNum(m['avg_price']);
    if (m['avg_transaction'] != null) return asNum(m['avg_transaction']);
    return null;
  }

  static num? _pickSummaryRevenueOrCost(Map m, ReportDomain domain) {
    if (domain == ReportDomain.purchase) {
      return (m['total_cost'] != null)
          ? asNum(m['total_cost'])
          : asNum(m['total_revenue']);
    }
    return (m['total_revenue'] != null)
        ? asNum(m['total_revenue'])
        : asNum(m['total_cost']);
  }

  static String? _pickSummaryRevenueFmtOrCostFmt(Map m, ReportDomain domain) {
    if (domain == ReportDomain.purchase) {
      return asStr(m['total_cost_formatted']) ??
          asStr(m['total_revenue_formatted']);
    }
    return asStr(m['total_revenue_formatted']) ??
        asStr(m['total_cost_formatted']);
  }
}

/// ===============================
/// SAFE CAST HELPERS
/// ===============================

int asInt(dynamic v, {int fallback = 0}) {
  if (v == null) return fallback;
  if (v is int) return v;
  if (v is num) return v.toInt();
  if (v is String) {
    final s = v.trim();
    if (s.isEmpty) return fallback;
    final n = num.tryParse(s);
    if (n == null) return fallback;
    return n.toInt();
  }
  return fallback;
}

num asNum(dynamic v, {num fallback = 0}) {
  if (v == null) return fallback;
  if (v is num) return v;
  if (v is String) {
    final s = v.trim();
    if (s.isEmpty) return fallback;
    final n = num.tryParse(s);
    return n ?? fallback;
  }
  return fallback;
}

String? asStr(dynamic v) {
  if (v == null) return null;
  if (v is String) return v;
  return v.toString();
}

String? _emptyToNull(String? s) {
  if (s == null) return null;
  return s.trim().isEmpty ? null : s;
}
