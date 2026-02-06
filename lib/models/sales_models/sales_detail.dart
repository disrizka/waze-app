part of '../../providers/sales_provider.dart';

@immutable
class SalesDetail {
  final String idTransaction;
  final String number;
  final String status;
  final String reference;
  final String note;
  final int amount;
  final int discount;
  final int shippingFee;
  final int paymentMethod;
  final DateTime time;
  final StoreLocationLite? storeLocation;
  final CustomerLite? customer;
  final List<SalesDetailItem> items;
  final SalesCalculation? calculation;

  // ⬇️ NEW
  final String? paymentToken; // midtrans/snap token
  final String? paymentLink; // redirect_url / deeplink

  const SalesDetail({
    required this.idTransaction,
    required this.number,
    required this.status,
    required this.reference,
    required this.note,
    required this.amount,
    required this.discount,
    required this.shippingFee,
    required this.paymentMethod,
    required this.time,
    required this.items,
    this.storeLocation,
    this.customer,
    this.calculation,
    this.paymentToken,
    this.paymentLink,
  });

  static String _pick(Map<String, dynamic> m, List<String> keys) {
    for (final k in keys) {
      final v = (m[k] ?? '').toString();
      if (v.isNotEmpty) return v;
    }
    return '';
  }

  static DateTime _parseTime(dynamic orderAt, dynamic createdAtIso) {
    if (orderAt is num) {
      return DateTime.fromMillisecondsSinceEpoch(orderAt.toInt() * 1000);
    }
    if (orderAt is String) {
      final n = int.tryParse(orderAt);
      if (n != null) {
        return DateTime.fromMillisecondsSinceEpoch(n * 1000);
      }
    }
    if (createdAtIso is String) {
      final t = DateTime.tryParse(createdAtIso);
      if (t != null) return t;
    }
    return DateTime.now();
  }

  factory SalesDetail.fromJson(Map<String, dynamic> j) {
    final data = (j['data'] as Map?)?.cast<String, dynamic>() ?? j;

    final items = ((data['items'] as List?) ?? [])
        .whereType<Map>()
        .map((e) => SalesDetailItem.fromJson(e.cast<String, dynamic>()))
        .toList();

    final calc = (j['calculation'] is Map)
        ? SalesCalculation.fromJson(
            (j['calculation'] as Map).cast<String, dynamic>(),
          )
        : null;

    // ⬇️ ambil token/link dari beberapa kemungkinan key (server beda-beda)
    final token = _pick(data, [
      'payment_token',
      'paymentToken',
      'snap_token',
      'midtrans_token',
      'token',
    ]);
    final link = _pick(data, [
      'payment_link',
      'paymentLink',
      'redirect_url',
      'snap_redirect_url',
      'deeplink',
    ]);

    return SalesDetail(
      idTransaction: (data['idTransaction'] ?? '').toString(),
      number: (data['number'] ?? '').toString(),
      status: (data['status'] ?? '').toString(),
      reference: (data['reference'] ?? '').toString(),
      note: (data['note'] ?? '').toString(),
      amount: (data['amount'] is num)
          ? (data['amount'] as num).toInt()
          : int.tryParse('${data['amount'] ?? 0}') ?? 0,
      discount: (data['discount'] is num)
          ? (data['discount'] as num).toInt()
          : int.tryParse('${data['discount'] ?? 0}') ?? 0,
      shippingFee: (data['shipping_fee'] is num)
          ? (data['shipping_fee'] as num).toInt()
          : int.tryParse('${data['shipping_fee'] ?? 0}') ?? 0,
      paymentMethod: (data['payment_method'] is num)
          ? (data['payment_method'] as num).toInt()
          : int.tryParse('${data['payment_method'] ?? 0}') ?? 0,
      time: _parseTime(data['order_at'], data['created_at']),
      storeLocation: (data['store_location'] is Map)
          ? StoreLocationLite.fromJson(
              (data['store_location'] as Map).cast<String, dynamic>(),
            )
          : null,
      customer: (data['customer'] is Map)
          ? CustomerLite.fromJson(
              (data['customer'] as Map).cast<String, dynamic>(),
            )
          : null,
      items: items,
      calculation: calc,
      paymentToken: token.isEmpty ? null : token,
      paymentLink: link.isEmpty ? null : link,
    );
  }
}
