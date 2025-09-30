import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:wa_blast/core/provider_helper.dart';
import 'package:wa_blast/providers/product_provider.dart' as catalog;

/// Representasi 1 SKU yang bisa dijual
class PosSku {
  final String skuId; // idProductSku
  final String skuCode; // code
  final int price; // harga retail
  final String productId; // idProduct
  final String productName; // name
  final String imageUrl; // url gambar
  final bool inStock; // asumsi dari isHide (kebalikan)

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

// === MODEL RINGAN UNTUK LIST REPORT ===
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
  final String code; // pakai "number"
  final DateTime time; // dari order_at (epoch detik) ATAU created_at
  final int quantity; // sum(qty_out)
  final int totalAmount; // dari "amount"
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

class SalesProvider extends ChangeNotifier {
  // ===== CATALOG (per-SKU) =====
  final List<PosSku> _catalogSkus = [];
  bool _loadingCatalog = false;
  String? _errorCatalog;

  List<PosSku> get skus => List.unmodifiable(_catalogSkus);
  bool get loadingSkus => _loadingCatalog;
  String? get catalogError => _errorCatalog;
  bool _submitting = false;
  String? _lastError;

  bool get submitting => _submitting;
  String? get lastError => _lastError;

  // ===== SALES REPORT LIST =====
  final List<SalesReportItem> _reports = [];
  bool _loadingReports = false;
  String? _reportError;
  PageMeta? _pageReports;

  List<SalesReportItem> get reports => List.unmodifiable(_reports);
  bool get loadingReports => _loadingReports;
  String? get reportError => _reportError;
  PageMeta? get pageReports => _pageReports;

  void _setReportError(String? v) {
    _reportError = v;
    notifyListeners();
  }

  void _setLoadingReports(bool v) {
    _loadingReports = v;
    notifyListeners();
  }

  SalesReportItem _salesItemFromApi(Map<String, dynamic> j) {
    // parse time: prefer order_at (epoch detik) fallback ke created_at
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
        .map((e) => SalesLine.fromJson((e as Map).cast<String, dynamic>()))
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

  Future<void> loadCatalog(BuildContext context) async {
    _setLoading(true);
    try {
      await context.read<catalog.ProductProvider>().fetchProducts(context);

      final prov = context.read<catalog.ProductProvider>();
      final products = prov.products;

      final List<PosSku> mapped = [];
      for (final p in products) {
        final productId = p.idProduct;
        final productName = p.name;
        final img =
            p.primaryImageUrl ??
            ((p.productImages?.isNotEmpty == true)
                ? p.productImages!.first.imagePath
                : '') ??
            '';
        final bool inStock = !(p.isHide == true);

        final skus = p.productSkus ?? const [];
        for (final s in skus) {
          final price = (s.price ?? p.basePrice ?? 0);
          if (price <= 0) continue;
          mapped.add(
            PosSku(
              skuId: s.idProductSku ?? '',
              skuCode: s.code ?? '',
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

  void syncFromCache(BuildContext context) {
    final prov = context.read<catalog.ProductProvider>();
    final products = prov.products;

    final List<PosSku> mapped = [];
    for (final p in products) {
      final productId = p.idProduct;
      final productName = p.name;
      final img =
          p.primaryImageUrl ??
          ((p.productImages?.isNotEmpty == true)
              ? p.productImages!.first.imagePath
              : '') ??
          '';
      final bool inStock = !(p.isHide == true);

      final skus = p.productSkus ?? const [];
      for (final s in skus) {
        final price = (s.price ?? p.basePrice ?? 0);
        if (price <= 0) continue;
        mapped.add(
          PosSku(
            skuId: s.idProductSku ?? '',
            skuCode: s.code ?? '',
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

  // ===== CART (key = skuId) =====
  final Map<String, CartItem> _cart = {};
  List<CartItem> get cartItems => _cart.values.toList(growable: false);

  void add(PosSku s) {
    final key = s.skuId;
    if (key.isEmpty) return;
    if (!_cart.containsKey(key)) {
      _cart[key] = CartItem(sku: s, qty: 1);
    } else {
      _cart[key]!.qty += 1;
    }
    notifyListeners();
  }

  void removeOne(PosSku s) {
    final key = s.skuId;
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
    _cart.remove(s.skuId);
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
  int? _paymentMethod = 1; // 1=Tunai, 2=Debit, 3=Midtrans biasa

  String? get storeLocationId => _storeLocationId;
  String? get storeLocationName => _storeLocationName;
  int? get discount => _discount;
  int? get shippingFee => _shippingFee;
  String? get note => _note;
  String? get currentReference => _reference; // pasif (no side-effect)
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
    // pastikan reference ada (tanpa notify)
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
          "qty": it.qty,
          "price": it.sku.price,
        };
      }).toList(),
    };
  }

  /// POST ke /waveup/{idBusiness}/transaction/sales
  /// Payload diambil dari buildOrderPayload()
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

    // Pastikan reference ada (tanpa notify)
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

      final ok = j != null && (j['status'] as num?)?.toInt() == 200;
      if (!ok) {
        _lastError =
            j?['msg']?.toString() ??
            j?['message']?.toString() ??
            'Failed to submit sales transaction';
        return false;
      }

      // success
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
