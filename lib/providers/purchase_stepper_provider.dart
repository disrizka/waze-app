import 'package:flutter/foundation.dart';

class Product {
  final String id;
  final String name;
  final int price; // in IDR
  final String imageUrl;
  final bool inStock;

  const Product({
    required this.id,
    required this.name,
    required this.price,
    required this.imageUrl,
    this.inStock = true,
  });
}

class CartItem {
  final Product product;
  int qty;
  CartItem({required this.product, this.qty = 1});
  int get subtotal => product.price * qty;
}

class PurchaseStepperProvider extends ChangeNotifier {
  // dummy catálogo
  final List<Product> products = const [
    Product(
      id: 'p1',
      name: 'Garlic Bread',
      price: 15000,
      imageUrl:
          'https://images.unsplash.com/photo-1540189549336-e6e99c3679fe?w=300',
    ),
    Product(
      id: 'p2',
      name: 'Hot Cappuccino',
      price: 24000,
      imageUrl:
          'https://images.unsplash.com/photo-1511920170033-f8396924c348?w=300',
    ),
    Product(
      id: 'p3',
      name: 'Berry Sourdough',
      price: 18000,
      imageUrl:
          'https://images.unsplash.com/photo-1511690656952-34342bb7c2f2?w=300',
      inStock: false,
    ),
    Product(
      id: 'p4',
      name: 'Ice Latte',
      price: 22000,
      imageUrl:
          'https://images.unsplash.com/photo-1541167760496-1628856ab772?w=300',
    ),
    Product(
      id: 'p5',
      name: 'Ice Americano',
      price: 20000,
      imageUrl:
          'https://images.unsplash.com/photo-1517705008128-361805f42e86?w=300',
    ),
  ];

  // stepper
  int _currentStep = 0;
  int get currentStep => _currentStep;
  void goTo(int step) {
    _currentStep = step.clamp(0, 2);
    notifyListeners();
  }

  // cart
  final Map<String, CartItem> _cart = {};
  List<CartItem> get cartItems => _cart.values.toList(growable: false);

  void add(Product p) {
    if (!_cart.containsKey(p.id)) {
      _cart[p.id] = CartItem(product: p, qty: 1);
    } else {
      _cart[p.id]!.qty += 1;
    }
    notifyListeners();
  }

  void removeOne(Product p) {
    if (!_cart.containsKey(p.id)) return;
    final item = _cart[p.id]!;
    if (item.qty > 1) {
      item.qty -= 1;
    } else {
      _cart.remove(p.id);
    }
    notifyListeners();
  }

  void removeAll(Product p) {
    _cart.remove(p.id);
    notifyListeners();
  }

  // totals & fees
  int get subtotal => cartItems.fold(0, (s, it) => s + it.subtotal);
  double get serviceFeeRate => 0.02;
  int get serviceFee => (subtotal * serviceFeeRate).round();
  int get total => subtotal + serviceFee;

  // order meta
  String get orderNumber =>
      'ODR${DateTime.now().millisecondsSinceEpoch % 1000000}'.padLeft(10, '0');

  void reset() {
    _cart.clear();
    _currentStep = 0;
    notifyListeners();
  }
}
