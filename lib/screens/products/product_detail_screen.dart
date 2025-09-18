import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import 'package:wa_blast/constants/app_colors.dart';
import 'package:wa_blast/models/product_model.dart';
import 'package:wa_blast/providers/product_provider.dart';
import 'package:wa_blast/screens/products/create_edit_sheet/edit_product_sheet.dart';
import 'package:wa_blast/screens/products/product_screen.dart'
    show openEditProductById;
import 'package:wa_blast/widgets/app_snackbar.dart';

String _formatRp(int value) {
  final f = NumberFormat.currency(
    locale: 'id',
    symbol: 'Rp. ',
    decimalDigits: 0,
  );
  return f.format(value);
}

class ProductDetailScreen extends StatefulWidget {
  const ProductDetailScreen({super.key, required this.idProduct});
  static const routeName = '/product/detail-product';
  final String idProduct;

  @override
  State<ProductDetailScreen> createState() => _ProductDetailScreenState();
}

class _ProductDetailScreenState extends State<ProductDetailScreen> {
  late Future _future;

  @override
  void initState() {
    super.initState();
    _future = context.read<ProductProvider>().fetchProductDetail(
      context,
      widget.idProduct,
      preferCache: true,
    );
  }

  @override
  Widget build(BuildContext context) {
    final prov = context.watch<ProductProvider>();

    return Scaffold(
      backgroundColor: AppColors.white,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: AppColors.white,
        foregroundColor: AppColors.textPrimary,
        title: Text(
          prov.productDetail?.name ?? 'Product Detail',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontWeight: FontWeight.w700),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded),
          onPressed: () => Navigator.pop(context),
          tooltip: 'Back',
        ),
      ),
      body: FutureBuilder(
        future: _future,
        builder: (context, snap) {
          final loading =
              prov.loadingDetail &&
              snap.connectionState != ConnectionState.done;
          final p = prov.productDetail;
          final imgs = [...(p?.productImages ?? const <ProductImage>[])]
            ..sort((a, b) => a.position.compareTo(b.position));

          return CustomScrollView(
            slivers: [
              // Gallery box
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                  child: _ImageGalleryBox(images: imgs),
                ),
              ),

              // Info card (nama, brand, category, harga)
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
                  child: _InfoCard(
                    name: p?.name ?? '-',
                    isHide: p?.isHide ?? false,
                    brand: p?.productBrand?.name,
                    category: p?.productCategory?.name,
                    headlinePrice: _headlinePriceOf(p),
                  ),
                ),
              ),

              // Description
              if ((p?.description ?? '').isNotEmpty)
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 6,
                    ),
                    child: _SectionCard(
                      title: 'Description',
                      child: Text(
                        p!.description,
                        style: const TextStyle(
                          color: AppColors.textPrimary,
                          height: 1.5,
                        ),
                      ),
                    ),
                  ),
                ),

              // Prices
              if ((p?.productPrices ?? []).isNotEmpty)
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 6,
                    ),
                    child: _SectionCard(
                      title: 'Prices (Wholesale tiers)',
                      child: Column(
                        children: p!.productPrices
                            .map(
                              (e) => _RowTile(
                                left: 'Min. ${e.minQty} pcs',
                                right: _formatRp(e.price),
                              ),
                            )
                            .toList(),
                      ),
                    ),
                  ),
                ),

              // SKUs
              if ((p?.productSkus ?? []).isNotEmpty)
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 6,
                    ),
                    child: _SectionCard(
                      title: 'SKU',
                      child: Column(
                        children: p!.productSkus
                            .map(
                              (s) => _SkuTile(
                                code: s.code,
                                price: s.price,
                                attrs: s.attributes
                                    .map((a) => '${a.name}: ${a.value}')
                                    .toList(),
                              ),
                            )
                            .toList(),
                      ),
                    ),
                  ),
                ),

              SliverToBoxAdapter(
                child: SizedBox(
                  height: MediaQuery.of(context).padding.bottom + 90,
                ),
              ),
            ],
          );
        },
      ),

      // Sticky bottom bar
      bottomNavigationBar: Consumer<ProductProvider>(
        builder: (context, prov, _) {
          final p = prov.productDetail;
          final loading = prov.loadingDetail;
          return Container(
            decoration: const BoxDecoration(
              color: AppColors.white,
              border: Border(top: BorderSide(color: AppColors.divider)),
            ),
            padding: EdgeInsets.fromLTRB(
              16,
              12,
              16,
              12 + MediaQuery.of(context).padding.bottom,
            ),
            child: Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: (loading || p == null)
                        ? null
                        : () async {
                            final ok = await prov.deleteProduct(
                              context,
                              p.idProduct,
                            );
                            if (!mounted) return;
                            if (ok) {
                              AppSnackbar.show(
                                context,
                                type: AppSnackType.success,
                                message: 'Product deleted',
                              );
                              Navigator.pop(context);
                            } else {
                              AppSnackbar.show(
                                context,
                                type: AppSnackType.error,
                                message: prov.lastError ?? 'Failed to delete',
                              );
                            }
                          },
                    icon: const Icon(Icons.delete_outline_rounded),
                    label: const Text('Delete'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.danger,
                      side: const BorderSide(color: AppColors.danger),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      disabledForegroundColor: AppColors.disabledFg,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: (loading || prov.productDetail == null)
                        ? null
                        : () => showEditProductSheet(
                            context,
                            prov.productDetail!.idProduct,
                          ),

                    icon: const Icon(Icons.edit_rounded),
                    label: const Text('Edit Product'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.blueButton,
                      foregroundColor: AppColors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      disabledBackgroundColor: AppColors.disabledBg,
                      disabledForegroundColor: AppColors.disabledFg,
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  int? _headlinePriceOf(Product? p) {
    if (p == null) return null;
    // if (p.productPrices.isNotEmpty) {
    //   final sorted = [...p.productPrices]
    //     ..sort((a, b) => a.minQty.compareTo(b.minQty));
    //   return sorted.first.price;
    // }
    if (p.productSkus.isNotEmpty) {
      final sorted = [...p.productSkus]
        ..sort((a, b) => a.price.compareTo(b.price));
      return sorted.first.price;
    }
    return null;
  }
}

/// =========================
/// UI Pieces (warna pakai AppColors)
/// =========================

class _InfoCard extends StatelessWidget {
  const _InfoCard({
    required this.name,
    required this.isHide,
    required this.brand,
    required this.category,
    required this.headlinePrice,
  });

  final String name;
  final bool isHide;
  final String? brand;
  final String? category;
  final int? headlinePrice;

  @override
  Widget build(BuildContext context) {
    return _Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              if (isHide)
                const _ChipBadge(
                  label: 'Hidden',
                  color: AppColors.danger,
                  bg: Color(0xFFFFF1F2),
                ),
              if ((brand ?? '').isNotEmpty) _ChipSoft(label: brand!),
              if ((category ?? '').isNotEmpty) _ChipSoft(label: category!),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            name,
            style: const TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w800,
              color: AppColors.textPrimary,
              height: 1.2,
            ),
          ),
          if (headlinePrice != null) ...[
            const SizedBox(height: 6),
            Text(
              _formatRp(headlinePrice!),
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w800,
                color: AppColors.primary,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  const _SectionCard({required this.title, required this.child});
  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return _Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w800,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }
}

class _Card extends StatelessWidget {
  const _Card({required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.divider),
        boxShadow: const [
          BoxShadow(
            color: Color(0x15000000),
            blurRadius: 18,
            offset: Offset(0, 10),
          ),
        ],
      ),
      child: child,
    );
  }
}

class _RowTile extends StatelessWidget {
  const _RowTile({required this.left, required this.right});
  final String left;
  final String right;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: AppColors.divider)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              left,
              style: const TextStyle(color: AppColors.textSecondary),
            ),
          ),
          const SizedBox(width: 10),
          Text(
            right,
            style: const TextStyle(
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
          ),
        ],
      ),
    );
  }
}

class _SkuTile extends StatefulWidget {
  const _SkuTile({
    required this.code,
    required this.price,
    required this.attrs,
  });
  final String code;
  final int price;
  final List<String> attrs;

  @override
  State<_SkuTile> createState() => _SkuTileState();
}

class _SkuTileState extends State<_SkuTile> {
  bool _open = false;

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: AppColors.greyBackground,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.divider),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: () => setState(() => _open = !_open),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              children: [
                Row(
                  children: [
                    // Code
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Code', style: _labelStyle),
                          const SizedBox(height: 2),
                          Text(
                            widget.code,
                            style: const TextStyle(
                              fontWeight: FontWeight.w700,
                              color: AppColors.textPrimary,
                            ),
                          ),
                        ],
                      ),
                    ),
                    // Price
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text('Price', style: _labelStyle),
                        const SizedBox(height: 2),
                        Text(
                          _formatRp(widget.price),
                          style: const TextStyle(
                            fontWeight: FontWeight.w800,
                            color: AppColors.textPrimary,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(width: 8),
                    AnimatedRotation(
                      turns: _open ? 0.5 : 0.0,
                      duration: const Duration(milliseconds: 160),
                      child: const Icon(
                        Icons.expand_more_rounded,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
                AnimatedCrossFade(
                  firstChild: const SizedBox.shrink(),
                  secondChild: Padding(
                    padding: const EdgeInsets.only(top: 12),
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: widget.attrs
                            .map((t) => _ChipSoft(label: t))
                            .toList(),
                      ),
                    ),
                  ),
                  crossFadeState: _open
                      ? CrossFadeState.showSecond
                      : CrossFadeState.showFirst,
                  duration: const Duration(milliseconds: 180),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  TextStyle get _labelStyle => const TextStyle(
    fontSize: 12,
    color: AppColors.textSecondary,
    fontWeight: FontWeight.w600,
  );
}

class _ChipBadge extends StatelessWidget {
  const _ChipBadge({
    required this.label,
    required this.color,
    required this.bg,
  });
  final String label;
  final Color color;
  final Color bg;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: TextStyle(color: color, fontWeight: FontWeight.w700),
      ),
    );
  }
}

class _ChipSoft extends StatelessWidget {
  const _ChipSoft({required this.label});
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.greyBackground,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.divider),
      ),
      child: Text(
        label,
        style: const TextStyle(
          color: AppColors.textPrimary,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class _ImageGalleryBox extends StatelessWidget {
  const _ImageGalleryBox({required this.images});
  final List<ProductImage> images;

  @override
  Widget build(BuildContext context) {
    debugPrint("[Gallery] count=${images.length}");
    for (var i = 0; i < images.length; i++) {
      debugPrint(
        "[Gallery] [$i] pos=${images[i].position} url=${images[i].imagePath}",
      );
    }

    if (images.isEmpty) return _emptyBox();

    final w = MediaQuery.of(context).size.width;
    const spacing = 8.0;

    // 1 gambar
    if (images.length == 1) {
      return _frame(
        child: AspectRatio(
          aspectRatio: 16 / 9,
          child: _net(images[0].imagePath),
        ),
      );
    }

    // 2 gambar
    if (images.length == 2) {
      const itemH = 150.0;
      return Row(
        children: [
          Expanded(
            child: _frame(
              child: SizedBox(height: itemH, child: _net(images[0].imagePath)),
            ),
          ),
          const SizedBox(width: spacing),
          Expanded(
            child: _frame(
              child: SizedBox(height: itemH, child: _net(images[1].imagePath)),
            ),
          ),
        ],
      );
    }

    // > 2 → grid 3 kolom
    final itemW = (w - 16 * 2 - spacing * 2) / 3;
    const itemH = 100.0;
    return Wrap(
      spacing: spacing,
      runSpacing: spacing,
      children: images
          .map(
            (e) => _frame(
              radius: 12,
              child: SizedBox(
                width: itemW,
                height: itemH,
                child: _net(e.imagePath),
              ),
            ),
          )
          .toList(),
    );
  }

  Widget _frame({required Widget child, double radius = 16}) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(color: AppColors.divider),
        boxShadow: const [
          BoxShadow(
            color: Color(0x11000000),
            blurRadius: 10,
            offset: Offset(0, 6),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: child,
    );
  }

  Widget _net(String url) {
    return Image.network(
      url,
      fit: BoxFit.cover,
      errorBuilder: (_, __, ___) => const Center(
        child: Icon(Icons.broken_image_rounded, color: AppColors.disabledFg),
      ),
      loadingBuilder: (c, child, p) => p == null
          ? child
          : const Center(
              child: SizedBox(
                height: 22,
                width: 22,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ),
    );
  }

  Widget _emptyBox() => Container(
    height: 180,
    decoration: BoxDecoration(
      color: AppColors.greyBackground,
      borderRadius: BorderRadius.circular(16),
      border: Border.all(color: AppColors.divider),
    ),
    child: const Center(
      child: Icon(
        Icons.image_not_supported_rounded,
        size: 40,
        color: AppColors.disabledFg,
      ),
    ),
  );
}
