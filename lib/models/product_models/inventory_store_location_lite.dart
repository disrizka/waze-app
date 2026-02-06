part of '../../providers/product_provider.dart';

@immutable
class InventoryStoreLocationLite {
  final String idStoreLocation;
  final String name;

  const InventoryStoreLocationLite({
    required this.idStoreLocation,
    required this.name,
  });

  factory InventoryStoreLocationLite.fromJson(Map<String, dynamic> j) =>
      InventoryStoreLocationLite(
        idStoreLocation: j['idStoreLocation']?.toString() ?? '',
        name: j['name']?.toString() ?? '',
      );
}
