import 'package:wa_blast/models/city_model.dart';

class Supplier {
  final String idSupplier;
  final String name;
  final String? logo;
  final String? logoPath;
  final String? phone;
  final String? email;
  final City? city;
  final String? address;

  Supplier({
    required this.idSupplier,
    required this.name,
    this.logo,
    this.logoPath,
    this.phone,
    this.email,
    this.city,
    this.address,
  });

  factory Supplier.fromJson(Map<String, dynamic> json) {
    return Supplier(
      idSupplier: (json['idSupplier'] as String?) ?? '',
      name: (json['name'] as String?) ?? '',
      logo: json['logo'] as String?,
      logoPath: json['logoPath'] as String?,
      phone: json['phone'] as String?,
      email: json['email'] as String?,
      city: (json['city'] is Map<String, dynamic>)
          ? City.fromJson(json['city'] as Map<String, dynamic>)
          : null,
      address: json['address'] as String?,
    );
  }
}

class Province {
  final int id;
  final String name;

  Province({required this.id, required this.name});

  factory Province.fromJson(Map<String, dynamic> json) {
    return Province(
      id: (json['id'] as num?)?.toInt() ?? 0,
      name: (json['name'] as String?) ?? '',
    );
  }
}
