import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:wa_blast/app_nav.dart';
import 'package:wa_blast/providers/splash_provider.dart';
import 'package:wa_blast/services/api_service.dart';

// Optional: kecilkan model agar enak dipakai di UI
@immutable
class BusinessInfo {
  final String idBusiness;
  final String name;
  final String username;
  final String logoPath;
  final bool isActive;
  const BusinessInfo({
    required this.idBusiness,
    required this.name,
    required this.username,
    required this.logoPath,
    this.isActive = false,
  });

  factory BusinessInfo.fromJson(Map<String, dynamic> j, {String? activeId}) {
    final id = (j['idBusiness'] ?? '').toString();
    return BusinessInfo(
      idBusiness: id,
      name: (j['name'] ?? '').toString(),
      username: (j['username'] ?? '').toString(),
      logoPath: (j['logoPath'] ?? j['logo'] ?? '').toString(),
      isActive: activeId != null && activeId == id,
    );
  }

  Map<String, dynamic> toJson() => {
    'idBusiness': idBusiness,
    'name': name,
    'username': username,
    'logoPath': logoPath,
  };
}

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
  String? get currentUserEmail => _email;
  static const String kAccountsKey = 'accounts';
  static const String kActiveAccountKey = 'activeAccountEmail';
  String? get activeAccountEmail => _email;

  final nav = appNavigatorKey.currentState;

  Future<String?> getCurrentUserEmailFromPrefs() async {
    if (_email != null && _email!.isNotEmpty) return _email;
    final prefs = await SharedPreferences.getInstance();
    // Prefer key aktif, fallback ke 'email' lama
    return prefs.getString(kActiveAccountKey) ?? prefs.getString('email');
  }

  // Tambahkan helper ini di dalam class AuthProvider
  String _pickMsg(
    dynamic j, {
    int? httpStatus,
    String fallback = 'Login gagal',
  }) {
    try {
      if (j is Map<String, dynamic>) {
        final m = j['msg'] ?? j['message'] ?? j['error'] ?? j['detail'];
        if (m != null && m.toString().trim().isNotEmpty) return m.toString();
      }
    } catch (_) {}
    return httpStatus != null ? '$fallback ($httpStatus)' : fallback;
  }

  // Ganti seluruh method login() dengan versi ini
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

      final response = await ApiService.login('/user/login', body);

      debugPrint("LOGIN ◀︎ status: ${response.statusCode}");
      final rawBody = response.body;
      debugPrint(
        "LOGIN ◀︎ body: ${rawBody.length > 500 ? rawBody.substring(0, 500) + '…' : rawBody}",
      );

      // Selalu coba decode body agar bisa baca msg dari server
      Map<String, dynamic>? decoded;
      try {
        decoded = jsonDecode(rawBody) as Map<String, dynamic>?;
      } catch (_) {}

      // CASE A: HTTP 200 tetapi status di body bukan 200 (mis. 401)
      if (response.statusCode == 200) {
        final apiStatus = (decoded?['status'] as num?)?.toInt();
        if (apiStatus != null && apiStatus != 200) {
          final msg = _pickMsg(
            decoded,
            httpStatus: apiStatus,
            fallback: 'Login gagal',
          );
          _error = msg;
          if (context.mounted) {
            ScaffoldMessenger.of(
              context,
            ).showSnackBar(SnackBar(content: Text(msg)));
          }
          _isLoading = false;
          notifyListeners();
          return false;
        }

        // === SUCCESS FLOW (status benar-benar 200) ===
        final tokenObj = (decoded?['token'] ?? {}) as Map<String, dynamic>;
        final userObj = (decoded?['data'] ?? {}) as Map<String, dynamic>;
        final bizList =
            (decoded?['business'] as List?)?.cast<Map<String, dynamic>>() ?? [];

        final accessToken = tokenObj['access_token'] as String?;
        final refreshToken = tokenObj['refresh_token'] as String?;
        if (accessToken == null || accessToken.isEmpty) {
          _error = "Login berhasil tapi token kosong";
          _isLoading = false;
          notifyListeners();
          return false;
        }

        // derive fields
        final firstname = (userObj['firstname'] ?? '') as String;
        final lastname = (userObj['lastname'] ?? '') as String;
        final fullName = '$firstname $lastname'.trim();
        final serverEmail = (userObj['email'] ?? email) as String;
        final username = (userObj['username'] ?? '') as String;
        final photoPath = (userObj['photoPath'] ?? '') as String;

        final Map<String, dynamic>? firstBiz = bizList.isNotEmpty
            ? bizList.first
            : null;
        final String activeBizName = (firstBiz?['name'] ?? '') as String;
        final String activeBizUsername =
            (firstBiz?['username'] ?? '') as String;
        final String activeBizId = (firstBiz?['idBusiness'] ?? '') as String;
        final String activeBizLogoPath =
            (firstBiz?['logoPath'] ?? firstBiz?['logo'] ?? '') as String;

        // set state
        _accessToken = accessToken;
        _refreshToken = refreshToken;
        _name = fullName.isNotEmpty ? fullName : null;
        _email = serverEmail;
        _isActivated = true;

        // persist
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
          'isActivated': _isActivated,
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
      }

      // CASE B: HTTP non-200 → tampilkan pesan dari body bila ada
      final msg = _pickMsg(
        decoded ?? {},
        httpStatus: response.statusCode,
        fallback: 'Login gagal',
      );
      _error = msg;
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(msg)));
      }
    } catch (e, st) {
      _error = "Terjadi kesalahan: $e";
      debugPrint("LOGIN ❌ exception: $e");
      debugPrint("$st");
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Terjadi kesalahan saat login.')),
        );
      }
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

  bool _isJwtExpired(String token, {int leewaySeconds = 60}) {
    try {
      final parts = token.split('.');
      if (parts.length != 3) return false; // bukan JWT → abaikan
      String _norm(String s) {
        var out = s.replaceAll('-', '+').replaceAll('_', '/');
        switch (out.length % 4) {
          case 2:
            out += '==';
            break;
          case 3:
            out += '=';
            break;
        }
        return out;
      }

      final payloadRaw = utf8.decode(base64Url.decode(_norm(parts[1])));
      final payload = jsonDecode(payloadRaw) as Map<String, dynamic>;
      final exp = (payload['exp'] as num?)?.toInt();
      if (exp == null) return false;
      final nowSec = DateTime.now().millisecondsSinceEpoch ~/ 1000;
      return nowSec >= (exp - leewaySeconds);
    } catch (_) {
      return false; // kalau gagal decode, anggap tidak expired
    }
  }

  // Autologin saat app dibuka
  // ganti isi tryAutoLogin agar TANPA cek exp / refresh proaktif
  Future<void> tryAutoLogin(BuildContext context) async {
    final prefs = await SharedPreferences.getInstance();
    final activeEmail = prefs.getString(kActiveAccountKey);
    if (activeEmail == null) return;

    final accountJson = prefs.getString('account_$activeEmail');

    try {
      final accountData = accountJson != null ? jsonDecode(accountJson) : null;

      _accessToken =
          prefs.getString('accessToken') ??
          (accountData != null ? accountData['accessToken'] as String? : null);

      _refreshToken =
          prefs.getString('refreshToken') ??
          (accountData != null ? accountData['refreshToken'] as String? : null);

      _name =
          prefs.getString('name') ??
          (accountData != null ? accountData['name'] as String? : null);

      _email =
          prefs.getString('email') ??
          (accountData != null ? accountData['email'] as String? : null);

      _isActivated =
          prefs.getBool('isActivated') ??
          (accountData != null
              ? (accountData['isActivated'] as bool?)
              : null) ??
          false;

      // Tidak ada cek exp / refresh di sini.
      notifyListeners();
    } catch (e) {
      debugPrint("AutoLogin parsing error: $e");
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

      // bersihkan daftar & snapshot akun
      accounts.remove(currentEmail);
      await prefs.setStringList(kAccountsKey, accounts);
      if (currentEmail != null) {
        await prefs.remove('account_$currentEmail');
      }

      // clear session
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

      // ⬅️ RESET Splash guard sebelum navigasi
      final sp = appNavigatorKey.currentContext?.read<SplashProvider>();
      sp?.resetNavigationGuards();
      sp?.abortDeepLink();

      // ⬅️ Gunakan navigator global supaya tidak nyasar ke nested navigator

      if (accounts.isNotEmpty) {
        final nextEmail = accounts.first;
        final success = await switchAccount(nextEmail);

        if (success) {
          nav?.pushNamedAndRemoveUntil('/splash', (r) => false);
          return;
        }
      }

      nav?.pushNamedAndRemoveUntil('/splash', (r) => false);
    } catch (e) {
      debugPrint("Gagal logout: $e");
    }
  }

  Future<bool> registerStep1({
    required String email,
    required String password,
    String referralCode = "",
    required String deviceId,
    required String deviceName,
    required String fcmToken,
  }) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final body = {
        "user": email,
        "password": password,
        "referral_code": referralCode,
        "device_id": deviceId,
        "device_name": deviceName,
        "fcm_token": fcmToken,
      };

      // endpoint: waveup/user/register — public, jadi without token
      final res = await ApiService.postJson('/waveup/user/register', body);
      final raw = res.body;
      debugPrint(
        "REGISTER STEP1 ◀︎ ${res.statusCode} ${raw.length > 500 ? raw.substring(0, 500) + '…' : raw}",
      );

      if (res.statusCode >= 200 && res.statusCode < 300) {
        final decoded = jsonDecode(raw) as Map<String, dynamic>;
        final ok = await _persistFromAuthResponse(decoded, raw);
        if (!ok) {
          _error = 'Register step 1 berhasil tapi token kosong';
          return false;
        }
        debugPrint('REGISTER STEP1 ✅ token & data disimpan');
        return true;
      } else {
        try {
          final j = jsonDecode(raw);
          _error =
              j['message']?.toString() ??
              'Register step 1 gagal (${res.statusCode})';
        } catch (_) {
          _error = 'Register step 1 gagal (${res.statusCode})';
        }
        return false;
      }
    } catch (e, st) {
      _error = 'Terjadi kesalahan: $e';
      debugPrint('REGISTER STEP1 ❌ $e\n$st');
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<bool> registerStep2({
    required BuildContext context,
    required String firstName,
    required String lastName,
    required String organisationName,
    File? organisationLogo,
  }) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final prefs = await SharedPreferences.getInstance();
      final token = _accessToken?.isNotEmpty == true
          ? _accessToken!
          : (prefs.getString('accessToken') ?? '');
      if (token.isEmpty) {
        _error =
            'Access token tidak tersedia. Selesaikan Step 1 terlebih dahulu.';
        return false;
      }

      // 1) Upload logo jika ada → dapat filename
      String? uploadedFilename;
      if (organisationLogo != null) {
        uploadedFilename = await _uploadLogoAndGetFilename(organisationLogo);
        if (uploadedFilename == null || uploadedFilename.isEmpty) {
          _error = 'Failed to upload logo. Please try again.';
          return false;
        }
      }

      // 2) Hit register/finish (organisation_logo kirim filename string)
      final fields = <String, String>{
        'firstname': firstName,
        'lastname': lastName,
        'organisation_name': organisationName,
        if (uploadedFilename != null) 'organisation_logo': uploadedFilename,
      };

      final res = await ApiService.postMultipart(
        '/waveup/user/register/finish',
        fields: fields,
        files: const {},
        withAccessToken: true,
      );

      final raw = res.body;
      debugPrint(
        "REGISTER STEP2 ◀︎ ${res.statusCode} ${raw.length > 500 ? raw.substring(0, 500) + '…' : raw}",
      );

      if (res.statusCode >= 200 && res.statusCode < 300) {
        final j = jsonDecode(raw) as Map<String, dynamic>;
        final idBusiness = (j['idBusiness'] ?? '').toString();
        if (idBusiness.isEmpty) {
          _error = 'Register step 2 succeeded, but idBusiness is empty';
          return false;
        }

        // 3) Persist idBusiness & mark logged-in
        await _saveActiveBusinessId(idBusiness);
        _isActivated = true;
        await prefs.setBool('isActivated', true);

        // 4) Fetch user profile terbaru dan persist
        await refreshCurrentUser(context);

        // 5) Redirect
        if (context.mounted) {
          final sp = appNavigatorKey.currentContext?.read<SplashProvider>();
          sp?.resetNavigationGuards();
          sp?.abortDeepLink();

          final navNow = appNavigatorKey.currentState;
          navNow?.pushNamedAndRemoveUntil('/splash', (r) => false);
        }

        debugPrint(
          'REGISTER STEP2 ✅ idBusiness=$idBusiness (logo=${uploadedFilename ?? '-'}) → refreshed user → /splash',
        );
        await refreshCurrentUser(context);
        return true;
      } else {
        try {
          final j = jsonDecode(raw);
          _error =
              j['message']?.toString() ??
              'Register step 2 failed (${res.statusCode})';
        } catch (_) {
          _error = 'Register step 2 failed (${res.statusCode})';
        }
        return false;
      }
    } catch (e, st) {
      _error = 'Terjadi kesalahan: $e';
      debugPrint('REGISTER STEP2 ❌ $e\n$st');
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<bool> fetchAndPersistCurrentUser(BuildContext context) async {
    try {
      final res = await ApiService.get(context, '/user', withAccessToken: true);
      final raw = res.body;
      debugPrint(
        "FETCH USER ◀︎ ${res.statusCode} ${raw.length > 500 ? raw.substring(0, 500) + '…' : raw}",
      );

      if (res.statusCode >= 200 && res.statusCode < 300) {
        final j = jsonDecode(raw) as Map<String, dynamic>;
        final userObj = (j['data'] ?? {}) as Map<String, dynamic>;
        final prefs = await SharedPreferences.getInstance();

        // derive fields
        final firstname = (userObj['firstname'] ?? '') as String;
        final lastname = (userObj['lastname'] ?? '') as String;
        final fullName = '$firstname $lastname'.trim();
        final email = (userObj['email'] ?? '') as String? ?? _email ?? '';
        final username = (userObj['username'] ?? '') as String? ?? '';
        final photoPath = (userObj['photoPath'] ?? '') as String? ?? '';
        final phone = (userObj['phone'] ?? '').toString();
        final hasPage = (userObj['hasPage'] ?? false) as bool;
        final roleName = (userObj['userRoleName'] ?? '').toString();
        final idUser = (userObj['idUser'] ?? '').toString();

        // update in-memory
        _name = fullName.isNotEmpty ? fullName : _name;
        _email = email.isNotEmpty ? email : _email;

        // persist single keys
        await prefs.setString('user', jsonEncode(userObj));
        if (_name != null) await prefs.setString('name', _name!);
        if (_email != null) await prefs.setString('email', _email!);
        await prefs.setString('username', username);
        await prefs.setString('photoPath', photoPath);
        await prefs.setString('phone', phone);
        await prefs.setBool('hasPage', hasPage);
        await prefs.setString('userRoleName', roleName);
        await prefs.setString('idUser', idUser);

        // update snapshot akun aktif
        final activeEmail = _email ?? prefs.getString(kActiveAccountKey);
        if (activeEmail != null) {
          final key = 'account_$activeEmail';
          final jsonStr = prefs.getString(key);
          if (jsonStr != null) {
            try {
              final Map<String, dynamic> snap = jsonDecode(jsonStr);
              snap['user'] = userObj;
              snap['name'] = _name;
              snap['email'] = _email;
              snap['username'] = username;
              snap['photoPath'] = photoPath;
              await prefs.setString(key, jsonEncode(snap));
            } catch (e) {
              debugPrint('UPDATE SNAPSHOT USER ❌ $e');
            }
          }
        }

        notifyListeners();
        return true;
      } else {
        debugPrint("FETCH USER ❌ status ${res.statusCode}");
        return false;
      }
    } catch (e, st) {
      debugPrint('FETCH USER ❌ $e\n$st');
      return false;
    }
  }

  // di dalam class AuthProvider
  Future<void> updateAccessToken(String newAccess) async {
    if (newAccess.isEmpty) return;
    _accessToken = newAccess;

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('accessToken', newAccess);

    // Sinkronkan snapshot akun aktif (account_<email>)
    final emailKey = _email ?? prefs.getString(kActiveAccountKey);
    if (emailKey != null && emailKey.isNotEmpty) {
      final key = 'account_$emailKey';
      final snapStr = prefs.getString(key);
      if (snapStr != null) {
        try {
          final snap = jsonDecode(snapStr) as Map<String, dynamic>;
          snap['accessToken'] = newAccess;
          await prefs.setString(key, jsonEncode(snap));
        } catch (e) {
          debugPrint('updateAccessToken: snapshot sync failed: $e');
        }
      }
    }

    notifyListeners();
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

  // === Helper: upload file -> ambil data.filename ===
  Future<String?> _uploadLogoAndGetFilename(File file) async {
    try {
      final res = await ApiService.postMultipart(
        '/file/upload',
        fields: const {}, // jika backend perlu field lain, tambahkan di sini
        files: {'file': file.path}, // asumsi key = 'file'
        withAccessToken: true, // pakai token dari prefs
      );
      final raw = res.body;
      debugPrint(
        "UPLOAD LOGO ◀︎ ${res.statusCode} ${raw.length > 500 ? raw.substring(0, 500) + '…' : raw}",
      );

      if (res.statusCode >= 200 && res.statusCode < 300) {
        final j = jsonDecode(raw) as Map<String, dynamic>;
        final data = (j['data'] ?? {}) as Map<String, dynamic>;
        final filename = (data['filename'] ?? '').toString();
        return filename.isEmpty ? null : filename;
      }
    } catch (e, st) {
      debugPrint('UPLOAD LOGO ❌ $e\n$st');
    }
    return null;
  }

  Future<void> _saveActiveBusinessId(String idBusiness) async {
    final prefs = await SharedPreferences.getInstance();

    await prefs.setString('activeBizId', idBusiness);

    final activeEmail = _email ?? prefs.getString(kActiveAccountKey);
    if (activeEmail != null) {
      final key = 'account_$activeEmail';
      final jsonStr = prefs.getString(key);
      if (jsonStr != null) {
        try {
          final Map<String, dynamic> snap = jsonDecode(jsonStr);
          final Map<String, dynamic> activeBiz =
              (snap['activeBusiness'] as Map?)?.cast<String, dynamic>() ?? {};
          activeBiz['idBusiness'] = idBusiness;
          snap['activeBusiness'] = activeBiz;
          await prefs.setString(key, jsonEncode(snap));
        } catch (e) {
          debugPrint('Gagal update snapshot idBusiness: $e');
        }
      }
    }
  }

  /// Ambil daftar bisnis yang tersimpan dari SharedPreferences
  Future<List<BusinessInfo>> getBusinesses() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString('business');
    final activeId = prefs.getString('activeBizId');
    if (raw == null || raw.isEmpty) return const [];

    try {
      final list = (jsonDecode(raw) as List).cast<Map<String, dynamic>>();
      return list
          .map((e) => BusinessInfo.fromJson(e, activeId: activeId))
          .toList();
    } catch (e) {
      debugPrint('getBusinesses parse error: $e');
      return const [];
    }
  }

  /// Getter singkat untuk bisnis aktif saat ini (atau null)
  Future<BusinessInfo?> getActiveBusiness() async {
    final prefs = await SharedPreferences.getInstance();
    final activeId = prefs.getString('activeBizId') ?? '';
    final all = await getBusinesses();

    if (all.isEmpty) return null; // boleh null di level fungsi
    if (activeId.isEmpty) return all.first; // pilih default ke item pertama

    // orElse WAJIB mengembalikan BusinessInfo (bukan null)
    return all.firstWhere(
      (b) => b.idBusiness == activeId,
      orElse: () => all.first,
    );
  }

  // === NEW: Simpan daftar bisnis user + role dari /user/business ===
  Future<bool> fetchAndPersistUserBusiness(BuildContext context) async {
    try {
      final res = await ApiService.get(
        context,
        '/user/business',
        withAccessToken: true,
      );
      final raw = res.body;
      debugPrint(
        "FETCH USER BUSINESS ◀︎ ${res.statusCode} ${raw.length > 500 ? raw.substring(0, 500) + '…' : raw}",
      );

      if (res.statusCode < 200 || res.statusCode >= 300) {
        debugPrint("FETCH USER BUSINESS ❌ status ${res.statusCode}");
        return false;
      }

      final j = jsonDecode(raw) as Map<String, dynamic>;
      final List data = (j['data'] as List?) ?? const [];

      // Simpan raw response untuk auditing
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('userBusinessRaw', raw);

      // Turunkan ke array "business" (dipakai oleh getBusinesses())
      final List<Map<String, dynamic>> simplifiedBusiness = data
          .map<Map<String, dynamic>>((e) {
            final b =
                (e as Map)['business'] as Map<String, dynamic>? ?? const {};
            return {
              'idBusiness': (b['idBusiness'] ?? '').toString(),
              'name': (b['name'] ?? '').toString(),
              'username': (b['username'] ?? '').toString(),
              'logoPath': (b['logoPath'] ?? b['logo'] ?? '').toString(),
            };
          })
          .toList();

      // Simpan daftar bisnis “standar” (agar kompatibel dgn getBusinesses())
      await prefs.setString('business', jsonEncode(simplifiedBusiness));

      // Simpan role per bisnis dalam map: { idBusiness: {idAdminRole, name, isPrimary} }
      final Map<String, dynamic> roleMap = {};
      for (final item in data) {
        final m = (item as Map).cast<String, dynamic>();
        final biz = (m['business'] ?? const {}) as Map<String, dynamic>;
        final role = (m['adminRole'] ?? const {}) as Map<String, dynamic>;
        final idBiz = (biz['idBusiness'] ?? '').toString();
        if (idBiz.isNotEmpty) {
          roleMap[idBiz] = {
            'idAdminRole': (role['idAdminRole'] ?? '').toString(),
            'name': (role['name'] ?? '').toString(),
            'isPrimary': (role['isPrimary'] ?? false) == true,
          };
        }
      }
      await prefs.setString('businessRoles', jsonEncode(roleMap));

      // Set active business = item pertama
      if (simplifiedBusiness.isNotEmpty) {
        final first = simplifiedBusiness.first;
        await prefs.setString('activeBizId', first['idBusiness'] ?? '');
        await prefs.setString('activeBizName', first['name'] ?? '');
        await prefs.setString('activeBizUsername', first['username'] ?? '');
        await prefs.setString('activeBizLogoPath', first['logoPath'] ?? '');

        // Sekalian simpan active role (kalau ada)
        final rb = roleMap[first['idBusiness']];
        await prefs.setString(
          'activeBizRoleId',
          (rb?['idAdminRole'] ?? '').toString(),
        );
        await prefs.setString(
          'activeBizRoleName',
          (rb?['name'] ?? '').toString(),
        );
        await prefs.setBool(
          'activeBizRoleIsPrimary',
          (rb?['isPrimary'] ?? false) == true,
        );

        // Sinkronkan snapshot account_<email>
        final emailKey = _email ?? prefs.getString(kActiveAccountKey);
        if (emailKey != null && emailKey.isNotEmpty) {
          final key = 'account_$emailKey';
          final snapStr = prefs.getString(key);
          if (snapStr != null) {
            try {
              final snap = jsonDecode(snapStr) as Map<String, dynamic>;
              snap['business'] = simplifiedBusiness;
              snap['activeBusiness'] = {
                'idBusiness': first['idBusiness'],
                'name': first['name'],
                'username': first['username'],
                'logoPath': first['logoPath'],
              };
              snap['businessRoles'] = roleMap;
              snap['activeBusinessRole'] = {
                'idAdminRole': (rb?['idAdminRole'] ?? '').toString(),
                'name': (rb?['name'] ?? '').toString(),
                'isPrimary': (rb?['isPrimary'] ?? false) == true,
              };
              await prefs.setString(key, jsonEncode(snap));
            } catch (e) {
              debugPrint('SYNC SNAPSHOT (user business) ❌ $e');
            }
          }
        }
      }

      notifyListeners();
      return true;
    } catch (e, st) {
      debugPrint('FETCH USER BUSINESS ❌ $e\n$st');
      return false;
    }
  }

  // Make the private fetcher callable from outside
  // di dalam class AuthProvider
  Future<bool> refreshCurrentUser(BuildContext context) async {
    debugPrint('refreshCurrentUser ▶︎ start');

    // 1) Ambil daftar bisnis + role dulu
    try {
      final okBiz = await fetchAndPersistUserBusiness(context);
      debugPrint('refreshCurrentUser ▶︎ fetchAndPersistUserBusiness = $okBiz');
    } catch (e, st) {
      debugPrint('refreshCurrentUser ❌ userBusiness error: $e\n$st');
    }

    // 2) Lalu fetch user (ini yang jadi nilai return)
    final okUser = await fetchAndPersistCurrentUser(context);
    debugPrint('refreshCurrentUser ▶︎ fetchAndPersistCurrentUser = $okUser');

    debugPrint('refreshCurrentUser ◀︎ done');
    return okUser;
  }

  /// Ganti active business by idBusiness, *tanpa* perlu login ulang.
  /// - Update keys: activeBizId, activeBizName, activeBizUsername, activeBizLogoPath
  /// - Update snapshot "account_<email>" agar konsisten saat cold start
  /// - Optional: jika API butuh header bisnis, panggil hook di ApiService
  Future<bool> switchActiveBusiness(String idBusiness) async {
    final prefs = await SharedPreferences.getInstance();

    // 1) Cari bisnis yang dimaksud dari list yg tersimpan
    final businesses = await getBusinesses();
    final target = businesses.firstWhere(
      (b) => b.idBusiness == idBusiness,
      orElse: () => const BusinessInfo(
        idBusiness: '',
        name: '',
        username: '',
        logoPath: '',
      ),
    );
    if (target.idBusiness.isEmpty) {
      _error = 'Business tidak ditemukan';
      notifyListeners();
      return false;
    }

    // 2) Persist ke prefs (single keys)
    await prefs.setString('activeBizId', target.idBusiness);
    await prefs.setString('activeBizName', target.name);
    await prefs.setString('activeBizUsername', target.username);
    await prefs.setString('activeBizLogoPath', target.logoPath);

    // 3) Update snapshot akun aktif (account_<email>)
    final emailKey = _email ?? prefs.getString(kActiveAccountKey);
    if (emailKey != null && emailKey.isNotEmpty) {
      final key = 'account_$emailKey';
      final snapStr = prefs.getString(key);
      if (snapStr != null) {
        try {
          final snap = jsonDecode(snapStr) as Map<String, dynamic>;
          final activeBiz =
              (snap['activeBusiness'] as Map?)?.cast<String, dynamic>() ?? {};
          activeBiz['idBusiness'] = target.idBusiness;
          activeBiz['name'] = target.name;
          activeBiz['username'] = target.username;
          activeBiz['logoPath'] = target.logoPath;
          snap['activeBusiness'] = activeBiz;
          await prefs.setString(key, jsonEncode(snap));
        } catch (e) {
          debugPrint('switchActiveBusiness: update snapshot error: $e');
        }
      }
      // Pastikan pointer akun aktif juga ke email ini
      await prefs.setString(kActiveAccountKey, emailKey);
    }

    // 4) Optional: inform ApiService kalau butuh header khusus per bisnis
    try {
      // Jika kamu punya hook seperti ini, aktifkan:
      // ApiService.setActiveBusinessId(target.idBusiness);
      // atau, jika perlu custom header:
      // ApiService.updateDefaultHeaders({'X-Business-Id': target.idBusiness});
    } catch (_) {}

    // 5) Update state in-memory (jika kamu ingin expose ke UI lewat provider)
    // (Tidak ada field khusus di state, tapi kita bisa notify agar UI refresh)
    _error = null;
    notifyListeners();
    return true;
  }
}
