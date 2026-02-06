part of '../../providers/auth_provider.dart';

/// =========================
/// Model ringan untuk UI
/// =========================
@immutable
class BusinessInfo {
  final String idBusiness;
  final String name;
  final String username;
  final String logoPath;
  final bool isActive;

  // premium
  final bool isPremium;
  final String? premiumStartAt;
  final String? premiumExpiresAt;

  // ⬇️ NEW: banned status dari server
  // contoh: "ban", "semi-ban", null / "" jika aman
  final String? banned;

  const BusinessInfo({
    required this.idBusiness,
    required this.name,
    required this.username,
    required this.logoPath,
    this.isActive = false,
    this.isPremium = false,
    this.premiumStartAt,
    this.premiumExpiresAt,
    this.banned,
  });

  /// opsional helper buat UI
  bool get isBanned => (banned ?? '').toString().trim().isNotEmpty;
  bool get isHardBanned => (banned ?? '').toLowerCase() == 'ban';
  bool get isSemiBanned => (banned ?? '').toLowerCase() == 'semi-ban';

  factory BusinessInfo.fromJson(Map<String, dynamic> j, {String? activeId}) {
    final id = (j['idBusiness'] ?? '').toString();

    // premium flag toleran key
    final rawPremium = j['isPremium'] ?? j['is_premium'];
    bool premiumFlag = false;
    if (rawPremium is bool) {
      premiumFlag = rawPremium;
    } else if (rawPremium is num) {
      premiumFlag = rawPremium != 0;
    } else if (rawPremium is String) {
      final s = rawPremium.toLowerCase();
      if (s == '1' || s == 'true' || s == 'yes') premiumFlag = true;
      if (s == '0' || s == 'false' || s == 'no') premiumFlag = false;
    }

    return BusinessInfo(
      idBusiness: id,
      name: (j['name'] ?? '').toString(),
      username: (j['username'] ?? '').toString(),
      logoPath: (j['logoPath'] ?? j['logo'] ?? '').toString(),
      isActive: activeId != null && activeId == id,
      isPremium: premiumFlag,
      premiumStartAt: (j['premiumStartAt'] ?? j['premium_start_at'])
          ?.toString(),
      premiumExpiresAt: (j['premiumExpiresAt'] ?? j['premium_expires_at'])
          ?.toString(),
      banned: (j['banned'])?.toString(),
    );
  }

  Map<String, dynamic> toJson() => {
    'idBusiness': idBusiness,
    'name': name,
    'username': username,
    'logoPath': logoPath,
    'isPremium': isPremium,
    'premiumStartAt': premiumStartAt,
    'premiumExpiresAt': premiumExpiresAt,
    'banned': banned,
  };
}
