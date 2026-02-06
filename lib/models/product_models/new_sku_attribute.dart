part of '../../providers/product_provider.dart';

@immutable
class NewSkuAttribute {
  final String name;
  final String value;
  const NewSkuAttribute({required this.name, required this.value});

  Map<String, dynamic> toJson() => {'name': name, 'value': value};
}
