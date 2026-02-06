import 'package:wa_blast/models/purchase_models/city_model.dart';

class Supplier {
  final String idSupplier;
  final String name;
  final String? logo;
  final String? logoPath;
  final String? phone;
  final String? email;
  final City? city;
  final String? address;

  const Supplier({
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
      idSupplier: (json['idSupplier'] ?? json['id'] ?? '').toString(),
      name: (json['name'] ?? '').toString(),
      logo: json['logo']?.toString(),
      logoPath: json['logoPath']?.toString(),
      phone: json['phone']?.toString(),
      email: json['email']?.toString(),
      city: (json['city'] is Map<String, dynamic>)
          ? City.fromJson(json['city'] as Map<String, dynamic>)
          : null,
      address: json['address']?.toString(),
    );
  }

  Map<String, dynamic> toJson() => {
    'idSupplier': idSupplier,
    'name': name,
    if (logo != null) 'logo': logo,
    if (logoPath != null) 'logoPath': logoPath,
    if (phone != null) 'phone': phone,
    if (email != null) 'email': email,
    if (city != null) 'city': city!.toJson(),
    if (address != null) 'address': address,
  };

  @override
  String toString() =>
      'Supplier(idSupplier: $idSupplier, name: $name, city: ${city?.name ?? '-'})';
}
