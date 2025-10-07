// lib/providers/hr_provider.dart
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:wa_blast/core/provider_helper.dart';
import 'package:wa_blast/providers/auth_provider.dart';
import 'package:wa_blast/screens/register/link/link_register_stepper_wrapper.dart'; // BizIdCache, ApiJson, FetchHelper, PageMeta

/// =========================
/// MODELS
/// =========================

@immutable
class InviteData {
  final String email;
  final String token;
  final String businessName;
  final String? businessLogo;

  const InviteData({
    required this.email,
    required this.token,
    required this.businessName,
    this.businessLogo,
  });

  factory InviteData.fromJson(String token, Map<String, dynamic> j) {
    return InviteData(
      email: (j['email'] ?? '').toString(),
      token: token,
      businessName: (j['business_name'] ?? j['business']?['name'] ?? '')
          .toString(),
      businessLogo: (j['business_logo'] ?? j['business']?['logo'])?.toString(),
    );
  }
}

@immutable
class HrRole {
  final String id;
  final String name;
  final bool isPrimary;
  final List<String> permissions; // optional, bisa kosong

  const HrRole({
    required this.id,
    required this.name,
    this.isPrimary = false,
    this.permissions = const [],
  });

  factory HrRole.fromJson(Map<String, dynamic> j) => HrRole(
    id: (j['id'] ?? j['idAdminRole'] ?? j['role_id'] ?? '').toString(),
    name: (j['name'] ?? '').toString(),
    isPrimary: (j['isPrimary'] ?? j['is_primary'] ?? false) == true,
    permissions: ((j['permissions'] as List?) ?? const [])
        .map((e) => e.toString())
        .toList(),
  );

  Map<String, dynamic> toJson() => {
    'name': name,
    if (permissions.isNotEmpty) 'permissions': permissions,
  };
}

@immutable
class HrInvitePreview {
  final String email;
  final String businessId;
  final String businessName;
  final String businessLogo;
  final String roleId;
  final String roleName;
  final String token;

  const HrInvitePreview({
    required this.email,
    required this.businessId,
    required this.businessName,
    required this.businessLogo,
    required this.roleId,
    required this.roleName,
    required this.token,
  });

  factory HrInvitePreview.fromJson(Map<String, dynamic> j) => HrInvitePreview(
    email: (j['email'] ?? '').toString(),
    businessId: (j['business']?['id'] ?? '').toString(),
    businessName: (j['business']?['name'] ?? '').toString(),
    businessLogo: (j['business']?['logo'] ?? j['business']?['logoPath'] ?? '')
        .toString(),
    roleId: (j['role']?['id'] ?? '').toString(),
    roleName: (j['role']?['name'] ?? '').toString(),
    token: (j['token'] ?? '').toString(),
  );
}

@immutable
class HrInviteHistoryItem {
  final String idInvite;
  final String email;
  final String roleId;
  final String roleName;
  final bool isPrimaryRole;
  final DateTime? expiresAt;
  final DateTime? usedAt;

  const HrInviteHistoryItem({
    required this.idInvite,
    required this.email,
    required this.roleId,
    required this.roleName,
    required this.isPrimaryRole,
    this.expiresAt,
    this.usedAt,
  });

  factory HrInviteHistoryItem.fromJson(Map<String, dynamic> j) {
    DateTime? _dt(String? s) =>
        s == null || s.isEmpty ? null : DateTime.tryParse(s);
    return HrInviteHistoryItem(
      idInvite: (j['idHrInvite'] ?? j['id'] ?? '').toString(),
      email: (j['email'] ?? '').toString(),
      roleId: (j['adminRole']?['idAdminRole'] ?? j['role']?['id'] ?? '')
          .toString(),
      roleName: (j['adminRole']?['name'] ?? j['role']?['name'] ?? '')
          .toString(),
      isPrimaryRole: (j['adminRole']?['isPrimary'] ?? false) == true,
      expiresAt: _dt(j['expires_at']?.toString()),
      usedAt: _dt(j['used_at']?.toString()),
    );
  }
}

@immutable
class InviteSubmitResult {
  final Map<String, dynamic> user; // minimal fields, bebas dipakai UI
  final Map<String, dynamic> token; // access_token, refresh_token

  const InviteSubmitResult({required this.user, required this.token});

  factory InviteSubmitResult.fromJson(Map<String, dynamic> j) =>
      InviteSubmitResult(
        user: (j['data'] as Map?)?.cast<String, dynamic>() ?? const {},
        token: (j['token'] as Map?)?.cast<String, dynamic>() ?? const {},
      );
}

/// =========================
/// Admin Menu Models (untuk builder payload role.menu)
/// =========================

@immutable
class AdminSubmenu {
  final int id;
  final String name;
  final String page;
  final String icon;

  const AdminSubmenu({
    required this.id,
    required this.name,
    required this.page,
    required this.icon,
  });

  factory AdminSubmenu.fromJson(Map<String, dynamic> j) => AdminSubmenu(
    id: (j['id'] as num?)?.toInt() ?? 0,
    name: (j['name'] ?? '').toString(),
    page: (j['page'] ?? '').toString(),
    icon: (j['icon'] ?? '').toString(),
  );
}

@immutable
class AdminMenu {
  final int id;
  final String name;
  final String page;
  final String icon;
  final List<AdminSubmenu> submenu;

  const AdminMenu({
    required this.id,
    required this.name,
    required this.page,
    required this.icon,
    required this.submenu,
  });

  factory AdminMenu.fromJson(Map<String, dynamic> j) => AdminMenu(
    id: (j['id'] as num?)?.toInt() ?? 0,
    name: (j['name'] ?? '').toString(),
    page: (j['page'] ?? '').toString(),
    icon: (j['icon'] ?? '').toString(),
    submenu: ((j['submenu'] as List?) ?? const [])
        .map((e) => AdminSubmenu.fromJson((e as Map).cast<String, dynamic>()))
        .toList(),
  );
}

String? extractInviteTokenFromUrl(String url) {
  try {
    final u = Uri.parse(url);

    // 1) Coba ambil dari fallback query param (kalau ada)
    final fb = u.queryParameters['fallback'];
    if (fb != null && fb.isNotEmpty) {
      final fu = Uri.parse(fb);
      if (fu.pathSegments.isNotEmpty) return fu.pathSegments.last;
    }

    // 2) Ambil dari URL utama (custom scheme atau https)
    if (u.pathSegments.isNotEmpty) return u.pathSegments.last;
    return null;
  } catch (_) {
    return null;
  }
}

/// =========================
/// PROVIDER
/// =========================

class HrProvider extends ChangeNotifier {
  // ====== CONFIGURABLE PATHS (ubah jika backend beda) ======
  String _rolesListPath(String bizId) =>
      '/waveup/$bizId/role'; // <= LIST & CREATE ROLE SESUAI SPEK BARU
  String _rolesBase(String bizId) =>
      '/waveup/$bizId/hr/role'; // (legacy) untuk UPDATE/DELETE bila diperlukan
  String _roleDetail(String bizId, String id) =>
      '/waveup/$bizId/hr/role/$id'; // (legacy) untuk UPDATE/DELETE
  String _invitePath(String bizId) => '/waveup/$bizId/hr/invite';
  String _inviteHistoryPath(String bizId) => '/waveup/$bizId/hr/history';
  String _inviteTokenPath(String token) => '/waveup/invite/$token';
  String _adminMenuPath(String bizId) => '/waveup/$bizId/admin/menu';

  // ====== STATE: Roles ======
  final List<HrRole> _roles = [];
  bool _loadingRoles = false;
  String? _rolesError;
  PageMeta? _pageRoles;

  List<HrRole> get roles => List.unmodifiable(_roles);
  bool get loadingRoles => _loadingRoles;
  String? get rolesError => _rolesError;
  PageMeta? get pageRoles => _pageRoles;

  // ====== STATE: Invite History ======
  final List<HrInviteHistoryItem> _history = [];
  bool _loadingHistory = false;
  String? _historyError;
  PageMeta? _pageHistory;

  List<HrInviteHistoryItem> get history => List.unmodifiable(_history);
  bool get loadingHistory => _loadingHistory;
  String? get historyError => _historyError;
  PageMeta? get pageHistory => _pageHistory;

  // ====== STATE: Admin Menus (untuk payload role.menu) ======
  final List<AdminMenu> _adminMenus = [];
  bool _loadingAdminMenus = false;
  String? _adminMenusError;

  List<AdminMenu> get adminMenus => List.unmodifiable(_adminMenus);
  bool get loadingAdminMenus => _loadingAdminMenus;
  String? get adminMenusError => _adminMenusError;

  // ====== STATE: Actions / Errors ======
  bool _submitting = false;
  String? _lastError;
  String? _lastMessage; // success message, e.g. "Undangan berhasil dikirim"
  String? get lastError => _lastError;
  String? get lastMessage => _lastMessage;
  bool get submitting => _submitting;

  void _setSubmitting(bool v) {
    _submitting = v;
    notifyListeners();
  }

  void _setRolesLoading(bool v) {
    _loadingRoles = v;
    notifyListeners();
  }

  void _setHistoryLoading(bool v) {
    _loadingHistory = v;
    notifyListeners();
  }

  void _setAdminMenusLoading(bool v) {
    _loadingAdminMenus = v;
    notifyListeners();
  }

  void _setRolesError(String? e) {
    _rolesError = e;
    notifyListeners();
  }

  void _setHistoryError(String? e) {
    _historyError = e;
    notifyListeners();
  }

  void _setAdminMenusError(String? e) {
    _adminMenusError = e;
    notifyListeners();
  }

  String? consumeLastError() {
    final e = _lastError;
    _lastError = null;
    return e;
  }

  String? consumeLastMessage() {
    final m = _lastMessage;
    _lastMessage = null;
    return m;
  }

  Future<String?> _requireBizId() async {
    final bizId = await BizIdCache.get();
    if (bizId == null || bizId.isEmpty) {
      _lastError = "Business ID is not available.";
      if (kDebugMode) debugPrint("[HrProvider] ❌ Business ID null/empty");
      notifyListeners();
      return null;
    }
    return bizId;
  }

  /// =========================
  /// ROLES - LIST
  /// =========================

  Future<void> fetchRoles(BuildContext context) async {
    final bizId = await _requireBizId();
    if (bizId == null) return;

    _setRolesError(null);
    _setRolesLoading(true);

    try {
      final result = await FetchHelper.fetchList<HrRole>(
        context: context,
        path: _rolesListPath(bizId), // GET /waveup/{bizId}/role
        parser: (json) => HrRole.fromJson(json),
      );

      _roles
        ..clear()
        ..addAll(result?.items ?? const []);
      _pageRoles = result?.page;

      if (kDebugMode) {
        debugPrint('[HrProvider] roles: ${_roles.length}');
        debugPrint('[HrProvider] page: $_pageRoles');
      }
      notifyListeners();
    } catch (e, st) {
      _roles.clear();
      _pageRoles = null;
      _setRolesError(e.toString());
      if (kDebugMode) {
        debugPrint('[HrProvider] fetchRoles ERROR: $e');
        debugPrint('$st');
      }
    } finally {
      _setRolesLoading(false);
    }
  }

  /// =========================
  /// ADMIN MENUS - untuk builder payload role.menu
  /// =========================
  Future<void> fetchAdminMenus(BuildContext context) async {
    final bizId = await _requireBizId();
    if (bizId == null) return;

    _setAdminMenusError(null);
    _setAdminMenusLoading(true);

    try {
      final result = await FetchHelper.fetchList<AdminMenu>(
        context: context,
        path: _adminMenuPath(bizId), // GET /waveup/{bizId}/admin/menu
        parser: (json) => AdminMenu.fromJson(json),
      );

      _adminMenus
        ..clear()
        ..addAll(result?.items ?? const []);
      if (kDebugMode) {
        debugPrint('[HrProvider] adminMenus: ${_adminMenus.length}');
      }
      notifyListeners();
    } catch (e, st) {
      _adminMenus.clear();
      _setAdminMenusError(e.toString());
      if (kDebugMode) {
        debugPrint('[HrProvider] fetchAdminMenus ERROR: $e');
        debugPrint('$st');
      }
    } finally {
      _setAdminMenusLoading(false);
    }
  }

  /// =========================
  /// ROLES - CREATE / UPDATE / DELETE
  /// =========================

  /// Create Role (payload baru: name + menu)
  /// [menuSelections] = Map<menuId, Set<submenuId>>.
  /// - Jika Set kosong → kirim "submenu": []
  /// - Field "permissions" tetap didukung (tidak mengurangi konteks lama)
  Future<HrRole?> createRole(
    BuildContext context, {
    required String name,
    Map<int, Set<int>> menuSelections = const {},
    List<String> permissions = const [],
  }) async {
    final bizId = await _requireBizId();
    if (bizId == null) return null;

    _setSubmitting(true);
    try {
      final payloadMenu = menuSelections.entries.map((e) {
        return {"id": e.key, "submenu": e.value.map((x) => x).toList()};
      }).toList();

      final payload = {
        "name": name,
        "menu": payloadMenu, // sesuai spesifikasi baru
        if (permissions.isNotEmpty)
          "permissions": permissions, // kompatibel konteks lama
      };

      if (kDebugMode) {
        debugPrint('[HrProvider] POST ${_rolesListPath(bizId)}');
        debugPrint('[HrProvider] payload: $payload');
      }

      final j = await ApiJson.postMap(
        context,
        _rolesListPath(bizId), // POST /waveup/{bizId}/role
        payload,
        withAccessToken: true,
      );

      final ok = j != null && (j['status'] as num?)?.toInt() == 200;
      if (!ok) {
        _lastError =
            j?['msg']?.toString() ??
            j?['message']?.toString() ??
            'Failed to create role';
        notifyListeners();
        return null;
      }

      // Jika API mengembalikan data role baru
      final data = (j['data'] ?? j['role']) as Map?;
      HrRole? created;
      if (data != null && data.isNotEmpty) {
        created = HrRole.fromJson(data.cast<String, dynamic>());
        _roles.insert(0, created);
        notifyListeners();
      } else {
        // fallback: refresh list
        await fetchRoles(context);
      }

      _lastMessage = j['msg']?.toString() ?? 'Role created';
      return created;
    } catch (e, st) {
      _lastError = e.toString();
      if (kDebugMode) {
        debugPrint('[HrProvider] createRole ERROR: $e');
        debugPrint('$st');
      }
      notifyListeners();
      return null;
    } finally {
      _setSubmitting(false);
    }
  }

  /// Update role (endpoint legacy yang sudah ada — dibiarkan untuk kompatibilitas)
  Future<bool> updateRole(
    BuildContext context, {
    required String id,
    String? name,
    List<String>? permissions,
  }) async {
    final bizId = await _requireBizId();
    if (bizId == null) return false;

    _setSubmitting(true);
    try {
      final payload = <String, dynamic>{};
      if (name != null) payload['name'] = name;
      if (permissions != null) payload['permissions'] = permissions;

      if (kDebugMode) {
        debugPrint('[HrProvider] PUT ${_roleDetail(bizId, id)}');
        debugPrint('[HrProvider] payload: $payload');
      }

      // tetap memakai ApiJson.postMap sesuai konteks lama
      final j = await ApiJson.postMap(
        context,
        _roleDetail(bizId, id),
        payload,
        withAccessToken: true,
      );

      final ok = j != null && (j['status'] as num?)?.toInt() == 200;
      if (!ok) {
        _lastError =
            j?['msg']?.toString() ??
            j?['message']?.toString() ??
            'Failed to update role';
        notifyListeners();
        return false;
      }

      // update in-memory
      final idx = _roles.indexWhere((r) => r.id == id);
      if (idx != -1) {
        final merged = HrRole(
          id: id,
          name: name ?? _roles[idx].name,
          isPrimary: _roles[idx].isPrimary,
          permissions: permissions ?? _roles[idx].permissions,
        );
        _roles[idx] = merged;
        notifyListeners();
      }
      return true;
    } catch (e, st) {
      _lastError = e.toString();
      if (kDebugMode) {
        debugPrint('[HrProvider] updateRole ERROR: $e');
        debugPrint('$st');
      }
      notifyListeners();
      return false;
    } finally {
      _setSubmitting(false);
    }
  }

  /// Delete role (endpoint legacy & method lama dipertahankan)
  Future<bool> deleteRole(BuildContext context, String id) async {
    final bizId = await _requireBizId();
    if (bizId == null) return false;

    _setSubmitting(true);
    try {
      if (kDebugMode) {
        debugPrint('[HrProvider] DELETE ${_roleDetail(bizId, id)}');
      }

      // tetap pakai getMap sesuai konteks lama
      final j = await ApiJson.getMap(
        context,
        _roleDetail(bizId, id),
        withAccessToken: true,
      );

      final ok = j != null && (j['status'] as num?)?.toInt() == 200;
      if (!ok) {
        _lastError =
            j?['msg']?.toString() ??
            j?['message']?.toString() ??
            'Failed to delete role';
        notifyListeners();
        return false;
      }

      _roles.removeWhere((r) => r.id == id);
      notifyListeners();
      return true;
    } catch (e, st) {
      _lastError = e.toString();
      if (kDebugMode) {
        debugPrint('[HrProvider] deleteRole ERROR: $e');
        debugPrint('$st');
      }
      notifyListeners();
      return false;
    } finally {
      _setSubmitting(false);
    }
  }

  /// =========================
  /// EMPLOYEE INVITE FLOW
  /// =========================

  /// Step 1: Kirim undangan ke email + role id
  Future<String?> inviteEmployee(
    BuildContext context, {
    required String email,
    required String roleId,
  }) async {
    final bizId = await _requireBizId();
    if (bizId == null) return null;

    _setSubmitting(true);
    try {
      final payload = {'email': email, 'role': roleId};

      if (kDebugMode) {
        debugPrint('[HrProvider] POST ${_invitePath(bizId)}');
        debugPrint('[HrProvider] payload: $payload');
      }

      final j = await ApiJson.postMap(
        context,
        _invitePath(bizId),
        payload,
        withAccessToken: true,
      );

      // 🔍 Pretty print full response
      if (kDebugMode) {
        const encoder = JsonEncoder.withIndent('  ');
        final pretty = encoder.convert(j);
        debugPrint('[HrProvider] 🔄 Full response:\n$pretty');
      }

      final ok = j != null && (j['status'] as num?)?.toInt() == 200;
      if (!ok) {
        _lastError =
            j?['msg']?.toString() ??
            j?['message']?.toString() ??
            'Failed to send invite';
        notifyListeners();
        return null;
      }

      final url = (j['invite_url'] ?? '').toString();
      _lastMessage = j['msg']?.toString() ?? 'Undangan berhasil dikirim';
      debugPrint('[HrProvider] ✅ status: ${j['status']}');
      debugPrint('[HrProvider] 📨 message: ${j['msg']}');
      debugPrint('[HrProvider] 🔗 invite_url: ${j['invite_url']}');
      notifyListeners();
      return url;
    } catch (e, st) {
      _lastError = e.toString();
      if (kDebugMode) {
        debugPrint('[HrProvider] inviteEmployee ERROR: $e');
        debugPrint('$st');
      }
      notifyListeners();
      return null;
    } finally {
      _setSubmitting(false);
    }
  }

  /// Step 2: Cek data undangan (halaman verifikasi)
  Future<HrInvitePreview?> getInviteData(
    BuildContext context, {
    required String token,
  }) async {
    try {
      final path = _inviteTokenPath(token);
      if (kDebugMode) debugPrint('[HrProvider] GET $path');

      final j = await ApiJson.getMap(
        context,
        path,
        withAccessToken: false, // public endpoint
      );

      // Pretty print untuk debug
      if (kDebugMode) {
        const enc = JsonEncoder.withIndent('  ');
        debugPrint(
          '[HrProvider] 📦 invite detail response:\n${enc.convert(j)}',
        );
      }

      final ok = j != null && (j['status'] as num?)?.toInt() == 200;
      if (!ok) {
        _lastError =
            j?['msg']?.toString() ??
            j?['message']?.toString() ??
            'Failed to get invite data';
        notifyListeners();
        return null;
      }

      // ✅ langsung pakai root JSON (sesuai respons terbarumu)
      final preview = HrInvitePreview.fromJson(j.cast<String, dynamic>());
      return preview;
    } catch (e, st) {
      _lastError = e.toString();
      if (kDebugMode) {
        debugPrint('[HrProvider] getInviteData ERROR: $e');
        debugPrint('$st');
      }
      notifyListeners();
      return null;
    }
  }

  String _maskToken(String? s) {
    final t = (s ?? '').trim();
    if (t.isEmpty) return '';
    if (t.length <= 12) return '${t.substring(0, 3)}...';
    return '${t.substring(0, 6)}...${t.substring(t.length - 4)}';
  }

  /// Step 3 (Last Step): Submit registrasi & join business
  Future<InviteSubmitResult?> completeInvite(
    BuildContext context, {
    required String token,
    required String user,
    required String password,
    String referralCode = '',
    required String deviceId,
    required String deviceName,
    String fcmToken = '',
  }) async {
    try {
      final payload = {
        'user': user,
        'password': password,
        'referral_code': referralCode,
        'device_id': deviceId,
        'device_name': deviceName,
        'fcm_token': fcmToken,
      };

      final path = _inviteTokenPath(token);
      if (kDebugMode) {
        debugPrint('[HrProvider] POST $path');
        debugPrint('[HrProvider] payload: $payload');
      }

      final j = await ApiJson.postMap(
        context,
        path,
        payload,
        withAccessToken: false, // register/join via invite
      );

      final ok = j != null && (j['status'] as num?)?.toInt() == 200;
      if (!ok) {
        _lastError =
            j?['msg']?.toString() ??
            j?['message']?.toString() ??
            'Failed to complete invite';
        notifyListeners();
        return null;
      }

      // === Pretty log full response (token masked)
      if (kDebugMode) {
        const enc = JsonEncoder.withIndent('  ');
        final masked = {
          'status': j['status'],
          'data': j['data'],
          'token': {
            'access_token': _maskToken(j['token']?['access_token']?.toString()),
            'refresh_token': _maskToken(
              j['token']?['refresh_token']?.toString(),
            ),
          },
          'msg': j['msg'],
        };
        debugPrint('[HrProvider] 🎉 completeInvite SUCCESS');
        debugPrint(
          '[HrProvider] 📦 FULL RESPONSE (masked):\n${enc.convert(masked)}',
        );

        final data = (j['data'] as Map?)?.cast<String, dynamic>() ?? const {};
        debugPrint('[HrProvider] ── USER ─────────────');
        debugPrint('• idUser       : ${data['idUser']}');
        debugPrint('• email        : ${data['email']}');
        debugPrint('• username     : ${data['username']}');
        debugPrint('• hasPage      : ${data['hasPage']}');
        debugPrint('• userRoleName : ${data['userRoleName']}');
      }

      _lastMessage =
          j['msg']?.toString() ?? 'Registrasi berhasil dan bergabung';
      final res = InviteSubmitResult.fromJson(j.cast<String, dynamic>());

      // === AUTO-LOGIN ===
      try {
        final data = (j['data'] as Map?)?.cast<String, dynamic>() ?? const {};
        final loginEmail = (data['email']?.toString() ?? '').isNotEmpty
            ? data['email'].toString()
            : user;

        final auth = context.read<AuthProvider>();
        final loginOk = await auth.login(
          context: context,
          email: loginEmail,
          password: password,
          fcmToken: fcmToken,
          deviceId: deviceId,
          deviceName: deviceName,
        );

        if (loginOk) {
          if (kDebugMode) debugPrint('[HrProvider] AUTOLOGIN ✅ -> /splash');
          if (context.mounted) {
            Navigator.pushNamedAndRemoveUntil(context, '/splash', (r) => false);
          }
        } else {
          if (kDebugMode) {
            debugPrint(
              '[HrProvider] AUTOLOGIN ❌ ${auth.error ?? "(unknown error)"}',
            );
          }
        }
      } catch (e, st) {
        if (kDebugMode) {
          debugPrint('[HrProvider] AUTOLOGIN exception: $e');
          debugPrint('$st');
        }
      }

      notifyListeners();
      return res;
    } catch (e, st) {
      _lastError = e.toString();
      if (kDebugMode) {
        debugPrint('[HrProvider] completeInvite ERROR: $e');
        debugPrint('$st');
      }
      notifyListeners();
      return null;
    }
  }

  /// Riwayat undangan pada business saat ini
  Future<void> fetchInviteHistory(BuildContext context) async {
    final bizId = await _requireBizId();
    if (bizId == null) return;

    _setHistoryError(null);
    _setHistoryLoading(true);

    try {
      final result = await FetchHelper.fetchList<HrInviteHistoryItem>(
        context: context,
        path: _inviteHistoryPath(bizId),
        parser: (json) => HrInviteHistoryItem.fromJson(json),
      );

      _history
        ..clear()
        ..addAll(result?.items ?? const []);
      _pageHistory = result?.page;

      if (kDebugMode) {
        debugPrint('[HrProvider] history: ${_history.length}');
        debugPrint('[HrProvider] page: $_pageHistory');
      }
      notifyListeners();
    } catch (e, st) {
      _history.clear();
      _pageHistory = null;
      _setHistoryError(e.toString());
      if (kDebugMode) {
        debugPrint('[HrProvider] fetchInviteHistory ERROR: $e');
        debugPrint('$st');
      }
    } finally {
      _setHistoryLoading(false);
    }
  }
}
