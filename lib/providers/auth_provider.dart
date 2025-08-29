import 'dart:io';

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:wa_blast/constants/api_constant.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:wa_blast/services/api_service.dart';

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

  Future<bool> login({
    required BuildContext context,
    required String email,
    required String password,
    required String fcmToken,
    required String deviceId,
    required String deviceName,
  }) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    final os = Platform.isIOS ? "ios" : "android";

    try {
      final body = {
        "user": email,
        "password": password,
        "app": "WAVEUP",
        "client": "app",
        "os": os,
        "device_id": deviceId,
        "device_name": deviceName,
        "fcm_token": fcmToken,
      };

      final response = await ApiService.login(
        '/user/login',
        body,
      ); // <- gunakan method login khusus

      debugPrint("LOGIN ◀︎ status: ${response.statusCode}");
      final rawBody = response.body;
      debugPrint(
        "LOGIN ◀︎ body: ${rawBody.length > 500 ? rawBody.substring(0, 500) + '…' : rawBody}",
      );

      if (response.statusCode == 200) {
        final decoded = jsonDecode(rawBody) as Map<String, dynamic>;
        final tokenObj = (decoded['token'] ?? {}) as Map<String, dynamic>;
        final userObj = (decoded['data'] ?? {}) as Map<String, dynamic>;
        final bizList =
            (decoded['business'] as List?)?.cast<Map<String, dynamic>>() ?? [];

        // ===== Validasi token =====
        final accessToken = tokenObj['access_token'] as String?;
        final refreshToken = tokenObj['refresh_token'] as String?;
        if (accessToken == null || accessToken.isEmpty) {
          _error = "Login berhasil tapi token kosong";
          _isLoading = false;
          notifyListeners();
          return false;
        }

        // ===== Derive beberapa field yang sering dipakai =====
        final firstname = (userObj['firstname'] ?? '') as String;
        final lastname = (userObj['lastname'] ?? '') as String;
        final fullName = '$firstname $lastname'.trim();
        final serverEmail = (userObj['email'] ?? email) as String;
        final username = (userObj['username'] ?? '') as String;
        final photoPath = (userObj['photoPath'] ?? '') as String;

        // Ambil business pertama sebagai "active business" (kalau diperlukan)
        final Map<String, dynamic>? firstBiz = bizList.isNotEmpty
            ? bizList.first
            : null;
        final String activeBizName = (firstBiz?['name'] ?? '') as String;
        final String activeBizUsername =
            (firstBiz?['username'] ?? '') as String;
        final String activeBizId = (firstBiz?['idBusiness'] ?? '') as String;
        final String activeBizLogoPath =
            (firstBiz?['logoPath'] ?? firstBiz?['logo'] ?? '') as String;

        // ===== Simpan ke state lokal =====
        _accessToken = accessToken;
        _refreshToken = refreshToken;
        _name = fullName.isNotEmpty ? fullName : null;
        _email = serverEmail;
        _isActivated = true;

        // ===== Persist SEMUA DATA ke SharedPreferences =====
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('login_raw', rawBody);
        await prefs.setString('token', jsonEncode(tokenObj));
        await prefs.setString('user', jsonEncode(userObj));
        await prefs.setString('business', jsonEncode(bizList));
        await prefs.setString('accessToken', _accessToken!);
        if (_refreshToken != null)
          await prefs.setString('refreshToken', _refreshToken!);
        if (_name != null) await prefs.setString('name', _name!);
        await prefs.setString('email', _email!);
        await prefs.setBool('isActivated', _isActivated);
        await prefs.setString('idUser', (userObj['idUser'] ?? '').toString());
        await prefs.setString('username', username);
        await prefs.setString('photoPath', photoPath);
        await prefs.setString('phone', (userObj['phone'] ?? '').toString());
        await prefs.setString(
          'hasPage',
          (userObj['hasPage'] ?? false).toString(),
        );
        await prefs.setString(
          'userRoleName',
          (userObj['userRoleName'] ?? '').toString(),
        );

        await prefs.setString('activeBizId', activeBizId);
        await prefs.setString('activeBizName', activeBizName);
        await prefs.setString('activeBizUsername', activeBizUsername);
        await prefs.setString('activeBizLogoPath', activeBizLogoPath);

        final accountSnapshot = {
          'token': tokenObj,
          'user': userObj,
          'business': bizList,
          'accessToken': _accessToken,
          'refreshToken': _refreshToken,
          'name': _name,
          'email': _email,
          'username': username,
          'photoPath': photoPath,
          'activeBusiness': {
            'idBusiness': activeBizId,
            'name': activeBizName,
            'username': activeBizUsername,
            'logoPath': activeBizLogoPath,
          },
        };
        await prefs.setString(
          'account_${_email!}',
          jsonEncode(accountSnapshot),
        );

        final accounts = prefs.getStringList(kAccountsKey) ?? [];
        if (!accounts.contains(_email)) {
          accounts.add(_email!);
          await prefs.setStringList(kAccountsKey, accounts);
        }
        await prefs.setString(kActiveAccountKey, _email!);

        debugPrint("LOGIN ✅ success for $_email");
        _isLoading = false;
        notifyListeners();
        return true;
      } else {
        final err = jsonDecode(rawBody);
        _error = err['message'] ?? 'Login gagal (${response.statusCode})';
        debugPrint("LOGIN ❌ error: $_error");
      }
    } catch (e, st) {
      _error = "Terjadi kesalahan: $e";
      debugPrint("LOGIN ❌ exception: $e");
      debugPrint("$st");
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

  Future<bool> registerStep1({
    required String email,
    required String password,
  }) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final body = {"email": email, "password": password};

      final res = await ApiService.postJson('/waveup/user/register', body);
      final raw = res.body;
      debugPrint(
        "REGISTER STEP1 ◀︎ ${res.statusCode} ${raw.length > 500 ? raw.substring(0, 500) + '…' : raw}",
      );

      if (res.statusCode >= 200 && res.statusCode < 300) {
        _isLoading = false;
        notifyListeners();
        return true;
      } else {
        // coba ambil message dari server
        try {
          final j = jsonDecode(raw);
          _error = j['message'] ?? 'Register step 1 gagal (${res.statusCode})';
        } catch (_) {
          _error = 'Register step 1 gagal (${res.statusCode})';
        }
      }
    } catch (e, st) {
      _error = 'Terjadi kesalahan: $e';
      debugPrint('REGISTER STEP1 ❌ $e\n$st');
    }

    _isLoading = false;
    notifyListeners();
    return false;
  }

  /// STEP 2 REGISTER: profile & business (+ optional logo)
  Future<bool> registerStep2({
    required String firstName,
    required String lastName,
    required String businessName,
    File? businessLogo,
    // opsional: kalau API butuh kirim kembali email/password dari step1, tambahkan param di sini
  }) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final fields = {
        'first_name': firstName,
        'last_name': lastName,
        'business_name': businessName,
      };

      final res = await ApiService.postMultipart(
        '/waveup/user/register/finish',
        fields: fields,
        files: businessLogo == null ? {} : {'business_logo': businessLogo.path},
      );

      final raw = res.body;
      debugPrint(
        "REGISTER STEP2 ◀︎ ${res.statusCode} ${raw.length > 500 ? raw.substring(0, 500) + '…' : raw}",
      );

      if (res.statusCode >= 200 && res.statusCode < 300) {
        // Beberapa backend langsung mengembalikan token + data user mirip /login
        try {
          final decoded = jsonDecode(raw) as Map<String, dynamic>;
          final persisted = await _persistFromAuthResponse(decoded, raw);
          _isLoading = false;
          notifyListeners();
          return persisted;
        } catch (_) {
          // kalau tidak ada struktur token/data/business, anggap sukses tanpa login otomatis
          _isLoading = false;
          notifyListeners();
          return true;
        }
      } else {
        try {
          final j = jsonDecode(raw);
          _error = j['message'] ?? 'Register step 2 gagal (${res.statusCode})';
        } catch (_) {
          _error = 'Register step 2 gagal (${res.statusCode})';
        }
      }
    } catch (e, st) {
      _error = 'Terjadi kesalahan: $e';
      debugPrint('REGISTER STEP2 ❌ $e\n$st');
    }

    _isLoading = false;
    notifyListeners();
    return false;
  }

  /// Persist state & SharedPreferences dari payload AUTH (struktur mirip /login)
  Future<bool> _persistFromAuthResponse(
    Map<String, dynamic> decoded,
    String rawBody,
  ) async {
    try {
      final tokenObj = (decoded['token'] ?? {}) as Map<String, dynamic>;
      final userObj = (decoded['data'] ?? {}) as Map<String, dynamic>;
      final bizList =
          (decoded['business'] as List?)?.cast<Map<String, dynamic>>() ?? [];

      final accessToken = tokenObj['access_token'] as String?;
      final refreshToken = tokenObj['refresh_token'] as String?;
      if (accessToken == null || accessToken.isEmpty) {
        _error = 'Register berhasil, tapi token kosong';
        return false;
      }

      final firstname = (userObj['firstname'] ?? '') as String;
      final lastname = (userObj['lastname'] ?? '') as String;
      final fullName = '$firstname $lastname'.trim();
      final serverEmail =
          (userObj['email'] ?? '') as String?; // bisa kosong tergantung API
      final username = (userObj['username'] ?? '') as String;
      final photoPath = (userObj['photoPath'] ?? '') as String;

      final Map<String, dynamic>? firstBiz = bizList.isNotEmpty
          ? bizList.first
          : null;
      final String activeBizName = (firstBiz?['name'] ?? '') as String;
      final String activeBizUsername = (firstBiz?['username'] ?? '') as String;
      final String activeBizId = (firstBiz?['idBusiness'] ?? '') as String;
      final String activeBizLogoPath =
          (firstBiz?['logoPath'] ?? firstBiz?['logo'] ?? '') as String;

      // set ke state
      _accessToken = accessToken;
      _refreshToken = refreshToken;
      _name = fullName.isNotEmpty ? fullName : null;
      _email =
          serverEmail ?? _email; // fallback jika server tidak mengembalikan
      _isActivated = true;

      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('login_raw', rawBody);
      await prefs.setString('token', jsonEncode(tokenObj));
      await prefs.setString('user', jsonEncode(userObj));
      await prefs.setString('business', jsonEncode(bizList));
      await prefs.setString('accessToken', _accessToken!);
      if (_refreshToken != null)
        await prefs.setString('refreshToken', _refreshToken!);
      if (_name != null) await prefs.setString('name', _name!);
      if (_email != null) await prefs.setString('email', _email!);
      await prefs.setBool('isActivated', _isActivated);
      await prefs.setString('idUser', (userObj['idUser'] ?? '').toString());
      await prefs.setString('username', username);
      await prefs.setString('photoPath', photoPath);
      await prefs.setString('phone', (userObj['phone'] ?? '').toString());
      await prefs.setString(
        'hasPage',
        (userObj['hasPage'] ?? false).toString(),
      );
      await prefs.setString(
        'userRoleName',
        (userObj['userRoleName'] ?? '').toString(),
      );

      await prefs.setString('activeBizId', activeBizId);
      await prefs.setString('activeBizName', activeBizName);
      await prefs.setString('activeBizUsername', activeBizUsername);
      await prefs.setString('activeBizLogoPath', activeBizLogoPath);

      final accountSnapshot = {
        'token': tokenObj,
        'user': userObj,
        'business': bizList,
        'accessToken': _accessToken,
        'refreshToken': _refreshToken,
        'name': _name,
        'email': _email,
        'username': username,
        'photoPath': photoPath,
        'isActivated': _isActivated,
        'activeBusiness': {
          'idBusiness': activeBizId,
          'name': activeBizName,
          'username': activeBizUsername,
          'logoPath': activeBizLogoPath,
        },
      };

      if (_email != null) {
        await prefs.setString(
          'account_${_email!}',
          jsonEncode(accountSnapshot),
        );
        final accounts = prefs.getStringList(kAccountsKey) ?? [];
        if (!accounts.contains(_email)) {
          accounts.add(_email!);
          await prefs.setStringList(kAccountsKey, accounts);
        }
        await prefs.setString(kActiveAccountKey, _email!);
      }

      debugPrint('REGISTER FINISH ✅ persisted');
      return true;
    } catch (e, st) {
      _error = 'Gagal menyimpan data register: $e';
      debugPrint('_persistFromAuthResponse ❌ $e\n$st');
      return false;
    }
  }
}
