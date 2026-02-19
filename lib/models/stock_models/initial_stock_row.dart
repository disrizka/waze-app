part of '../../providers/stock_provider.dart';

/// Satu baris hasil GET /waveup/{businessId}/initial-stock
@immutable
class InitialStockRow {
  final String id;
  final String number;
  final DateTime? createdAt;
  final StockStoreLocationLite storeLocation;
  final Product product;
  final StockProductSku productSku;
  final int qty;
  final String type; // "initial_stock"
  final String note;
  final String referenceType; // "initial_stock"

  const InitialStockRow({
    required this.id,
    required this.number,
    required this.createdAt,
    required this.storeLocation,
    required this.product,
    required this.productSku,
    required this.qty,
    required this.type,
    required this.note,
    required this.referenceType,
  });

  factory InitialStockRow.fromJson(Map<String, dynamic> j) {
    DateTime? parseDateTime(dynamic raw) {
      if (raw == null) return null;

      if (raw is num) {
        final n = raw.toInt();
        if (n <= 0) return null;
        final ms = n > 1000000000000 ? n : (n * 1000);
        return DateTime.fromMillisecondsSinceEpoch(ms);
      }

      final s = raw.toString().trim();
      if (s.isEmpty) return null;

      final asNum = int.tryParse(s);
      if (asNum != null && asNum > 0) {
        final ms = asNum > 1000000000000 ? asNum : (asNum * 1000);
        return DateTime.fromMillisecondsSinceEpoch(ms);
      }

      return DateTime.tryParse(s);
    }

    return InitialStockRow(
      id:
          (j['id'] ??
                  j['idTransaction'] ??
                  j['id_transaction'] ??
                  j['transactionId'] ??
                  '')
              .toString(),
      number:
          (j['number'] ??
                  j['reference'] ??
                  j['code'] ??
                  j['transaction_number'] ??
                  '')
              .toString(),
      createdAt: parseDateTime(
        j['created_at'] ??
            j['createdAt'] ??
            j['create_time'] ??
            j['createTime'] ??
            j['date'] ??
            j['datetime'],
      ),
      storeLocation: StockStoreLocationLite.fromJson(
        _asMap(j['storeLocation']).isNotEmpty
            ? _asMap(j['storeLocation'])
            : _asMap(j['store_location']),
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
