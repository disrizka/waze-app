import 'dart:io';

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:wa_blast/constants/api_constant.dart';
import 'package:device_info_plus/device_info_plus.dart';

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

  static const String kAccountsKey = 'accounts';
  static const String kActiveAccountKey = 'activeAccountEmail';
  String? get activeAccountEmail => _email;

  Future<bool> login(String email, String password) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    final String loginUrl = '${ApiConstant.baseUrl}/user/login';
    final headers = {
      'Content-Type': 'application/json',
      'Authorization': ApiConstant.basicAuth,
    };

    final prefs = await SharedPreferences.getInstance();
    final accounts = prefs.getStringList(kAccountsKey) ?? [];

    final alreadyExists = accounts.contains(email);

    if (alreadyExists) {
      _error = 'Akun ini sudah pernah login di perangkat ini.';
      _isLoading = false;
      notifyListeners();
      return false;
    }

    if (accounts.length >= 5) {
      _error = 'Maksimal 5 akun yang dapat login di perangkat ini.';
      _isLoading = false;
      notifyListeners();
      return false;
    }

    try {
      final deviceInfoPlugin = DeviceInfoPlugin();
      String deviceId = '';
      String deviceName = '';

      if (Platform.isAndroid) {
        final androidInfo = await deviceInfoPlugin.androidInfo;
        deviceId = androidInfo.id ?? 'unknown';
        deviceName = androidInfo.model ?? 'Android Device';
      } else if (Platform.isIOS) {
        final iosInfo = await deviceInfoPlugin.iosInfo;
        deviceId = iosInfo.identifierForVendor ?? 'unknown';
        deviceName = iosInfo.utsname.machine ?? 'iPhone';
      }

      final fcmToken = await FirebaseMessaging.instance.getToken();

      final body = jsonEncode({
        'email': email,
        'password': password,
        'device_id': deviceId,
        'device_name': deviceName,
        'fcm_token': fcmToken,
      });

      debugPrint('payload: $body');

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

        await prefs.setString('accessToken', _accessToken!);
        await prefs.setString('refreshToken', _refreshToken!);
        await prefs.setString('name', _name!);
        await prefs.setString('email', _email!);
        await prefs.setBool('isActivated', _isActivated);
        await prefs.setString(kActiveAccountKey, _email!);

        final accountData = {
          'accessToken': _accessToken,
          'refreshToken': _refreshToken,
          'name': _name,
          'email': _email,
          'isActivated': _isActivated,
        };
        await prefs.setString('account_${_email!}', jsonEncode(accountData));
        accounts.add(_email!);
        await prefs.setStringList(kAccountsKey, accounts);

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

  Future<bool> switchAccount(String email) async {
    final prefs = await SharedPreferences.getInstance();
    final accountJson = prefs.getString('account_$email');

    if (accountJson == null) {
      _error = 'Data akun tidak ditemukan';
      notifyListeners();
      return false;
    }

    try {
      final accountData = jsonDecode(accountJson);
      _accessToken = accountData['accessToken'];
      _refreshToken = accountData['refreshToken'];
      _name = accountData['name'];
      _email = accountData['email'];
      _isActivated = accountData['isActivated'] ?? false;

      // Set data aktif
      await prefs.setString('accessToken', _accessToken!);
      await prefs.setString('refreshToken', _refreshToken!);
      await prefs.setString('name', _name!);
      await prefs.setString('email', _email!);
      await prefs.setBool('isActivated', _isActivated);
      await prefs.setString(kActiveAccountKey, _email!);

      _error = null;
      notifyListeners();
      return true;
    } catch (e) {
      _error = 'Gagal switch akun: $e';
      notifyListeners();
      return false;
    }
  }

  // Ambil daftar akun
  Future<List<String>> getStoredAccounts() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getStringList(kAccountsKey) ?? [];
  }

  // Hapus akun tertentu dari daftar
  Future<void> removeAccount(String email) async {
    final prefs = await SharedPreferences.getInstance();
    final accounts = prefs.getStringList(kAccountsKey) ?? [];

    accounts.remove(email);
    await prefs.setStringList(kAccountsKey, accounts);
    await prefs.remove('account_$email');

    if (_email == email) {
      await logoutWithoutNavigation();
    }

    notifyListeners();
  }

  // Autologin saat app dibuka
  Future<void> tryAutoLogin() async {
    final prefs = await SharedPreferences.getInstance();
    final activeEmail = prefs.getString(kActiveAccountKey);
    if (activeEmail == null) return;

    final accountJson = prefs.getString('account_$activeEmail');
    if (accountJson == null) return;

    try {
      final accountData = jsonDecode(accountJson);

      _accessToken = accountData['accessToken'];
      _refreshToken = accountData['refreshToken'];
      _name = accountData['name'];
      _email = accountData['email'];
      _isActivated = accountData['isActivated'] ?? false;

      notifyListeners();
    } catch (e) {
      debugPrint("AutoLogin gagal parsing: $e");
    }
  }

  // Logout (tanpa pindah halaman)
  Future<void> logoutWithoutNavigation() async {
    final prefs = await SharedPreferences.getInstance();

    _accessToken = null;
    _refreshToken = null;
    _name = null;
    _email = null;
    _isActivated = false;
    _error = null;

    await prefs.remove('accessToken');
    await prefs.remove('refreshToken');
    await prefs.remove('name');
    await prefs.remove('email');
    await prefs.remove('isActivated');
    notifyListeners();
  }

  Future<void> logout(BuildContext context) async {
    try {
      final prefs = await SharedPreferences.getInstance();

      final currentEmail = _email;
      final accounts = prefs.getStringList(kAccountsKey) ?? [];

      // Hapus akun aktif dari daftar dan data JSON-nya
      accounts.remove(currentEmail);
      await prefs.setStringList(kAccountsKey, accounts);
      await prefs.remove('account_$currentEmail');

      // Clear data akun aktif
      _accessToken = null;
      _refreshToken = null;
      _name = null;
      _email = null;
      _isActivated = false;
      _error = null;

      await prefs.remove('accessToken');
      await prefs.remove('refreshToken');
      await prefs.remove('name');
      await prefs.remove('email');
      await prefs.remove('isActivated');
      await prefs.remove(kActiveAccountKey);

      notifyListeners();

      if (accounts.isNotEmpty) {
        final nextEmail = accounts.first;
        final success = await switchAccount(nextEmail);

        if (success) {
          Navigator.pushNamedAndRemoveUntil(
            context,
            '/splash',
            (route) => false,
          );
          return;
        }
      }

      Navigator.pushNamedAndRemoveUntil(context, '/splash', (route) => false);
    } catch (e) {
      debugPrint("Gagal logout: $e");
    }
  }
}
