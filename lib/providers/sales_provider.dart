import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'dart:math' as math;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:midtrans_sdk/midtrans_sdk.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:url_launcher/url_launcher_string.dart';

import 'package:wa_blast/core/provider_helper.dart'; // BizIdCache, ApiJson, FetchHelper, PageMeta
import 'package:wa_blast/providers/product_provider.dart' as catalog;
import 'package:wa_blast/models/product_model.dart' as model;

/// =========================
/// CART SKU (ringan)
/// =========================

// =========================
// SALES DETAIL MODELS (NEW)
// =========================
@immutable
class StoreProvince {
  final String id;
  final String name;
  const StoreProvince({required this.id, required this.name});

  factory StoreProvince.fromJson(Map<String, dynamic> j) => StoreProvince(
    id: (j['id'] ?? '').toString(),
    name: (j['name'] ?? '').toString(),
  );
}

@immutable
class StoreCity {
  final String id;
  final String name;
  final StoreProvince? province;
  const StoreCity({required this.id, required this.name, this.province});

  factory StoreCity.fromJson(Map<String, dynamic> j) => StoreCity(
    id: (j['id'] ?? '').toString(),
    name: (j['name'] ?? '').toString(),
    province: (j['province'] is Map)
        ? StoreProvince.fromJson((j['province'] as Map).cast<String, dynamic>())
        : null,
  );
}

@immutable
class StoreLocationLite {
  final String idStoreLocation;
  final String name;
  final StoreCity? city;

  const StoreLocationLite({
    required this.idStoreLocation,
    required this.name,
    this.city,
  });

  factory StoreLocationLite.fromJson(Map<String, dynamic> j) =>
      StoreLocationLite(
        idStoreLocation: (j['idStoreLocation'] ?? '').toString(),
        name: (j['name'] ?? '').toString(),
        city: (j['city'] is Map)
            ? StoreCity.fromJson((j['city'] as Map).cast<String, dynamic>())
            : null,
      );
}

@immutable
class CustomerLite {
  final String idCustomer;
  final String name;
  final String phone;
  final String email;
  final String address;

  const CustomerLite({
    required this.idCustomer,
    required this.name,
    required this.phone,
    required this.email,
    required this.address,
  });

  factory CustomerLite.fromJson(Map<String, dynamic> j) => CustomerLite(
    idCustomer: (j['idCustomer'] ?? '').toString(),
    name: (j['name'] ?? '').toString(),
    phone: (j['phone'] ?? '').toString(),
    email: (j['email'] ?? '').toString(),
    address: (j['address'] ?? '').toString(),
  );
}

@immutable
class ProductLite {
  final String idProduct;
  final String name;
  final String? imagePath;
  final String? brand;
  final String? category;

  const ProductLite({
    required this.idProduct,
    required this.name,
    this.imagePath,
    this.brand,
    this.category,
  });

  factory ProductLite.fromJson(Map<String, dynamic> j) {
    String? img() {
      final imgs = j['productImages'];
      if (imgs is List && imgs.isNotEmpty && imgs.first is Map) {
        return (imgs.first['imagePath'] ?? '').toString();
      }
      return null;
    }

    return ProductLite(
      idProduct: (j['idProduct'] ?? '').toString(),
      name: (j['name'] ?? '').toString(),
      imagePath: img(),
      brand: (j['productBrand'] is Map)
          ? ((j['productBrand']['name'] ?? '').toString())
          : null,
      category: (j['productCategory'] is Map)
          ? ((j['productCategory']['name'] ?? '').toString())
          : null,
    );
  }
}

@immutable
class ProductSkuLite {
  final String idProductSku;
  final String code;
  final int price;
  final List<Map<String, String>> attributes; // [{name, value}, ...]

  const ProductSkuLite({
    required this.idProductSku,
    required this.code,
    required this.price,
    required this.attributes,
  });

  factory ProductSkuLite.fromJson(Map<String, dynamic> j) => ProductSkuLite(
    idProductSku: (j['idProductSku'] ?? '').toString(),
    code: (j['code'] ?? '').toString(),
    price: (j['price'] is num)
        ? (j['price'] as num).toInt()
        : int.tryParse('${j['price'] ?? 0}') ?? 0,
    attributes: ((j['attributes'] as List?) ?? [])
        .whereType<Map>()
        .map(
          (e) => {
            'name': (e['name'] ?? '').toString(),
            'value': (e['value'] ?? '').toString(),
          },
        )
        .toList(),
  );
}

@immutable
class SalesDetailItem {
  final String productId;
  final String productSkuId;
  final int qtyOut;
  final int price;
  final int discount;
  final ProductLite? product;
  final ProductSkuLite? productSku;

  const SalesDetailItem({
    required this.productId,
    required this.productSkuId,
    required this.qtyOut,
    required this.price,
    required this.discount,
    this.product,
    this.productSku,
  });

  factory SalesDetailItem.fromJson(Map<String, dynamic> j) => SalesDetailItem(
    productId: (j['product_id'] ?? '').toString(),
    productSkuId: (j['product_sku_id'] ?? '').toString(),
    qtyOut: (j['qty_out'] is num)
        ? (j['qty_out'] as num).toInt()
        : int.tryParse('${j['qty_out'] ?? 0}') ?? 0,
    price: (j['price'] is num)
        ? (j['price'] as num).toInt()
        : int.tryParse('${j['price'] ?? 0}') ?? 0,
    discount: (j['discount'] is num)
        ? (j['discount'] as num).toInt()
        : int.tryParse('${j['discount'] ?? 0}') ?? 0,
    product: (j['product'] is Map)
        ? ProductLite.fromJson((j['product'] as Map).cast<String, dynamic>())
        : null,
    productSku: (j['product_sku'] is Map)
        ? ProductSkuLite.fromJson(
            (j['product_sku'] as Map).cast<String, dynamic>(),
          )
        : null,
  );
}

@immutable
class SalesCalculation {
  final int subtotal;
  final int discount;
  final int shippingFee;
  final int grandtotal;

  const SalesCalculation({
    required this.subtotal,
    required this.discount,
    required this.shippingFee,
    required this.grandtotal,
  });

  factory SalesCalculation.fromJson(Map<String, dynamic> j) => SalesCalculation(
    subtotal: (j['subtotal'] is num)
        ? (j['subtotal'] as num).toInt()
        : int.tryParse('${j['subtotal'] ?? 0}') ?? 0,
    discount: (j['discount'] is num)
        ? (j['discount'] as num).toInt()
        : int.tryParse('${j['discount'] ?? 0}') ?? 0,
    shippingFee: (j['shipping_fee'] is num)
        ? (j['shipping_fee'] as num).toInt()
        : int.tryParse('${j['shipping_fee'] ?? 0}') ?? 0,
    grandtotal: (j['grandtotal'] is num)
        ? (j['grandtotal'] as num).toInt()
        : int.tryParse('${j['grandtotal'] ?? 0}') ?? 0,
  );
}

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
  final DateTime time; // from order_at or created_at
  final StoreLocationLite? storeLocation;
  final CustomerLite? customer;
  final List<SalesDetailItem> items;
  final SalesCalculation? calculation;

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
  });

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
    );
  }
}

enum _PayState { pending, success, cancel, deny, expire, failure, error }

const Set<_PayState> _doneStates = {
  _PayState.success,
  _PayState.cancel,
  _PayState.deny,
  _PayState.expire,
  _PayState.failure,
  _PayState.error,
};

/// Representasi 1 SKU yang bisa dijual (ringan untuk cart)
class PosSku {
  final String skuId; // idProductSku
  final String skuCode; // code
  final int price; // harga retail
  final String productId; // idProduct
  final String productName; // name
  final String imageUrl; // url gambar (ambil dari product.primaryImageUrl)
  final bool inStock; // sementara: !product.isHide

  const PosSku({
    required this.skuId,
    required this.skuCode,
    required this.price,
    required this.productId,
    required this.productName,
    required this.imageUrl,
    this.inStock = true,
  });
}

class CartItem {
  final PosSku sku;
  int qty;
  CartItem({required this.sku, this.qty = 1});
  int get subtotal => sku.price * qty;
}

/// =========================
/// MODEL RINGAN UNTUK LIST REPORT
/// =========================
@immutable
class SalesLine {
  final String productId;
  final String productSkuId;
  final int qtyOut;
  final int price;

  const SalesLine({
    required this.productId,
    required this.productSkuId,
    required this.qtyOut,
    required this.price,
  });

  factory SalesLine.fromJson(Map<String, dynamic> j) => SalesLine(
    productId: (j['product_id'] ?? '').toString(),
    productSkuId: (j['product_sku_id'] ?? '').toString(),
    qtyOut: (j['qty_out'] is num)
        ? (j['qty_out'] as num).toInt()
        : int.tryParse('${j['qty_out'] ?? 0}') ?? 0,
    price: (j['price'] is num)
        ? (j['price'] as num).toInt()
        : int.tryParse('${j['price'] ?? 0}') ?? 0,
  );
}

@immutable
class SalesReportItem {
  final String idTransaction;
  final String code; // "number"
  final DateTime time; // order_at (epoch detik) atau created_at
  final int quantity; // sum(qty_out)
  final int totalAmount; // "amount"
  final String reference;
  final String status;
  final List<SalesLine> lines;

  const SalesReportItem({
    required this.idTransaction,
    required this.code,
    required this.time,
    required this.quantity,
    required this.totalAmount,
    required this.reference,
    required this.status,
    required this.lines,
  });
}

// =========================
// CUSTOMER MODELS
// =========================
@immutable
class ProvinceLite {
  final String id;
  final String name;
  const ProvinceLite({required this.id, required this.name});

  factory ProvinceLite.fromJson(Map<String, dynamic> j) => ProvinceLite(
    id: (j['id'] ?? '').toString(),
    name: (j['name'] ?? '').toString(),
  );
}

@immutable
class CityLite {
  final String id;
  final String name;
  final ProvinceLite? province;

  const CityLite({required this.id, required this.name, this.province});

  factory CityLite.fromJson(Map<String, dynamic> j) => CityLite(
    id: (j['id'] ?? '').toString(),
    name: (j['name'] ?? '').toString(),
    province: (j['province'] is Map)
        ? ProvinceLite.fromJson((j['province'] as Map).cast<String, dynamic>())
        : null,
  );
}

@immutable
class Customer {
  final String idCustomer;
  final String name;
  final String phone;
  final String email;
  final CityLite? city;
  final String address;

  const Customer({
    required this.idCustomer,
    required this.name,
    required this.phone,
    required this.email,
    required this.city,
    required this.address,
  });

  factory Customer.fromJson(Map<String, dynamic> j) => Customer(
    idCustomer: (j['idCustomer'] ?? '').toString(),
    name: (j['name'] ?? '').toString(),
    phone: (j['phone'] ?? '').toString(),
    email: (j['email'] ?? '').toString(),
    city: (j['city'] is Map)
        ? CityLite.fromJson((j['city'] as Map).cast<String, dynamic>())
        : null,
    address: (j['address'] ?? '').toString(),
  );

  /// payload untuk Create/Edit sesuai spesifikasi
  Map<String, dynamic> toPayload({required int cityIdOverride}) => {
    "name": name,
    "phone": phone,
    "email": email,
    "city_id": cityIdOverride,
    "address": address,
  };
}

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

/// =========================
/// PROVIDER
/// =========================
class SalesProvider extends ChangeNotifier {
  // ====== CATALOG (Products + per-SKU ringan) ======
  final List<model.Product> _products = [];
  final List<PosSku> _catalogSkus = [];

  bool _loadingCatalog = false;
  String? _errorCatalog;

  /// UI baru pakai ini:
  List<model.Product> get products => List.unmodifiable(_products);
  bool get loadingProducts => _loadingCatalog;
  String? get catalogError => _errorCatalog;

  /// Kompat lama (kalau masih ada bagian UI yang pakai SKUs langsung)
  List<PosSku> get skus => List.unmodifiable(_catalogSkus);
  bool get loadingSkus => _loadingCatalog;

  bool _submitting = false;
  String? _lastError;

  bool get submitting => _submitting;
  String? get lastError => _lastError;

  // ====== SALES REPORT LIST ======
  final List<SalesReportItem> _reports = [];
  bool _loadingReports = false;
  String? _reportError;
  PageMeta? _pageReports;

  List<SalesReportItem> get reports => List.unmodifiable(_reports);
  bool get loadingReports => _loadingReports;
  String? get reportError => _reportError;
  PageMeta? get pageReports => _pageReports;

  // ====== CUSTOMERS ======
  final List<Customer> _customers = [];
  bool _loadingCustomers = false;
  String? _customerError;
  PageMeta? _pageCustomers;
  Customer? _selectedCustomer; // opsional: hasil detail

  List<Customer> get customers => List.unmodifiable(_customers);
  bool get loadingCustomers => _loadingCustomers;
  String? get customerError => _customerError;
  PageMeta? get pageCustomers => _pageCustomers;
  Customer? get selectedCustomer => _selectedCustomer;

  String? _storeLocationId;
  String? _storeLocationName;
  int? _discount = 0;

  // ——— shipping fee di-deprecate: pertahankan field agar kompat,
  //     tapi tidak dipakai lagi (selalu 0 lewat getter).
  int? _shippingFee = 0;

  String? _note;
  String? _reference;
  int? _paymentMethod = 1;

  // ✅ TAMBAH:
  String? _customerId;
  String? _customerName;

  String? get storeLocationId => _storeLocationId;
  String? get storeLocationName => _storeLocationName;
  int? get discount => _discount;

  // ⬇️ selalu kembalikan 0 agar tidak ada ongkir
  int? get shippingFee => 0;

  String? get note => _note;
  String? get currentReference => _reference;
  int? get paymentMethod => _paymentMethod;

  // ✅ (opsional, untuk UI)
  String? get customerId => _customerId;
  String? get customerName => _customerName;

  MidtransSDK? _midtrans;
  // ====== Payment tracking (Midtrans + server) ======
  String? _pendingPaymentTxId; // transaksi yang sedang dipantau

  String _s(Object? v) => v?.toString() ?? '';

  String? _extractIdTx(Map<String, dynamic> j) {
    final m =
        (j['data'] as Map?)?.cast<String, dynamic>() ??
        j.cast<String, dynamic>();
    final id = _s(m['idTransaction'] ?? m['id_transaction'] ?? m['id']);
    return id.isEmpty ? null : id;
  }

  String? _extractTxNumber(Map<String, dynamic> j) {
    final m =
        (j['data'] as Map?)?.cast<String, dynamic>() ??
        j.cast<String, dynamic>();
    final n = _s(m['transaction_number'] ?? m['number'] ?? m['code']);
    return n.isEmpty ? null : n;
  }

  String? _extractTxRef(Map<String, dynamic> j) {
    final m =
        (j['data'] as Map?)?.cast<String, dynamic>() ??
        j.cast<String, dynamic>();
    final r = _s(m['transaction_reference'] ?? m['reference']);
    return r.isEmpty ? null : r;
  }

  _PayState _mapStatus(dynamic raw) {
    final s = (raw ?? '').toString().toLowerCase();
    switch (s) {
      case 'settlement':
      case 'capture':
      case 'success':
      case 'paid':
        return _PayState.success;
      case 'pending':
        return _PayState.pending;
      case 'cancel':
      case 'canceled':
        return _PayState.cancel;
      case 'deny':
        return _PayState.deny;
      case 'expire':
      case 'expired':
        return _PayState.expire;
      case 'failure':
      case 'failed':
      default:
        return _PayState.failure;
    }
  }

  /// Subtotal base (tanpa diskon apa pun)
  int get subtotalBase =>
      cartItems.fold(0, (s, it) => s + it.sku.price * it.qty);

  // ====== SALES DETAIL (NEW) ======
  SalesDetail? _salesDetail;
  bool _loadingSalesDetail = false;
  String? _salesDetailError;

  SalesDetail? get salesDetail => _salesDetail;
  bool get loadingSalesDetail => _loadingSalesDetail;
  String? get salesDetailError => _salesDetailError;

  Completer<PaymentResult>? _snapCompleter;

  void _setLoadingSalesDetail(bool v) {
    _loadingSalesDetail = v;
    notifyListeners();
  }

  void _setSalesDetailError(String? v) {
    _salesDetailError = v;
    notifyListeners();
  }

  /// GET /waveup/{bizId}/transaction/sales/:id   (NEW)
  Future<SalesDetail?> fetchSalesDetail(
    BuildContext context,
    String idTransaction,
  ) async {
    final bizId = await _requireBizId();
    if (bizId == null) return null;

    final path = '/waveup/$bizId/transaction/sales/$idTransaction';
    if (kDebugMode) debugPrint('[SalesProvider] GET $path (detail)');

    _setSalesDetailError(null);
    _setLoadingSalesDetail(true);

    try {
      final j = await ApiJson.getMap(context, path, withAccessToken: true);
      if (kDebugMode) _debugBig('[SalesProvider] sales detail resp', j);

      if (j == null || (j['status'] as num?)?.toInt() != 200) {
        _salesDetail = null;
        _setSalesDetailError(
          j?['message']?.toString() ?? 'Failed to fetch sales detail',
        );
        return null;
      }

      final detail = SalesDetail.fromJson(j);
      _salesDetail = detail;
      notifyListeners();
      return detail;
    } catch (e, st) {
      _salesDetail = null;
      _setSalesDetailError('$e');
      if (kDebugMode) {
        debugPrint('[SalesProvider] fetchSalesDetail exception: $e');
        debugPrint('$st');
      }
      return null;
    } finally {
      _setLoadingSalesDetail(false);
    }
  }

  /// Subtotal setelah per-item discount saja
  int get subtotalAfterItemDisc {
    var sum = 0;
    for (final it in _cart.values) {
      final unit = (it.sku.price - perItemDiscountOf(it.sku.skuId));
      sum += (unit > 0 ? unit : 0) * it.qty;
    }
    return sum;
  }

  int _subtotalPerItemOnly(SalesProvider prov) {
    var sum = 0;
    for (final it in prov.cartItems) {
      final sku = it.sku;
      final perItemDisc = prov.perItemDiscountOf(sku.skuId);
      final unitAfterItem = (sku.price - perItemDisc).clamp(0, 1 << 31) as int;
      sum += unitAfterItem * it.qty;
    }
    return sum;
  }

  Map<String, int> _allocOrderDiscountPerUnit(SalesProvider prov) {
    final od = prov.discount ?? 0;
    if (od <= 0 || prov.cartItems.isEmpty) return const {};

    final bases = <String, int>{};
    var baseSum = 0;
    for (final it in prov.cartItems) {
      final skuId = it.sku.skuId;
      final unitAfterItem = (it.sku.price - prov.perItemDiscountOf(skuId));
      final base = (unitAfterItem > 0 ? unitAfterItem : 0) * it.qty;
      if (base > 0) {
        bases[skuId] = base;
        baseSum += base;
      }
    }
    if (baseSum == 0) return const {};

    final perUnit = <String, int>{};
    var allocated = 0;
    for (final it in prov.cartItems) {
      final skuId = it.sku.skuId;
      final base = bases[skuId] ?? 0;
      if (base == 0) {
        perUnit[skuId] = 0;
        continue;
      }
      final rowDisc = (od * base) ~/ baseSum;
      allocated += rowDisc;
      perUnit[skuId] = it.qty > 0 ? (rowDisc ~/ it.qty) : 0;
    }

    final remain = od - allocated;
    if (remain > 0 && prov.cartItems.isNotEmpty) {
      final first = prov.cartItems.first;
      final d0 = perUnit[first.sku.skuId] ?? 0;
      perUnit[first.sku.skuId] =
          d0 + (remain ~/ (first.qty > 0 ? first.qty : 1));
    }

    perUnit.updateAll((skuId, d) {
      final sku = prov.cartItems.firstWhere((x) => x.sku.skuId == skuId).sku;
      final maxDisc = (sku.price - prov.perItemDiscountOf(skuId));
      return d.clamp(0, maxDisc);
    });

    return perUnit;
  }

  /// Total alokasi order-level discount (jumlah disc/unit * qty)
  int get orderDiscountAllocatedTotal {
    final map = allocOrderDiscountPerUnit();
    var sum = 0;
    for (final it in _cart.values) {
      sum += (map[it.sku.skuId] ?? 0) * it.qty;
    }
    return sum;
  }

  /// Subtotal efektif (setelah per-item + alokasi order discount)
  int get subtotalEffective =>
      (subtotalAfterItemDisc - orderDiscountAllocatedTotal).clamp(0, 1 << 31);

  /// Service fee terhadap subtotal efektif → dihapus (0)
  int get serviceFeeOnEffective => 0;

  /// Grand total efektif → tanpa service fee
  int get grandTotalEffective => subtotalEffective;

  void _setLoadingCustomers(bool v) {
    _loadingCustomers = v;
    notifyListeners();
  }

  void _setCustomerError(String? v) {
    _customerError = v;
    notifyListeners();
  }

  void _setReportError(String? v) {
    _reportError = v;
    notifyListeners();
  }

  void _setLoadingReports(bool v) {
    _loadingReports = v;
    notifyListeners();
  }

  Future<PaymentResult?> _paymentCheckOnce(
    BuildContext context,
    String idTx,
  ) async {
    final bizId = await _requireBizId();
    if (bizId == null) return null;

    final path = '/waveup/$bizId/transaction/sales/$idTx/payment-check';
    if (kDebugMode) debugPrint('[SalesProvider] GET $path (payment-check)');

    try {
      final j = await ApiJson.getMap(context, path, withAccessToken: true);
      if (kDebugMode) _debugBig('[payment-check] resp', j);

      if (j == null) return null;

      // Sesuaikan key berikut sesuai respons backend kamu
      final data =
          (j['data'] as Map?)?.cast<String, dynamic>() ??
          j.cast<String, dynamic>();
      final statusRaw =
          data['payment_status'] ?? data['status'] ?? j['payment_status'];
      final txId = (data['transaction_id'] ?? data['transactionId'] ?? '')
          .toString();
      final orderId = (data['order_id'] ?? data['orderId'] ?? '').toString();
      final ptype = (data['payment_type'] ?? data['paymentType'] ?? '')
          .toString();
      final msg = (data['message'] ?? j['message'] ?? '').toString();

      final st = _mapStatus(statusRaw);
      return PaymentResult(
        st.toString().split('.').last,
        transactionId: txId.isEmpty ? null : txId,
        orderId: orderId.isEmpty ? null : orderId,
        paymentType: ptype.isEmpty ? null : ptype,
        message: msg.isEmpty ? null : msg,
        raw: j.toString(),
      );
    } catch (e, st) {
      if (kDebugMode) {
        debugPrint('[payment-check] error: $e');
        debugPrint('$st');
      }
      return PaymentResult('error', message: '$e');
    }
  }

  Future<PaymentResult?> _waitPaymentUntilDone(
    BuildContext context, {
    required String idTransaction,
    Duration totalTimeout = const Duration(minutes: 7),
    List<Duration>? schedule,
  }) async {
    final plan =
        schedule ??
        <Duration>[
          const Duration(milliseconds: 800),
          const Duration(seconds: 1),
          const Duration(seconds: 2),
          const Duration(seconds: 3),
          const Duration(seconds: 5),
          const Duration(seconds: 7),
          const Duration(seconds: 10),
          const Duration(seconds: 12),
          const Duration(seconds: 15),
          const Duration(seconds: 20),
          const Duration(seconds: 25),
          const Duration(seconds: 30),
        ];

    final start = DateTime.now();
    PaymentResult? last;

    for (final d in plan) {
      if (DateTime.now().difference(start) > totalTimeout) {
        return PaymentResult('timeout', message: 'Payment status timeout');
      }

      await Future.delayed(d);
      final res = await _paymentCheckOnce(context, idTransaction);
      last = res ?? last;

      if (res != null) {
        final ps = _mapStatus(res.status);
        if (_doneStates.contains(ps)) {
          if (kDebugMode) {
            debugPrint(
              '[poll] DONE: ${res.status} (${DateTime.now().difference(start)})',
            );
          }
          return res;
        }
      }
    }
    return last ?? PaymentResult('pending', message: 'No final status yet');
  }

  Future<PaymentResult?> checkPaymentNow(
    BuildContext context,
    String idTx,
  ) async {
    return _paymentCheckOnce(context, idTx);
  }

  Future<PaymentResult?> _openMidtransIfAny(
    Map<String, dynamic> resp,
    BuildContext context,
  ) async {
    final Object? dataObj = resp['data'];
    String _s(Object? v) => v?.toString() ?? '';
    String pick(Object? o, String k) {
      if (o is Map) return _s(o[k]);
      return '';
    }

    final link = _s(resp['payment_link'] ?? pick(dataObj, 'payment_link'));
    final token = _s(resp['payment_token'] ?? pick(dataObj, 'payment_token'));

    if (link.isEmpty && token.isEmpty) {
      if (kDebugMode)
        debugPrint('[SalesProvider] no payment link/token, skip Midtrans.');
      return null;
    }

    if (token.isNotEmpty) {
      try {
        if (kDebugMode) debugPrint('Start Snap');
        final res = await _startSnap(token, context);
        return res;
      } catch (e) {
        debugPrint('[SalesProvider] Snap UI error: $e');
      }
    }

    // Kalau tidak ada token (misal VA/QR tertentu), UI Snap tidak dibuka di sini.
    return null;
  }

  Future<PaymentResult?> _paymentCheckOnceSafe(BuildContext context) async {
    final idTx = _pendingPaymentTxId;
    if (idTx == null || idTx.isEmpty) return null;
    return _paymentCheckOnce(context, idTx);
  }

  void _attachMidtransCallback() {
    _midtrans?.setTransactionFinishedCallback((result) {
      debugPrint(
        '🔔 Midtrans Callback:'
        '\n  transactionId=${result.transactionId}'
        '\n  status=${result.status}'
        '\n  message=${result.message}'
        '\n  paymentType=${result.paymentType}',
      );

      final status = (result.status ?? '').toLowerCase();
      final pr = PaymentResult(
        status.isEmpty ? 'unknown' : status,
        transactionId: result.transactionId,
        paymentType: result.paymentType,
        message: result.message,
        raw: result.toString(),
      );

      _snapCompleter?..complete(pr);
      _snapCompleter = null;
      notifyListeners();
    });
  }

  Future<void> _initMidtransIfNeeded(BuildContext context) async {
    if (_midtrans != null) return;
    _midtrans = await MidtransSDK.init(
      config: MidtransConfig(
        clientKey: 'SB-Mid-client-OlAvtRicKKPMklc4',
        merchantBaseUrl: '',
        colorTheme: ColorTheme(
          colorPrimary: Theme.of(context).colorScheme.primary,
          colorPrimaryDark: Theme.of(context).colorScheme.primary,
          colorSecondary: Theme.of(context).colorScheme.secondary,
        ),
        enableLog: true,
      ),
    );
  }

  Future<PaymentResult?> _startSnap(String token, BuildContext context) async {
    debugPrint('🚀 [Midtrans] _startSnap() BEGIN dengan token: $token');

    try {
      await _initMidtransIfNeeded(context);
      debugPrint('✅ [Midtrans] SDK sudah di-init');
    } catch (e, st) {
      debugPrint('❌ [Midtrans] init error: $e\n$st');
      return PaymentResult('error', message: 'Init Midtrans gagal: $e');
    }

    if (_snapCompleter != null && !(_snapCompleter!.isCompleted)) {
      debugPrint(
        '[Midtrans] Completer lama belum complete, diselesaikan paksa.',
      );
      _snapCompleter!.complete(
        PaymentResult('aborted', message: 'Flow sebelumnya digantikan'),
      );
    }
    _snapCompleter = Completer<PaymentResult>();

    try {
      _midtrans?.removeTransactionFinishedCallback();
      debugPrint('[Midtrans] Callback lama dihapus');
    } catch (_) {}

    _midtrans?.setTransactionFinishedCallback((result) {
      debugPrint(' [Midtrans] CALLBACK TERPANGGIL!');
      try {
        debugPrint(' result = ${result.toString()}');
        debugPrint('   transactionId=${result.transactionId}');
        debugPrint('   status=${result.status}');
        debugPrint('   message=${result.message}');
        debugPrint('   paymentType=${result.paymentType}');
      } catch (e) {
        debugPrint('[Midtrans] gagal print result: $e');
      }

      String? _s(Object? v) => v?.toString();
      final status = (_s(result.status) ?? '').toLowerCase();
      final pr = PaymentResult(
        status.isEmpty ? 'unknown' : status,
        transactionId: _s(result.transactionId),
        paymentType: _s(result.paymentType),
        message: _s(result.message),
        raw: result.toString(),
      );

      if (!(_snapCompleter?.isCompleted ?? true)) {
        debugPrint('✅ [Midtrans] Completer diselesaikan via callback');
        _snapCompleter!.complete(pr);
      }
    });

    try {
      debugPrint('▶️ [Midtrans] Memulai startPaymentUiFlow...');
      await _midtrans?.startPaymentUiFlow(token: token);
      debugPrint(
        '⏳ [Midtrans] startPaymentUiFlow() selesai, menunggu callback...',
      );
    } catch (e, st) {
      debugPrint('❌ [Midtrans] startPaymentUiFlow error: $e\n$st');
      if (!(_snapCompleter?.isCompleted ?? true)) {
        _snapCompleter!.complete(
          PaymentResult('error', message: 'Gagal membuka Snap UI: $e'),
        );
      }
    }

    PaymentResult result;
    try {
      result = await _snapCompleter!.future.timeout(
        const Duration(minutes: 5),
        onTimeout: () {
          debugPrint('⏰ [Midtrans] Timeout 5 menit, callback tidak diterima.');
          return PaymentResult('timeout', message: 'Tidak ada callback');
        },
      );
    } catch (e, st) {
      debugPrint('❌ [Midtrans] Future error: $e\n$st');
      result = PaymentResult('error', message: 'Future error: $e');
    } finally {
      try {
        _midtrans?.removeTransactionFinishedCallback();
        debugPrint('🧹 [Midtrans] Callback dilepas setelah flow selesai.');
      } catch (_) {}
      _snapCompleter = null;
    }

    debugPrint(
      '🏁 [Midtrans] _startSnap() SELESAI dengan status: ${result.status}',
    );
    return result;
  }

  SalesReportItem _salesItemFromApi(Map<String, dynamic> j) {
    DateTime _parseTime(dynamic orderAt, dynamic createdAtIso) {
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

    final List<SalesLine> lines = ((j['items'] as List?) ?? [])
        .whereType<Map>()
        .map((e) => SalesLine.fromJson((e).cast<String, dynamic>()))
        .toList();

    final qty = lines.fold<int>(0, (s, it) => s + it.qtyOut);

    int _asInt(dynamic v) {
      if (v is num) return v.toInt();
      return int.tryParse('${v ?? 0}') ?? 0;
    }

    return SalesReportItem(
      idTransaction: (j['idTransaction'] ?? '').toString(),
      code: (j['number'] ?? '').toString(),
      time: _parseTime(j['order_at'], j['created_at']),
      quantity: qty,
      totalAmount: _asInt(j['amount']),
      reference: (j['reference'] ?? '').toString(),
      status: (j['status'] ?? '').toString(),
      lines: lines,
    );
  }

  Future<void> fetchSalesReports(BuildContext context) async {
    final sw = Stopwatch()..start();
    if (kDebugMode) debugPrint('[SalesProvider] fetchSalesReports() start');

    final bizId = await BizIdCache.get();
    if (bizId == null || bizId.isEmpty) {
      _reports.clear();
      _pageReports = null;
      _setReportError('Business ID is missing.');
      return;
    }

    _setReportError(null);
    _setLoadingReports(true);

    try {
      final path = '/waveup/$bizId/transaction/sales';
      if (kDebugMode) debugPrint('[SalesProvider] GET $path');

      final result = await FetchHelper.fetchList<SalesReportItem>(
        context: context,
        path: path,
        parser: (json) => _salesItemFromApi(json),
      );

      if (result == null) {
        _reports.clear();
        _pageReports = null;
        return;
      }

      _reports
        ..clear()
        ..addAll(result.items);
      _pageReports = result.page;

      if (kDebugMode) {
        debugPrint('[SalesProvider] reports: ${_reports.length}');
        debugPrint('[SalesProvider] page: $_pageReports');
      }
      notifyListeners();
    } catch (e, st) {
      if (kDebugMode) {
        debugPrint('[SalesProvider] fetchSalesReports ERROR: $e');
        debugPrintStack(stackTrace: st);
      }
      _reports.clear();
      _pageReports = null;
      _setReportError(e.toString());
    } finally {
      _setLoadingReports(false);
      sw.stop();
      if (kDebugMode) {
        debugPrint(
          '[SalesProvider] fetchSalesReports finished in ${sw.elapsedMilliseconds} ms',
        );
      }
    }
  }

  void _setSubmitting(bool v) {
    _submitting = v;
    notifyListeners();
  }

  String? consumeLastError() {
    final e = _lastError;
    _lastError = null;
    return e;
  }

  Future<String?> _requireBizId() async {
    final bizId = await BizIdCache.get();
    if (bizId == null || bizId.isEmpty) {
      _lastError = "Business ID is not available.";
      debugPrint("[SalesProvider] ❌ Business ID null/empty");
      return null;
    }
    return bizId;
  }

  /// Muat katalog dari ProductProvider (model baru)
  Future<void> loadCatalog(BuildContext context) async {
    _setLoading(true);
    try {
      await context.read<catalog.ProductProvider>().fetchProducts(context);
      final prov = context.read<catalog.ProductProvider>();
      final prods = prov.products;

      _products
        ..clear()
        ..addAll(prods);

      final List<PosSku> mapped = [];
      for (final p in prods) {
        final productId = p.idProduct;
        final productName = p.name;
        final img = p.primaryImageUrl ?? '';
        final bool inStock = !p.isHide;

        final skus = p.productSkus;
        if (skus.isEmpty) {
          final base = p.basePrice ?? 0;
          if (base > 0) {
            mapped.add(
              PosSku(
                skuId: '${productId}_BASE',
                skuCode: 'BASE',
                price: base,
                productId: productId,
                productName: productName,
                imageUrl: img,
                inStock: inStock,
              ),
            );
          }
          continue;
        }

        for (final s in skus) {
          final safeId = (s.idProductSku.isNotEmpty)
              ? s.idProductSku
              : '${productId}_${s.code}';
          final price = s.price > 0 ? s.price : (p.basePrice ?? 0);
          if (price <= 0) continue;

          mapped.add(
            PosSku(
              skuId: safeId,
              skuCode: s.code,
              price: price,
              productId: productId,
              productName: productName,
              imageUrl: img,
              inStock: inStock,
            ),
          );
        }
      }

      _catalogSkus
        ..clear()
        ..addAll(mapped);

      _errorCatalog = null;
    } catch (e) {
      _errorCatalog = e.toString();
    } finally {
      _setLoading(false);
    }
  }

  /// Sinkron dari cache ProductProvider tanpa network
  void syncFromCache(BuildContext context) {
    final prov = context.read<catalog.ProductProvider>();
    final prods = prov.products;

    _products
      ..clear()
      ..addAll(prods);

    final List<PosSku> mapped = [];
    for (final p in prods) {
      final productId = p.idProduct;
      final productName = p.name;
      final img = p.primaryImageUrl ?? '';
      final bool inStock = !p.isHide;

      final skus = p.productSkus;
      if (skus.isEmpty) {
        final base = p.basePrice ?? 0;
        if (base > 0) {
          mapped.add(
            PosSku(
              skuId: '${productId}_BASE',
              skuCode: 'BASE',
              price: base,
              productId: productId,
              productName: productName,
              imageUrl: img,
              inStock: inStock,
            ),
          );
        }
        continue;
      }

      for (final s in skus) {
        final safeId = (s.idProductSku.isNotEmpty)
            ? s.idProductSku
            : '${productId}_${s.code}';
        final price = s.price > 0 ? s.price : (p.basePrice ?? 0);
        if (price <= 0) continue;

        mapped.add(
          PosSku(
            skuId: safeId,
            skuCode: s.code,
            price: price,
            productId: productId,
            productName: productName,
            imageUrl: img,
            inStock: inStock,
          ),
        );
      }
    }

    _catalogSkus
      ..clear()
      ..addAll(mapped);
    notifyListeners();
  }

  void _setLoading(bool v) {
    _loadingCatalog = v;
    notifyListeners();
  }

  // ===== CHECKOUT STEPPER =====
  int _currentStep = 0;
  int get currentStep => _currentStep;
  void goTo(int step) {
    _currentStep = step.clamp(0, 2);
    notifyListeners();
  }

  // ===== PER-ITEM DISCOUNT (IDR) =====
  final Map<String, int> _itemDiscount = {}; // key: skuId -> disc per item

  int perItemDiscountOf(String skuId) => _itemDiscount[skuId] ?? 0;

  void setPerItemDiscount({
    required String skuId,
    required int discountPerItem,
  }) {
    final v = discountPerItem < 0 ? 0 : discountPerItem;
    if (v == 0) {
      _itemDiscount.remove(skuId);
    } else {
      _itemDiscount[skuId] = v;
    }
    notifyListeners();
  }

  // ===== CART =====
  final Map<String, CartItem> _cart = {};
  List<CartItem> get cartItems => _cart.values.toList(growable: false);

  int get cartLen => _cart.length;
  int get cartQtyTotal {
    var sum = 0;
    for (final it in _cart.values) sum += it.qty;
    return sum;
  }

  String _keyFor(PosSku s) =>
      s.skuId.isNotEmpty ? s.skuId : '${s.productId}_${s.skuCode}';

  void add(PosSku s) {
    final key = _keyFor(s);
    if (kDebugMode) debugPrint('[Cart] add $key (${s.productName})');
    if (!_cart.containsKey(key)) {
      _cart[key] = CartItem(sku: s, qty: 1);
    } else {
      _cart[key]!.qty += 1;
    }
    notifyListeners();
  }

  void addByRef({
    required String productId,
    required String productName,
    required String skuId,
    required String skuCode,
    required int price,
    String imageUrl = '',
    bool inStock = true,
  }) {
    final s = PosSku(
      skuId: skuId,
      skuCode: skuCode,
      price: price,
      productId: productId,
      productName: productName,
      imageUrl: imageUrl,
      inStock: inStock,
    );
    add(s);
  }

  void removeOne(PosSku s) {
    final key = _keyFor(s);
    if (!_cart.containsKey(key)) return;
    final item = _cart[key]!;
    if (item.qty > 1) {
      item.qty -= 1;
    } else {
      _cart.remove(key);
      _itemDiscount.remove(s.skuId);
    }
    notifyListeners();
  }

  void removeAll(PosSku s) {
    final key = _keyFor(s);
    _cart.remove(key);
    _itemDiscount.remove(s.skuId);
    notifyListeners();
  }

  // ===== TOTALS & FEES =====
  int get subtotal => cartItems.fold(0, (s, it) => s + it.subtotal);

  // ⬇️ Hapus service fee: rate 0, nilai 0, total=subtotal
  double get serviceFeeRate => 0.0;
  int get serviceFee => 0;
  int get total => subtotal;

  // ===== ORDER NUMBER (display only) =====
  String get orderNumber =>
      'ODR${DateTime.now().millisecondsSinceEpoch % 1000000}'.padLeft(10, '0');

  String generateDefaultReference() {
    final rnd = Random();
    final num = rnd.nextInt(900000) + 100000; // 100000..999999
    return 'REF-$num';
  }

  /// Inisialisasi reference jika kosong. Hindari panggil saat build.
  void ensureReferenceInitialized({bool notify = false}) {
    if ((_reference ?? '').isEmpty) {
      _reference = generateDefaultReference();
      if (notify) notifyListeners();
    }
  }

  void setOrderMeta({
    String? storeLocationId,
    String? storeLocationName,
    int? discount,
    int? shippingFee, // ← tetap diterima tapi diabaikan
    String? note,
    String? reference,
    int? paymentMethod,

    // ✅ TAMBAH PARAM
    String? customerId,
    String? customerName,
  }) {
    _storeLocationId = storeLocationId ?? _storeLocationId;
    _storeLocationName = storeLocationName ?? _storeLocationName;
    _discount = discount ?? _discount ?? 0;

    // ⬇️ abaikan shippingFee; pastikan state tetap 0
    _shippingFee = 0;

    _note = note ?? _note;

    if (reference != null && reference.isNotEmpty) {
      _reference = reference;
    }

    _paymentMethod = paymentMethod ?? _paymentMethod ?? 1;

    if (customerId != null && customerId.isNotEmpty) {
      _customerId = customerId;
    }
    if (customerName != null && customerName.isNotEmpty) {
      _customerName = customerName;
    }

    notifyListeners();
  }

  Object? get _customerIdForPayload {
    final id = _customerId;
    if (id == null || id.isEmpty) return null;
    final asInt = int.tryParse(id);
    return asInt ?? id;
  }

  /// Payload final saat submit ke backend (items dari cart)
  Map<String, dynamic> buildOrderPayload() {
    ensureReferenceInitialized(notify: false);
    return {
      "store_location_id": _storeLocationId,
      "customer_id": _customerIdForPayload,
      "discount": _discount ?? 0,
      // ⬇️ selalu kirim 0 ke server
      "shipping_fee": 0,
      "note": _note ?? "",
      "reference": "",
      "payment_method": _paymentMethod ?? 1,
      "items": cartItems.map((it) {
        final sku = it.sku;
        final discPerItem = perItemDiscountOf(sku.skuId);
        return {
          "product_id": sku.productId,
          "product_sku_id": sku.skuId,
          "discount": discPerItem,
          "qty": it.qty,
          "price": sku.price,
        };
      }).toList(),
    };
  }

  void _debugBig(String prefix, Object? data, {int chunk = 900}) {
    if (!kDebugMode) return;

    final text = () {
      if (data == null) return 'null';
      if (data is String) return data;
      try {
        return const JsonEncoder.withIndent('  ').convert(data);
      } catch (_) {
        return data.toString();
      }
    }();

    for (var i = 0; i < text.length; i += chunk) {
      final end = math.min(i + chunk, text.length);
      final seg = text.substring(i, end);
      debugPrint('$prefix${i == 0 ? '' : ' (cont.)'}: $seg');
    }
  }

  /// POST ke /waveup/{idBusiness}/transaction/sales
  Future<bool> submitSales(BuildContext context) async {
    final bizId = await _requireBizId();
    if (bizId == null) return false;

    if (cartItems.isEmpty) {
      _lastError = "Cart is empty.";
      return false;
    }
    if ((storeLocationId ?? '').isEmpty) {
      _lastError = "Store location must be selected.";
      return false;
    }

    if ((_customerId ?? '').isEmpty) {
      _lastError = "Customer must be selected.";
      return false;
    }

    ensureReferenceInitialized(notify: false);

    final payload = buildOrderPayload();
    final path = '/waveup/$bizId/transaction/sales';

    if (kDebugMode) {
      debugPrint("[SalesProvider] 🌐 POST $path");
      debugPrint("[SalesProvider] payload: $payload");
    }

    _setSubmitting(true);
    try {
      final j = await ApiJson.postMap(
        context,
        path,
        payload,
        withAccessToken: true,
      );

      if (kDebugMode) {
        _debugBig("[SalesProvider] 🔄 Server response", j);
      }

      final ok = j != null && (j['status'] as num?)?.toInt() == 200;
      if (!ok) {
        _lastError =
            j?['msg']?.toString() ??
            j?['message']?.toString() ??
            'Failed to submit sales transaction';

        if (kDebugMode) {
          debugPrint("[SalesProvider] ❌ Submit failed: $_lastError");
        }
        return false;
      }

      if (kDebugMode) {
        debugPrint("[SalesProvider] ✅ Submit success");
      }
      try {
        // Tetap buka Snap (jika ada token) — non-blocking terhadap polling
        unawaited(_openMidtransIfAny(j, context));
      } catch (e, st) {
        debugPrint('[SalesProvider] openMidtrans error: $e\n$st');
      }

      // Ambil idTransaction / number / reference langsung dari respons POST
      final idTx = _extractIdTx(j);
      final tNum = _extractTxNumber(j); // opsional, kalau mau ditampilkan di UI
      final tRef = _extractTxRef(j); // opsional, kalau mau disimpan

      if (kDebugMode) {
        debugPrint(
          '[SalesProvider] ➕ Created Tx: id=$idTx, number=$tNum, ref=$tRef',
        );
      }

      if (idTx != null) {
        _pendingPaymentTxId = idTx;

        // Siapkan future callback Snap (jika setTransactionFinishedCallback aktif di _startSnap)
        PaymentResult? cbRes;
        final cbFuture = _snapCompleter?.future.then((v) => cbRes = v);

        // Mulai polling payment-check pakai idTransaction dari POST
        final pollFuture = _waitPaymentUntilDone(context, idTransaction: idTx);

        // Tunggu salah satu lebih dulu selesai
        PaymentResult? first;
        try {
          first = await Future.any([
            if (cbFuture != null) cbFuture.then((_) => cbRes),
            pollFuture,
          ]);
        } catch (_) {
          // ignore
        }

        // Jika masih pending / belum yakin → konfirmasi sekali lagi ke server
        if (first == null || first.status.toLowerCase() == 'pending') {
          final serverFinal = await _paymentCheckOnce(context, idTx);
          first = serverFinal ?? first;
        }

        // Cleanup
        _pendingPaymentTxId = null;
        try {
          _midtrans?.removeTransactionFinishedCallback();
        } catch (_) {}
        _snapCompleter = null;

        if (kDebugMode) {
          debugPrint('🎯 Final payment status = ${first?.status}');
        }

        // (Opsional) taruh ke state & notify untuk UI kamu
        // _lastPaymentResult = first; notifyListeners();
      }

      return true;
    } catch (e, st) {
      _lastError = '$e';
      if (kDebugMode) {
        debugPrint("[SalesProvider] submitSales exception: $e");
        debugPrint("$st");
      }
      return false;
    } finally {
      _setSubmitting(false);
    }
  }

  /// GET /waveup/{bizId}/customer  -> list
  Future<void> fetchCustomers(
    BuildContext context, {
    int page = 1,
    int perPage = 50,
  }) async {
    final bizId = await _requireBizId();
    if (bizId == null) {
      _customers.clear();
      _pageCustomers = null;
      _setCustomerError('Business ID is missing.');
      return;
    }

    _setCustomerError(null);
    _setLoadingCustomers(true);
    try {
      final path = '/waveup/$bizId/customer';
      if (kDebugMode) debugPrint('[SalesProvider] GET $path');

      final result = await FetchHelper.fetchList<Customer>(
        context: context,
        path: path,
        parser: (json) => Customer.fromJson(json),
      );

      if (result == null) {
        _customers.clear();
        _pageCustomers = null;
        return;
      }

      _customers
        ..clear()
        ..addAll(result.items);
      _pageCustomers = result.page;

      if (kDebugMode) {
        debugPrint('[SalesProvider] customers: ${_customers.length}');
        debugPrint('[SalesProvider] page: $_pageCustomers');
      }
      notifyListeners();
    } catch (e, st) {
      if (kDebugMode) {
        debugPrint('[SalesProvider] fetchCustomers ERROR: $e');
        debugPrintStack(stackTrace: st);
      }
      _customers.clear();
      _pageCustomers = null;
      _setCustomerError(e.toString());
    } finally {
      _setLoadingCustomers(false);
    }
  }

  /// GET /waveup/{bizId}/customer/{idCustomer} -> detail
  Future<Customer?> fetchCustomerDetail(
    BuildContext context,
    String idCustomer,
  ) async {
    final bizId = await _requireBizId();
    if (bizId == null) return null;

    final path = '/waveup/$bizId/customer/$idCustomer';
    if (kDebugMode) debugPrint('[SalesProvider] GET $path');

    try {
      final j = await ApiJson.getMap(context, path, withAccessToken: true);
      if (kDebugMode) debugPrint('[SalesProvider] detail resp: $j');

      if (j == null || (j['status'] as num?)?.toInt() != 200) {
        _lastError =
            j?['message']?.toString() ?? 'Failed to fetch customer detail';
        _selectedCustomer = null;
        notifyListeners();
        return null;
      }

      final data = (j['data'] as Map).cast<String, dynamic>();
      final c = Customer.fromJson(data);
      _selectedCustomer = c;
      notifyListeners();
      return c;
    } catch (e, st) {
      _lastError = '$e';
      if (kDebugMode) {
        debugPrint('[SalesProvider] fetchCustomerDetail exception: $e');
        debugPrint('$st');
      }
      _selectedCustomer = null;
      notifyListeners();
      return null;
    }
  }

  Future<Customer?> createCustomer(
    BuildContext context, {
    required String name,
    required String phone,
    required String email,
    required Object cityId,
    required String address,
  }) async {
    final bizId = await _requireBizId();
    if (bizId == null) return null;

    final path = '/waveup/$bizId/customer';
    final payload = {
      "name": name,
      "phone": phone,
      "email": email,
      "city_id": cityId,
      "address": address,
    };

    if (kDebugMode) {
      debugPrint('[SalesProvider] 🌐 POST $path');
      debugPrint('[SalesProvider] payload: $payload');
    }

    try {
      final j = await ApiJson.postMap(
        context,
        path,
        payload,
        withAccessToken: true,
      );
      if (kDebugMode) debugPrint('[SalesProvider] create resp: $j');

      if (j == null || (j['status'] as num?)?.toInt() != 200) {
        _lastError = j?['message']?.toString() ?? 'Failed to create customer';
        return null;
      }

      final data = (j['data'] as Map).cast<String, dynamic>();
      final c = Customer.fromJson(data);

      _customers.insert(0, c);
      notifyListeners();
      return c;
    } catch (e, st) {
      _lastError = '$e';
      if (kDebugMode) {
        debugPrint('[SalesProvider] createCustomer exception: $e');
        debugPrint('$st');
      }
      return null;
    }
  }

  Future<Customer?> updateCustomer(
    BuildContext context, {
    required String idCustomer,
    required String name,
    required String phone,
    required String email,
    required Object cityId,
    required String address,
  }) async {
    final bizId = await _requireBizId();
    if (bizId == null) return null;

    final path = '/waveup/$bizId/customer/$idCustomer';
    final payload = {
      "name": name,
      "phone": phone,
      "email": email,
      "city_id": cityId,
      "address": address,
    };

    if (kDebugMode) {
      debugPrint('[SalesProvider] 🌐 POST $path');
      debugPrint('[SalesProvider] payload: $payload');
    }

    try {
      final j = await ApiJson.postMap(
        context,
        path,
        payload,
        withAccessToken: true,
      );
      if (kDebugMode) debugPrint('[SalesProvider] update resp: $j');

      if (j == null || (j['status'] as num?)?.toInt() != 200) {
        _lastError = j?['message']?.toString() ?? 'Failed to update customer';
        return null;
      }

      final data = (j['data'] as Map).cast<String, dynamic>();
      final updated = Customer.fromJson(data);

      final idx = _customers.indexWhere((e) => e.idCustomer == idCustomer);
      if (idx >= 0) _customers[idx] = updated;
      if (_selectedCustomer?.idCustomer == idCustomer) {
        _selectedCustomer = updated;
      }
      notifyListeners();
      return updated;
    } catch (e, st) {
      _lastError = '$e';
      if (kDebugMode) {
        debugPrint('[SalesProvider] updateCustomer exception: $e');
        debugPrint('$st');
      }
      return null;
    }
  }

  Future<bool> deleteCustomer(BuildContext context, String idCustomer) async {
    final bizId = await _requireBizId();
    if (bizId == null) return false;

    final path = '/waveup/$bizId/customer/remove/$idCustomer';
    if (kDebugMode) debugPrint('[SalesProvider] 🌐 GET $path (delete)');

    try {
      final j = await ApiJson.getMap(context, path, withAccessToken: true);
      if (kDebugMode) debugPrint('[SalesProvider] delete resp: $j');

      final ok = j != null && (j['status'] as num?)?.toInt() == 200;
      if (ok) {
        _customers.removeWhere((e) => e.idCustomer == idCustomer);
        if (_selectedCustomer?.idCustomer == idCustomer) {
          _selectedCustomer = null;
        }
        notifyListeners();
        return true;
      } else {
        _lastError = j?['message']?.toString() ?? 'Failed to delete customer';
        return false;
      }
    } catch (e, st) {
      _lastError = '$e';
      if (kDebugMode) {
        debugPrint('[SalesProvider] deleteCustomer exception: $e');
        debugPrint('$st');
      }
      return false;
    }
  }

  Map<String, int> allocOrderDiscountPerUnit() {
    final od = _discount ?? 0;
    if (od <= 0 || _cart.isEmpty) return const {};

    final bases = <String, int>{};
    var baseSum = 0;

    for (final it in _cart.values) {
      final skuId = it.sku.skuId;
      final afterItem = (it.sku.price - perItemDiscountOf(skuId));
      final base = (afterItem > 0 ? afterItem : 0) * it.qty;
      if (base > 0) {
        bases[skuId] = base;
        baseSum += base;
      }
    }
    if (baseSum == 0) return const {};

    final perUnit = <String, int>{};
    var allocated = 0;

    for (final it in _cart.values) {
      final skuId = it.sku.skuId;
      final base = bases[skuId] ?? 0;
      if (base == 0) {
        perUnit[skuId] = 0;
        continue;
      }
      final rowDisc = (od * base) ~/ baseSum;
      allocated += rowDisc;
      perUnit[skuId] = it.qty > 0 ? (rowDisc ~/ it.qty) : 0;
    }

    final remain = od - allocated;
    if (remain > 0 && _cart.isNotEmpty) {
      final first = _cart.values.first;
      final d0 = perUnit[first.sku.skuId] ?? 0;
      perUnit[first.sku.skuId] =
          d0 + (remain ~/ (first.qty > 0 ? first.qty : 1));
    }

    perUnit.updateAll((skuId, d) {
      final sku = _cart.values.firstWhere((x) => x.sku.skuId == skuId).sku;
      final maxDisc = (sku.price - perItemDiscountOf(skuId));
      return d.clamp(0, maxDisc);
    });

    return perUnit;
  }

  void reset() {
    _cart.clear();
    _currentStep = 0;

    _storeLocationId = null;
    _storeLocationName = null;
    _discount = 0;

    // pastikan nol terus
    _shippingFee = 0;

    _note = null;
    _reference = null;
    _paymentMethod = 1;
    _customerId = null;
    _customerName = null;
    _itemDiscount.clear();

    notifyListeners();
  }
}
