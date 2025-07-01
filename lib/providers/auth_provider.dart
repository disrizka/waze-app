import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:wa_blast/api/api_constant.dart';

class AuthProvider with ChangeNotifier {
  // Internal fields
  String? _accessToken;
  String? _refreshToken;
  String? _name;
  String? _email;
  bool _isActivated = false;
  bool _isLoading = false;
  String? _error;

  // Secure storage instance
  final FlutterSecureStorage _secureStorage = const FlutterSecureStorage();

  // Getters
  String? get accessToken => _accessToken;
  String? get refreshToken => _refreshToken;
  String? get name => _name;
  String? get email => _email;
  bool get isActivated => _isActivated;
  bool get isLoading => _isLoading;
  String? get error => _error;

  // Login function
  Future<bool> login(String email, String password) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    final String loginUrl = '${ApiConstant.baseUrl}/user/login';

    final headers = {
      'Content-Type': 'application/json',
      'Authorization': ApiConstant.basicAuth,
    };

    final body = jsonEncode({'email': email, 'password': password});

    try {
      final response = await http.post(
        Uri.parse(loginUrl),
        headers: headers,
        body: body,
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);

        _name = data['data']['name'];
        _email = data['data']['email'];
        _isActivated = data['data']['isActivated'];
        _accessToken = data['token']['access_token'];
        _refreshToken = data['token']['refresh_token'];

        // Simpan ke secure storage
        await _secureStorage.write(key: 'accessToken', value: _accessToken);
        await _secureStorage.write(key: 'refreshToken', value: _refreshToken);
        await _secureStorage.write(key: 'name', value: _name);
        await _secureStorage.write(key: 'email', value: _email);
        await _secureStorage.write(
          key: 'isActivated',
          value: _isActivated.toString(),
        );

        _isLoading = false;
        notifyListeners();
        return true;
      } else {
        _error = 'Login gagal: ${response.statusCode}';
      }
    } catch (e) {
      _error = 'Terjadi kesalahan: $e';
    }

    _isLoading = false;
    notifyListeners();
    return false;
  }

  // Autologin saat app dibuka
  Future<void> tryAutoLogin() async {
    final access = await _secureStorage.read(key: 'accessToken');
    if (access == null) return;

    _accessToken = access;
    _refreshToken = await _secureStorage.read(key: 'refreshToken');
    _name = await _secureStorage.read(key: 'name');
    _email = await _secureStorage.read(key: 'email');
    _isActivated = (await _secureStorage.read(key: 'isActivated')) == 'true';

    notifyListeners();
  }

  // Logout & bersihkan data
  void logout() async {
    await _secureStorage.deleteAll();

    _accessToken = null;
    _refreshToken = null;
    _name = null;
    _email = null;
    _isActivated = false;

    notifyListeners();
  }
}
