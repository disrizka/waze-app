part of '../../providers/stock_provider.dart';

/// Representasi SKU di initial stock.
@immutable
class StockProductSku {
  final String idProductSku;
  final String code;
  final int price;

  /// qty dari API bisa 0 / nullable
  final int? qty;

  final List<StockSkuAttribute> attributes;

  const StockProductSku({
    required this.idProductSku,
    required this.code,
    required this.price,
    this.qty,
    this.attributes = const [],
  });

  factory StockProductSku.fromJson(Map<String, dynamic> j) {
    final attrsJ = (j['attributes'] as List<dynamic>? ?? const <dynamic>[])
        .whereType<Map>()
        .map((e) => StockSkuAttribute.fromJson(e.cast<String, dynamic>()))
        .toList();

    final rawQty = j['qty'];
    final parsedQty = (rawQty is num)
        ? rawQty.toInt()
        : int.tryParse(rawQty?.toString() ?? '');

    final rawPrice = j['price'];
    final parsedPrice = (rawPrice is num)
        ? rawPrice.toInt()
        : int.tryParse(rawPrice?.toString() ?? '') ?? 0;

    return StockProductSku(
      idProductSku:
          j['idProductSku']?.toString() ??
          j['id_product_sku']?.toString() ??
          '',
      code: j['code']?.toString() ?? '',
      price: parsedPrice,
      qty: parsedQty,
      attributes: attrsJ,
    );
  }
}
