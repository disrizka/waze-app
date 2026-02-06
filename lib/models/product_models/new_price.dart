part of '../../providers/product_provider.dart';

@immutable
class NewPrice {
  final int minQty;
  final int price;
  const NewPrice({required this.minQty, required this.price});

  Map<String, dynamic> toJson() => {'min_qty': minQty, 'price': price};
}
