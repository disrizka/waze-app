part of '../../providers/hr_provider.dart';

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
