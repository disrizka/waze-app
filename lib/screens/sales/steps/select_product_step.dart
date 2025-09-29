// lib/screens/sales/steps/select_product_step.dart
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
      if (!sp.loadingSkus && sp.skus.isEmpty) {
        sp.loadCatalog(context);
      }
    });

    final sp = context.watch<SalesProvider>();

    Widget body;
    if (sp.loadingSkus) {
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
              Text('Failed to load SKUs', style: DS.tsTitle),
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
    } else if (sp.skus.isEmpty) {
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
              Text('No SKUs available', style: DS.tsTitle),
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
          itemCount: sp.skus.length,
          separatorBuilder: (_, __) =>
              const Divider(height: 1, color: AppColors.divider),
          itemBuilder: (_, i) => _RowSku(sku: sp.skus[i]),
        ),
      );
    }

    return Container(
      color: Colors.white,
      child: Column(
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
      ),
    );
  }
}

class _RowSku extends StatelessWidget {
  final PosSku sku;
  const _RowSku({required this.sku});

  @override
  Widget build(BuildContext context) {
    final prov = context.watch<SalesProvider>();

    final item = prov.cartItems.firstWhere(
      (e) => e.sku.skuId == sku.skuId,
      orElse: () => CartItem(sku: sku, qty: 0),
    );
    final inCart = item.qty > 0;

    final image = ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: (sku.imageUrl.isNotEmpty)
          ? Image.network(
              sku.imageUrl,
              width: 72,
              height: 72,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => const _ImageFallback(),
            )
          : const _ImageFallback(),
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
                // Nama produk (besar)
                Text(
                  sku.productName,
                  style: sku.inStock
                      ? DS.tsTitle
                      : DS.tsTitle.copyWith(color: AppColors.disabledFg),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                // Kode SKU (kecil)
                Text(
                  sku.skuCode,
                  style: DS.tsBody.copyWith(
                    color: sku.inStock
                        ? AppColors.secondaryText
                        : AppColors.disabledFg,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 6),
                // Harga SKU
                Text(
                  formatRp(sku.price),
                  style: sku.inStock
                      ? DS.tsPrice
                      : DS.tsPrice.copyWith(color: AppColors.disabledFg),
                ),
                if (!sku.inStock) ...[
                  const SizedBox(height: 6),
                  const Text('Out Of Stock', style: DS.tsOutOfStock),
                ],
              ],
            ),
          ),
          if (sku.inStock)
            (inCart
                ? _QtyPill(
                    qty: item.qty,
                    onMinus: () => prov.removeOne(sku),
                    onPlus: () => prov.add(sku),
                  )
                : ElevatedButton(
                    onPressed: () => prov.add(sku),
                    style: DS.pillChoose(),
                    child: const Text('Choose'),
                  )),
        ],
      ),
    );

    return Stack(
      children: [
        content,
        if (!sku.inStock)
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
  const _ImageFallback();

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
