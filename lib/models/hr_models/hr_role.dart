part of '../../providers/hr_provider.dart';

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
