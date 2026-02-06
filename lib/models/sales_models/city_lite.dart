part of '../../providers/sales_provider.dart';

@immutable
class CityLite {
  final String id;
  final String name;
  final ProvinceLite? province;

  const CityLite({required this.id, required this.name, this.province});

  factory CityLite.fromJson(Map<String, dynamic> j) => CityLite(
    id: (j['id'] ?? '').toString(),
    name: (j['name'] ?? '').toString(),
    province: (j['province'] is Map)
        ? ProvinceLite.fromJson((j['province'] as Map).cast<String, dynamic>())
        : null,
  );
}
