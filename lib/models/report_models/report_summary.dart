part of '../../providers/report_provider.dart';

@immutable
class ReportSummary {
  final int? totalTransactions; // opsional
  final int? totalQty; // opsional
  final num? totalRevenue; // purchase: total_cost
  final String? totalRevenueFormatted;

  // optional counts
  final int? totalProducts;
  final int? totalCategories;
  final int? totalBrands;
  final int? totalSuppliers;
  final int? totalCustomers;

  const ReportSummary({
    this.totalTransactions,
    this.totalQty,
    this.totalRevenue,
    this.totalRevenueFormatted,
    this.totalProducts,
    this.totalCategories,
    this.totalBrands,
    this.totalSuppliers,
    this.totalCustomers,
  });
}
