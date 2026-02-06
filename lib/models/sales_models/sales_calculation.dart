part of '../../providers/sales_provider.dart';

@immutable
class SalesCalculation {
  final int subtotal;
  final int discount;
  final int shippingFee;
  final int grandtotal;

  const SalesCalculation({
    required this.subtotal,
    required this.discount,
    required this.shippingFee,
    required this.grandtotal,
  });

  factory SalesCalculation.fromJson(Map<String, dynamic> j) => SalesCalculation(
    subtotal: (j['subtotal'] is num)
        ? (j['subtotal'] as num).toInt()
        : int.tryParse('${j['subtotal'] ?? 0}') ?? 0,
    discount: (j['discount'] is num)
        ? (j['discount'] as num).toInt()
        : int.tryParse('${j['discount'] ?? 0}') ?? 0,
    shippingFee: (j['shipping_fee'] is num)
        ? (j['shipping_fee'] as num).toInt()
        : int.tryParse('${j['shipping_fee'] ?? 0}') ?? 0,
    grandtotal: (j['grandtotal'] is num)
        ? (j['grandtotal'] as num).toInt()
        : int.tryParse('${j['grandtotal'] ?? 0}') ?? 0,
  );
}
