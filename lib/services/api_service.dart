import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:provider/provider.dart';
import 'package:wa_blast/env.dart';
import '../constants/api_constant.dart';
import '../providers/auth_provider.dart';

class ApiService {
  static Future<Map<String, String>> _buildHeaders({
    bool withAccessToken = false,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final accessToken = prefs.getString('accessToken') ?? '';

    return {
      'Content-Type': 'application/json',
      'Authorization': ApiConstant.basicAuth,
      if (withAccessToken) 'Access-Token': 'Bearer $accessToken',
    };
  }

  // ApiService (tambahkan import provider sudah ada)

  // Di dalam class ApiService
  static Future<http.Response> _withAutoRefresh(
    BuildContext context, {
    required bool withAccessToken,
    required Future<http.Response> Function(Map<String, String> headers)
    requestFn,
  }) async {
    // 1) Request awal pakai header saat ini
    Map<String, String> headers = await _buildHeaders(
      withAccessToken: withAccessToken,
    );
    http.Response res = await requestFn(headers);

    // Jika bukan 401, langsung kembalikan
    if (res.statusCode != 401) return res;

    debugPrint('[ApiService] 401 detected → try /user/refresh-token');

    // 2) Coba refresh token
    try {
      final refreshRes = await refreshAccessToken();
      final raw = refreshRes.body;
      debugPrint(
        "[ApiService] REFRESH ◀︎ ${refreshRes.statusCode} ${raw.length > 400 ? raw.substring(0, 400) + '…' : raw}",
      );

      Map<String, dynamic>? j;
      try {
        j = jsonDecode(raw) as Map<String, dynamic>;
      } catch (_) {
        j = null;
      }

      // === RULE KHUSUS: kalau backend balas { e: "e2", status: 401 } → langsung logout & /splash
      final backendStatus = (j?['status'] as num?)?.toInt();
      final backendError = (j?['e'] ?? '').toString();
      final refreshDenied =
          refreshRes.statusCode == 401 ||
          backendStatus == 401 ||
          backendError == 'e2';

      if (refreshDenied) {
        debugPrint('[ApiService] Refresh denied (e2/401) → logout');
        try {
          await Provider.of<AuthProvider>(
            context,
            listen: false,
          ).logout(context);
        } catch (_) {}
        return res; // kembalikan response awal (401) agar caller aware
      }

      // === Jika refresh sukses (2xx) dan ada access_token baru → simpan & retry sekali
      if (refreshRes.statusCode >= 200 && refreshRes.statusCode < 300) {
        final newAccess = (j?['access_token'] ?? '').toString();

        // 200 tapi token kosong → anggap gagal, logout
        if (newAccess.isEmpty) {
          debugPrint('[ApiService] Refresh returned empty token → logout');
          try {
            await Provider.of<AuthProvider>(
              context,
              listen: false,
            ).logout(context);
          } catch (_) {}
          return res;
        }

        // Simpan & sinkron ke AuthProvider
        try {
          final prefs = await SharedPreferences.getInstance();
          await prefs.setString('accessToken', newAccess);
        } catch (_) {}
        try {
          final auth = Provider.of<AuthProvider>(context, listen: false);
          await auth.updateAccessToken(newAccess);
        } catch (e) {
          debugPrint('[ApiService] updateAccessToken via provider failed: $e');
        }

        // Retry sekali dengan header baru
        headers = await _buildHeaders(withAccessToken: withAccessToken);
        final retryRes = await requestFn(headers);

        // Kalau retry berhasil (bukan 401), kembalikan hasil retry
        if (retryRes.statusCode != 401) return retryRes;

        // Retry tetap 401 → logout
        debugPrint('[ApiService] Retry still 401 → logout');
        try {
          await Provider.of<AuthProvider>(
            context,
            listen: false,
          ).logout(context);
        } catch (_) {}
        return res;
      }
    } catch (e, st) {
      debugPrint('[ApiService] refresh-token failed: $e\n$st');
      // fallthrough ke logout di bawah
    }

    // 3) Default: refresh gagal → logout
    try {
      await Provider.of<AuthProvider>(context, listen: false).logout(context);
    } catch (_) {}
    return res;
  }

  // === Modifikasi wrapper HTTP ===

  static Future<http.Response> get(
    BuildContext context,
    String endpoint, {
    bool withAccessToken = true,
  }) async {
    final base = ApiConstant.baseUrl; // akan fail fast kalau Env belum set
    final url = Uri.parse('$base$endpoint');
    debugPrint('[API] GET $url (flavor=${Env.flavor.name})');
    return _withAutoRefresh(
      context,
      withAccessToken: withAccessToken,
      requestFn: (headers) => http.get(url, headers: headers),
    );
  }

  static Future<http.Response> post(
    BuildContext context,
    String endpoint,
    Map<String, dynamic> body, {
    bool withAccessToken = true,
  }) async {
    final base = ApiConstant.baseUrl; // akan fail fast kalau Env belum set
    final url = Uri.parse('$base$endpoint');
    debugPrint('[API] GET $url (flavor=${Env.flavor.name})');
    return _withAutoRefresh(
      context,
      withAccessToken: withAccessToken,
      requestFn: (headers) =>
          http.post(url, headers: headers, body: jsonEncode(body)),
    );
  }

  static Future<http.Response> put(
    BuildContext context,
    String endpoint,
    Map<String, dynamic> body, {
    bool withAccessToken = true,
  }) async {
    final base = ApiConstant.baseUrl; // akan fail fast kalau Env belum set
    final url = Uri.parse('$base$endpoint');
    debugPrint('[API] GET $url (flavor=${Env.flavor.name})');
    return _withAutoRefresh(
      context,
      withAccessToken: withAccessToken,
      requestFn: (headers) =>
          http.put(url, headers: headers, body: jsonEncode(body)),
    );
  }

  static Future<http.Response> delete(
    BuildContext context,
    String endpoint, {
    bool withAccessToken = true,
  }) async {
    final base = ApiConstant.baseUrl; // akan fail fast kalau Env belum set
    final url = Uri.parse('$base$endpoint');
    debugPrint('[API] GET $url (flavor=${Env.flavor.name})');
    return _withAutoRefresh(
      context,
      withAccessToken: withAccessToken,
      requestFn: (headers) => http.delete(url, headers: headers),
    );
  }

  static Future<void> _handleUnauthorized(
    BuildContext context,
    http.Response response,
  ) async {
    if (response.statusCode == 401) {
      debugPrint("Unauthorized detected. Logging out...");
      await Provider.of<AuthProvider>(context, listen: false).logout(context);
    }
  }

  //auth
  static Future<http.Response> login(
    String endpoint,
    Map<String, dynamic> body, {
    Duration timeout = const Duration(seconds: 30),
  }) async {
    final headers = {
      'Content-Type': 'application/json',
      'Authorization': ApiConstant.basicAuth,
    };

    final url = Uri.parse('${ApiConstant.baseUrl}$endpoint');
    debugPrint("LOGIN ◀︎ URL: $url");

    final response = await http
        .post(url, headers: headers, body: jsonEncode(body))
        .timeout(timeout);

    return response;
  }

  static Future<Map<String, String>> _buildHeadersForMultipart({
    bool withAccessToken = false,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final accessToken = prefs.getString('accessToken') ?? '';
    return {
      'Authorization': ApiConstant.basicAuth,
      if (withAccessToken) 'Access-Token': 'Bearer $accessToken',
    };
  }

  /// POST JSON tanpa `BuildContext` (tidak auto-logout saat 401).
  /// Cocok untuk endpoint public seperti /waveup/user/register.
  static Future<http.Response> postJson(
    String endpoint,
    Map<String, dynamic> body, {
    bool withAccessToken = false,
    Duration timeout = const Duration(seconds: 30),
  }) async {
    final headers = await _buildHeaders(withAccessToken: withAccessToken);
    final url = Uri.parse('${ApiConstant.baseUrl}$endpoint');

    return http
        .post(url, headers: headers, body: jsonEncode(body))
        .timeout(timeout);
  }

  static Future<http.Response> postMultipart(
    String endpoint, {
    required Map<String, String> fields,
    Map<String, String>? files,
    bool withAccessToken = false,
    Duration timeout = const Duration(seconds: 60),
  }) async {
    final url = Uri.parse('${ApiConstant.baseUrl}$endpoint');
    final headers = await _buildHeadersForMultipart(
      withAccessToken: withAccessToken,
    );

    final req = http.MultipartRequest('POST', url)..fields.addAll(fields);
    req.headers.addAll(headers);

    if (files != null && files.isNotEmpty) {
      for (final entry in files.entries) {
        req.files.add(
          await http.MultipartFile.fromPath(entry.key, entry.value),
        );
      }
    }

    final streamed = await req.send().timeout(timeout);
    return http.Response.fromStream(streamed);
  }

  static Future<Map<String, String>> _buildHeadersForRefresh() async {
    final prefs = await SharedPreferences.getInstance();
    final refreshToken = prefs.getString('refreshToken') ?? '';
    return {
      'Content-Type': 'application/json',
      'Authorization': ApiConstant.basicAuth,
      'Refresh-Token': refreshToken,
    };
  }

  static Future<http.Response> refreshAccessToken({
    Duration timeout = const Duration(seconds: 30),
  }) async {
    final headers = await _buildHeadersForRefresh();
    final url = Uri.parse('${ApiConstant.baseUrl}/user/refresh-token');
    return http.get(url, headers: headers).timeout(timeout);
  }

  static Future<Map<String, dynamic>?> uploadFile(
    String filePath, {
    String fieldName = 'file',
    Duration timeout = const Duration(seconds: 60),
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final accessToken = prefs.getString('accessToken') ?? '';

    final url = Uri.parse('${ApiConstant.baseUrl}/file/upload');

    final headers = <String, String>{
      'Authorization': ApiConstant.basicAuth,
      'Access-Token': 'Bearer $accessToken',
    };

    final req = http.MultipartRequest('POST', url)
      ..headers.addAll(headers)
      ..files.add(await http.MultipartFile.fromPath(fieldName, filePath));

    final streamed = await req.send().timeout(timeout);
    final res = await http.Response.fromStream(streamed);

    if (res.statusCode >= 200 && res.statusCode < 300) {
      try {
        final body = json.decode(res.body);
        if (body is Map<String, dynamic>) return body;
      } catch (e) {
        debugPrint('[ApiService.uploadFile] decode error: $e');
      }
    }

    debugPrint('[ApiService.uploadFile] failed: ${res.statusCode} ${res.body}');
    return null;
  }

  /// POST JSON langsung ke baseUrl PROD (override flavor).
  /// Tidak butuh BuildContext & tidak auto-logout saat 401 (mirip postJson).
  static Future<http.Response> postJsonProd(
    String endpoint,
    Map<String, dynamic> body, {
    bool withAccessToken = false,
    Duration timeout = const Duration(seconds: 30),
  }) async {
    final headers = await _buildHeaders(withAccessToken: withAccessToken);

    final prodBase = "https://api.wave.id/";
    final url = Uri.parse('$prodBase$endpoint');

    debugPrint('[API] POST(PROD) $url (forcd)');
    return http
        .post(url, headers: headers, body: jsonEncode(body))
        .timeout(timeout);
  }
}
