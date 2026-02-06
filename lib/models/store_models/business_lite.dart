part of '../../providers/store_provider.dart';

@immutable
class BusinessLite {
  final String idBusiness;
  final String name;
  final String? logo;
  final String? logoPath;
  final String? username;
  final String? about;

  const BusinessLite({
    required this.idBusiness,
    required this.name,
    this.logo,
    this.logoPath,
    this.username,
    this.about,
  });

  factory BusinessLite.fromJson(Map<String, dynamic> j) => BusinessLite(
    idBusiness: (j['idBusiness'] ?? '').toString(),
    name: (j['name'] ?? '').toString(),
    logo: j['logo']?.toString(),
    logoPath: j['logoPath']?.toString(),
    username: j['username']?.toString(),
    about: j['about']?.toString(),
  );
}
