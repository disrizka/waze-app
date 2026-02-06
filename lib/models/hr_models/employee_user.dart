part of '../../providers/hr_provider.dart';

@immutable
class EmployeeUser {
  final String idUser;
  final String firstName;
  final String lastName;
  final String phone;
  final String email;
  final String photo;
  final String photoPath;
  final bool isDeactivated;
  final String username;
  final bool hasPage;
  final String userRoleName;
  final String roleId;

  const EmployeeUser({
    required this.idUser,
    required this.firstName,
    required this.lastName,
    required this.phone,
    required this.email,
    required this.photo,
    required this.photoPath,
    required this.isDeactivated,
    required this.username,
    required this.hasPage,
    required this.userRoleName,
    required this.roleId,
  });

  factory EmployeeUser.fromJson(Map<String, dynamic> j) => EmployeeUser(
    idUser: (j['idUser'] ?? '').toString(),
    firstName: (j['firstname'] ?? '').toString(),
    lastName: (j['lastname'] ?? '').toString(),
    phone: (j['phone'] ?? '').toString(),
    email: (j['email'] ?? '').toString(),
    photo: (j['photo'] ?? '').toString(),
    photoPath: (j['photoPath'] ?? '').toString(),
    isDeactivated: (j['isDeactivated'] ?? false) == true,
    username: (j['username'] ?? '').toString(),
    hasPage: (j['hasPage'] ?? false) == true,
    userRoleName: (j['userRoleName'] ?? '').toString(),
    roleId: (j['roleId'] ?? '').toString(),
  );

  String get fullName {
    final parts = <String>[
      firstName.trim(),
      lastName.trim(),
    ].where((e) => e.isNotEmpty).toList();
    if (parts.isEmpty) return '';
    return parts.join(' ');
  }
}
