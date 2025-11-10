import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:wa_blast/app_nav.dart';
import 'package:wa_blast/providers/splash_provider.dart';
import 'package:wa_blast/services/api_service.dart';
import 'package:path/path.dart' as p;

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

/// =========================
/// Logging & Utilities
/// =========================
void _log(String tag, String message) => debugPrint('$tag $message');

String _maskSecret(String? s) {
  if (s == null || s.isEmpty) return '(empty)';
  if (s.length <= 4) return '*' * s.length;
  return '${s.substring(0, 1)}${'*' * (s.length - 2)}${s.substring(s.length - 1)}';
}

String _prettyJson(Object? data) {
  try {
    if (data == null) return 'null';
    if (data is String) {
      final decoded = json.decode(data);
      return const JsonEncoder.withIndent('  ').convert(decoded);
    }
    return const JsonEncoder.withIndent('  ').convert(data);
  } catch (_) {
    return data.toString();
  }
}

/// Selalu tunda ke post-frame; jangan memanggil notify sinkron.
extension _NotifyLater on ChangeNotifier {
  void notifyLater({String? tag}) {
    if (tag != null) _log(tag, '🕒 notifyLater() scheduled (post-frame)');
    WidgetsBinding.instance.addPostFrameCallback((_) {
      try {
        if (hasListeners) {
          notifyListeners();
          if (tag != null) {
            _log(tag, '🔄 notifyListeners() executed (post-frame)');
          }
        } else {
          if (tag != null) _log(tag, '⚠️ skipped notify (no listeners)');
        }
      } catch (e) {
        if (tag != null) _log(tag, '❌ notifyLater error: $e');
      }
    });
  }
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

  /// =========================
  /// Helpers anti “notify during build”
  /// =========================

  /// Tampilkan SnackBar di post-frame (aman dipanggil kapan pun).
  Future<void> _snackLater(
    BuildContext context, {
    required Widget content,
    Color? bg,
    Duration duration = const Duration(seconds: 4),
    String? tag,
    SnackBarAction? action,
  }) async {
    if (tag != null) _log(tag, '🕒 snackLater() scheduled (post-frame)');
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!context.mounted) {
        if (tag != null) _log(tag, '⚠️ context not mounted; skip SnackBar');
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          backgroundColor: bg,
          elevation: 6,
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          duration: duration,
          content: content,
          action: action,
        ),
      );
      if (tag != null) _log(tag, '🔔 SnackBar shown (post-frame)');
    });
  }

  /// =========================
  /// Penilaian sukses “app-level”
  /// =========================
  bool _isAppLevelSuccess({
    required int httpStatus,
    required Map<String, dynamic> body,
  }) {
    final okHttp = httpStatus >= 200 && httpStatus < 300;

    // Guard kata-kata error umum
    final lowerAll = body.values
        .map((v) => v.toString().toLowerCase())
        .join(' ');
    if (lowerAll.contains('wrong password') ||
        lowerAll.contains('invalid password') ||
        lowerAll.contains('password salah')) {
      return false;
    }

    // status: int → harus 2xx juga
    final s = body['status'];
    if (s is int) return okHttp && s >= 200 && s < 300;

    // success: bool → harus true
    final success = body['success'];
    if (success is bool) return okHttp && success;

    // fallback: HTTP saja
    return okHttp;
  }

  String _pickMsgCompat(
    Map<String, dynamic> j, {
    String fallback = 'Operation failed',
  }) {
    return (j['message'] ?? j['msg'] ?? fallback).toString();
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

  // === Helper: set active role hanya jika ada nilainya ===
  Future<void> _setActiveRoleIfPresent(
    SharedPreferences prefs,
    Map<String, dynamic>? rb,
  ) async {
    final id = (rb?['idAdminRole'] ?? '').toString().trim();
    if (id.isEmpty) {
      if (kDebugMode) {
        debugPrint('[AuthProvider] skip writing empty activeBizRoleId');
      }
      return; // jangan menimpa dengan kosong
    }
    await prefs.setString(kActiveBizRoleIdKey, id);
    await prefs.setString(
      kActiveBizRoleNameKey,
      (rb?['name'] ?? '').toString(),
    );
    await prefs.setBool(
      kActiveBizRoleIsPrimaryKey,
      (rb?['isPrimary'] ?? false) == true,
    );
  }

  Future<bool> createBusiness({
    required BuildContext context,
    required String name,
    required String username,
    String? category,
    File? logoFile,
  }) async {
    const tag = '🏢 [CreateBusiness]';
    final sw = Stopwatch()..start();

    _log(tag, '🚀 Start create business (name="$name", username="$username")');
    _isLoading = true;
    _error = null;
    notifyLater(tag: tag);

    try {
      // ===== VALIDASI WAJIB =====
      if (name.trim().isEmpty || username.trim().isEmpty) {
        _error = 'Name dan username wajib diisi';
        _log(tag, '❌ $_error');
        await _snackLater(
          context,
          tag: tag,
          bg: Colors.red.shade600,
          content: const Row(
            children: [
              Icon(Icons.error_outline, color: Colors.white),
              SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Please fill in both name and username.',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        );
        _isLoading = false;
        notifyLater(tag: tag);
        return false;
      }

      // ===== CEK TOKEN =====
      final prefs = await SharedPreferences.getInstance();
      final token = _accessToken?.isNotEmpty == true
          ? _accessToken!
          : (prefs.getString('accessToken') ?? '');
      if (token.isEmpty) {
        _error = 'Access token tidak tersedia. Silakan login dulu.';
        _log(tag, '❗ $_error');
        await _snackLater(
          context,
          tag: tag,
          bg: Colors.red.shade600,
          content: const Row(
            children: [
              Icon(Icons.error_outline, color: Colors.white),
              SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Access token tidak tersedia. Silakan login dulu.',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        );
        _isLoading = false;
        notifyLater(tag: tag);
        return false;
      }

      // ===== 1. Upload logo jika ada =====
      String logoField = '';
      if (logoFile != null) {
        _log(tag, '📤 Upload logo: ${logoFile.path}');
        final uploaded = await _uploadLogoAndGetFilename(logoFile);
        if (uploaded == null || uploaded.isEmpty) {
          _log(tag, '⚠️ Upload logo gagal, lanjut tanpa logo');
        } else {
          logoField = uploaded;
        }
      }

      // ===== 2. Siapkan payload =====
      final payload = <String, dynamic>{
        "name": name,
        "username": username,
        "category": category ?? '',
        "logo": logoField,
      };
      _log(tag, '📦 Payload:\n${_prettyJson(payload)}');

      // ===== 3. POST ke /business =====
      final res = await ApiService.postJson(
        '/business',
        payload,
        withAccessToken: true,
      );

      sw.stop();
      final raw = res.body;
      _log(tag, '◀︎ status=${res.statusCode} (${sw.elapsedMilliseconds} ms)');
      _log(
        tag,
        '🧾 body:\n${raw.length > 1200 ? raw.substring(0, 1200) + '…' : raw}',
      );

      Map<String, dynamic> j = {};
      try {
        j = (jsonDecode(raw) as Map).cast<String, dynamic>();
      } catch (_) {}

      final appOk = _isAppLevelSuccess(httpStatus: res.statusCode, body: j);
      final msg = _pickMsgCompat(j, fallback: 'Create business failed');

      if (!appOk) {
        _error = msg;
        _log(tag, '❌ FAIL: $_error');
        await _snackLater(
          context,
          tag: tag,
          bg: Colors.red.shade600,
          content: Row(
            children: [
              const Icon(Icons.error_outline, color: Colors.white),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  _error!,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        );
        _isLoading = false;
        notifyLater(tag: tag);
        return false;
      }

      // ===== 4. Ambil ID business dari response (opsional) =====
      String? newBizId;
      try {
        final data = (j['data'] ?? j) as Map<String, dynamic>;
        newBizId = (data['idBusiness'] ?? data['id'] ?? '').toString().trim();
      } catch (_) {}

      // ===== 5. Refresh data user & business =====
      final okRefresh = await refreshCurrentUser(context);
      _log(tag, '🔄 refreshCurrentUser = $okRefresh');

      if (newBizId != null && newBizId.isNotEmpty) {
        _log(tag, '⭐ Active business switched to $newBizId');
        await switchActiveBusiness(newBizId);
      }

      _isLoading = false;
      _error = null;
      notifyLater(tag: tag);
      _log(tag, '✅ Done (success=true)');
      return true;
    } catch (e, st) {
      sw.stop();
      _error = 'Error creating business: $e';
      _log(tag, '❌ Exception after ${sw.elapsedMilliseconds} ms: $e');
      _log(tag, '🧵 $st');

      await _snackLater(
        context,
        tag: tag,
        bg: Colors.red.shade600,
        content: const Row(
          children: [
            Icon(Icons.error_outline, color: Colors.white),
            SizedBox(width: 12),
            Expanded(
              child: Text(
                'Failed to create business.',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      );

      _isLoading = false;
      notifyLater(tag: tag);
      _log(tag, '🧯 Done (exception, success=false)');
      return false;
    }
  }

  // === Helper: ambil RB (role business) dari roleMap argumen atau prefs ===
  Map<String, dynamic>? _resolveRBForBusiness(
    String idBusiness,
    SharedPreferences prefs, {
    Map<String, dynamic>? roleMapArg,
  }) {
    try {
      Map<String, dynamic>? roleMap = roleMapArg;
      if (roleMap == null) {
        final s = prefs.getString(kBusinessRolesKey);
        if (s != null && s.isNotEmpty) {
          roleMap = (jsonDecode(s) as Map).cast<String, dynamic>();
        }
      }
      return (roleMap?[idBusiness] as Map?)?.cast<String, dynamic>();
    } catch (_) {
      return null;
    }
  }

  // === Helper: set active business + set active role (wajib) ===
  Future<void> _applyActiveBusinessAndRole({
    required SharedPreferences prefs,
    required String idBusiness,
    required String name,
    required String username,
    required String logoPath,
    Map<String, dynamic>? roleMap, // opsional; kalau null diambil dari prefs
  }) async {
    // set active business
    await prefs.setString('activeBizId', idBusiness);
    await prefs.setString('activeBizName', name);
    await prefs.setString('activeBizUsername', username);
    await prefs.setString('activeBizLogoPath', logoPath);

    // set active role → ambil dari roleMap (arg/prefs)
    final rb = _resolveRBForBusiness(idBusiness, prefs, roleMapArg: roleMap);
    await _setActiveRoleIfPresent(prefs, rb);

    if (kDebugMode) {
      final rid = (rb?['idAdminRole'] ?? '').toString();
      debugPrint(
        '[AuthProvider] _applyActiveBusinessAndRole -> biz=$idBusiness role=$rid',
      );
    }
  }

  // Tambahkan HELPER ini di dalam class AuthProvider
  Future<void> _clearActiveBusinessPrefs(SharedPreferences prefs) async {
    await prefs.remove('activeBizId');
    await prefs.remove('activeBizName');
    await prefs.remove('activeBizUsername');
    await prefs.remove('activeBizLogoPath');
    await prefs.remove(kActiveBizRoleIdKey);
    await prefs.remove(kActiveBizRoleNameKey);
    await prefs.remove(kActiveBizRoleIsPrimaryKey);
  }

  // Ganti seluruh method login(...) dengan versi ini
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

        // Build role map dari LOGIN response
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

        // set state
        _accessToken = accessToken;
        _refreshToken = refreshToken;
        _name = fullName.isNotEmpty ? fullName : null;
        _email = serverEmail;
        _isActivated = true;

        // persist basic
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('login_raw', rawBody);
        await prefs.setString('token', jsonEncode(tokenObj));
        await prefs.setString('user', jsonEncode(userObj));
        await prefs.setString(
          'business',
          jsonEncode(bizList),
        ); // simpan list (bisa kosong)
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
        await prefs.setString(kBusinessRolesKey, jsonEncode(roleMap));

        // === Branch A: business KOSONG → arahkan ke /register/business
        if (bizList.isEmpty) {
          await _clearActiveBusinessPrefs(prefs);

          // snapshot akun (tanpa activeBusiness)
          final accountSnapshot = {
            'token': tokenObj,
            'user': userObj,
            'business': bizList, // []
            'accessToken': _accessToken,
            'refreshToken': _refreshToken,
            'name': _name,
            'email': _email,
            'username': username,
            'photoPath': photoPath,
            'isActivated': _isActivated,
            'businessRoles': roleMap,
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

          // Info + navigasi
          await _snackLater(
            context,
            bg: Colors.blue.shade700,
            content: const Row(
              children: [
                Icon(Icons.info_outline, color: Colors.white),
                SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Hold up! You need to create your first business account before using WaveUp.',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
            duration: const Duration(seconds: 4),
          );

          nav?.pushNamedAndRemoveUntil('/register/business', (r) => false);

          _isLoading = false;
          notifyListeners();
          return true;
        }

        // === Branch B: ADA business → set active + ARAHKAN KE /splash
        final Map<String, dynamic>? firstBiz = bizList.isNotEmpty
            ? bizList.first
            : null;
        final String activeBizId = (firstBiz?['idBusiness'] ?? '').toString();
        final String activeBizName = (firstBiz?['name'] ?? '').toString();
        final String activeBizUsername = (firstBiz?['username'] ?? '')
            .toString();
        final String activeBizLogoPath =
            (firstBiz?['logoPath'] ?? firstBiz?['logo'] ?? '').toString();

        if (activeBizId.isNotEmpty) {
          await _applyActiveBusinessAndRole(
            prefs: prefs,
            idBusiness: activeBizId,
            name: activeBizName,
            username: activeBizUsername,
            logoPath: activeBizLogoPath,
            roleMap: roleMap,
          );
        } else {
          // data anomali: ada list tapi id kosong → bersihkan pointer
          await _clearActiveBusinessPrefs(prefs);
        }

        // snapshot akun
        final rbSnap = _resolveRBForBusiness(
          activeBizId,
          prefs,
          roleMapArg: roleMap,
        );
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
          if (activeBizId.isNotEmpty)
            'activeBusiness': {
              'idBusiness': activeBizId,
              'name': activeBizName,
              'username': activeBizUsername,
              'logoPath': activeBizLogoPath,
            },
          'businessRoles': roleMap,
          if ((rbSnap?['idAdminRole'] ?? '').toString().isNotEmpty)
            'activeBusinessRole': {
              'idAdminRole': (rbSnap?['idAdminRole'] ?? '').toString(),
              'name': (rbSnap?['name'] ?? '').toString(),
              'isPrimary': (rbSnap?['isPrimary'] ?? false) == true,
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

        // ⤵️ Tambahkan blok navigasi yang kamu minta
        if (activeBizId.isNotEmpty) {
          final sp = appNavigatorKey.currentContext?.read<SplashProvider>();
          sp?.resetNavigationGuards();
          sp?.abortDeepLink();
          appNavigatorKey.currentState?.pushNamedAndRemoveUntil(
            '/splash',
            (r) => false,
          );
        }

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
      if (activeRole != null &&
          ((activeRole['idAdminRole'] ?? '').toString().isNotEmpty)) {
        await _setActiveRoleIfPresent(prefs, activeRole);
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
        // 1) Kompres dulu
        final compressed = await _maybeCompressImage(
          organisationLogo,
          maxWidth: 1280,
          maxHeight: 1280,
          quality: 80,
        );

        // 2) Upload file hasil kompres (atau asli jika kompres gagal)
        uploadedFilename = await _uploadLogoAndGetFilename(compressed);
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
          'REGISTER STEP2 (logo=${uploadedFilename ?? '-'}) → refreshed user → /splash',
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
      if (_refreshToken != null) {
        await prefs.setString('refreshToken', _refreshToken!);
      }
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

      // persist roles
      await prefs.setString(kBusinessRolesKey, jsonEncode(roleMap));

      // set default active business + active role
      await _applyActiveBusinessAndRole(
        prefs: prefs,
        idBusiness: activeBizId,
        name: activeBizName,
        username: activeBizUsername,
        logoPath: activeBizLogoPath,
        roleMap: roleMap,
      );

      if (_email != null) {
        final rbSnap = _resolveRBForBusiness(
          activeBizId,
          prefs,
          roleMapArg: roleMap,
        );
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
          if ((rbSnap?['idAdminRole'] ?? '').toString().isNotEmpty)
            'activeBusinessRole': {
              'idAdminRole': (rbSnap?['idAdminRole'] ?? '').toString(),
              'name': (rbSnap?['name'] ?? '').toString(),
              'isPrimary': (rbSnap?['isPrimary'] ?? false) == true,
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

    // ambil detail business dari list agar bisa isi name/username/logoPath
    final bizList = await getBusinesses();
    final b = bizList.firstWhere(
      (x) => x.idBusiness == idBusiness,
      orElse: () => const BusinessInfo(
        idBusiness: '',
        name: '',
        username: '',
        logoPath: '',
      ),
    );

    await _applyActiveBusinessAndRole(
      prefs: prefs,
      idBusiness: idBusiness,
      name: b.name,
      username: b.username,
      logoPath: b.logoPath,
      // roleMap: null → baca dari prefs
    );

    // sinkronisasi snapshot (opsional / sesuai kode kamu sebelumnya)
    final emailKey = _email ?? prefs.getString(kActiveAccountKey);
    if (emailKey != null) {
      final key = 'account_$emailKey';
      final jsonStr = prefs.getString(key);
      if (jsonStr != null) {
        try {
          final Map<String, dynamic> snap = jsonDecode(jsonStr);
          final Map<String, dynamic> activeBiz =
              (snap['activeBusiness'] as Map?)?.cast<String, dynamic>() ?? {};
          activeBiz['idBusiness'] = idBusiness;
          activeBiz['name'] = b.name;
          activeBiz['username'] = b.username;
          activeBiz['logoPath'] = b.logoPath;

          // sinkronkan active role di snapshot juga (bila ada)
          final rb = _resolveRBForBusiness(idBusiness, prefs);
          if ((rb?['idAdminRole'] ?? '').toString().isNotEmpty) {
            snap['activeBusinessRole'] = {
              'idAdminRole': (rb?['idAdminRole'] ?? '').toString(),
              'name': (rb?['name'] ?? '').toString(),
              'isPrimary': (rb?['isPrimary'] ?? false) == true,
            };
          }

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

      // ——— Normalisasi daftar business untuk dipakai app
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

      // ——— Role map per business
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

      // ——— HORMATI activeBizId yang ada; hanya fallback jika belum ada / tidak valid
      final String? prevActiveId = prefs.getString('activeBizId');
      final ids = simplifiedBusiness
          .map((e) => (e['idBusiness'] ?? '').toString())
          .where((s) => s.isNotEmpty)
          .toList();

      String? nextActiveId = prevActiveId;
      if (nextActiveId == null ||
          nextActiveId.isEmpty ||
          !ids.contains(nextActiveId)) {
        // belum pernah set atau id lama tidak ada pada data terbaru → pilih pertama (kalau ada)
        nextActiveId = ids.isNotEmpty ? ids.first : null;
      }

      // Terapkan active business (hanya jika ada data)
      if (nextActiveId != null && nextActiveId.isNotEmpty) {
        final first = simplifiedBusiness.firstWhere(
          (m) => (m['idBusiness'] ?? '') == nextActiveId,
          orElse: () => simplifiedBusiness.first,
        );

        await _applyActiveBusinessAndRole(
          prefs: prefs,
          idBusiness: (first['idBusiness'] ?? '').toString(),
          name: (first['name'] ?? '').toString(),
          username: (first['username'] ?? '').toString(),
          logoPath: (first['logoPath'] ?? '').toString(),
          roleMap: roleMap,
        );

        // Sinkronkan snapshot akun aktif
        final rb = _resolveRBForBusiness(
          (first['idBusiness'] ?? '').toString(),
          prefs,
          roleMapArg: roleMap,
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
              if ((rb?['idAdminRole'] ?? '').toString().isNotEmpty) {
                snap['activeBusinessRole'] = {
                  'idAdminRole': (rb?['idAdminRole'] ?? '').toString(),
                  'name': (rb?['name'] ?? '').toString(),
                  'isPrimary': (rb?['isPrimary'] ?? false) == true,
                };
              }
              await prefs.setString(key, jsonEncode(snap));
            } catch (e) {
              debugPrint('SYNC SNAPSHOT (user business) ❌ $e');
            }
          }
        }
      } else {
        // Tidak ada business sama sekali → bersihkan pointer active (opsional)
        await prefs.remove('activeBizId');
        await prefs.remove('activeBizName');
        await prefs.remove('activeBizUsername');
        await prefs.remove('activeBizLogoPath');
        await prefs.remove(kActiveBizRoleIdKey);
        await prefs.remove(kActiveBizRoleNameKey);
        await prefs.remove(kActiveBizRoleIsPrimaryKey);
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
      // =========================================================
      // 1) Ambil data terbaru dari /user
      //    Struktur: { status, data: {...user}, business: [ {...}, ... ] }
      // =========================================================
      final res = await ApiService.get(context, '/user', withAccessToken: true);
      final raw = res.body;
      debugPrint(
        "REFRESH USER (via /user) ◀︎ ${res.statusCode} ${raw.length > 800 ? raw.substring(0, 800) + '…' : raw}",
      );

      if (res.statusCode < 200 || res.statusCode >= 300) {
        debugPrint("REFRESH USER ❌ status ${res.statusCode}");
        return false;
      }

      final Map<String, dynamic> root = jsonDecode(raw);
      final Map<String, dynamic> userObj =
          (root['data'] ?? const <String, dynamic>{}).cast<String, dynamic>();
      final List businessFull =
          (root['business'] as List?) ?? const <dynamic>[];

      final prefs = await SharedPreferences.getInstance();

      // =========================================================
      // 2) Simpan semua versi data "apa adanya" untuk keperluan debug/inspeksi
      // =========================================================
      await prefs.setString('user_fetch_raw', raw); // raw lengkap
      await prefs.setString(
        'user_full',
        jsonEncode(userObj),
      ); // objek user "full"
      await prefs.setString(
        'business_full',
        jsonEncode(businessFull),
      ); // list business "full"

      // =========================================================
      // 3) Update state & legacy keys dari USER
      // =========================================================
      final firstname = (userObj['firstname'] ?? '').toString();
      final lastname = (userObj['lastname'] ?? '').toString();
      final fullName = '$firstname $lastname'.trim();

      final serverEmail = (userObj['email'] ?? '').toString();
      final email = serverEmail.isNotEmpty ? serverEmail : (_email ?? '');
      final username = (userObj['username'] ?? '').toString();
      final photoPath = (userObj['photoPath'] ?? '').toString();
      final phone = (userObj['phone'] ?? '').toString();
      final hasPage = (userObj['hasPage'] ?? false) == true;
      final roleName = (userObj['userRoleName'] ?? '').toString();
      final idUser = (userObj['idUser'] ?? '').toString();
      final isDeactivated = (userObj['isDeactivated'] ?? false) == true;

      // set ke memori
      _name = fullName.isNotEmpty ? fullName : _name;
      _email = email.isNotEmpty ? email : _email;

      // persist (legacy keys yang dipakai bagian lain aplikasi)
      await prefs.setString('user', jsonEncode(userObj));
      if (_name != null) await prefs.setString('name', _name!);
      if (_email != null) await prefs.setString('email', _email!);
      await prefs.setString('username', username);
      await prefs.setString('photoPath', photoPath);
      await prefs.setString('phone', phone);
      await prefs.setBool('hasPage', hasPage);
      await prefs.setString('userRoleName', roleName);
      await prefs.setString('idUser', idUser);
      await prefs.setBool('isDeactivated', isDeactivated);

      // =========================================================
      // 4) Normalisasi BUSINESS → isi legacy key `business`
      //    sekaligus siapkan roleMap dari roleId/userRoleName
      // =========================================================
      final List<Map<String, dynamic>> simplifiedBusiness = businessFull
          .map<Map<String, dynamic>>((e) {
            final m = (e as Map).cast<String, dynamic>();
            return {
              'idBusiness': (m['idBusiness'] ?? '').toString(),
              'name': (m['name'] ?? '').toString(),
              'username': (m['username'] ?? '').toString(),
              'logoPath': (m['logoPath'] ?? m['logo'] ?? '').toString(),
            };
          })
          .toList();

      await prefs.setString(
        'business',
        jsonEncode(simplifiedBusiness),
      ); // legacy

      final Map<String, dynamic> roleMap = {};
      for (final e in businessFull) {
        final m = (e as Map).cast<String, dynamic>();
        final idBiz = (m['idBusiness'] ?? '').toString();
        if (idBiz.isEmpty) continue;
        roleMap[idBiz] = {
          'idAdminRole': (m['roleId'] ?? '').toString(),
          'name': (m['userRoleName'] ?? '').toString(),
          'isPrimary': false, // tidak ada info isPrimary di payload
        };
      }
      await prefs.setString(kBusinessRolesKey, jsonEncode(roleMap));

      // =========================================================
      // 5) Active Business:
      //    - hormati activeBizId lama jika masih valid
      //    - fallback ke bisnis pertama jika tidak ada/invalid
      //    - jika tidak ada business → bersihkan pointer active & active role
      // =========================================================
      final String? prevActiveId = prefs.getString('activeBizId');
      final ids = simplifiedBusiness
          .map((e) => (e['idBusiness'] ?? '').toString())
          .where((s) => s.isNotEmpty)
          .toList();

      String? nextActiveId = prevActiveId;
      if (nextActiveId == null ||
          nextActiveId.isEmpty ||
          !ids.contains(nextActiveId)) {
        nextActiveId = ids.isNotEmpty ? ids.first : null;
      }

      if (nextActiveId != null && nextActiveId.isNotEmpty) {
        final selected = simplifiedBusiness.firstWhere(
          (m) => (m['idBusiness'] ?? '') == nextActiveId,
          orElse: () => simplifiedBusiness.first,
        );

        await _applyActiveBusinessAndRole(
          prefs: prefs,
          idBusiness: (selected['idBusiness'] ?? '').toString(),
          name: (selected['name'] ?? '').toString(),
          username: (selected['username'] ?? '').toString(),
          logoPath: (selected['logoPath'] ?? '').toString(),
          roleMap: roleMap, // penting agar active role ikut ter-set
        );

        // =======================================================
        // 6) Sinkronkan snapshot akun aktif (account_<email>)
        // =======================================================
        final rb = _resolveRBForBusiness(
          (selected['idBusiness'] ?? '').toString(),
          prefs,
          roleMapArg: roleMap,
        );
        final emailKey = _email ?? prefs.getString(kActiveAccountKey);
        if (emailKey != null && emailKey.isNotEmpty) {
          final key = 'account_$emailKey';
          final snapStr = prefs.getString(key);
          if (snapStr != null) {
            try {
              final snap = jsonDecode(snapStr) as Map<String, dynamic>;
              snap['user'] = userObj; // full user
              snap['name'] = _name;
              snap['email'] = _email;
              snap['username'] = username;
              snap['photoPath'] = photoPath;

              snap['business'] = simplifiedBusiness; // legacy list
              snap['business_full'] = businessFull; // simpan juga full
              snap['activeBusiness'] = {
                'idBusiness': selected['idBusiness'],
                'name': selected['name'],
                'username': selected['username'],
                'logoPath': selected['logoPath'],
              };
              snap['businessRoles'] = roleMap;
              if ((rb?['idAdminRole'] ?? '').toString().isNotEmpty) {
                snap['activeBusinessRole'] = {
                  'idAdminRole': (rb?['idAdminRole'] ?? '').toString(),
                  'name': (rb?['name'] ?? '').toString(),
                  'isPrimary': (rb?['isPrimary'] ?? false) == true,
                };
              }
              await prefs.setString(key, jsonEncode(snap));
            } catch (e) {
              debugPrint('SYNC SNAPSHOT (refreshCurrentUser) ❌ $e');
            }
          }
        }
      } else {
        // tidak punya business → bersihkan pointer active & role
        await prefs.remove('activeBizId');
        await prefs.remove('activeBizName');
        await prefs.remove('activeBizUsername');
        await prefs.remove('activeBizLogoPath');
        await prefs.remove(kActiveBizRoleIdKey);
        await prefs.remove(kActiveBizRoleNameKey);
        await prefs.remove(kActiveBizRoleIsPrimaryKey);

        // bersihkan dari snapshot bila ada
        final emailKey = _email ?? prefs.getString(kActiveAccountKey);
        if (emailKey != null && emailKey.isNotEmpty) {
          final key = 'account_$emailKey';
          final snapStr = prefs.getString(key);
          if (snapStr != null) {
            try {
              final snap = jsonDecode(snapStr) as Map<String, dynamic>;
              snap['user'] = userObj;
              snap['name'] = _name;
              snap['email'] = _email;
              snap['username'] = username;
              snap['photoPath'] = photoPath;
              snap['business'] = simplifiedBusiness;
              snap['business_full'] = businessFull;
              snap.remove('activeBusiness');
              snap.remove('activeBusinessRole');
              await prefs.setString(key, jsonEncode(snap));
            } catch (e) {
              debugPrint('SYNC SNAPSHOT (no business) ❌ $e');
            }
          }
        }
      }

      notifyListeners();
      debugPrint('refreshCurrentUser ◀︎ done');
      return true;
    } catch (e, st) {
      debugPrint('refreshCurrentUser ❌ $e\n$st');
      return false;
    }
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

    await _applyActiveBusinessAndRole(
      prefs: prefs,
      idBusiness: target.idBusiness,
      name: target.name,
      username: target.username,
      logoPath: target.logoPath,
    );

    // snapshot
    final emailKey = _email ?? prefs.getString(kActiveAccountKey);
    if (emailKey != null && emailKey.isNotEmpty) {
      final key = 'account_$emailKey';
      final snapStr = prefs.getString(key);
      if (snapStr != null) {
        try {
          final snap = jsonDecode(snapStr) as Map<String, dynamic>;
          snap['activeBusiness'] = {
            'idBusiness': target.idBusiness,
            'name': target.name,
            'username': target.username,
            'logoPath': target.logoPath,
          };
          final rb = _resolveRBForBusiness(target.idBusiness, prefs);
          if ((rb?['idAdminRole'] ?? '').toString().isNotEmpty) {
            snap['activeBusinessRole'] = {
              'idAdminRole': (rb?['idAdminRole'] ?? '').toString(),
              'name': (rb?['name'] ?? '').toString(),
              'isPrimary': (rb?['isPrimary'] ?? false) == true,
            };
          }
          await prefs.setString(key, jsonEncode(snap));
        } catch (e) {
          debugPrint('switchActiveBusiness: update snapshot error: $e');
        }
      }
      await prefs.setString(kActiveAccountKey, emailKey);
    }

    _error = null;
    notifyListeners();
    return true;
  }

  /// =========================
  /// Deactivate & Delete Account
  /// =========================

  // ---------- Dialog helpers (UI) ----------
  Future<String?> _showPasswordDialog(
    BuildContext context, {
    required String title,
    String subtitle = 'Please enter your account password to continue.',
  }) async {
    final controller = TextEditingController();
    String? errorText;
    bool obscured = true;

    return showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setState) {
            return AlertDialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              title: Row(
                children: [
                  const Icon(Icons.lock_outline, size: 22),
                  const SizedBox(width: 8),
                  Expanded(child: Text(title)),
                ],
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      subtitle,
                      style: Theme.of(
                        ctx,
                      ).textTheme.bodyMedium?.copyWith(color: Colors.grey[700]),
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: controller,
                    obscureText: obscured,
                    decoration: InputDecoration(
                      labelText: 'Password',
                      hintText: 'Your account password',
                      errorText: errorText,
                      prefixIcon: const Icon(Icons.password_outlined),
                      suffixIcon: IconButton(
                        tooltip: obscured ? 'Show' : 'Hide',
                        icon: Icon(
                          obscured ? Icons.visibility : Icons.visibility_off,
                        ),
                        onPressed: () => setState(() => obscured = !obscured),
                      ),
                      border: const OutlineInputBorder(),
                    ),
                    onSubmitted: (_) => setState(() {
                      if (controller.text.trim().isEmpty) {
                        errorText = 'Password is required';
                      } else {
                        errorText = null;
                        Navigator.of(ctx).pop(controller.text.trim());
                      }
                    }),
                  ),
                ],
              ),
              actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(ctx).pop(null),
                  child: const Text('Cancel'),
                  style: TextButton.styleFrom(
                    foregroundColor: Colors.blue.shade700,
                  ),
                ),
                ElevatedButton(
                  onPressed: () {
                    final val = controller.text.trim();
                    if (val.isEmpty) {
                      setState(() => errorText = 'Password is required');
                      return;
                    }
                    Navigator.of(ctx).pop(val);
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red.shade600,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  child: const Text('Continue'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<bool?> _showConfirmDialog(
    BuildContext context, {
    required String title,
    required String message,
    String positiveText = 'Yes, continue',
    String negativeText = 'No',
    bool danger = true,
  }) async {
    return showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: Row(
            children: [
              Icon(
                danger ? Icons.warning_amber_rounded : Icons.help_outline,
                color: danger ? Colors.red.shade600 : null,
              ),
              const SizedBox(width: 8),
              Expanded(child: Text(title)),
            ],
          ),
          content: Text(message, style: Theme.of(ctx).textTheme.bodyMedium),
          actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
          actions: [
            OutlinedButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.blue.shade700,
                side: BorderSide(color: Colors.blue.shade700),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              child: Text(negativeText),
            ),
            ElevatedButton(
              onPressed: () => Navigator.of(ctx).pop(true),
              style: ElevatedButton.styleFrom(
                backgroundColor: danger
                    ? Colors.red.shade600
                    : Colors.blue.shade700,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              child: Text(positiveText),
            ),
          ],
        );
      },
    );
  }

  // ---------- Public flows (UI + API) ----------
  /// Flow DEACTIVATE:
  /// 1) Password dialog → 2) Confirm Yes/No → 3) Call deactivateAccount(password)
  Future<void> startDeactivateFlow(BuildContext context) async {
    const tag = '🛑 [DeactivateFlow]';
    _log(tag, '▶︎ open password dialog');

    final pwd = await _showPasswordDialog(
      context,
      title: 'Deactivate Account',
      subtitle: 'To deactivate your account, please confirm your password.',
    );
    if (pwd == null) {
      _log(tag, '⏹ cancelled at password step');
      return;
    }

    final ok = await _showConfirmDialog(
      context,
      title: 'Are you sure?',
      message:
          'Your account will be deactivated. You can reactivate later by logging in again (depending on server policy). Continue?',
      positiveText: 'Yes, deactivate',
      negativeText: 'No',
      danger: true,
    );
    if (ok != true) {
      _log(tag, '⏹ cancelled at confirm step');
      return;
    }

    _log(tag, '✅ calling deactivateAccount()');
    await deactivateAccount(context, password: pwd);
  }

  /// Flow DELETE PERMANENT:
  /// 1) Password dialog → 2) Confirm Yes/No → 3) Call deleteAccountPermanently(password)
  Future<void> startDeleteFlow(BuildContext context) async {
    const tag = '🗑️ [DeleteFlow]';
    _log(tag, '▶︎ open password dialog');

    final pwd = await _showPasswordDialog(
      context,
      title: 'Delete Account Permanently',
      subtitle:
          'This action is irreversible. Please enter your password to proceed.',
    );
    if (pwd == null) {
      _log(tag, '⏹ cancelled at password step');
      return;
    }

    final ok = await _showConfirmDialog(
      context,
      title: 'Delete permanently?',
      message:
          'All your data may be removed permanently and cannot be recovered. Do you really want to delete your account?',
      positiveText: 'Yes, delete',
      negativeText: 'No',
      danger: true,
    );
    if (ok != true) {
      _log(tag, '⏹ cancelled at confirm step');
      return;
    }

    _log(tag, '✅ calling deleteAccountPermanently()');
    await deleteAccountPermanently(context, password: pwd);
  }

  // ---------- Core API callers (unchanged) ----------
  /// Helper kecil untuk POST ke endpoint sensitif (dengan access token)
  ///
  /// Evaluasi sukses versi “app-level”:
  /// - HTTP sukses (2xx) saja TIDAK cukup.
  /// - Jika body punya `status` (int), maka wajib juga 2xx.
  /// - Jika body punya `success` (bool), wajib true.
  /// - Jika pesan mengandung indikasi error (mis. Wrong password), dianggap gagal.
  Future<Map<String, dynamic>> _postSensitiveAccountAction(
    BuildContext context, {
    required String endpoint,
    required String password,
  }) async {
    final body = {"password": password};

    final res = await ApiService.postJson(
      endpoint,
      body,
      withAccessToken: true,
    );

    final raw = res.body;
    debugPrint(
      "ACCOUNT ACTION $endpoint ◀︎ ${res.statusCode} ${raw.length > 500 ? raw.substring(0, 500) + '…' : raw}",
    );

    Map<String, dynamic> decoded = {};
    try {
      decoded = (jsonDecode(raw) as Map).cast<String, dynamic>();
    } catch (_) {
      // biarkan kosong, nanti _pickMsg pakai fallback
    }

    return {"statusCode": res.statusCode, "json": decoded, "raw": raw};
  }

  Future<bool> deactivateAccount(
    BuildContext context, {
    required String password,
  }) async {
    const tag = '🛑 [DeactivateAccount]';
    final sw = Stopwatch()..start();

    _log(tag, '🚀 Start deactivate');
    _isLoading = true;
    _error = null;
    notifyLater(tag: tag);

    _log(tag, '📥 Input: password="${_maskSecret(password)}"');

    try {
      _log(tag, '📤 _postSensitiveAccountAction("/user/deactivate") …');
      final result = await _postSensitiveAccountAction(
        context,
        endpoint: '/user/deactivate',
        password: password,
      );

      sw.stop();
      _log(tag, '⏱️ ${sw.elapsedMilliseconds} ms');

      final statusCode = (result['statusCode'] as int?) ?? -1;
      final rawJson = result['json'];
      Map<String, dynamic> j;
      if (rawJson is Map) {
        j = rawJson.cast<String, dynamic>();
      } else if (rawJson is String) {
        try {
          j = (json.decode(rawJson) as Map).cast<String, dynamic>();
        } catch (_) {
          j = <String, dynamic>{'raw': rawJson};
        }
      } else {
        j = const <String, dynamic>{};
      }

      _log(tag, '📦 statusCode=$statusCode');
      _log(tag, '🧾 JSON:\n${_prettyJson(j)}');

      final appOk = _isAppLevelSuccess(httpStatus: statusCode, body: j);
      final msg = _pickMsgCompat(j, fallback: 'Deactivate account failed');
      _log(tag, '🧠 appOk=$appOk | msg="$msg"');

      if (appOk) {
        await _snackLater(
          context,
          tag: tag,
          bg: Colors.green.shade600,
          content: Row(
            children: const [
              Icon(Icons.check_circle_outline, color: Colors.white),
              SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Account deactivated',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          action: SnackBarAction(
            label: 'OK',
            textColor: Colors.white,
            onPressed: () =>
                ScaffoldMessenger.of(context).hideCurrentSnackBar(),
          ),
        );

        await logout(context);
        _log(tag, '🚪 logout() selesai');

        _isLoading = false;
        notifyLater(tag: tag);
        _log(tag, '🎉 Done (success=true)');
        return true;
      } else {
        _error = msg.isNotEmpty ? msg : 'Deactivate account failed';
        _log(tag, '❗ FAIL: $_error');

        await _snackLater(
          context,
          tag: tag,
          bg: Colors.red.shade600,
          content: Row(
            children: [
              const Icon(Icons.error_outline, color: Colors.white),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  _error!,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        );

        _isLoading = false;
        notifyLater(tag: tag);
        _log(tag, '🧯 Done (success=false)');
        return false;
      }
    } catch (e, st) {
      sw.stop();
      _error = 'Error deactivating account: $e';
      _log(tag, '❌ Exception after ${sw.elapsedMilliseconds} ms: $e');
      _log(tag, '🧵 $st');

      await _snackLater(
        context,
        tag: tag,
        bg: Colors.red.shade600,
        content: const Row(
          children: [
            Icon(Icons.error_outline, color: Colors.white),
            SizedBox(width: 12),
            Expanded(
              child: Text(
                'Failed to deactivate account.',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      );

      _isLoading = false;
      notifyLater(tag: tag);
      _log(tag, '🧯 Done (exception, success=false)');
      return false;
    }
  }

  /// =================================================
  ///  deleteAccountPermanently dengan debug komplit
  /// =================================================
  Future<bool> deleteAccountPermanently(
    BuildContext context, {
    required String password,
  }) async {
    const tag = '🗑️ [DeleteAccount]';
    final sw = Stopwatch()..start();

    _log(tag, '🚀 Start delete permanently');
    _isLoading = true;
    _error = null;
    notifyLater(tag: tag);

    _log(tag, '📥 Input: password="${_maskSecret(password)}"');

    try {
      _log(tag, '📤 _postSensitiveAccountAction("/user/delete-permanently") …');
      final result = await _postSensitiveAccountAction(
        context,
        endpoint: '/user/delete-permanently',
        password: password,
      );

      sw.stop();
      _log(tag, '⏱️ ${sw.elapsedMilliseconds} ms');

      final statusCode = (result['statusCode'] as int?) ?? -1;
      final rawJson = result['json'];
      Map<String, dynamic> j;
      if (rawJson is Map) {
        j = rawJson.cast<String, dynamic>();
      } else if (rawJson is String) {
        try {
          j = (json.decode(rawJson) as Map).cast<String, dynamic>();
        } catch (_) {
          j = <String, dynamic>{'raw': rawJson};
        }
      } else {
        j = const <String, dynamic>{};
      }

      _log(tag, '📦 statusCode=$statusCode');
      _log(tag, '🧾 JSON:\n${_prettyJson(j)}');

      final appOk = _isAppLevelSuccess(httpStatus: statusCode, body: j);
      final msg = _pickMsgCompat(j, fallback: 'Delete account failed');
      _log(tag, '🧠 appOk=$appOk | msg="$msg"');

      if (appOk) {
        await _snackLater(
          context,
          tag: tag,
          bg: Colors.green.shade600,
          content: Row(
            children: const [
              Icon(Icons.check_circle_outline, color: Colors.white),
              SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Account deleted permanently',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          action: SnackBarAction(
            label: 'OK',
            textColor: Colors.white,
            onPressed: () =>
                ScaffoldMessenger.of(context).hideCurrentSnackBar(),
          ),
        );

        await logout(context);
        _log(tag, '🚪 logout() selesai');

        _isLoading = false;
        notifyLater(tag: tag);
        _log(tag, '🎉 Done (success=true)');
        return true;
      } else {
        _error = msg.isNotEmpty ? msg : 'Delete account failed';
        _log(tag, '❗ FAIL: $_error');

        await _snackLater(
          context,
          tag: tag,
          bg: Colors.red.shade600,
          content: Row(
            children: [
              const Icon(Icons.error_outline, color: Colors.white),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  _error!,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          action: SnackBarAction(
            label: 'DISMISS',
            textColor: Colors.white,
            onPressed: () =>
                ScaffoldMessenger.of(context).hideCurrentSnackBar(),
          ),
        );

        _isLoading = false;
        notifyLater(tag: tag);
        _log(tag, '🧯 Done (success=false)');
        return false;
      }
    } catch (e, st) {
      sw.stop();
      _error = 'Error deleting account: $e';
      _log(tag, '❌ Exception after ${sw.elapsedMilliseconds} ms: $e');
      _log(tag, '🧵 $st');

      await _snackLater(
        context,
        tag: tag,
        bg: Colors.red.shade600,
        content: const Row(
          children: [
            Icon(Icons.error_outline, color: Colors.white),
            SizedBox(width: 12),
            Expanded(
              child: Text(
                'Failed to delete account.',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      );

      _isLoading = false;
      notifyLater(tag: tag);
      _log(tag, '🧯 Done (exception, success=false)');
      return false;
    }
  }

  /// Kompres gambar agar lebih kecil sebelum upload.
  /// - Target: sisi terpanjang maksimal 1280px, kualitas 80 (jpeg).
  /// - Jika hasil kompres gagal/kosong, fallback ke file asli.
  /// - Jika file sudah cukup kecil (< 800 KB), skip kompres.
  Future<File> _maybeCompressImage(
    File input, {
    int maxWidth = 1280,
    int maxHeight = 1280,
    int quality = 80,
    int skipBelowBytes = 800 * 1024, // 800 KB
  }) async {
    try {
      final originalSize = await input.length();
      if (originalSize < skipBelowBytes) {
        // Sudah kecil — tidak perlu kompres
        return input;
      }

      // Tentukan ekstensi output (jpeg)
      final dir = input.parent.path;
      final base = p.basenameWithoutExtension(input.path);
      final outPath = p.join(dir, '${base}_cmp.jpg');

      final result = await FlutterImageCompress.compressWithFile(
        input.absolute.path,
        minWidth: maxWidth,
        minHeight: maxHeight,
        quality: quality,
        format: CompressFormat.jpeg,
      );

      if (result == null || result.isEmpty) {
        // Kompres gagal → pakai file asli
        return input;
      }

      final outFile = File(outPath);
      await outFile.writeAsBytes(result, flush: true);

      // Jika kompresan tidak lebih kecil, pakai yang asli
      final newSize = await outFile.length();
      if (newSize >= originalSize) {
        try {
          await outFile.delete();
        } catch (_) {}
        return input;
      }
      return outFile;
    } catch (_) {
      // Gagal kompres (misal format tidak didukung) → pakai file asli
      return input;
    }
  }
}
