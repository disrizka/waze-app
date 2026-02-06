part of '../../providers/sales_provider.dart';

class CartItem {
  final PosSku sku;
  int qty;
  CartItem({required this.sku, this.qty = 1});
  int get subtotal => sku.price * qty;
}
