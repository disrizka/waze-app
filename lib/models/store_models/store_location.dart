part of '../../providers/store_provider.dart';

@immutable
class StoreLocation {
  final String idStoreLocation;
  final String name;
  final City? city;
  final BusinessLite? business;

  const StoreLocation({
    required this.idStoreLocation,
    required this.name,
    this.city,
    this.business,
  });

  factory StoreLocation.fromJson(Map<String, dynamic> j) => StoreLocation(
    idStoreLocation: (j['idStoreLocation'] ?? '').toString(),
    name: (j['name'] ?? '').toString(),
    city: (j['city'] is Map<String, dynamic>)
        ? City.fromJson(j['city'] as Map<String, dynamic>)
        : null,
    business: (j['business'] is Map<String, dynamic>)
        ? BusinessLite.fromJson(j['business'] as Map<String, dynamic>)
        : null,
  );
}
