part of '../../providers/subscription_provider.dart';

class TransactionFeeItem {
  final String idTransactionFee;
  final String idBusiness;
  final int month;
  final int year;
  final int transactionCount;
  final int totalFee;
  final String status; // pending / paid / etc

  const TransactionFeeItem({
    required this.idTransactionFee,
    required this.idBusiness,
    required this.month,
    required this.year,
    required this.transactionCount,
    required this.totalFee,
    required this.status,
  });

  factory TransactionFeeItem.fromJson(Map<String, dynamic> json) {
    return TransactionFeeItem(
      idTransactionFee: json['idTransactionFee']?.toString() ?? '',
      idBusiness: json['idBusiness']?.toString() ?? '',
      month: (json['month'] as num?)?.toInt() ?? 0,
      year: (json['year'] as num?)?.toInt() ?? 0,
      transactionCount: (json['transaction_count'] as num?)?.toInt() ?? 0,
      totalFee: (json['total_fee'] as num?)?.toInt() ?? 0,
      status: json['status']?.toString() ?? '',
    );
  }
}
