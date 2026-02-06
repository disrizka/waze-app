part of '../../providers/product_provider.dart';

@immutable
class InventoryAttr {
  final String name;
  final String value;
  const InventoryAttr({required this.name, required this.value});

  factory InventoryAttr.fromJson(Map<String, dynamic> j) => InventoryAttr(
    name: j['name']?.toString() ?? '',
    value: j['value']?.toString() ?? '',
  );
}
