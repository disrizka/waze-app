import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:wa_blast/services/api_service.dart';

typedef FromJson<T> = T Function(Map<String, dynamic>);

@immutable
class PageMeta {
  final int currentPage;
  final int rowPerPage;
  final int totalPages;
  final int totalRows;

  const PageMeta({
    required this.currentPage,
    required this.rowPerPage,
    required this.totalPages,
    required this.totalRows,
  });

  factory PageMeta.fromJson(Map<String, dynamic> j) => PageMeta(
    currentPage: _asInt(j['current_page']),
    rowPerPage: _asInt(j['row_per_page']),
    totalPages: _asInt(j['total_pages']),
    totalRows: _asInt(j['total_rows']),
  );
}

@immutable
class PagedResult<T> {
  final List<T> items;
  final PageMeta? page;

  const PagedResult({required this.items, required this.page});
}

/// ===== Utils kecil untuk parsing aman =====
int _asInt(dynamic v, [int def = 0]) {
  if (v is num) return v.toInt();
  if (v is String) return int.tryParse(v) ?? def;
  return def;
}

String _asStr(dynamic v, [String def = '']) => v?.toString() ?? def;

/// ===== Cache businessId biar enggak get prefs berulang =====
class BizIdCache {
  /// Selalu baca dari SharedPreferences (tidak pakai cache sama sekali)
  static Future<String?> get() async {
    final prefs = await SharedPreferences.getInstance();
    final id = prefs.getString('activeBizId');
    if (kDebugMode) debugPrint('[BizIdCache] get() -> $id');
    return id;
  }

  /// Set & persist bizId (dipakai saat login atau switch business)
  static Future<void> set(String? id) async {
    final prefs = await SharedPreferences.getInstance();
    if (id == null || id.isEmpty) {
      await prefs.remove('activeBizId');
    } else {
      await prefs.setString('activeBizId', id);
    }
    if (kDebugMode) debugPrint('[BizIdCache] set($id)');
  }

  /// Reset data di prefs (opsional)
  static Future<void> clear() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('activeBizId');
    if (kDebugMode) debugPrint('[BizIdCache] clear()');
  }
}

// ==== Tambahan util kecil untuk build query string aman ====
String _buildQueryString(
  Map<String, dynamic?> filters, {
  int? page,
  int? limit,
}) {
  final qp = <String, String>{};

  if (page != null) qp['page'] = page.toString();
  // default limit = 40
  qp['limit'] = (limit ?? 40).toString();

  filters.forEach((k, v) {
    if (v == null) return;
    if (v is String) {
      // ijinkan string kosong (mis. search=)
      qp[k] = v;
    } else {
      qp[k] = v.toString();
    }
  });

  final query = Uri(
    queryParameters: qp,
  ).query; // otomatis encode & pertahankan empty value (k=)
  return query.isEmpty ? '' : '?$query';
}

/// Opsional: ganti placeholder {{idBusiness}} pakai prefs (BizIdCache)
Future<String?> _inflateBizPath(String template) async {
  if (!template.contains('{{idBusiness}}')) return template;
  final id = await BizIdCache.get();
  if (id == null || id.isEmpty) return null;
  return template.replaceAll('{{idBusiness}}', id);
}

/// ===== API JSON wrapper tipis (selalu balikin Map) =====
class ApiJson {
  static Future<Map<String, dynamic>?> getMap(
    BuildContext context,
    String path, {
    bool withAccessToken = true,
  }) async {
    try {
      final res = await ApiService.get(
        context,
        path,
        withAccessToken: withAccessToken,
      );
      if (res == null || res.body.isEmpty) return null;
      final decoded = json.decode(res.body);
      return (decoded is Map<String, dynamic>) ? decoded : null;
    } catch (e) {
      debugPrint('[ApiJson.getMap] $path -> $e');
      return null;
    }
  }

  static Future<Map<String, dynamic>?> postMap(
    BuildContext context,
    String path,
    Map<String, dynamic> payload, {
    bool withAccessToken = true,
  }) async {
    try {
      final res = await ApiService.post(
        context,
        path,
        payload,
        withAccessToken: withAccessToken,
      );
      if (res == null || res.body.isEmpty) return null;
      final decoded = json.decode(res.body);
      return (decoded is Map<String, dynamic>) ? decoded : null;
    } catch (e) {
      debugPrint('[ApiJson.postMap] $path -> $e');
      return null;
    }
  }
}

/// ===== Helper serbaguna untuk fetch list paginated =====
/// Asumsi respons: { status, data: [], page? }
class FetchHelper {
  static Future<PagedResult<T>?> fetchList<T>({
    required BuildContext context,
    required String path,
    required FromJson<T> parser,
    String dataKey = 'data', // kalau backend beda key-nya tinggal ganti
  }) async {
    final j = await ApiJson.getMap(context, path);
    if (j == null) return null;
    final status = _asInt(j['status'], -1);
    if (status != 200) return null;

    final raw = j[dataKey];
    final items = (raw is List)
        ? raw
              .whereType<Map<String, dynamic>>()
              .map(parser)
              .toList(growable: false)
        : List<T>.empty(growable: false);

    final page = (j['page'] is Map<String, dynamic>)
        ? PageMeta.fromJson(j['page'] as Map<String, dynamic>)
        : null;

    return PagedResult<T>(items: items, page: page);
  }

  static Future<T?> fetchOne<T>({
    required BuildContext context,
    required String path,
    required FromJson<T> parser,
    String dataKey = 'data',
  }) async {
    final j = await ApiJson.getMap(context, path);
    if (j == null) return null;
    final status = _asInt(j['status'], -1);
    if (status != 200) return null;

    final raw = j[dataKey];
    if (raw is Map<String, dynamic>) {
      return parser(raw);
    }
    // fallback: kalau backend mengirim array berisi 1 item
    if (raw is List && raw.isNotEmpty && raw.first is Map<String, dynamic>) {
      return parser(raw.first as Map<String, dynamic>);
    }
    return null;
  }

  static Future<PagedResult<T>?> fetchListByFilter<T>({
    required BuildContext context,

    /// Contoh: "/waveup/{{idBusiness}}/product"
    required String basePath,
    required FromJson<T> parser,
    Map<String, dynamic?> filters =
        const {}, // contoh: { 'search': '', 'storelocationid': 'abc' }
    int page = 1,
    int limit = 40,
    String dataKey = 'data',
    bool injectBizId =
        true, // set false kalau tidak pakai placeholder {{idBusiness}}
  }) async {
    // inflate path bila ada placeholder {{idBusiness}}
    String? path = injectBizId ? await _inflateBizPath(basePath) : basePath;
    if (path == null) {
      debugPrint(
        '[FetchHelper.fetchListByFilter] idBusiness kosong → path gagal di-inflate',
      );
      return null;
    }

    // rakit query string: page, limit (default 40), dan filters bebas
    final qs = _buildQueryString(filters, page: page, limit: limit);
    final fullPath = '$path$qs';

    // delegasikan ke fetchList yang sudah ada
    return fetchList<T>(
      context: context,
      path: fullPath,
      parser: parser,
      dataKey: dataKey,
    );
  }
}
