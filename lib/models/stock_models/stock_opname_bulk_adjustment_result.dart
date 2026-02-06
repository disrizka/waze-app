part of '../../providers/stock_provider.dart';

@immutable
class StockOpnameBulkAdjustmentResult {
  final String stockOpnameId;
  final String productName;
  final String skuCode;
  final int variance;

  /// "success" / "skipped" / dll tergantung backend
  final String status;

  const StockOpnameBulkAdjustmentResult({
    required this.stockOpnameId,
    required this.productName,
    required this.skuCode,
    required this.variance,
    required this.status,
  });

  factory StockOpnameBulkAdjustmentResult.fromJson(Map<String, dynamic> j) {
    return StockOpnameBulkAdjustmentResult(
      stockOpnameId: j['stockOpnameId']?.toString() ?? '',
      productName: j['productName']?.toString() ?? '',
      skuCode: j['skuCode']?.toString() ?? '',
      variance: _toInt(j['variance']),
      status: j['status']?.toString() ?? '',
    );
  }
}
