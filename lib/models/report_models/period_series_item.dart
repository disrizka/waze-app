part of '../../providers/report_provider.dart';

@immutable
class PeriodSeriesItem {
  final String period; // contoh "2025-08-01" / "2025-11" / "2025-W46"
  final int totalTransactions;
  final int totalQty;
  final num totalRevenue; // purchase: total_cost (dinormalisasi)
  final String? revenueFormatted;

  const PeriodSeriesItem({
    required this.period,
    required this.totalTransactions,
    required this.totalQty,
    required this.totalRevenue,
    this.revenueFormatted,
  });
}
