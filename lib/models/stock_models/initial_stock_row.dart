part of '../../providers/stock_provider.dart';

/// Satu baris hasil GET /waveup/{businessId}/initial-stock
@immutable
class InitialStockRow {
  final String id;
  final StockStoreLocationLite storeLocation;
  final Product product;
  final StockProductSku productSku;
  final int qty;
  final String type; // "initial_stock"
  final String note;
  final String referenceType; // "initial_stock"

  const InitialStockRow({
    required this.id,
    required this.storeLocation,
    required this.product,
    required this.productSku,
    required this.qty,
    required this.type,
    required this.note,
    required this.referenceType,
  });

  factory InitialStockRow.fromJson(Map<String, dynamic> j) {
    return InitialStockRow(
      id: j['id']?.toString() ?? '',
      storeLocation: StockStoreLocationLite.fromJson(
        _asMap(j['storeLocation']),
      ),
      product: Product.fromJson(_asMap(j['product'])),
      productSku: StockProductSku.fromJson(_asMap(j['productSku'])),
      qty: _toInt(j['qty']),
      type: j['type']?.toString() ?? '',
      note: j['note']?.toString() ?? '',
      referenceType: j['referenceType']?.toString() ?? '',
    );
  }
}
