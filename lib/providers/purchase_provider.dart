import 'package:flutter/foundation.dart';

/// Status order
enum PurchaseStatus { inProgress, completed, canceled }

/// Produk katalog (untuk tambah dari bottom sheet)
class Product {
  final String name;
  final int price;
  final String imageUrl;
  const Product({
    required this.name,
    required this.price,
    required this.imageUrl,
  });
}

/// Baris item di order
class OrderLine {
  final String name;
  final int qty;
  final int price; // harga per item (IDR)
  final String note;
  final String imageUrl;

  const OrderLine({
    required this.name,
    required this.qty,
    required this.price,
    this.note = 'Note here',
    this.imageUrl =
        'https://images.unsplash.com/photo-1542831371-29b0f74f9713?w=200&q=60',
  });

  int get lineTotal => qty * price;

  OrderLine copyWith({
    String? name,
    int? qty,
    int? price,
    String? note,
    String? imageUrl,
  }) {
    return OrderLine(
      name: name ?? this.name,
      qty: qty ?? this.qty,
      price: price ?? this.price,
      note: note ?? this.note,
      imageUrl: imageUrl ?? this.imageUrl,
    );
  }
}

/// Entitas purchase/order
class PurchaseItem {
  final String code;
  final DateTime time;
  final int quantity; // total qty semua line
  final int totalAmount; // dipakai di list (legacy display)
  final PurchaseStatus status;

  // Detail
  final String servicedByName;
  final String servicedById;
  final String servicedByAvatarUrl;
  final double serviceFeePercent; // 0.02 = 2%
  final List<OrderLine> lines;

  const PurchaseItem({
    required this.code,
    required this.time,
    required this.quantity,
    required this.totalAmount,
    required this.status,
    required this.servicedByName,
    required this.servicedById,
    required this.servicedByAvatarUrl,
    required this.serviceFeePercent,
    required this.lines,
  });

  // Perhitungan live
  int get subtotal => lines.fold<int>(0, (sum, l) => sum + l.lineTotal);
  int get serviceFee => (subtotal * serviceFeePercent).round();
  int get grandTotal => subtotal + serviceFee;

  PurchaseItem copyWith({
    String? code,
    DateTime? time,
    int? quantity,
    int? totalAmount,
    PurchaseStatus? status,
    String? servicedByName,
    String? servicedById,
    String? servicedByAvatarUrl,
    double? serviceFeePercent,
    List<OrderLine>? lines,
  }) {
    return PurchaseItem(
      code: code ?? this.code,
      time: time ?? this.time,
      quantity: quantity ?? this.quantity,
      totalAmount: totalAmount ?? this.totalAmount,
      status: status ?? this.status,
      servicedByName: servicedByName ?? this.servicedByName,
      servicedById: servicedById ?? this.servicedById,
      servicedByAvatarUrl: servicedByAvatarUrl ?? this.servicedByAvatarUrl,
      serviceFeePercent: serviceFeePercent ?? this.serviceFeePercent,
      lines: lines ?? this.lines,
    );
  }
}

class PurchaseProvider extends ChangeNotifier {
  // ====== Dummy katalog produk ======
  final List<Product> _products = const [
    Product(
      name: 'Garlic Bread',
      price: 15000,
      imageUrl:
          'https://images.unsplash.com/photo-1542831371-29b0f74f9713?w=400&q=60',
    ),
    Product(
      name: 'Hot Cappucino',
      price: 24000,
      imageUrl:
          'https://images.unsplash.com/photo-1504754524776-8f4f37790ca0?w=400&q=60',
    ),
    Product(
      name: 'Berry Sourdough',
      price: 18000,
      imageUrl:
          'https://images.unsplash.com/photo-1550367086-456a0a0f1c1b?w=400&q=60',
    ),
    Product(
      name: 'Ice Latte',
      price: 22000,
      imageUrl:
          'https://images.unsplash.com/photo-1541167760496-1628856ab772?w=400&q=60',
    ),
    Product(
      name: 'Ice Americano',
      price: 20000,
      imageUrl:
          'https://images.unsplash.com/photo-1517705008128-361805f42e86?w=400&q=60',
    ),
  ];

  List<Product> get products => List.unmodifiable(_products);

  // ====== Dummy orders ======
  final List<PurchaseItem> _items = [
    PurchaseItem(
      code: 'ODR0003',
      time: DateTime(2025, 9, 4, 12, 0, 5),
      quantity: 3,
      totalAmount: 54000,
      status: PurchaseStatus.inProgress,
      servicedByName: 'Mirna Sari', // fallback jika nama prefs kosong
      servicedById: 'ID 2004882',
      servicedByAvatarUrl:
          'https://images.unsplash.com/photo-1535713875002-d1d0cf377fde?w=120&q=60',
      serviceFeePercent: 0.02,
      lines: const [
        OrderLine(
          name: 'Garlic Bread',
          qty: 2,
          price: 15000,
          imageUrl:
              'https://images.unsplash.com/photo-1542831371-29b0f74f9713?w=400&q=60',
        ),
        OrderLine(
          name: 'Hot Cappucino',
          qty: 1,
          price: 24000,
          imageUrl:
              'https://images.unsplash.com/photo-1504754524776-8f4f37790ca0?w=400&q=60',
        ),
      ],
    ),
    PurchaseItem(
      code: 'ODR0001',
      time: DateTime(2025, 9, 4, 12, 0, 5),
      quantity: 8,
      totalAmount: 108500,
      status: PurchaseStatus.completed,
      servicedByName: 'Mirna Sari',
      servicedById: 'ID 2004882',
      servicedByAvatarUrl:
          'https://images.unsplash.com/photo-1535713875002-d1d0cf377fde?w=120&q=60',
      serviceFeePercent: 0.02,
      lines: const [
        OrderLine(
          name: 'Garlic Bread',
          qty: 2,
          price: 15000,
          imageUrl:
              'https://images.unsplash.com/photo-1542831371-29b0f74f9713?w=400&q=60',
        ),
        OrderLine(
          name: 'Hot Cappucino',
          qty: 1,
          price: 74000,
          imageUrl:
              'https://images.unsplash.com/photo-1550547660-d9450f859349?w=400&q=60',
        ),
        OrderLine(
          name: 'Berry Sourdough',
          qty: 5,
          price: 2400,
          imageUrl:
              'https://images.unsplash.com/photo-1550367086-456a0a0f1c1b?w=400&q=60',
        ),
      ],
    ),
    PurchaseItem(
      code: 'ODR0002',
      time: DateTime(2025, 9, 4, 12, 0, 5),
      quantity: 2,
      totalAmount: 54000,
      status: PurchaseStatus.completed,
      servicedByName: 'Mirna Sari',
      servicedById: 'ID 2004882',
      servicedByAvatarUrl:
          'https://images.unsplash.com/photo-1535713875002-d1d0cf377fde?w=120&q=60',
      serviceFeePercent: 0.02,
      lines: const [OrderLine(name: 'Garlic Bread', qty: 2, price: 27000)],
    ),
    PurchaseItem(
      code: 'ODR0004',
      time: DateTime(2025, 9, 4, 12, 0, 5),
      quantity: 2,
      totalAmount: 54000,
      status: PurchaseStatus.canceled,
      servicedByName: 'Mirna Sari',
      servicedById: 'ID 2004882',
      servicedByAvatarUrl:
          'https://images.unsplash.com/photo-1535713875002-d1d0cf377fde?w=120&q=60',
      serviceFeePercent: 0.02,
      lines: const [OrderLine(name: 'Garlic Bread', qty: 2, price: 27000)],
    ),
  ];

  PurchaseStatus? _filter;

  // ====== Selectors ======
  List<PurchaseItem> get items => _filter == null
      ? List.unmodifiable(_items)
      : _items.where((e) => e.status == _filter).toList(growable: false);

  PurchaseStatus? get filter => _filter;

  // ====== Actions umum ======
  void setFilter(PurchaseStatus? status) {
    _filter = status;
    notifyListeners();
  }

  Future<void> refresh() async {
    await Future<void>.delayed(const Duration(milliseconds: 500));
    notifyListeners();
  }

  PurchaseItem? getByCode(String code) {
    try {
      return _items.firstWhere((e) => e.code == code);
    } catch (_) {
      return null;
    }
  }

  void updateStatus(String code, PurchaseStatus newStatus) {
    final idx = _items.indexWhere((e) => e.code == code);
    if (idx == -1) return;
    _items[idx] = _items[idx].copyWith(status: newStatus);
    notifyListeners();
  }

  // ====== Kontrol qty/baris ======

  /// Set qty baris [lineIndex] pada order [code].
  /// Jika qty==0 -> baris dihapus.
  void setLineQty(String code, int lineIndex, int qty) {
    final idx = _items.indexWhere((e) => e.code == code);
    if (idx == -1) return;

    final item = _items[idx];
    if (lineIndex < 0 || lineIndex >= item.lines.length) return;

    final newLines = List<OrderLine>.from(item.lines);
    final newQty = qty.clamp(0, 9999);

    if (newQty == 0) {
      newLines.removeAt(lineIndex);
    } else {
      newLines[lineIndex] = newLines[lineIndex].copyWith(qty: newQty);
    }

    final newTotalQty = newLines.fold<int>(0, (s, l) => s + l.qty);

    _items[idx] = item.copyWith(lines: newLines, quantity: newTotalQty);
    notifyListeners();
  }

  void incrementLineQty(String code, int lineIndex) {
    final item = getByCode(code);
    if (item == null || lineIndex < 0 || lineIndex >= item.lines.length) return;
    setLineQty(code, lineIndex, item.lines[lineIndex].qty + 1);
  }

  void decrementLineQty(String code, int lineIndex) {
    final item = getByCode(code);
    if (item == null || lineIndex < 0 || lineIndex >= item.lines.length) return;
    setLineQty(code, lineIndex, (item.lines[lineIndex].qty - 1).clamp(0, 9999));
  }

  /// Tambah produk ke order: jika sudah ada -> qty+1, kalau belum -> buat baris qty=1.
  void addProductToOrder(String code, Product product) {
    final idx = _items.indexWhere((e) => e.code == code);
    if (idx == -1) return;

    final item = _items[idx];
    final lines = List<OrderLine>.from(item.lines);

    final existIdx = lines.indexWhere((l) => l.name == product.name);
    if (existIdx >= 0) {
      final exist = lines[existIdx];
      lines[existIdx] = exist.copyWith(qty: exist.qty + 1);
    } else {
      lines.add(
        OrderLine(
          name: product.name,
          qty: 1,
          price: product.price,
          imageUrl: product.imageUrl,
        ),
      );
    }

    final newTotalQty = lines.fold<int>(0, (s, l) => s + l.qty);
    _items[idx] = item.copyWith(lines: lines, quantity: newTotalQty);
    notifyListeners();
  }

  /// Ambil qty untuk produk bernama [productName] di order [code].
  /// Berguna untuk menampilkan tombol "Add" -> "Added".
  int getQtyForProduct(String code, String productName) {
    final item = getByCode(code);
    if (item == null) return 0;
    final i = item.lines.indexWhere((l) => l.name == productName);
    return i == -1 ? 0 : item.lines[i].qty;
  }
}
