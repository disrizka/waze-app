import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../api/api_constant.dart';

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
    String endpoint, {
    bool withAccessToken = true,
  }) async {
    final headers = await _buildHeaders(withAccessToken: withAccessToken);
    final url = Uri.parse('${ApiConstant.baseUrl}$endpoint');
    return await http.get(url, headers: headers);
  }

  static Future<http.Response> post(
    String endpoint,
    Map<String, dynamic> body, {
    bool withAccessToken = true,
  }) async {
    final headers = await _buildHeaders(withAccessToken: withAccessToken);
    final url = Uri.parse('${ApiConstant.baseUrl}$endpoint');
    return await http.post(url, headers: headers, body: jsonEncode(body));
  }

  static Future<http.Response> put(
    String endpoint,
    Map<String, dynamic> body, {
    bool withAccessToken = true,
  }) async {
    final headers = await _buildHeaders(withAccessToken: withAccessToken);
    final url = Uri.parse('${ApiConstant.baseUrl}$endpoint');
    return await http.put(url, headers: headers, body: jsonEncode(body));
  }

  static Future<http.Response> delete(
    String endpoint, {
    bool withAccessToken = true,
  }) async {
    final headers = await _buildHeaders(withAccessToken: withAccessToken);
    final url = Uri.parse('${ApiConstant.baseUrl}$endpoint');
    return await http.delete(url, headers: headers);
  }
}
