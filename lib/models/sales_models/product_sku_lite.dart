part of '../../providers/sales_provider.dart';

@immutable
class ProductSkuLite {
  final String idProductSku;
  final String code;
  final int price;
  final List<Map<String, String>> attributes; // [{name, value}, ...]

  const ProductSkuLite({
    required this.idProductSku,
    required this.code,
    required this.price,
    required this.attributes,
  });

  factory ProductSkuLite.fromJson(Map<String, dynamic> j) => ProductSkuLite(
    idProductSku: (j['idProductSku'] ?? '').toString(),
    code: (j['code'] ?? '').toString(),
    price: (j['price'] is num)
        ? (j['price'] as num).toInt()
        : int.tryParse('${j['price'] ?? 0}') ?? 0,
    attributes: ((j['attributes'] as List?) ?? [])
        .whereType<Map>()
        .map(
          (e) => {
            'name': (e['name'] ?? '').toString(),
            'value': (e['value'] ?? '').toString(),
          },
        )
        .toList(),
  );
}
