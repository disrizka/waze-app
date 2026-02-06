part of '../../providers/stock_provider.dart';

@immutable
class StockOpnameItem {
  final String idStockOpnameItem;
  final Product product;
  final StockProductSku productSku;

  final int countedQty;
  final int systemQty;
  final int variance;
  final String reason;

  const StockOpnameItem({
    required this.idStockOpnameItem,
    required this.product,
    required this.productSku,
    required this.countedQty,
    required this.systemQty,
    required this.variance,
    required this.reason,
  });

  factory StockOpnameItem.fromJson(Map<String, dynamic> j) {
    return StockOpnameItem(
      idStockOpnameItem: j['idStockOpnameItem']?.toString() ?? '',
      product: Product.fromJson(_asMap(j['product'])),
      productSku: StockProductSku.fromJson(_asMap(j['productSku'])),
      countedQty: _toInt(j['countedQty']),
      systemQty: _toInt(j['systemQty']),
      variance: _toInt(j['variance']),
      reason: j['reason']?.toString() ?? '',
    );
  }
}
