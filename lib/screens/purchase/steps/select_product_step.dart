import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../constants/app_colors.dart';
import '../../../constants/design_system.dart';
import '../../../providers/purchase_stepper_provider.dart';
import '../../../widgets/stepper_header.dart';

class SelectProductStep extends StatelessWidget {
  final bool withHeader;
  const SelectProductStep({super.key, this.withHeader = true});

  @override
  Widget build(BuildContext context) {
    final prov = context.watch<PurchaseStepperProvider>();
    return Column(
      children: [
        if (withHeader)
          const StepperHeader(activeIndex: 0)
        else
          const SizedBox.shrink(),
        Expanded(
          child: ListView.separated(
            padding: EdgeInsets.zero,
            itemCount: prov.products.length,
            separatorBuilder: (_, __) =>
                const Divider(height: 1, color: AppColors.divider),
            itemBuilder: (_, i) => _RowProduct(product: prov.products[i]),
          ),
        ),
        SafeArea(
          minimum: DS.p16,
          child: SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: prov.cartItems.isEmpty ? null : () => prov.goTo(1),
              style: DS.primaryBtn(enabled: !prov.cartItems.isEmpty),
              child: const Text('Next'),
            ),
          ),
        ),
      ],
    );
  }
}

class _RowProduct extends StatelessWidget {
  final Product product;
  const _RowProduct({required this.product});

  @override
  Widget build(BuildContext context) {
    final prov = context.watch<PurchaseStepperProvider>();
    final item = prov.cartItems.firstWhere(
      (e) => e.product.id == product.id,
      orElse: () => CartItem(product: product, qty: 0),
    );
    final inCart = item.qty > 0;

    final content = Padding(
      padding: DS.listTilePad,
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: Image.network(
              product.imageUrl,
              width: 72,
              height: 72,
              fit: BoxFit.cover,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  product.name,
                  style: product.inStock
                      ? DS.tsTitle
                      : DS.tsTitle.copyWith(color: AppColors.disabledFg),
                ),
                const SizedBox(height: 4),
                Text(
                  formatRp(product.price),
                  style: product.inStock
                      ? DS.tsPrice
                      : DS.tsPrice.copyWith(color: AppColors.disabledFg),
                ),
                if (!product.inStock) ...[
                  const SizedBox(height: 6),
                  const Text('Out Of Stock', style: DS.tsOutOfStock),
                ],
              ],
            ),
          ),
          if (product.inStock)
            (inCart
                ? _QtyPill(
                    qty: item.qty,
                    onMinus: () => prov.removeOne(product),
                    onPlus: () => prov.add(product),
                  )
                : ElevatedButton(
                    onPressed: () => prov.add(product),
                    style: DS.pillChoose(),
                    child: const Text('Choose'),
                  )),
        ],
      ),
    );

    return Stack(
      children: [
        content,
        if (!product.inStock)
          Positioned.fill(
            child: IgnorePointer(
              child: Container(
                color: AppColors.greyBackground.withOpacity(0.4),
              ),
            ),
          ),
      ],
    );
  }
}

class _QtyPill extends StatelessWidget {
  final int qty;
  final VoidCallback onMinus;
  final VoidCallback onPlus;
  const _QtyPill({
    required this.qty,
    required this.onMinus,
    required this.onPlus,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 40,
      decoration: BoxDecoration(
        border: Border.all(color: AppColors.divider),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            visualDensity: VisualDensity.compact,
            onPressed: onMinus,
            icon: const Icon(Icons.remove),
          ),
          Text('$qty', style: const TextStyle(fontWeight: FontWeight.w700)),
          IconButton(
            visualDensity: VisualDensity.compact,
            onPressed: onPlus,
            icon: const Icon(Icons.add),
          ),
        ],
      ),
    );
  }
}
