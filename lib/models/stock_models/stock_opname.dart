part of '../../providers/stock_provider.dart';

@immutable
class StockOpname {
  final String idStockOpname;

  final StockStoreLocationLite storeLocation;
  final Product product;
  final StockProductSku productSku;

  final int systemQty;
  final int countedQty;
  final int variance;

  /// contoh: "submitted", "UNADJUSTED"
  final String status;

  final String note;

  /// contoh: "NOT_ADJUSTED"
  final String adjustmentStatus;

  /// contoh: "12-01-2026 11:04"
  final String createdAt;
  final String updatedAt;

  const StockOpname({
    required this.idStockOpname,
    required this.storeLocation,
    required this.product,
    required this.productSku,
    required this.systemQty,
    required this.countedQty,
    required this.variance,
    required this.status,
    required this.note,
    required this.adjustmentStatus,
    required this.createdAt,
    required this.updatedAt,
  });

  factory StockOpname.fromJson(Map<String, dynamic> j) {
    return StockOpname(
      idStockOpname: j['idStockOpname']?.toString() ?? '',
      storeLocation: StockStoreLocationLite.fromJson(
        _asMap(j['storeLocation']),
      ),
      product: Product.fromJson(_asMap(j['product'])),
      productSku: StockProductSku.fromJson(_asMap(j['productSku'])),
      systemQty: _toInt(j['systemQty']),
      countedQty: _toInt(j['countedQty']),
      variance: _toInt(j['variance']),
      status: j['status']?.toString() ?? '',
      note: j['note']?.toString() ?? '',
      adjustmentStatus: j['adjustmentStatus']?.toString() ?? '',
      createdAt: j['createdAt']?.toString() ?? '',
      updatedAt: j['updatedAt']?.toString() ?? '',
    );
  }
}
