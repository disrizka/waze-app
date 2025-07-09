import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:wa_blast/constants/api_constant.dart';

class AuthProvider with ChangeNotifier {
  // Internal fields
  String? _accessToken;
  String? _refreshToken;
  String? _name;
  String? _email;
  bool _isActivated = false;
  bool _isLoading = false;
  String? _error;

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

        // Simpan ke shared preferences
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('accessToken', _accessToken!);
        await prefs.setString('refreshToken', _refreshToken!);
        await prefs.setString('name', _name!);
        await prefs.setString('email', _email!);
        await prefs.setBool('isActivated', _isActivated);

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
    final prefs = await SharedPreferences.getInstance();
    final access = prefs.getString('accessToken');
    if (access == null) return;

    _accessToken = access;
    _refreshToken = prefs.getString('refreshToken');
    _name = prefs.getString('name');
    _email = prefs.getString('email');
    _isActivated = prefs.getBool('isActivated') ?? false;

    notifyListeners();
  }

  // Logout function
  Future<void> logout(BuildContext context) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.clear();

      _accessToken = null;
      _refreshToken = null;
      _name = null;
      _email = null;
      _isActivated = false;
      _error = null;

      debugPrint("Berhasil logout");

      notifyListeners();
      Navigator.pushNamedAndRemoveUntil(context, '/splash', (route) => false);
    } catch (e) {
      debugPrint("Gagal logout: $e");
    }
  }
}
