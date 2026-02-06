part of '../../providers/subscription_provider.dart';

class SubscriptionHistoryItem {
  final String id;
  final String number;
  final int amount;
  final DateTime? createdAt;
  final int paid; // 0 / 1
  final DateTime? paidAt;
  final String paidStatus;

  final int paymentMethod;
  final String paymentMethodName;

  final String planId;
  final String planName;
  final String pricingId;

  final String description;
  final String period;
  final String type;

  final String paymentLink;
  final String paymentToken;

  final String transactionFeeId;

  SubscriptionHistoryItem({
    required this.id,
    required this.number,
    required this.amount,
    required this.createdAt,
    required this.paid,
    required this.paidAt,
    required this.paidStatus,
    required this.paymentMethod,
    required this.paymentMethodName,
    required this.planId,
    required this.planName,
    required this.pricingId,
    required this.description,
    required this.period,
    required this.type,
    required this.paymentLink,
    required this.paymentToken,
    required this.transactionFeeId,
  });

  factory SubscriptionHistoryItem.fromJson(Map<String, dynamic> json) {
    DateTime? _parseDate(String? raw) {
      if (raw == null || raw.isEmpty) return null;
      try {
        return DateTime.parse(raw);
      } catch (_) {
        return null;
      }
    }

    String pickTxFeeId(Map<String, dynamic> j) {
      final candidates = [
        'idTransactionFee',
        'id_transaction_fee',
        'transaction_fee_id',
        'transactionFeeId',
        'transaction_fee',
      ];

      for (final k in candidates) {
        final v = j[k];
        if (v == null) continue;

        if (v is Map && v['id'] != null) {
          final s = v['id'].toString().trim();
          if (s.isNotEmpty) return s;
        }

        final s = v.toString().trim();
        if (s.isNotEmpty && s.toLowerCase() != 'null') return s;
      }
      return '';
    }

    return SubscriptionHistoryItem(
      id: json['id']?.toString() ?? '',
      number: json['number']?.toString() ?? '',
      amount: (json['amount'] as num?)?.toInt() ?? 0,
      createdAt: _parseDate(json['created_at']?.toString()),
      paid: (json['paid'] as num?)?.toInt() ?? 0,
      paidAt: _parseDate(json['paid_at']?.toString()),
      paidStatus: json['paid_status']?.toString() ?? '',
      paymentMethod: (json['payment_method'] as num?)?.toInt() ?? 0,
      paymentMethodName: json['payment_method_name']?.toString() ?? '',
      planId: json['plan_id']?.toString() ?? '',
      planName: json['plan_name']?.toString() ?? '',
      pricingId: json['pricing_id']?.toString() ?? '',
      description: json['description']?.toString() ?? '',
      period: json['period']?.toString() ?? '',
      type: json['type']?.toString() ?? '',
      paymentLink: json['payment_link']?.toString() ?? '',
      paymentToken: json['payment_token']?.toString() ?? '',
      transactionFeeId: pickTxFeeId(json),
    );
  }
}
