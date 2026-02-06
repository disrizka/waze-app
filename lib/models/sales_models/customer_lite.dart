part of '../../providers/sales_provider.dart';

@immutable
class CustomerLite {
  final String idCustomer;
  final String name;
  final String phone;
  final String email;
  final String address;

  const CustomerLite({
    required this.idCustomer,
    required this.name,
    required this.phone,
    required this.email,
    required this.address,
  });

  factory CustomerLite.fromJson(Map<String, dynamic> j) => CustomerLite(
    idCustomer: (j['idCustomer'] ?? '').toString(),
    name: (j['name'] ?? '').toString(),
    phone: (j['phone'] ?? '').toString(),
    email: (j['email'] ?? '').toString(),
    address: (j['address'] ?? '').toString(),
  );
}
