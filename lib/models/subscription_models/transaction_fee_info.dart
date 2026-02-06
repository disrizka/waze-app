part of '../../providers/subscription_provider.dart';

class TransactionFeeInfo {
  final String id;
  final int month;
  final int year;
  final String period;
  final String status; // pending / paid / etc
  final int totalFee;
  final int transactionCount;

  const TransactionFeeInfo({
    required this.id,
    required this.month,
    required this.year,
    required this.period,
    required this.status,
    required this.totalFee,
    required this.transactionCount,
  });

  factory TransactionFeeInfo.fromJson(Map<String, dynamic> json) {
    return TransactionFeeInfo(
      id: json['id']?.toString() ?? '',
      month: (json['month'] as num?)?.toInt() ?? 0,
      year: (json['year'] as num?)?.toInt() ?? 0,
      period: json['period']?.toString() ?? '',
      status: json['status']?.toString() ?? '',
      totalFee: (json['total_fee'] as num?)?.toInt() ?? 0,
      transactionCount: (json['transaction_count'] as num?)?.toInt() ?? 0,
    );
  }
}
