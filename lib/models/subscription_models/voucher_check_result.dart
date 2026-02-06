part of '../../providers/subscription_provider.dart';

class VoucherCheckResult {
  final bool isValid;
  final int originalPrice;
  final int finalPrice;
  final int discount;
  final String? voucherName;
  final String? voucherDesc;
  final String? message;

  const VoucherCheckResult({
    required this.isValid,
    required this.originalPrice,
    required this.finalPrice,
    required this.discount,
    this.voucherName,
    this.voucherDesc,
    this.message,
  });
}
