part of '../../providers/sales_provider.dart';

class PaymentResult {
  final String status; // settlement | pending | cancel | failure | etc.
  final String? transactionId; // dari TransactionResult
  final String? paymentType; // dari TransactionResult
  final String? message; // dari TransactionResult
  final String?
  orderId; // [Opsional] isi dari sistemmu sendiri / finish URL / server
  final String? raw;
  const PaymentResult(
    this.status, {
    this.transactionId,
    this.paymentType,
    this.message,
    this.orderId,
    this.raw,
  });
}
