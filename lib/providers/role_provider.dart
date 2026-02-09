// lib/providers/role_provider.dart
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:wa_blast/config/role_route_mapping.dart';
import 'package:wa_blast/core/provider_helper.dart';
import 'package:wa_blast/models/auth_models/role_models.dart';
import 'package:wa_blast/providers/auth_provider.dart';

/// Provider untuk mengelola izin berbasis role:
/// - allowedRoutes: nama route Flutter yang boleh diakses (untuk guard onGenerateRoute)
/// - allowedPages: "page" mentah dari API (untuk gating fitur/tab seperti 'waba')
class RoleProvider with ChangeNotifier {
  // ===== STATE =====
  AdminRole? _role; // untuk bentuk "detail role" (opsional)
  Set<String> _allowedRoutes = {...kPublicRoutes};

  bool _forceWaba = false;

  /// Kumpulan 'page' dari API (mis. 'product', 'waba', dst)
  Set<String> _allowedPages = {}; // akan disuntik 'waba' jika _forceWaba = true

  bool _isReady = false;
  DateTime? _updatedAt;

  // ===== GETTERS =====
  AdminRole? get role => _role;
  Set<String> get allowedRoutes => _allowedRoutes;
  Set<String> get allowedPages => _allowedPages;
  bool get isReady => _isReady;
  DateTime? get updatedAt => _updatedAt;

  bool get forceWaba => _forceWaba;

  // ===== PUBLIC API =====

  /// Aktif/nonaktifkan pemaksaan WABA.
  /// Jika persist=true, preferensi disimpan di SharedPreferences ('forceWabaEnabled').
  Future<void> setForceWaba(bool value, {bool persist = true}) async {
    _forceWaba = value;
    if (persist) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('forceWabaEnabled', value);
    }
    // re-apply pages supaya efek langsung terlihat
    _applyPages(_allowedPages);
    notifyListeners();
  }

  /// (Opsional) panggil saat startup (mis. di Splash) untuk memuat preferensi.
  Future<void> loadForceWabaPrefOnce() async {
    final prefs = await SharedPreferences.getInstance();
    _forceWaba = prefs.getBool('forceWabaEnabled') ?? true; // default: true
    // setelah load, re-apply agar konsisten
    _applyPages(_allowedPages);
  }

  bool can(String? routeName) {
    if (routeName == null || routeName.isEmpty) return false;
    return _allowedRoutes.contains(routeName);
  }

  /// Cek akses salah satu dari beberapa route (berguna untuk tombol yang menuju beberapa fallback)
  bool canAny(Iterable<String> routes) {
    for (final r in routes) {
      if (_allowedRoutes.contains(r)) return true;
    }
    return false;
  }

  /// Cek izin berdasarkan "page" API (mis. 'waba' untuk gate tab Chat)
  bool canPage(String page) => _allowedPages.contains(page);

  // ===== MUTATORS =====
  void clear() {
    _role = null;

    // Jika force WABA aktif, tetap suntik 'waba' meskipun clear()
    _allowedPages = _forceWaba ? {'waba'} : {};

    _allowedRoutes = buildAllowedRoutesFromPages(_allowedPages);
    _isReady = false;
    _updatedAt = DateTime.now();
    notifyListeners();
  }

  // ===== PATH HELPER =====
  String _roleDetailPath(String bizId, String idAdminRole) =>
      '/waveup/$bizId/role/$idAdminRole';

  // ====== FETCH DETAIL ROLE (pakai FetchHelper.fetchOne) ======
  Future<AdminRole?> fetchDetailRoleUserUsingFetchHelper({
    required BuildContext context,
    required String idBusiness,
    required String idAdminRole,
    bool updateProviderState = true,
  }) async {
    if (kDebugMode) {
      debugPrint('==============================================');
      debugPrint('[RoleProvider] fetchDetailRoleUserUsingFetchHelper BEGIN');
      debugPrint('  bizId       : $idBusiness');
      debugPrint('  idAdminRole : $idAdminRole');
      debugPrint('  path        : ${_roleDetailPath(idBusiness, idAdminRole)}');
    }
    try {
      final role = await FetchHelper.fetchOne<AdminRole>(
        context: context,
        path: _roleDetailPath(idBusiness, idAdminRole),
        parser: (json) => AdminRole.fromJson(json),
      );

      if (role == null) {
        if (kDebugMode) {
          debugPrint(
            '[RoleProvider] fetchDetailRoleUserUsingFetchHelper -> null',
          );
        }
        return null;
      }

      if (updateProviderState) {
        final map = {
          'status': 200,
          'data': role.toJson(), // toJson() sudah mengarah ke toMap()
        };
        setFromDetailRoleApi(map);
      }

      return role;
    } catch (e, st) {
      if (kDebugMode) {
        debugPrint(
          '[RoleProvider] fetchDetailRoleUserUsingFetchHelper error: $e\n$st',
        );
      }
      return null;
    }
  }

  /// Convenience: langsung apply role yang di-fetch
  Future<bool> refreshDetailRoleAndApplyFH({
    required BuildContext context,
    required String idBusiness,
    required String idAdminRole,
  }) async {
    final role = await fetchDetailRoleUserUsingFetchHelper(
      context: context,
      idBusiness: idBusiness,
      idAdminRole: idAdminRole,
      updateProviderState: true,
    );
    return role != null;
  }

  // ====== BACA ID LANGSUNG DARI PREFS (tanpa AuthProvider) ======
  /// Ambil (bizId, roleId) aktif dari SharedPreferences.
  /// Keys: 'activeBizId' & 'activeBizRoleId' (sesuai AuthProvider).
  Future<({String bizId, String roleId})?> _readActiveBizAndRoleIds() async {
    final prefs = await SharedPreferences.getInstance();
    final bizId = (prefs.getString('activeBizId') ?? '').trim();
    var roleId = (prefs.getString('activeBizRoleId') ?? '').trim();
    final roleName = (prefs.getString('activeBizRoleName') ?? '').trim();

    if (bizId.isNotEmpty && roleId.isEmpty) {
      // 🔁 Recovery dari businessRoles map
      try {
        final mapStr = prefs.getString(AuthProvider.kBusinessRolesKey);
        if (mapStr != null && mapStr.isNotEmpty) {
          final map = (jsonDecode(mapStr) as Map).cast<String, dynamic>();
          final rb = (map[bizId] as Map?)?.cast<String, dynamic>();
          final recovered = (rb?['idAdminRole'] ?? '').toString().trim();
          if (recovered.isNotEmpty) {
            roleId = recovered;
            // tulis balik agar stabil di refresh berikutnya
            await prefs.setString(AuthProvider.kActiveBizRoleIdKey, recovered);
            await prefs.setString(
              AuthProvider.kActiveBizRoleNameKey,
              (rb?['name'] ?? '').toString(),
            );
            await prefs.setBool(
              AuthProvider.kActiveBizRoleIsPrimaryKey,
              (rb?['isPrimary'] ?? false) == true,
            );
            if (kDebugMode) {
              debugPrint(
                '[RoleProvider] recovered roleId="$recovered" from businessRoles map',
              );
            }
          }
        }
      } catch (e) {
        if (kDebugMode) debugPrint('[RoleProvider] recovery error: $e');
      }
    }

    if (bizId.isEmpty || roleId.isEmpty) {
      if (kDebugMode) {
        debugPrint(
          '[RoleProvider] _readActiveBizAndRoleIds -> bizId="$bizId", roleId="$roleId" (INVALID)',
        );
      }
      return null;
    }

    if (kDebugMode) {
      debugPrint(
        '[RoleProvider] _readActiveBizAndRoleIds -> bizId="$bizId", roleId="$roleId", roleName="$roleName"',
      );
    }
    return (bizId: bizId, roleId: roleId);
  }

  void _markReadyFallback({String? reason}) {
    // fallback: minimal hanya public routes, pages kosong (atau waba kalau force)
    _role = null;
    _allowedPages = _forceWaba ? {'waba'} : {};
    _allowedRoutes = buildAllowedRoutesFromPages(_allowedPages);
    _isReady = true;
    _updatedAt = DateTime.now();
    if (kDebugMode) debugPrint('[RoleProvider] READY FALLBACK: $reason');
    notifyListeners();
  }

  /// Publik: baca id dari prefs → fetch detail role → apply ke provider.
  Future<bool> refreshActiveRoleFromPrefs(BuildContext context) async {
    // optional: set loading dulu (kalau kamu mau shimmer muncul saat refresh)
    _isReady = false;
    notifyListeners();

    final pair = await _readActiveBizAndRoleIds();
    if (pair == null) {
      _markReadyFallback(reason: 'prefs bizId/roleId invalid');
      return false;
    }

    final ok = await refreshDetailRoleAndApplyFH(
      context: context,
      idBusiness: pair.bizId,
      idAdminRole: pair.roleId,
    );

    if (!ok) {
      // fetch gagal / null → jangan biarkan shimmer selamanya
      _markReadyFallback(reason: 'fetch role failed or returned null');
      return false;
    }

    return true;
  }

  void setFromDetailRoleApi(Map<String, dynamic> json) {
    final data = (json['data'] as Map<String, dynamic>?);
    if (data == null) {
      clear();
      return;
    }

    final parsed = AdminRole.fromJson(data);

    // Kumpulkan pages dari menu + submenu
    final pages = <String>[];
    for (final m in parsed.menus) {
      if (m.page.isNotEmpty) pages.add(m.page);
      for (final s in m.submenu) {
        if (s.page.isNotEmpty) pages.add(s.page);
      }
    }

    _applyPages(pages);
    _role = parsed;
    _isReady = true;
    _updatedAt = DateTime.now();
    notifyListeners();
  }

  /// Versi 2: response “role turunan” (list menu di level atas)
  /// {
  ///   "status": 200,
  ///   "data": [ { "page": "", "submenu": [ {"page": "employee"}, ... ] }, ... ]
  /// }
  void setFromSubmenuApi(Map<String, dynamic> json) {
    final List data = (json['data'] as List?) ?? [];
    final pages = <String>[];

    for (final menu in data) {
      if (menu is Map) {
        final p = (menu['page'] as String?) ?? '';
        if (p.isNotEmpty) pages.add(p);

        final subs = (menu['submenu'] as List?) ?? [];
        for (final s in subs) {
          if (s is Map) {
            final sp = (s['page'] as String?) ?? '';
            if (sp.isNotEmpty) pages.add(sp);
          }
        }
      }
    }

    _applyPages(pages);
    // bentuk ini tidak mengandung entitas AdminRole penuh → biarkan _role null
    _isReady = true;
    _updatedAt = DateTime.now();
    notifyListeners();
  }

  /// Jika kamu punya beberapa sumber role (multi-role) dan ingin union:
  /// panggil beberapa kali `mergePages(pagesDariSumberLain)`
  void mergePages(Iterable<String> pages) {
    final merged = {..._allowedPages, ...pages};
    _applyPages(merged);
    _isReady = true;
    _updatedAt = DateTime.now();
    notifyListeners();
  }

  // ===== INTERNAL =====
  void _applyPages(Iterable<String> pages) {
    // normalisasi & simpan "page" mentah
    final setPages = pages
        .where((e) => e.trim().isNotEmpty)
        .map((e) => e.trim())
        .toSet();

    // ⛳️ Suntik 'waba' bila force aktif
    if (_forceWaba) {
      setPages.add('waba');
    }

    _allowedPages = setPages;

    // hitung allowedRoutes dari pages via mapping + ekspansi
    _allowedRoutes = buildAllowedRoutesFromPages(setPages);

    if (kDebugMode) {
      debugDump(); // gampang trace di console saat dev
    }
  }

  /// Log ringkas untuk debugging
  void debugDump() {
    debugPrint('---- RoleProvider Debug ----');
    debugPrint('isReady: $_isReady  updatedAt: $_updatedAt');
    debugPrint('allowedPages: ${_allowedPages.toList()..sort()}');
    debugPrint('allowedRoutes: ${_allowedRoutes.toList()..sort()}');
    if (_role != null) {
      debugPrint(
        'role.id: ${_role!.id}  name: ${_role!.name}  isPrimary: ${_role!.isPrimary}',
      );
    } else {
      debugPrint('role: (null / built from submenu)');
    }
    debugPrint('forceWaba: $_forceWaba');
    debugPrint('----------------------------');
  }
}
