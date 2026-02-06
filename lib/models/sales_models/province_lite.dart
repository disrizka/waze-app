part of '../../providers/sales_provider.dart';

@immutable
class ProvinceLite {
  final String id;
  final String name;
  const ProvinceLite({required this.id, required this.name});

  factory ProvinceLite.fromJson(Map<String, dynamic> j) => ProvinceLite(
    id: (j['id'] ?? '').toString(),
    name: (j['name'] ?? '').toString(),
  );
}
