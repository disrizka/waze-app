// lib/providers/role_provider.dart
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'package:wa_blast/config/role_route_mapping.dart';
import 'package:wa_blast/models/role_models.dart';

/// Provider untuk mengelola izin berbasis role:
/// - allowedRoutes: nama route Flutter yang boleh diakses (untuk guard onGenerateRoute)
/// - allowedPages: "page" mentah dari API (untuk gating fitur/tab seperti 'waba')
class RoleProvider with ChangeNotifier {
  // ===== STATE =====
  AdminRole? _role; // untuk bentuk "detail role" (opsional)
  Set<String> _allowedRoutes = {...kPublicRoutes};
  Set<String> _allowedPages = {
    // 'waba',
  }; // kumpulan 'page' dari API (mis. 'product', 'waba', dst)
  bool _isReady = false;
  DateTime? _updatedAt;

  // ===== GETTERS =====
  AdminRole? get role => _role;
  Set<String> get allowedRoutes => _allowedRoutes;
  Set<String> get allowedPages => _allowedPages;
  bool get isReady => _isReady;
  DateTime? get updatedAt => _updatedAt;

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
    _allowedPages = {};
    _allowedRoutes = {...kPublicRoutes};
    _isReady = false;
    _updatedAt = DateTime.now();
    notifyListeners();
  }

  /// Versi 1: response "detail role" (seperti contoh awalmu)
  /// {
  ///   "status": 200,
  ///   "data": {
  ///     "idAdminRole": "...",
  ///     "name": "...",
  ///     "isPrimary": false,
  ///     "menus": [ { "page": "", "submenu": [ {"page": "product"}, ... ] } ]
  ///   }
  /// }
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
    debugPrint('----------------------------');
  }
}
