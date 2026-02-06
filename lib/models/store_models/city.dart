part of '../../providers/store_provider.dart';

@immutable
class City {
  final String id;
  final String name;
  final Province? province;

  const City({required this.id, required this.name, this.province});

  factory City.fromJson(Map<String, dynamic> j) => City(
    id: (j['id'] ?? '').toString(),
    name: (j['name'] ?? '').toString(),
    province: (j['province'] is Map<String, dynamic>)
        ? Province.fromJson(j['province'] as Map<String, dynamic>)
        : null,
  );
}
