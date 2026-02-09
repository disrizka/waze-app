part of '../../providers/product_provider.dart';

@immutable
class SkuInventoryBuckets {
  final List<InventoryHistoryItem> currentStock;
  final List<InventoryHistoryItem> purchases;
  final List<InventoryHistoryItem> sales;
  final List<InventoryHistoryItem> transactions;

  const SkuInventoryBuckets({
    required this.currentStock,
    required this.purchases,
    required this.sales,
    required this.transactions,
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

    int _compareByLatest(InventoryHistoryItem a, InventoryHistoryItem b) {
      final aDt = a.createdAt.isAfter(a.updatedAt) ? a.createdAt : a.updatedAt;
      final bDt = b.createdAt.isAfter(b.updatedAt) ? b.createdAt : b.updatedAt;
      return bDt.compareTo(aDt);
    }

    final purchases = _parseList(j['purchases']);
    final sales = _parseList(j['sales']);
    final transactions = <InventoryHistoryItem>[...sales, ...purchases]
      ..sort(_compareByLatest);

    return SkuInventoryBuckets(
      currentStock: _parseList(j['current_stock']),
      purchases: purchases,
      sales: sales,
      transactions: transactions,
    );
  }
}
