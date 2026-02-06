part of '../../providers/subscription_provider.dart';

class TransactionFeeHistoryLineItem {
  final String transactionReference;
  final int qtyIn;
  final int qtyOut;
  final int price;
  final int discount;

  final String productId;
  final String productName;

  const TransactionFeeHistoryLineItem({
    required this.transactionReference,
    required this.qtyIn,
    required this.qtyOut,
    required this.price,
    required this.discount,
    required this.productId,
    required this.productName,
  });

  factory TransactionFeeHistoryLineItem.fromJson(Map<String, dynamic> json) {
    final product = (json['product'] is Map) ? (json['product'] as Map) : null;

    return TransactionFeeHistoryLineItem(
      transactionReference: json['transaction_reference']?.toString() ?? '',
      qtyIn: (json['qty_in'] as num?)?.toInt() ?? 0,
      qtyOut: (json['qty_out'] as num?)?.toInt() ?? 0,
      price: (json['price'] as num?)?.toInt() ?? 0,
      discount: (json['discount'] as num?)?.toInt() ?? 0,
      productId:
          (product?['idProduct'] ?? json['product_id'])?.toString() ?? '',
      productName: (product?['name'])?.toString() ?? '-',
    );
  }
}
