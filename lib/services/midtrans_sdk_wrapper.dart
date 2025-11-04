// lib/src/models/transaction_result.dart  (contoh path)
class TransactionResult {
  final String? transactionId;
  final String? status; // settlement | pending | cancel | failure | dll
  final String? paymentType;
  final String? message;
  final String? orderId; // opsional; ambil jika ada

  const TransactionResult({
    this.transactionId,
    this.status,
    this.paymentType,
    this.message,
    this.orderId,
  });

  factory TransactionResult.fromJson(Map<String, dynamic>? json) {
    final m = json ?? const <String, dynamic>{};
    String? s(Object? v) => v?.toString();
    // sebagian SDK pakai snake_case; amankan keduanya:
    String? pick(List<String> keys) {
      for (final k in keys) {
        final v = m[k];
        if (v != null) return s(v);
      }
      return null;
    }

    return TransactionResult(
      transactionId: pick(['transactionId', 'transaction_id']),
      status: pick(['status', 'transaction_status']),
      paymentType: pick(['paymentType', 'payment_type']),
      message: pick(['message', 'status_message']),
      orderId: pick(['orderId', 'order_id']),
    );
  }

  @override
  String toString() =>
      'TransactionResult('
      'transactionId=$transactionId, '
      'status=$status, '
      'paymentType=$paymentType, '
      'message=$message, '
      'orderId=$orderId'
      ')';
}
