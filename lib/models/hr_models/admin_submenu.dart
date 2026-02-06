part of '../../providers/hr_provider.dart';

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
