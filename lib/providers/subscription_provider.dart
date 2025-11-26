import 'package:flutter/material.dart';

enum BillingCycle { monthly, yearly }

class SubscriptionProvider with ChangeNotifier {
  static const double _monthlyPrice = 11.0;
  static const double _yearlyPrice = 120.0;

  BillingCycle _selectedCycle = BillingCycle.monthly;
  bool _isProcessing = false;

  BillingCycle get selectedCycle => _selectedCycle;
  bool get isProcessing => _isProcessing;

  double get monthlyPrice => _monthlyPrice;
  double get yearlyPrice => _yearlyPrice;

  double get yearlyDiscountPercent {
    final normalYearly = _monthlyPrice * 12;
    final discount = 100 - (_yearlyPrice / normalYearly * 100);
    return discount;
  }

  void selectCycle(BillingCycle cycle) {
    if (_selectedCycle == cycle) return;
    _selectedCycle = cycle;
    notifyListeners();
  }

  /// Di sini nanti kamu bisa ganti dengan call API / Midtrans, dsb.
  Future<void> goToPayment(BuildContext context) async {
    _isProcessing = true;
    notifyListeners();

    // Dummy delay
    await Future.delayed(const Duration(seconds: 1));

    _isProcessing = false;
    notifyListeners();

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'Checkout simulation only. Integrate payment gateway here.',
        ),
      ),
    );
  }

  String get selectedPriceLabel {
    switch (_selectedCycle) {
      case BillingCycle.monthly:
        return '\$${_monthlyPrice.toStringAsFixed(2)} /month';
      case BillingCycle.yearly:
        return '\$${_yearlyPrice.toStringAsFixed(2)} /year';
    }
  }
}
