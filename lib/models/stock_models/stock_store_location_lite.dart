part of '../../providers/stock_provider.dart';

/// Store location versi ringan untuk initial stock.
@immutable
class StockStoreLocationLite {
  final String idStoreLocation;
  final String name;
  final String? cityName;
  final String? provinceName;

  const StockStoreLocationLite({
    required this.idStoreLocation,
    required this.name,
    this.cityName,
    this.provinceName,
  });

  factory StockStoreLocationLite.fromJson(Map<String, dynamic> j) {
    final cityJ = _asMap(j['city']);
    final provJ = _asMap(cityJ['province']);

    return StockStoreLocationLite(
      idStoreLocation: j['idStoreLocation']?.toString() ?? '',
      name: j['name']?.toString() ?? '',
      cityName: cityJ['name']?.toString(),
      provinceName: provJ['name']?.toString(),
    );
  }
}
