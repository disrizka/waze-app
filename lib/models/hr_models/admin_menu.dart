part of '../../providers/hr_provider.dart';

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
