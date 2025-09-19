import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:provider/provider.dart';
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

  static Future<http.Response> get(
    BuildContext context,
    String endpoint, {
    bool withAccessToken = true,
  }) async {
    final headers = await _buildHeaders(withAccessToken: withAccessToken);
    final url = Uri.parse('${ApiConstant.baseUrl}$endpoint');
    final response = await http.get(url, headers: headers);
    await _handleUnauthorized(context, response);
    return response;
  }

  static Future<http.Response> post(
    BuildContext context,
    String endpoint,
    Map<String, dynamic> body, {
    bool withAccessToken = true,
  }) async {
    final headers = await _buildHeaders(withAccessToken: withAccessToken);
    final url = Uri.parse('${ApiConstant.baseUrl}$endpoint');
    final response = await http.post(
      url,
      headers: headers,
      body: jsonEncode(body),
    );
    await _handleUnauthorized(context, response);
    return response;
  }

  static Future<http.Response> put(
    BuildContext context,
    String endpoint,
    Map<String, dynamic> body, {
    bool withAccessToken = true,
  }) async {
    final headers = await _buildHeaders(withAccessToken: withAccessToken);
    final url = Uri.parse('${ApiConstant.baseUrl}$endpoint');
    final response = await http.put(
      url,
      headers: headers,
      body: jsonEncode(body),
    );
    await _handleUnauthorized(context, response);
    return response;
  }

  static Future<http.Response> delete(
    BuildContext context,
    String endpoint, {
    bool withAccessToken = true,
  }) async {
    final headers = await _buildHeaders(withAccessToken: withAccessToken);
    final url = Uri.parse('${ApiConstant.baseUrl}$endpoint');
    final response = await http.delete(url, headers: headers);
    await _handleUnauthorized(context, response);
    return response;
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
}
