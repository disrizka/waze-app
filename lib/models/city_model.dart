class City {
  final int id;
  final String name;
  final int provinceId;
  final String provinceName;

  City({
    required this.id,
    required this.name,
    required this.provinceId,
    required this.provinceName,
  });

  factory City.fromJson(Map<String, dynamic> j) {
    return City(
      id: (j['id'] as num).toInt(),
      name: (j['name'] as String).trim(),
      provinceId: (j['province_id'] as num).toInt(),
      provinceName:
          (j['Province'] is Map && (j['Province']['name'] ?? '') is String)
          ? (j['Province']['name'] as String).trim()
          : '',
    );
  }
}
