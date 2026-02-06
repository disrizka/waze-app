part of '../../providers/product_provider.dart';

@immutable
class SkuInventoryBuckets {
  final List<InventoryHistoryItem> currentStock;
  final List<InventoryHistoryItem> purchases;
  final List<InventoryHistoryItem> sales;

  const SkuInventoryBuckets({
    required this.currentStock,
    required this.purchases,
    required this.sales,
  });

  factory SkuInventoryBuckets.fromJson(Map<String, dynamic> j) {
    List<InventoryHistoryItem> _parseList(dynamic raw) {
      final list = (raw as List?) ?? const [];
      return list
          .whereType<Map>()
          .map(
            (e) => InventoryHistoryItem.fromJson(
              Map<String, dynamic>.from(e.cast<String, dynamic>()),
            ),
          )
          .toList();
    }

    return SkuInventoryBuckets(
      currentStock: _parseList(j['current_stock']),
      purchases: _parseList(j['purchases']),
      sales: _parseList(j['sales']),
    );
  }
}
