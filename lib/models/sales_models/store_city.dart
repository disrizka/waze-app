part of '../../providers/sales_provider.dart';

@immutable
class StoreCity {
  final String id;
  final String name;
  final StoreProvince? province;
  const StoreCity({required this.id, required this.name, this.province});

  factory StoreCity.fromJson(Map<String, dynamic> j) => StoreCity(
    id: (j['id'] ?? '').toString(),
    name: (j['name'] ?? '').toString(),
    province: (j['province'] is Map)
        ? StoreProvince.fromJson((j['province'] as Map).cast<String, dynamic>())
        : null,
  );
}
