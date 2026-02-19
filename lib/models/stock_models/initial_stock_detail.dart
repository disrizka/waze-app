part of '../../providers/stock_provider.dart';

/// Dokumen detail initial stock (/initial-stock/:id).
/// Bentuk pastinya belum kamu kirim, jadi ini dibuat cukup fleksibel.
@immutable
class InitialStockDetail {
  final String id;
  final StockStoreLocationLite? storeLocation;
  final String note;

  /// total / header discount (jika ada)
  final int? discount;

  final List<InitialStockItem> items;

  const InitialStockDetail({
    required this.id,
    required this.storeLocation,
    required this.note,
    required this.items,
    this.discount,
  });

  factory InitialStockDetail.fromJson(Map<String, dynamic> j) {
    final storeJ = _asMap(j['storeLocation']).isNotEmpty
        ? _asMap(j['storeLocation'])
        : _asMap(j['store_location']);

    final itemsJ = _asMapList(j['items']);
    final items = itemsJ.map(InitialStockItem.fromJson).toList();

    final parsedDiscount = (j['discount'] == null)
        ? null
        : _toInt(j['discount']);

    return InitialStockDetail(
      id:
          (j['id'] ??
                  j['idTransaction'] ??
                  j['id_transaction'] ??
                  j['transactionId'] ??
                  '')
              .toString(),
      storeLocation: storeJ.isNotEmpty
          ? StockStoreLocationLite.fromJson(storeJ)
          : null,
      note: j['note']?.toString() ?? '',
      items: items,
      discount: parsedDiscount,
    );
  }
}
