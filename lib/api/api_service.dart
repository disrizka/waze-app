import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:provider/provider.dart';
import '../api/api_constant.dart';
import '../providers/auth_provider.dart';

class ApiService {
  static final _storage = const FlutterSecureStorage();

  static Future<Map<String, String>> _buildHeaders({
    bool withAccessToken = false,
  }) async {
    final accessToken = await _storage.read(key: 'accessToken') ?? '';
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
}
