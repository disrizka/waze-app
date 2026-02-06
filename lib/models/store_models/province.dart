part of '../../providers/store_provider.dart';

@immutable
class Province {
  final String id;
  final String name;

  const Province({required this.id, required this.name});

  factory Province.fromJson(Map<String, dynamic> j) => Province(
    id: (j['id'] ?? '').toString(),
    name: (j['name'] ?? '').toString(),
  );
}
