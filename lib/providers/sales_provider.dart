// lib/providers/sales_provider.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:wa_blast/providers/product_provider.dart' as catalog;

class PosProduct {
  final String id;
  final String name;
  final int price; // IDR
  final String imageUrl;
  final bool inStock;

  const PosProduct({
    required this.id,
    required this.name,
    required this.price,
    required this.imageUrl,
    this.inStock = true,
  });
}

class CartItem {
  final PosProduct product;
  int qty;
  CartItem({required this.product, this.qty = 1});
  int get subtotal => product.price * qty;
}

class SalesProvider extends ChangeNotifier {
  // ===== CATALOG (from real API) =====
  final List<PosProduct> _catalog = [];
  bool _loadingCatalog = false;
  String? _errorCatalog;

  List<PosProduct> get products => List.unmodifiable(_catalog);
  bool get loadingProducts => _loadingCatalog;
  String? get catalogError => _errorCatalog;

  /// Fetch dari ProductProvider dan map ke POS catalog.
  Future<void> loadCatalog(BuildContext context) async {
    _setLoading(true);

    try {
      // 1) fetch ke server via ProductProvider (punya kamu)
      await context.read<catalog.ProductProvider>().fetchProducts(context);

      // 2) ambil list dari provider & mapping
      final prov = context.read<catalog.ProductProvider>();
      final source = prov.products; // List<catalog.Product>

      final mapped = source
          .map(
            (p) => PosProduct(
              id: p.idProduct,
              name: p.name,
              price: p.basePrice ?? 0, // fallback 0 kalau tidak ada price
              imageUrl: p.primaryImageUrl ?? '',
              inStock:
                  !p.isHide, // anggap isHide == out of stock / disembunyikan
            ),
          )
          // optional: hanya tampilkan yang punya harga
          .where((pp) => pp.price > 0)
          .toList(growable: false);

      _catalog
        ..clear()
        ..addAll(mapped);

      _errorCatalog = null;
    } catch (e) {
      _errorCatalog = e.toString();
    } finally {
      _setLoading(false);
    }
  }

  /// Sinkron dari cache ProductProvider tanpa network call.
  /// Pakai ini kalau kamu sudah memanggil fetchProducts(...) di tempat lain.
  void syncFromCache(BuildContext context) {
    final prov = context.read<catalog.ProductProvider>();
    final source = prov.products;

    final mapped = source
        .map(
          (p) => PosProduct(
            id: p.idProduct,
            name: p.name,
            price: p.basePrice ?? 0,
            imageUrl: p.primaryImageUrl ?? '',
            inStock: !p.isHide,
          ),
        )
        .where((pp) => pp.price > 0)
        .toList(growable: false);

    _catalog
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

  void add(PosProduct p) {
    final key = p.id;
    if (!_cart.containsKey(key)) {
      _cart[key] = CartItem(product: p, qty: 1);
    } else {
      _cart[key]!.qty += 1;
    }
    notifyListeners();
  }

  void removeOne(PosProduct p) {
    final key = p.id;
    if (!_cart.containsKey(key)) return;
    final item = _cart[key]!;
    if (item.qty > 1) {
      item.qty -= 1;
    } else {
      _cart.remove(key);
    }
    notifyListeners();
  }

  void removeAll(PosProduct p) {
    _cart.remove(p.id);
    notifyListeners();
  }

  // ===== TOTALS & FEES =====
  int get subtotal => cartItems.fold(0, (s, it) => s + it.subtotal);
  double get serviceFeeRate => 0.02;
  int get serviceFee => (subtotal * serviceFeeRate).round();
  int get total => subtotal + serviceFee;

  // ===== ORDER META =====
  String get orderNumber =>
      'ODR${DateTime.now().millisecondsSinceEpoch % 1000000}'.padLeft(10, '0');

  void reset() {
    _cart.clear();
    _currentStep = 0;
    notifyListeners();
  }
}
