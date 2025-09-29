// lib/models/city_model.dart

class Province {
  final String id;
  final String name;

  const Province({required this.id, required this.name});

  factory Province.fromJson(Map<String, dynamic> j) {
    return Province(id: _asString(j['id']), name: _asString(j['name']));
  }

  Map<String, dynamic> toJson() => {'id': id, 'name': name};

  @override
  String toString() => 'Province(id: $id, name: $name)';
}

class City {
  final String id;
  final String name;
  final Province province;

  const City({required this.id, required this.name, required this.province});

  factory City.fromJson(Map<String, dynamic> j) {
    final rawProv = j['province'] ?? j['Province'] ?? const {};
    return City(
      id: _asString(j['id']), // <-- tidak lagi cast ke num
      name: _asString(j['name']),
      province: Province.fromJson(
        (rawProv is Map<String, dynamic>) ? rawProv : const {},
      ),
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'province': province.toJson(),
  };

  @override
  String toString() => 'City(id: $id, name: $name, province: ${province.name})';
}

/// -------- helpers ----------
String _asString(dynamic v, {String fallback = ''}) {
  if (v == null) return fallback;
  final s = v.toString().trim();
  return s.isEmpty ? fallback : s;
}
