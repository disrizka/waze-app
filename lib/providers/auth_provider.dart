import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:wa_blast/app_nav.dart';
import 'package:wa_blast/providers/splash_provider.dart';
import 'package:wa_blast/services/api_service.dart';

/// =========================
/// Model ringan untuk UI
/// =========================
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
  // ========= State internal
  String? _accessToken;
  String? _refreshToken;
  String? _name;
  String? _email;
  bool _isActivated = false;
  bool _isLoading = false;
  String? _error;

  // ========= Getters publik
  String? get accessToken => _accessToken;
  String? get refreshToken => _refreshToken;
  String? get name => _name;
  String? get email => _email;
  bool get isActivated => _isActivated;
  bool get isLoading => _isLoading;
  String? get error => _error;
  String? get currentUserEmail => _email;

  // ========= Keys & konstanta
  static const String kAccountsKey = 'accounts';
  static const String kActiveAccountKey = 'activeAccountEmail';
  static const String kBusinessRolesKey =
      'businessRoles'; // Map: idBusiness -> {idAdminRole,name,isPrimary}
  static const String kActiveBizRoleIdKey = 'activeBizRoleId';
  static const String kActiveBizRoleNameKey = 'activeBizRoleName';
  static const String kActiveBizRoleIsPrimaryKey = 'activeBizRoleIsPrimary';

  String? get activeAccountEmail => _email;
  final nav = appNavigatorKey.currentState;

  // ========= Optional getters role aktif (buat UI)
  Future<String?> getActiveBusinessRoleId() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(kActiveBizRoleIdKey);
  }

  Future<String?> getActiveBusinessRoleName() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(kActiveBizRoleNameKey);
  }

  Future<bool> getActiveBusinessRoleIsPrimary() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(kActiveBizRoleIsPrimaryKey) ?? false;
  }

  Future<String?> getCurrentUserEmailFromPrefs() async {
    if (_email != null && _email!.isNotEmpty) return _email;
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(kActiveAccountKey) ?? prefs.getString('email');
  }

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

  // ========= LOGIN (UPDATED: simpan role per business + active role)
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

      Map<String, dynamic>? decoded;
      try {
        decoded = jsonDecode(rawBody) as Map<String, dynamic>?;
      } catch (_) {}

      if (response.statusCode == 200) {
        final apiStatus = (decoded?['status'] as num?)?.toInt();
        if (apiStatus != 200) {
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

        // === SUCCESS FLOW ===
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

        // derive user
        final firstname = (userObj['firstname'] ?? '') as String;
        final lastname = (userObj['lastname'] ?? '') as String;
        final fullName = '$firstname $lastname'.trim();
        final serverEmail = (userObj['email'] ?? email) as String;
        final username = (userObj['username'] ?? '') as String;
        final photoPath = (userObj['photoPath'] ?? '') as String;

        // pilih active business = item pertama (fallback kosong)
        final Map<String, dynamic>? firstBiz = bizList.isNotEmpty
            ? bizList.first
            : null;
        final String activeBizId = (firstBiz?['idBusiness'] ?? '').toString();
        final String activeBizName = (firstBiz?['name'] ?? '').toString();
        final String activeBizUsername = (firstBiz?['username'] ?? '')
            .toString();
        final String activeBizLogoPath =
            (firstBiz?['logoPath'] ?? firstBiz?['logo'] ?? '').toString();

        // === Build role map dari LOGIN response
        // { "<idBusiness>": { "idAdminRole": roleId, "name": userRoleName, "isPrimary": false } }
        final Map<String, dynamic> roleMap = {};
        for (final b in bizList) {
          final idBiz = (b['idBusiness'] ?? '').toString();
          if (idBiz.isEmpty) continue;
          final roleId = (b['roleId'] ?? '').toString();
          final roleName = (b['userRoleName'] ?? '').toString();
          roleMap[idBiz] = {
            'idAdminRole': roleId,
            'name': roleName,
            'isPrimary':
                false, // tidak tersedia di response login → default false
          };
        }

        // active role mengikuti active business
        final activeRole = roleMap[activeBizId] as Map<String, dynamic>?;

        // === set state
        _accessToken = accessToken;
        _refreshToken = refreshToken;
        _name = fullName.isNotEmpty ? fullName : null;
        _email = serverEmail;
        _isActivated = true;

        // === persist
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

        // active business
        await prefs.setString('activeBizId', activeBizId);
        await prefs.setString('activeBizName', activeBizName);
        await prefs.setString('activeBizUsername', activeBizUsername);
        await prefs.setString('activeBizLogoPath', activeBizLogoPath);

        // simpan role map & active role
        await prefs.setString(kBusinessRolesKey, jsonEncode(roleMap));
        await prefs.setString(
          kActiveBizRoleIdKey,
          (activeRole?['idAdminRole'] ?? '').toString(),
        );
        await prefs.setString(
          kActiveBizRoleNameKey,
          (activeRole?['name'] ?? '').toString(),
        );
        await prefs.setBool(
          kActiveBizRoleIsPrimaryKey,
          (activeRole?['isPrimary'] ?? false) == true,
        );

        // snapshot akun
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
          'businessRoles': roleMap,
          'activeBusinessRole': {
            'idAdminRole': (activeRole?['idAdminRole'] ?? '').toString(),
            'name': (activeRole?['name'] ?? '').toString(),
            'isPrimary': (activeRole?['isPrimary'] ?? false) == true,
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

      // HTTP non-200
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

      await prefs.setString('accessToken', _accessToken ?? '');
      await prefs.setString('refreshToken', _refreshToken ?? '');
      await prefs.setString('name', _name ?? '');
      await prefs.setString('email', _email ?? '');
      await prefs.setBool('isActivated', _isActivated);
      await prefs.setString(kActiveAccountKey, _email ?? '');

      // Sinkronkan juga active business & role dari snapshot jika ada
      final activeBiz =
          (accountData['activeBusiness'] as Map?)?.cast<String, dynamic>() ??
          {};
      await prefs.setString(
        'activeBizId',
        (activeBiz['idBusiness'] ?? '').toString(),
      );
      await prefs.setString(
        'activeBizName',
        (activeBiz['name'] ?? '').toString(),
      );
      await prefs.setString(
        'activeBizUsername',
        (activeBiz['username'] ?? '').toString(),
      );
      await prefs.setString(
        'activeBizLogoPath',
        (activeBiz['logoPath'] ?? '').toString(),
      );

      final roleMap = (accountData['businessRoles'] as Map?)
          ?.cast<String, dynamic>();
      if (roleMap != null) {
        await prefs.setString(kBusinessRolesKey, jsonEncode(roleMap));
      }
      final activeRole = (accountData['activeBusinessRole'] as Map?)
          ?.cast<String, dynamic>();
      if (activeRole != null) {
        await prefs.setString(
          kActiveBizRoleIdKey,
          (activeRole['idAdminRole'] ?? '').toString(),
        );
        await prefs.setString(
          kActiveBizRoleNameKey,
          (activeRole['name'] ?? '').toString(),
        );
        await prefs.setBool(
          kActiveBizRoleIsPrimaryKey,
          (activeRole['isPrimary'] ?? false) == true,
        );
      }

      _error = null;
      notifyListeners();
      return true;
    } catch (e) {
      _error = 'Gagal switch akun: $e';
      notifyListeners();
      return false;
    }
  }

  Future<List<String>> getStoredAccounts() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getStringList(kAccountsKey) ?? [];
  }

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
      if (parts.length != 3) return false;
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
      return false;
    }
  }

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

      notifyListeners();
    } catch (e) {
      debugPrint("AutoLogin parsing error: $e");
    }
  }

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

    // Bersihkan pointer active biz & role
    await prefs.remove('activeBizId');
    await prefs.remove('activeBizName');
    await prefs.remove('activeBizUsername');
    await prefs.remove('activeBizLogoPath');
    await prefs.remove(kActiveBizRoleIdKey);
    await prefs.remove(kActiveBizRoleNameKey);
    await prefs.remove(kActiveBizRoleIsPrimaryKey);

    notifyListeners();
  }

  Future<void> logout(BuildContext context) async {
    try {
      final prefs = await SharedPreferences.getInstance();

      final currentEmail = _email;
      final accounts = prefs.getStringList(kAccountsKey) ?? [];

      accounts.remove(currentEmail);
      await prefs.setStringList(kAccountsKey, accounts);
      if (currentEmail != null) {
        await prefs.remove('account_$currentEmail');
      }

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

      // Bersihkan active biz & role
      await prefs.remove('activeBizId');
      await prefs.remove('activeBizName');
      await prefs.remove('activeBizUsername');
      await prefs.remove('activeBizLogoPath');
      await prefs.remove(kActiveBizRoleIdKey);
      await prefs.remove(kActiveBizRoleNameKey);
      await prefs.remove(kActiveBizRoleIsPrimaryKey);

      notifyListeners();

      final sp = appNavigatorKey.currentContext?.read<SplashProvider>();
      sp?.resetNavigationGuards();
      sp?.abortDeepLink();

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

      String? uploadedFilename;
      if (organisationLogo != null) {
        uploadedFilename = await _uploadLogoAndGetFilename(organisationLogo);
        if (uploadedFilename == null || uploadedFilename.isEmpty) {
          _error = 'Failed to upload logo. Please try again.';
          return false;
        }
      }

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

        await _saveActiveBusinessId(idBusiness);
        _isActivated = true;
        await prefs.setBool('isActivated', true);

        await refreshCurrentUser(context);

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

        _name = fullName.isNotEmpty ? fullName : _name;
        _email = email.isNotEmpty ? email : _email;

        await prefs.setString('user', jsonEncode(userObj));
        if (_name != null) await prefs.setString('name', _name!);
        if (_email != null) await prefs.setString('email', _email!);
        await prefs.setString('username', username);
        await prefs.setString('photoPath', photoPath);
        await prefs.setString('phone', phone);
        await prefs.setBool('hasPage', hasPage);
        await prefs.setString('userRoleName', roleName);
        await prefs.setString('idUser', idUser);

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

  Future<void> updateAccessToken(String newAccess) async {
    if (newAccess.isEmpty) return;
    _accessToken = newAccess;

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('accessToken', newAccess);

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

  /// Persist dari payload AUTH (login/register) + role map
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
      final serverEmail = (userObj['email'] ?? '') as String?;
      final username = (userObj['username'] ?? '') as String;
      final photoPath = (userObj['photoPath'] ?? '') as String;

      final Map<String, dynamic>? firstBiz = bizList.isNotEmpty
          ? bizList.first
          : null;
      final String activeBizId = (firstBiz?['idBusiness'] ?? '').toString();
      final String activeBizName = (firstBiz?['name'] ?? '').toString();
      final String activeBizUsername = (firstBiz?['username'] ?? '').toString();
      final String activeBizLogoPath =
          (firstBiz?['logoPath'] ?? firstBiz?['logo'] ?? '').toString();

      // Build role map dari register (struktur sama dengan login)
      final Map<String, dynamic> roleMap = {};
      for (final b in bizList) {
        final idBiz = (b['idBusiness'] ?? '').toString();
        if (idBiz.isEmpty) continue;
        final roleId = (b['roleId'] ?? '').toString();
        final roleName = (b['userRoleName'] ?? '').toString();
        roleMap[idBiz] = {
          'idAdminRole': roleId,
          'name': roleName,
          'isPrimary': false,
        };
      }
      final activeRole = roleMap[activeBizId] as Map<String, dynamic>?;

      _accessToken = accessToken;
      _refreshToken = refreshToken;
      _name = fullName.isNotEmpty ? fullName : null;
      _email = serverEmail ?? _email;
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

      // persist roles
      await prefs.setString(kBusinessRolesKey, jsonEncode(roleMap));
      await prefs.setString(
        kActiveBizRoleIdKey,
        (activeRole?['idAdminRole'] ?? '').toString(),
      );
      await prefs.setString(
        kActiveBizRoleNameKey,
        (activeRole?['name'] ?? '').toString(),
      );
      await prefs.setBool(
        kActiveBizRoleIsPrimaryKey,
        (activeRole?['isPrimary'] ?? false) == true,
      );

      if (_email != null) {
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
          'businessRoles': roleMap,
          'activeBusinessRole': {
            'idAdminRole': (activeRole?['idAdminRole'] ?? '').toString(),
            'name': (activeRole?['name'] ?? '').toString(),
            'isPrimary': (activeRole?['isPrimary'] ?? false) == true,
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
      }

      debugPrint('REGISTER FINISH ✅ persisted (+roles)');
      return true;
    } catch (e, st) {
      _error = 'Gagal menyimpan data register: $e';
      debugPrint('_persistFromAuthResponse ❌ $e\n$st');
      return false;
    }
  }

  Future<String?> _uploadLogoAndGetFilename(File file) async {
    try {
      final res = await ApiService.postMultipart(
        '/file/upload',
        fields: const {},
        files: {'file': file.path},
        withAccessToken: true,
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

    // Saat mengganti active business manual di register flow,
    // ikutkan active role jika ada di businessRoles map.
    try {
      final roleMapStr = prefs.getString(kBusinessRolesKey);
      if (roleMapStr != null && roleMapStr.isNotEmpty) {
        final Map<String, dynamic> roleMap = jsonDecode(roleMapStr);
        final rb = (roleMap[idBusiness] as Map?)?.cast<String, dynamic>();
        await prefs.setString(
          kActiveBizRoleIdKey,
          (rb?['idAdminRole'] ?? '').toString(),
        );
        await prefs.setString(
          kActiveBizRoleNameKey,
          (rb?['name'] ?? '').toString(),
        );
        await prefs.setBool(
          kActiveBizRoleIsPrimaryKey,
          (rb?['isPrimary'] ?? false) == true,
        );
      }
    } catch (_) {}

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

          // sinkronkan active role di snapshot juga
          final rb = (() {
            final roleMapStr = prefs.getString(kBusinessRolesKey);
            if (roleMapStr == null) return null;
            final Map<String, dynamic> rmap = jsonDecode(roleMapStr);
            return (rmap[idBusiness] as Map?)?.cast<String, dynamic>();
          })();

          snap['activeBusinessRole'] = {
            'idAdminRole': (rb?['idAdminRole'] ?? '').toString(),
            'name': (rb?['name'] ?? '').toString(),
            'isPrimary': (rb?['isPrimary'] ?? false) == true,
          };

          await prefs.setString(key, jsonEncode(snap));
        } catch (e) {
          debugPrint('Gagal update snapshot idBusiness: $e');
        }
      }
    }
  }

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

  Future<BusinessInfo?> getActiveBusiness() async {
    final prefs = await SharedPreferences.getInstance();
    final activeId = prefs.getString('activeBizId') ?? '';
    final all = await getBusinesses();
    if (all.isEmpty) return null;
    if (activeId.isEmpty) return all.first;
    return all.firstWhere(
      (b) => b.idBusiness == activeId,
      orElse: () => all.first,
    );
  }

  /// Ambil daftar bisnis + role dari /user/business (jika ada endpointnya)
  /// Sudah include penyimpanan role & active role.
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

      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('userBusinessRaw', raw);

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

      await prefs.setString('business', jsonEncode(simplifiedBusiness));

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
      await prefs.setString(kBusinessRolesKey, jsonEncode(roleMap));

      if (simplifiedBusiness.isNotEmpty) {
        final first = simplifiedBusiness.first;
        await prefs.setString('activeBizId', first['idBusiness'] ?? '');
        await prefs.setString('activeBizName', first['name'] ?? '');
        await prefs.setString('activeBizUsername', first['username'] ?? '');
        await prefs.setString('activeBizLogoPath', first['logoPath'] ?? '');

        final rb = roleMap[first['idBusiness']];
        await prefs.setString(
          kActiveBizRoleIdKey,
          (rb?['idAdminRole'] ?? '').toString(),
        );
        await prefs.setString(
          kActiveBizRoleNameKey,
          (rb?['name'] ?? '').toString(),
        );
        await prefs.setBool(
          kActiveBizRoleIsPrimaryKey,
          (rb?['isPrimary'] ?? false) == true,
        );

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

  Future<bool> refreshCurrentUser(BuildContext context) async {
    debugPrint('refreshCurrentUser ▶︎ start');
    try {
      final okBiz = await fetchAndPersistUserBusiness(context);
      debugPrint('refreshCurrentUser ▶︎ fetchAndPersistUserBusiness = $okBiz');
    } catch (e, st) {
      debugPrint('refreshCurrentUser ❌ userBusiness error: $e\n$st');
    }

    final okUser = await fetchAndPersistCurrentUser(context);
    debugPrint('refreshCurrentUser ▶︎ fetchAndPersistCurrentUser = $okUser');
    debugPrint('refreshCurrentUser ◀︎ done');
    return okUser;
  }

  /// Ganti active business + set active role dari map roles
  Future<bool> switchActiveBusiness(String idBusiness) async {
    final prefs = await SharedPreferences.getInstance();

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

    await prefs.setString('activeBizId', target.idBusiness);
    await prefs.setString('activeBizName', target.name);
    await prefs.setString('activeBizUsername', target.username);
    await prefs.setString('activeBizLogoPath', target.logoPath);

    // update active role berdasarkan role map
    try {
      final roleMapStr = prefs.getString(kBusinessRolesKey);
      Map<String, dynamic>? roleMap;
      if (roleMapStr != null && roleMapStr.isNotEmpty) {
        roleMap = jsonDecode(roleMapStr) as Map<String, dynamic>;
      }

      final rb = (roleMap?[target.idBusiness] as Map?)?.cast<String, dynamic>();
      await prefs.setString(
        kActiveBizRoleIdKey,
        (rb?['idAdminRole'] ?? '').toString(),
      );
      await prefs.setString(
        kActiveBizRoleNameKey,
        (rb?['name'] ?? '').toString(),
      );
      await prefs.setBool(
        kActiveBizRoleIsPrimaryKey,
        (rb?['isPrimary'] ?? false) == true,
      );
    } catch (e) {
      debugPrint('switchActiveBusiness: update active role error: $e');
    }

    // snapshot
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

          final rb = (() {
            final roleMapStr = prefs.getString(kBusinessRolesKey);
            if (roleMapStr == null) return null;
            final Map<String, dynamic> rmap = jsonDecode(roleMapStr);
            return (rmap[target.idBusiness] as Map?)?.cast<String, dynamic>();
          })();

          snap['activeBusinessRole'] = {
            'idAdminRole': (rb?['idAdminRole'] ?? '').toString(),
            'name': (rb?['name'] ?? '').toString(),
            'isPrimary': (rb?['isPrimary'] ?? false) == true,
          };

          await prefs.setString(key, jsonEncode(snap));
        } catch (e) {
          debugPrint('switchActiveBusiness: update snapshot error: $e');
        }
      }
      await prefs.setString(kActiveAccountKey, emailKey);
    }

    // Jika perlu header khusus per bisnis:
    // try { ApiService.setActiveBusinessId(target.idBusiness); } catch (_) {}

    _error = null;
    notifyListeners();
    return true;
  }
}
