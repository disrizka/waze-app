part of '../../providers/sales_provider.dart';

@immutable
class SalesReportItem {
  final String idTransaction;
  final String code; // "number"
  final DateTime time; // order_at (epoch detik) atau created_at
  final int quantity; // sum(qty_out)
  final int totalAmount; // "amount"
  final String reference;
  final String status;
  final List<SalesLine> lines;

  const SalesReportItem({
    required this.idTransaction,
    required this.code,
    required this.time,
    required this.quantity,
    required this.totalAmount,
    required this.reference,
    required this.status,
    required this.lines,
  });
}
