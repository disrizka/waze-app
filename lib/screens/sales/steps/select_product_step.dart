import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:wa_blast/providers/sales_provider.dart';

import '../../../constants/app_colors.dart';
import '../../../constants/design_system.dart';
import '../../../widgets/stepper_header.dart';

class SelectProductStep extends StatelessWidget {
  final bool withHeader;
  const SelectProductStep({super.key, this.withHeader = true});

  @override
  Widget build(BuildContext context) {
    // Auto-load katalog saat pertama kali masuk jika masih kosong
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final sp = context.read<SalesProvider>();
      if (!sp.loadingProducts && sp.products.isEmpty) {
        sp.loadCatalog(context);
      }
    });

    final sp = context.watch<SalesProvider>();

    Widget body;
    if (sp.loadingProducts) {
      body = const Center(child: CircularProgressIndicator());
    } else if (sp.catalogError != null) {
      body = Center(
        child: Padding(
          padding: DS.p16,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.error_outline,
                size: 32,
                color: AppColors.danger,
              ),
              const SizedBox(height: 8),
              Text('Failed to load products', style: DS.tsTitle),
              const SizedBox(height: 6),
              Text(
                sp.catalogError!,
                style: DS.tsBody.copyWith(color: AppColors.disabledFg),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              OutlinedButton(
                onPressed: () => sp.loadCatalog(context),
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
      );
    } else if (sp.products.isEmpty) {
      body = Center(
        child: Padding(
          padding: DS.p16,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.inventory_2_outlined,
                size: 36,
                color: AppColors.disabledFg,
              ),
              const SizedBox(height: 8),
              Text('No products available', style: DS.tsTitle),
              const SizedBox(height: 6),
              Text(
                'Add products first or pull to refresh.',
                style: DS.tsBody.copyWith(color: AppColors.disabledFg),
              ),
            ],
          ),
        ),
      );
    } else {
      body = RefreshIndicator(
        onRefresh: () => sp.loadCatalog(context),
        child: ListView.separated(
          padding: EdgeInsets.zero,
          itemCount: sp.products.length,
          separatorBuilder: (_, __) =>
              const Divider(height: 1, color: AppColors.divider),
          itemBuilder: (_, i) => _RowProduct(product: sp.products[i]),
        ),
      );
    }

    return Column(
      children: [
        if (withHeader)
          const StepperHeader(activeIndex: 0)
        else
          const SizedBox.shrink(),
        Expanded(child: body),
        SafeArea(
          minimum: DS.p16,
          child: SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: sp.cartItems.isEmpty ? null : () => sp.goTo(1),
              style: DS.primaryBtn(enabled: !sp.cartItems.isEmpty),
              child: const Text('Next'),
            ),
          ),
        ),
      ],
    );
  }
}

class _RowProduct extends StatelessWidget {
  final PosProduct product; // <- pakai PosProduct dari SalesProvider
  const _RowProduct({required this.product});

  @override
  Widget build(BuildContext context) {
    final prov = context.watch<SalesProvider>();

    final item = prov.cartItems.firstWhere(
      (e) => e.product.id == product.id,
      orElse: () => CartItem(product: product, qty: 0),
    );
    final inCart = item.qty > 0;

    final image = ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: (product.imageUrl.isNotEmpty)
          ? Image.network(
              product.imageUrl,
              width: 72,
              height: 72,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => _ImageFallback(),
            )
          : _ImageFallback(),
    );

    final content = Padding(
      padding: DS.listTilePad,
      child: Row(
        children: [
          image,
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
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
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

class _ImageFallback extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      width: 72,
      height: 72,
      color: AppColors.greyBackground,
      child: const Icon(
        Icons.image_not_supported_outlined,
        size: 24,
        color: AppColors.disabledFg,
      ),
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
