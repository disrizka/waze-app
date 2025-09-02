import 'package:flutter/foundation.dart';

class Product {
  final String id;
  final String name;
  Product({required this.id, required this.name});
}

class ProductProvider with ChangeNotifier {
  final List<Product> _items = [];
  bool _isLoading = false;

  List<Product> get items => List.unmodifiable(_items);
  bool get isLoading => _isLoading;
  bool get isEmpty => _items.isEmpty;

  Future<void> refresh() async {
    _isLoading = true;
    notifyListeners();
    // TODO: fetch from API if needed
    await Future.delayed(const Duration(milliseconds: 300));
    _isLoading = false;
    notifyListeners();
  }

  void addDummy() {
    _items.add(Product(id: DateTime.now().toIso8601String(), name: 'Sample'));
    notifyListeners();
  }
}
