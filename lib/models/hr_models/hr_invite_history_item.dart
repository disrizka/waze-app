part of '../../providers/hr_provider.dart';

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
