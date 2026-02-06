part of '../../providers/adjustment_provider.dart';

@immutable
class AdjustmentStoreLocationLite {
  final String idStoreLocation;
  final String name;
  final String? cityName;
  final String? provinceName;

  const AdjustmentStoreLocationLite({
    required this.idStoreLocation,
    required this.name,
    this.cityName,
    this.provinceName,
  });

  factory AdjustmentStoreLocationLite.fromJson(Map<String, dynamic> j) {
    final cityJ = _asMap(j['city']);
    final provJ = _asMap(cityJ?['province']);

    return AdjustmentStoreLocationLite(
      idStoreLocation: _asString(j['idStoreLocation']),
      name: _asString(j['name']),
      cityName: cityJ?['name']?.toString(),
      provinceName: provJ?['name']?.toString(),
    );
  }
}
