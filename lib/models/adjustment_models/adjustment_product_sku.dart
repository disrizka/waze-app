part of '../../providers/adjustment_provider.dart';

@immutable
class AdjustmentProductSku {
  final String idProductSku;
  final String code;
  final int price;
  final int? qty;
  final List<AdjustmentSkuAttribute> attributes;

  const AdjustmentProductSku({
    required this.idProductSku,
    required this.code,
    required this.price,
    this.qty,
    this.attributes = const [],
  });

  factory AdjustmentProductSku.fromJson(Map<String, dynamic> j) {
    final attrs = _asListOfMap(
      j['attributes'],
    ).map(AdjustmentSkuAttribute.fromJson).toList();

    final rawQty = j['qty'];
    final parsedQty = (rawQty is num)
        ? rawQty.toInt()
        : int.tryParse(rawQty?.toString() ?? '');

    return AdjustmentProductSku(
      idProductSku: _asString(j['idProductSku']).isNotEmpty
          ? _asString(j['idProductSku'])
          : _asString(j['id_product_sku']),
      code: _asString(j['code']),
      price: _asInt(j['price']),
      qty: parsedQty,
      attributes: attrs,
    );
  }
}
