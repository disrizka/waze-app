part of '../../providers/adjustment_provider.dart';

/// Detail response
@immutable
class AdjustmentDetailResult {
  final AdjustmentTransaction transaction;
  final Map<String, dynamic>? stockOpname;
  final String? adjustmentStatus;

  const AdjustmentDetailResult({
    required this.transaction,
    this.stockOpname,
    this.adjustmentStatus,
  });
}
