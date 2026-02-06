part of '../../providers/sales_provider.dart';

@immutable
class StoreProvince {
  final String id;
  final String name;
  const StoreProvince({required this.id, required this.name});

  factory StoreProvince.fromJson(Map<String, dynamic> j) => StoreProvince(
    id: (j['id'] ?? '').toString(),
    name: (j['name'] ?? '').toString(),
  );
}
