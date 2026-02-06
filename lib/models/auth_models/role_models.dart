import 'package:flutter/foundation.dart';

/// ---------- Helpers ----------
String _s(dynamic v, {String def = ''}) {
  if (v == null) return def;
  if (v is String) return v;
  return v.toString();
}

int _i(dynamic v, {int def = 0}) {
  if (v == null) return def;
  if (v is int) return v;
  if (v is num) return v.toInt();
  final s = v.toString();
  return int.tryParse(s) ?? def;
}

bool _b(dynamic v, {bool def = false}) {
  if (v == null) return def;
  if (v is bool) return v;
  if (v is num) return v != 0;
  final s = v.toString().toLowerCase().trim();
  if (s == 'true' || s == 'yes' || s == 'y' || s == '1') return true;
  if (s == 'false' || s == 'no' || s == 'n' || s == '0') return false;
  return def;
}

Map<String, dynamic> _map(dynamic v) {
  if (v is Map<String, dynamic>) return v;
  if (v is Map) return Map<String, dynamic>.from(v);
  return <String, dynamic>{};
}

List<Map<String, dynamic>> _listOfMap(dynamic v) {
  if (v is List) {
    return v
        .where((e) => e is Map || e is Map<String, dynamic>)
        .map<Map<String, dynamic>>((e) => _map(e))
        .toList(growable: false);
  }
  return const <Map<String, dynamic>>[];
}

/// ---------- Models ----------
@immutable
class AdminRole {
  final String id; // dari idAdminRole
  final String name;
  final bool isPrimary;
  final List<RoleMenu> menus;

  const AdminRole({
    required this.id,
    required this.name,
    required this.isPrimary,
    required this.menus,
  });

  factory AdminRole.fromJson(Map<String, dynamic> j) {
    // Beberapa endpoint bisa bentuk {status,data:{...}} → caller sebaiknya kirim node data.
    final m = _map(j);

    final id = _s(m['idAdminRole']); // kalau number, toString() aman
    final name = _s(m['name']);
    final isPrimary = _b(m['isPrimary']);
    final menus = _listOfMap(
      m['menus'],
    ).map((mm) => RoleMenu.fromJson(mm)).toList(growable: false);

    return AdminRole(id: id, name: name, isPrimary: isPrimary, menus: menus);
  }

  Map<String, dynamic> toMap() => {
    'idAdminRole': id,
    'name': name,
    'isPrimary': isPrimary,
    'menus': menus.map((m) => m.toMap()).toList(),
  };

  Map<String, dynamic> toJson() => toMap();

  AdminRole copyWith({
    String? id,
    String? name,
    bool? isPrimary,
    List<RoleMenu>? menus,
  }) => AdminRole(
    id: id ?? this.id,
    name: name ?? this.name,
    isPrimary: isPrimary ?? this.isPrimary,
    menus: menus ?? this.menus,
  );
}

@immutable
class RoleMenu {
  final int id;
  final String name;
  final String page; // bisa "" kalau parent menu
  final String icon;
  final List<RoleSubmenu> submenu;

  const RoleMenu({
    required this.id,
    required this.name,
    required this.page,
    required this.icon,
    required this.submenu,
  });

  factory RoleMenu.fromJson(Map<String, dynamic> j) {
    final m = _map(j);
    final id = _i(m['id']);
    final name = _s(m['name']);
    final page = _s(m['page']); // bisa kosong
    final icon = _s(m['icon']);
    final submenu = _listOfMap(
      m['submenu'],
    ).map((sm) => RoleSubmenu.fromJson(sm)).toList(growable: false);

    return RoleMenu(
      id: id,
      name: name,
      page: page,
      icon: icon,
      submenu: submenu,
    );
  }

  Map<String, dynamic> toMap() => {
    'id': id,
    'name': name,
    'page': page,
    'icon': icon,
    'submenu': submenu.map((s) => s.toMap()).toList(),
  };

  Map<String, dynamic> toJson() => toMap();
}

@immutable
class RoleSubmenu {
  final int id;
  final String name;
  final String page;
  final String icon;

  const RoleSubmenu({
    required this.id,
    required this.name,
    required this.page,
    required this.icon,
  });

  factory RoleSubmenu.fromJson(Map<String, dynamic> j) {
    final m = _map(j);
    return RoleSubmenu(
      id: _i(m['id']),
      name: _s(m['name']),
      page: _s(m['page']),
      icon: _s(m['icon']),
    );
  }

  Map<String, dynamic> toMap() => {
    'id': id,
    'name': name,
    'page': page,
    'icon': icon,
  };

  Map<String, dynamic> toJson() => toMap();
}
