part of '../../providers/subscription_provider.dart';

class PaymentResult {
  final String status;
  final String? transactionId;
  final String? paymentType;
  final String? message;
  final String? raw;

  PaymentResult(
    this.status, {
    this.transactionId,
    this.paymentType,
    this.message,
    this.raw,
  });
}
