import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:wa_blast/core/provider_helper.dart'; // BizIdCache, ApiJson, FetchHelper, PageMeta
import 'package:wa_blast/providers/product_provider.dart' as catalog;
import 'package:wa_blast/models/product_model.dart' as model;

/// =========================
/// CART SKU (ringan)
/// =========================

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

  /// Opsional: konsumsi error terakhir (sekali pakai buat snackbar)
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
      // fetch & ambil cache dari ProductProvider
      await context.read<catalog.ProductProvider>().fetchProducts(context);
      final prov = context.read<catalog.ProductProvider>();
      final prods = prov.products; // List<model.Product>

      // simpan cache products untuk UI grid
      _products
        ..clear()
        ..addAll(prods);

      // Map ke PosSku ringan untuk cart/pipeline lama
      final List<PosSku> mapped = [];
      for (final p in prods) {
        final productId = p.idProduct;
        final productName = p.name;
        final img = p.primaryImageUrl ?? '';
        final bool inStock = !p.isHide;

        final skus = p.productSkus; // non-nullable List<ProductSku>
        if (skus.isEmpty) {
          // fallback: kalau produk tanpa SKU, pakai basePrice (jika ada) sebagai entri tunggal
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

  /// Tambah SKU (pipeline lama – menerima PosSku)
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

  /// Tambah SKU berbasis referensi Product/SKU (dipakai UI varian baru)
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
    }
    notifyListeners();
  }

  void removeAll(PosSku s) {
    final key = _keyFor(s);
    _cart.remove(key);
    notifyListeners();
  }

  // ===== TOTALS & FEES =====
  int get subtotal => cartItems.fold(0, (s, it) => s + it.subtotal);
  double get serviceFeeRate => 0.02;
  int get serviceFee => (subtotal * serviceFeeRate).round();
  int get total => subtotal + serviceFee;

  // ===== ORDER NUMBER (display only) =====
  String get orderNumber =>
      'ODR${DateTime.now().millisecondsSinceEpoch % 1000000}'.padLeft(10, '0');

  // ===== ORDER META (form CheckOrderStep) =====
  String? _storeLocationId;
  String? _storeLocationName;
  int? _discount = 0;
  int? _shippingFee = 0;
  String? _note;
  String? _reference; // REF-xxxxxx (editable)
  int? _paymentMethod = 1; // 1=Tunai, 2=Debit, 3=QRIS/VA

  String? get storeLocationId => _storeLocationId;
  String? get storeLocationName => _storeLocationName;
  int? get discount => _discount;
  int? get shippingFee => _shippingFee;
  String? get note => _note;
  String? get currentReference => _reference;
  int? get paymentMethod => _paymentMethod;

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
    int? shippingFee,
    String? note,
    String? reference,
    int? paymentMethod,
  }) {
    _storeLocationId = storeLocationId ?? _storeLocationId;
    _storeLocationName = storeLocationName ?? _storeLocationName;
    _discount = discount ?? _discount ?? 0;
    _shippingFee = shippingFee ?? _shippingFee ?? 0;
    _note = note ?? _note;

    if (reference != null && reference.isNotEmpty) {
      _reference = reference;
    }

    _paymentMethod = paymentMethod ?? _paymentMethod ?? 1;
    notifyListeners();
  }

  /// Payload final saat submit ke backend (items dari cart)
  Map<String, dynamic> buildOrderPayload() {
    ensureReferenceInitialized(notify: false);
    return {
      "store_location_id": _storeLocationId,
      "store_id": 0, // sesuai instruksi
      "discount": _discount ?? 0,
      "shipping_fee": _shippingFee ?? 0,
      "note": _note ?? "",
      "reference": _reference!, // REF-xxxxxx
      "payment_method": _paymentMethod ?? 1, // 1/2/3
      "items": cartItems.map((it) {
        return {
          "product_id": it.sku.productId,
          "product_sku_id": it.sku.skuId,
          "discount": 0,
          "qty": it.qty,
          "price": it.sku.price,
        };
      }).toList(),
    };
  }

  /// POST ke /waveup/{idBusiness}/transaction/sales
  Future<bool> submitSales(BuildContext context) async {
    final bizId = await _requireBizId();
    if (bizId == null) return false;

    // Validasi ringan
    if (cartItems.isEmpty) {
      _lastError = "Cart is empty.";
      return false;
    }
    if ((storeLocationId ?? '').isEmpty) {
      _lastError = "Store location must be selected.";
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
        debugPrint("[SalesProvider] 🔄 Server response: $j");
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

  /// POST /waveup/{bizId}/customer -> create
  Future<Customer?> createCustomer(
    BuildContext context, {
    required String name,
    required String phone,
    required String email,
    required int cityId,
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

      // opsional: tambahkan ke list saat ini (jika ingin terlihat langsung)
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

  /// POST /waveup/{bizId}/customer/{idCustomer} -> edit/update
  Future<Customer?> updateCustomer(
    BuildContext context, {
    required String idCustomer,
    required String name,
    required String phone,
    required String email,
    required int cityId,
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

      // sinkronkan di list
      final idx = _customers.indexWhere((e) => e.idCustomer == idCustomer);
      if (idx >= 0) {
        _customers[idx] = updated;
      }
      // sinkronkan selected jika sedang terbuka
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

  /// GET /waveup/{bizId}/customer/remove/{idCustomer} -> delete
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

  void reset() {
    _cart.clear();
    _currentStep = 0;

    _storeLocationId = null;
    _storeLocationName = null;
    _discount = 0;
    _shippingFee = 0;
    _note = null;
    _reference = null; // supaya transaksi baru dapat REF baru
    _paymentMethod = 1;

    notifyListeners();
  }
}
