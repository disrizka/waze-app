part of '../../providers/report_provider.dart';

@immutable
class EntityReportItem {
  final String label; // nama: customer/supplier/brand/category/product
  final String? sku; // product_sku (opsional)
  final String? phone; // phone (opsional)
  final int totalTransactions;
  final int totalQty;
  final num totalRevenue; // purchase: total_cost (dinormalisasi)
  final String? revenueFormatted;
  final num? avgTransaction; // avg_price / avg_transaction (dinormalisasi)
  final String? avgTransactionFormatted;

  const EntityReportItem({
    required this.label,
    this.sku,
    this.phone,
    required this.totalTransactions,
    required this.totalQty,
    required this.totalRevenue,
    this.revenueFormatted,
    this.avgTransaction,
    this.avgTransactionFormatted,
  });

  EntityReportItem copyWith({
    String? label,
    String? sku,
    String? phone,
    int? totalTransactions,
    int? totalQty,
    num? totalRevenue,
    String? revenueFormatted,
    num? avgTransaction,
    String? avgTransactionFormatted,
  }) {
    return EntityReportItem(
      label: label ?? this.label,
      sku: sku ?? this.sku,
      phone: phone ?? this.phone,
      totalTransactions: totalTransactions ?? this.totalTransactions,
      totalQty: totalQty ?? this.totalQty,
      totalRevenue: totalRevenue ?? this.totalRevenue,
      revenueFormatted: revenueFormatted ?? this.revenueFormatted,
      avgTransaction: avgTransaction ?? this.avgTransaction,
      avgTransactionFormatted:
          avgTransactionFormatted ?? this.avgTransactionFormatted,
    );
  }
}
