// role_models.dart
class AdminRole {
  final String id;
  final String name;
  final bool isPrimary;
  final List<RoleMenu> menus;

  AdminRole({
    required this.id,
    required this.name,
    required this.isPrimary,
    required this.menus,
  });

  factory AdminRole.fromJson(Map<String, dynamic> j) => AdminRole(
    id: j['idAdminRole'] as String,
    name: j['name'] as String,
    isPrimary: j['isPrimary'] as bool? ?? false,
    menus: (j['menus'] as List? ?? [])
        .map((m) => RoleMenu.fromJson(m))
        .toList(),
  );
}

class RoleMenu {
  final int id;
  final String name;
  final String page;
  final String icon;
  final List<RoleSubmenu> submenu;

  RoleMenu({
    required this.id,
    required this.name,
    required this.page,
    required this.icon,
    required this.submenu,
  });

  factory RoleMenu.fromJson(Map<String, dynamic> j) => RoleMenu(
    id: j['id'] as int,
    name: j['name'] as String,
    page: j['page'] as String? ?? '',
    icon: j['icon'] as String? ?? '',
    submenu: (j['submenu'] as List? ?? [])
        .map((s) => RoleSubmenu.fromJson(s))
        .toList(),
  );
}

class RoleSubmenu {
  final int id;
  final String name;
  final String page;
  final String icon;

  RoleSubmenu({
    required this.id,
    required this.name,
    required this.page,
    required this.icon,
  });

  factory RoleSubmenu.fromJson(Map<String, dynamic> j) => RoleSubmenu(
    id: j['id'] as int,
    name: j['name'] as String,
    page: j['page'] as String? ?? '',
    icon: j['icon'] as String? ?? '',
  );
}
