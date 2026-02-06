part of '../../providers/sales_provider.dart';

@immutable
class StoreLocationLite {
  final String idStoreLocation;
  final String name;
  final StoreCity? city;

  const StoreLocationLite({
    required this.idStoreLocation,
    required this.name,
    this.city,
  });

  factory StoreLocationLite.fromJson(Map<String, dynamic> j) =>
      StoreLocationLite(
        idStoreLocation: (j['idStoreLocation'] ?? '').toString(),
        name: (j['name'] ?? '').toString(),
        city: (j['city'] is Map)
            ? StoreCity.fromJson((j['city'] as Map).cast<String, dynamic>())
            : null,
      );
}
