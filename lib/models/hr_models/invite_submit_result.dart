part of '../../providers/hr_provider.dart';

@immutable
class InviteSubmitResult {
  final Map<String, dynamic> user; // minimal fields, bebas dipakai UI
  final Map<String, dynamic> token; // access_token, refresh_token

  const InviteSubmitResult({required this.user, required this.token});

  factory InviteSubmitResult.fromJson(Map<String, dynamic> j) =>
      InviteSubmitResult(
        user: (j['data'] as Map?)?.cast<String, dynamic>() ?? const {},
        token: (j['token'] as Map?)?.cast<String, dynamic>() ?? const {},
      );
}
