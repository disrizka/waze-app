// ====== Tambahkan di luar class (model detail & parser) ======

class PurchaseDetail {
  final String idTransaction;
  final String number;
  final String status; // "pending" | "completed" | "canceled" (sesuai API)
  final String storeLocationId;
  final String note;
  final String reference;
  final int amount; // grand total dari API
  final int discount;
  final int shippingFee;
  final DateTime orderAt;
  final DateTime createdAt;
  final List<PurchaseDetailItem> items;

  const PurchaseDetail({
    required this.idTransaction,
    required this.number,
    required this.status,
    required this.storeLocationId,
    required this.note,
    required this.reference,
    required this.amount,
    required this.discount,
    required this.shippingFee,
    required this.orderAt,
    required this.createdAt,
    required this.items,
  });

  /// Total kuantitas masuk (qty_in - qty_out)
  int get totalQty => items.fold<int>(0, (s, i) => s + (i.qtyIn - i.qtyOut));

  /// Subtotal dihitung dari item (qty_in - qty_out) * price
  int get itemsSubtotal =>
      items.fold<int>(0, (s, i) => s + (i.netQty * i.price));

  factory PurchaseDetail.fromJson(Map<String, dynamic> j) {
    final items = ((j['items'] as List?) ?? const [])
        .whereType<Map<String, dynamic>>()
        .map(PurchaseDetailItem.fromJson)
        .toList(growable: false);

    return PurchaseDetail(
      idTransaction: (j['idTransaction'] ?? '').toString(),
      number: (j['number'] ?? '').toString(),
      status: (j['status'] ?? '').toString(),
      storeLocationId: (j['store_location_id'] ?? '').toString(),
      note: (j['note'] ?? '').toString(),
      reference: (j['reference'] ?? '').toString(),
      amount: _asInt(j['amount']),
      discount: _asInt(j['discount']),
      shippingFee: _asInt(j['shipping_fee']),
      orderAt: _parseTime(j['order_at'], j['created_at']),
      createdAt: _parseTime(0, j['created_at']),
      items: items,
    );
  }
}

class PurchaseDetailItem {
  final String productId;
  final String productSkuId;
  final int qtyIn;
  final int qtyOut;
  final int price;

  int get netQty => (qtyIn - qtyOut).clamp(0, 1 << 31);

  const PurchaseDetailItem({
    required this.productId,
    required this.productSkuId,
    required this.qtyIn,
    required this.qtyOut,
    required this.price,
  });

  factory PurchaseDetailItem.fromJson(Map<String, dynamic> j) {
    return PurchaseDetailItem(
      productId: (j['product_id'] ?? '').toString(),
      productSkuId: (j['product_sku_id'] ?? '').toString(),
      qtyIn: _asInt(j['qty_in']),
      qtyOut: _asInt(j['qty_out']),
      price: _asInt(j['price']),
    );
  }
}

DateTime _parseTime(dynamic orderAt, dynamic createdAtStr) {
  // order_at: epoch detik
  final sec = _asInt(orderAt);
  if (sec > 0) return DateTime.fromMillisecondsSinceEpoch(sec * 1000);
  if (createdAtStr is String && createdAtStr.isNotEmpty) {
    try {
      return DateTime.parse(createdAtStr);
    } catch (_) {}
  }
  return DateTime.now();
}

int _asInt(dynamic v) {
  if (v == null) return 0;
  if (v is num) return v.toInt();
  if (v is String) return int.tryParse(v) ?? 0;
  return 0;
}
