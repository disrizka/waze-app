part of '../../providers/product_provider.dart';

/// Item riwayat per transaksi inventory.
@immutable
class InventoryHistoryItem {
  final DateTime createdAt;
  final DateTime updatedAt;
  final String note;
  final int qty;
  final String referenceId;
  final String referenceType; // e.g. "purchase"
  final String source; // e.g. "transaction"
  final String type; // e.g. "purchase"
  final Product product; // pakai model Product yang sudah ada
  final InventoryProductSku productSku;
  final InventoryStoreLocationLite storeLocation;

  const InventoryHistoryItem({
    required this.createdAt,
    required this.updatedAt,
    required this.note,
    required this.qty,
    required this.referenceId,
    required this.referenceType,
    required this.source,
    required this.type,
    required this.product,
    required this.productSku,
    required this.storeLocation,
  });

  factory InventoryHistoryItem.fromJson(Map<String, dynamic> j) =>
      InventoryHistoryItem(
        createdAt:
            DateTime.tryParse(j['createdAt']?.toString() ?? '') ??
            DateTime.fromMillisecondsSinceEpoch(0),
        updatedAt:
            DateTime.tryParse(j['updatedAt']?.toString() ?? '') ??
            DateTime.fromMillisecondsSinceEpoch(0),
        note: j['note']?.toString() ?? '',
        qty: (j['qty'] is num)
            ? (j['qty'] as num).toInt()
            : int.tryParse('${j['qty']}') ?? 0,
        referenceId: j['referenceId']?.toString() ?? '',
        referenceType: j['referenceType']?.toString() ?? '',
        source: j['source']?.toString() ?? '',
        type: j['type']?.toString() ?? '',
        product: Product.fromJson(
          (j['product'] as Map?)?.cast<String, dynamic>() ?? const {},
        ),
        productSku: InventoryProductSku.fromJson(
          (j['productSku'] as Map?)?.cast<String, dynamic>() ?? const {},
        ),
        storeLocation: InventoryStoreLocationLite.fromJson(
          (j['storeLocation'] as Map?)?.cast<String, dynamic>() ?? const {},
        ),
      );
}
