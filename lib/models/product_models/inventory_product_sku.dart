part of '../../providers/product_provider.dart';

@immutable
class InventoryProductSku {
  final String idProductSku;
  final String code;
  final int price;
  final List<InventoryAttr> attributes;

  const InventoryProductSku({
    required this.idProductSku,
    required this.code,
    required this.price,
    required this.attributes,
  });

  factory InventoryProductSku.fromJson(Map<String, dynamic> j) =>
      InventoryProductSku(
        idProductSku: j['idProductSku']?.toString() ?? '',
        code: j['code']?.toString() ?? '',
        price: (j['price'] is num)
            ? (j['price'] as num).toInt()
            : int.tryParse('${j['price']}') ?? 0,
        attributes: (j['attributes'] as List<dynamic>? ?? const [])
            .whereType<Map<String, dynamic>>()
            .map(InventoryAttr.fromJson)
            .toList(),
      );
}
