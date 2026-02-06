part of '../../providers/hr_provider.dart';

@immutable
class HrInvitePreview {
  final String email;
  final String businessId;
  final String businessName;
  final String businessLogo;
  final String roleId;
  final String roleName;
  final String token;
  final bool isAccountExists;

  const HrInvitePreview({
    required this.email,
    required this.businessId,
    required this.businessName,
    required this.businessLogo,
    required this.roleId,
    required this.roleName,
    required this.token,
    required this.isAccountExists, // ⬅️ NEW
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
    isAccountExists: (j['isAccountExists'] ?? false) == true, // ⬅️ NEW
  );
}
