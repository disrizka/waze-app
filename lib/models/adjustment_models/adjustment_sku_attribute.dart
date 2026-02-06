part of '../../providers/adjustment_provider.dart';

@immutable
class AdjustmentSkuAttribute {
  final String name;
  final String value;

  const AdjustmentSkuAttribute({required this.name, required this.value});

  factory AdjustmentSkuAttribute.fromJson(Map<String, dynamic> j) =>
      AdjustmentSkuAttribute(
        name: _asString(j['name']),
        value: _asString(j['value']),
      );
}
