part of '../../providers/sales_provider.dart';

@immutable
class Customer {
  final String idCustomer;
  final String name;
  final String phone;
  final String email;
  final CityLite? city;
  final String address;

  const Customer({
    required this.idCustomer,
    required this.name,
    required this.phone,
    required this.email,
    required this.city,
    required this.address,
  });

  factory Customer.fromJson(Map<String, dynamic> j) => Customer(
    idCustomer: (j['idCustomer'] ?? '').toString(),
    name: (j['name'] ?? '').toString(),
    phone: (j['phone'] ?? '').toString(),
    email: (j['email'] ?? '').toString(),
    city: (j['city'] is Map)
        ? CityLite.fromJson((j['city'] as Map).cast<String, dynamic>())
        : null,
    address: (j['address'] ?? '').toString(),
  );

  /// payload untuk Create/Edit sesuai spesifikasi
  Map<String, dynamic> toPayload({required int cityIdOverride}) => {
    "name": name,
    "phone": phone,
    "email": email,
    "city_id": cityIdOverride,
    "address": address,
  };
}
