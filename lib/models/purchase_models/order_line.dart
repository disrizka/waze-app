part of '../../providers/purchase_provider.dart';

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
