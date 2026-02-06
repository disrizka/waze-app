part of '../../providers/stock_provider.dart';

@immutable
class StockAdjustmentTransaction {
  final String idTransaction;
  final String storeLocationId;
  final StockStoreLocationLite storeLocation;

  final int type;
  final String number;
  final int storeId;

  final String note;
  final String reference;
  final String status;

  final int amount;
  final int discount;
  final int shippingFee;

  /// unix timestamp (seconds)
  final int orderAt;

  final int paymentMethod;

  /// ISO string
  final String createdAt;

  /// ISO string
  final String updatedAt;

  const StockAdjustmentTransaction({
    required this.idTransaction,
    required this.storeLocationId,
    required this.storeLocation,
    required this.type,
    required this.number,
    required this.storeId,
    required this.note,
    required this.reference,
    required this.status,
    required this.amount,
    required this.discount,
    required this.shippingFee,
    required this.orderAt,
    required this.paymentMethod,
    required this.createdAt,
    required this.updatedAt,
  });

  factory StockAdjustmentTransaction.fromJson(Map<String, dynamic> j) {
    return StockAdjustmentTransaction(
      idTransaction: j['idTransaction']?.toString() ?? '',
      storeLocationId: j['store_location_id']?.toString() ?? '',
      storeLocation: StockStoreLocationLite.fromJson(
        _asMap(j['store_location']),
      ),
      type: _toInt(j['type']),
      number: j['number']?.toString() ?? '',
      storeId: _toInt(j['store_id']),
      note: j['note']?.toString() ?? '',
      reference: j['reference']?.toString() ?? '',
      status: j['status']?.toString() ?? '',
      amount: _toInt(j['amount']),
      discount: _toInt(j['discount']),
      shippingFee: _toInt(j['shipping_fee']),
      orderAt: _toInt(j['order_at']),
      paymentMethod: _toInt(j['payment_method']),
      createdAt: j['created_at']?.toString() ?? '',
      updatedAt: j['updated_at']?.toString() ?? '',
    );
  }
}
