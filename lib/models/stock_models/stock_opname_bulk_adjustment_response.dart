part of '../../providers/stock_provider.dart';

@immutable
class StockOpnameBulkAdjustmentResponse {
  final int status;
  final String message;
  final int successCount;
  final int skipCount;
  final List<StockOpnameBulkAdjustmentResult> results;

  const StockOpnameBulkAdjustmentResponse({
    required this.status,
    required this.message,
    required this.successCount,
    required this.skipCount,
    required this.results,
  });

  factory StockOpnameBulkAdjustmentResponse.fromJson(Map<String, dynamic> j) {
    final resultsJ = _asMapList(j['results']);
    final list = resultsJ
        .map(StockOpnameBulkAdjustmentResult.fromJson)
        .toList();

    return StockOpnameBulkAdjustmentResponse(
      status: _toInt(j['status']),
      message: j['message']?.toString() ?? '',
      successCount: _toInt(j['successCount']),
      skipCount: _toInt(j['skipCount']),
      results: list,
    );
  }
}
