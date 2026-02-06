part of '../../providers/stock_provider.dart';

/// Attribute SKU di konteks initial stock.
@immutable
class StockSkuAttribute {
  final String name;
  final String value;

  const StockSkuAttribute({required this.name, required this.value});

  factory StockSkuAttribute.fromJson(Map<String, dynamic> j) {
    return StockSkuAttribute(
      name: j['name']?.toString() ?? '',
      value: j['value']?.toString() ?? '',
    );
  }
}
