part of '../../providers/adjustment_provider.dart';

/// 1 transaksi adjustment (list & detail)
@immutable
class AdjustmentTransaction {
  final String idTransaction;

  final String storeLocationId;
  final AdjustmentStoreLocationLite storeLocation;

  final int type;
  final String number;
  final int storeId;

  final String note;
  final String reference;
  final String status;

  final int amount;
  final int discount;
  final int shippingFee;

  final int orderAt; // unix timestamp seconds
  final int paymentMethod;

  final String createdAt;
  final String updatedAt;

  final List<AdjustmentItem> items;

  const AdjustmentTransaction({
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
    required this.items,
  });

  factory AdjustmentTransaction.fromJson(Map<String, dynamic> j) {
    final parsedItems = _asListOfMap(
      j['items'],
    ).map(AdjustmentItem.fromJson).toList();

    return AdjustmentTransaction(
      idTransaction: _asString(j['idTransaction']),
      storeLocationId: _asString(j['store_location_id']),
      storeLocation: AdjustmentStoreLocationLite.fromJson(
        _asMap(j['store_location']) ?? const {},
      ),
      type: _asInt(j['type']),
      number: _asString(j['number']),
      storeId: _asInt(j['store_id']),
      note: _asString(j['note']),
      reference: _asString(j['reference']),
      status: _asString(j['status']),
      amount: _asInt(j['amount']),
      discount: _asInt(j['discount']),
      shippingFee: _asInt(j['shipping_fee']),
      orderAt: _asInt(j['order_at']),
      paymentMethod: _asInt(j['payment_method']),
      createdAt: _asString(j['created_at']),
      updatedAt: _asString(j['updated_at']),
      items: parsedItems,
    );
  }
}
