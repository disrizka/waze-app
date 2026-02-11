import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import 'package:wa_blast/constants/app_colors.dart';
import 'package:wa_blast/l10n/app_localizations.dart';
import 'package:wa_blast/models/product_models/product_model.dart';
import 'package:wa_blast/providers/product_provider.dart';
import 'package:wa_blast/screens/products/create_edit_screen/product_form_screen.dart';
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
  static const routeName = '/product/list/detail';
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
    final loc = AppLocalizations.of(context)!;

    return Scaffold(
      backgroundColor: AppColors.white,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: AppColors.white,
        foregroundColor: AppColors.textPrimary,
        title: Text(
          prov.productDetail?.name ?? loc.productDetailTitle,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontWeight: FontWeight.w700),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded),
          onPressed: () => Navigator.pop(context),
          tooltip: loc.productDetailBackTooltip,
        ),
      ),
      body: FutureBuilder(
        future: _future,
        builder: (context, snap) {
          final p = prov.productDetail;
          final imgs = [...(p?.productImages ?? const <ProductImage>[])]
            ..sort((a, b) => a.position.compareTo(b.position));

          // gabung "Kota, Provinsi" jika tersedia
          final storeRegion = [
            p?.storeLocation?.city?.name,
            p?.storeLocation?.city?.province?.name,
          ].where((e) => (e ?? '').isNotEmpty).join(', ');
          final storeRegionOrNull = storeRegion.isEmpty ? null : storeRegion;

          return CustomScrollView(
            slivers: [
              // Gallery box
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                  child: _ImageGalleryBox(images: imgs),
                ),
              ),

              // Info card (nama, brand, category, harga, store location)
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
                  child: _InfoCard(
                    name: p?.name ?? '-',
                    isHide: p?.isHide ?? false,
                    brand: p?.productBrand?.name,
                    category: p?.productCategory?.name,
                    headlinePrice: _headlinePriceOf(p),
                    storeLocationName: p?.storeLocation?.name,
                    storeRegion: storeRegionOrNull,
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
                      title: loc.productDetailDescriptionSectionTitle,
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
                      title: loc.productDetailPricesWholesaleTitle,
                      child: Column(
                        children: p!.productPrices
                            .map(
                              (e) => _RowTile(
                                left: loc.productDetailPriceRowMin(e.minQty),
                                right: _formatRp(e.price),
                              ),
                            )
                            .toList(),
                      ),
                    ),
                  ),
                ),

              // SKUs (tunggal → simple row; banyak → simple list)
              if ((p?.productSkus ?? []).isNotEmpty)
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 6,
                    ),
                    child: _SectionCard(
                      title: loc.productDetailSkuSectionTitle,
                      child: _SkuSection(skus: p!.productSkus),
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
          final loc = AppLocalizations.of(context)!;
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
                                message: loc.productDetailDeleteSuccess,
                              );
                              Navigator.pop(context);
                            } else {
                              AppSnackbar.show(
                                context,
                                type: AppSnackType.error,
                                message:
                                    prov.lastError ??
                                    loc.productDetailDeleteFailed,
                              );
                            }
                          },
                    icon: const Icon(Icons.delete_outline_rounded),
                    label: Text(loc.productDetailDeleteButton),
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
                        : () async {
                            final id = prov.productDetail!.idProduct;

                            final ok = await Navigator.push<bool>(
                              context,
                              MaterialPageRoute(
                                builder: (_) =>
                                    ProductFormScreen(idProduct: id), // EDIT
                              ),
                            );

                            if (!mounted) return;

                            if (ok == true) {
                              // refresh detail biar tampilannya update
                              await prov.fetchProductDetail(
                                context,
                                id,
                                preferCache: false,
                              );

                              AppSnackbar.show(
                                context,
                                type: AppSnackType.success,
                                message: 'Product updated successfully.',
                              );
                            }
                          },

                    icon: const Icon(Icons.edit_rounded),
                    label: Text(loc.productDetailEditButton),
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
    if (p.productSkus.isNotEmpty) {
      final sorted = [...p.productSkus]
        ..sort((a, b) => a.price.compareTo(b.price));
      return sorted.first.price;
    }
    return null;
  }
}

/// =========================
/// UI Pieces
/// =========================

class _InfoCard extends StatelessWidget {
  const _InfoCard({
    required this.name,
    required this.isHide,
    required this.brand,
    required this.category,
    required this.headlinePrice,
    this.storeLocationName,
    this.storeRegion,
  });

  final String name;
  final bool isHide;
  final String? brand;
  final String? category;
  final int? headlinePrice;

  /// dari response `storeLocation.name`
  final String? storeLocationName;

  /// "Kota, Provinsi" (opsional)
  final String? storeRegion;

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context)!;

    return _Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              if (isHide)
                _ChipBadge(
                  label: loc.productDetailHiddenLabel,
                  color: AppColors.danger,
                  bg: const Color(0xFFFFF1F2),
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

          // Store Location section
          if ((storeLocationName ?? '').isNotEmpty) ...[
            const SizedBox(height: 12),
            const Divider(height: 1, color: AppColors.divider),
            const SizedBox(height: 10),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(
                  Icons.store_mall_directory_rounded,
                  size: 18,
                  color: AppColors.textSecondary,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        storeLocationName!,
                        style: const TextStyle(
                          fontWeight: FontWeight.w800,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      if ((storeRegion ?? '').isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: 2),
                          child: Text(
                            storeRegion!,
                            style: const TextStyle(
                              color: AppColors.textSecondary,
                              fontSize: 12,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ],
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

/// =========================
/// SKU Section (baru)
/// =========================
class _SkuSection extends StatelessWidget {
  const _SkuSection({required this.skus});
  final List<ProductSku> skus;

  void _openStock(BuildContext context, ProductSku s) {
    Navigator.pushNamed(
      context,
      '/product/sku/inventory',
      arguments: {
        'idProductSKU': s.idProductSku,
        'skuCode': s.code,
        'initialPrice': s.price,
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    if (skus.length == 1) {
      final s = skus.first;
      return _SingleSkuRow(
        code: s.code,
        price: s.price,
        attrs: s.attributes.map((a) => '${a.name}: ${a.value}').toList(),
        onOpenStock: () => _openStock(context, s),
      );
    }

    // Banyak SKU → list simpel (tanpa border/kartu), hanya divider tipis antar item
    return Column(
      children: [
        for (int i = 0; i < skus.length; i++) ...[
          _MultiSkuRow(
            code: skus[i].code,
            price: skus[i].price,
            attrs: skus[i].attributes
                .map((a) => '${a.name}: ${a.value}')
                .toList(),
            onOpenStock: () => _openStock(context, skus[i]),
          ),
          if (i != skus.length - 1)
            const Divider(height: 14, color: AppColors.divider),
        ],
      ],
    );
  }
}

class _SingleSkuRow extends StatelessWidget {
  const _SingleSkuRow({
    required this.code,
    required this.price,
    required this.attrs,
    required this.onOpenStock,
  });

  final String code;
  final int price;
  final List<String> attrs;
  final VoidCallback onOpenStock;

  @override
  Widget build(BuildContext context) {
    final isNarrow = MediaQuery.of(context).size.width < 360;
    final loc = AppLocalizations.of(context)!;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Baris utama: Code + Harga + tombol
        Row(
          children: [
            // Kode + Harga
            Expanded(
              child: Wrap(
                spacing: 10,
                runSpacing: 4,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  Text(
                    code,
                    style: const TextStyle(
                      fontWeight: FontWeight.w800,
                      color: AppColors.textPrimary,
                      fontSize: 16,
                    ),
                  ),
                  Text(
                    '• ${_formatRp(price)}',
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),

            // Tombol Open stock
            // SizedBox(
            //   height: 36,
            //   child: isNarrow
            //       ? Tooltip(
            //           message: loc.productDetailOpenStock,
            //           child: OutlinedButton(
            //             onPressed: onOpenStock,
            //             style: OutlinedButton.styleFrom(
            //               foregroundColor: AppColors.primary,
            //               side: const BorderSide(color: AppColors.primary),
            //               padding: const EdgeInsets.symmetric(horizontal: 10),
            //               shape: RoundedRectangleBorder(
            //                 borderRadius: BorderRadius.circular(10),
            //               ),
            //               visualDensity: VisualDensity.compact,
            //             ),
            //             child: const Icon(Icons.inventory_2_outlined, size: 18),
            //           ),
            //         )
            //       : OutlinedButton.icon(
            //           onPressed: onOpenStock,
            //           icon: const Icon(Icons.inventory_2_outlined, size: 18),
            //           label: Text(loc.productDetailOpenStock),
            //           style: OutlinedButton.styleFrom(
            //             foregroundColor: AppColors.primary,
            //             side: const BorderSide(color: AppColors.primary),
            //             padding: const EdgeInsets.symmetric(horizontal: 12),
            //             shape: RoundedRectangleBorder(
            //               borderRadius: BorderRadius.circular(10),
            //             ),
            //             visualDensity: VisualDensity.compact,
            //           ),
            //         ),
            // ),
          ],
        ),

        // Atribut (opsional)
        if (attrs.isNotEmpty) ...[
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: attrs.map((t) => _ChipSoft(label: t)).toList(),
          ),
        ],
      ],
    );
  }
}

class _MultiSkuRow extends StatelessWidget {
  const _MultiSkuRow({
    required this.code,
    required this.price,
    required this.attrs,
    required this.onOpenStock,
  });

  final String code;
  final int price;
  final List<String> attrs;
  final VoidCallback onOpenStock;

  @override
  Widget build(BuildContext context) {
    final isNarrow = MediaQuery.of(context).size.width < 360;
    final loc = AppLocalizations.of(context)!;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Column(
        children: [
          // Baris 1: Kode + Harga + tombol
          Row(
            children: [
              Expanded(
                child: Wrap(
                  spacing: 10,
                  runSpacing: 4,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    Text(
                      code,
                      style: const TextStyle(
                        fontWeight: FontWeight.w800,
                        color: AppColors.textPrimary,
                        fontSize: 15,
                      ),
                    ),
                    Text(
                      '• ${_formatRp(price)}',
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              // SizedBox(
              //   height: 32,
              //   child: isNarrow
              //       ? IconButton.filledTonal(
              //           tooltip: loc.productDetailOpenStock,
              //           onPressed: onOpenStock,
              //           icon: const Icon(
              //             Icons.inventory_2_outlined,
              //             size: 18,
              //             color: AppColors.primary,
              //           ),
              //           style: ButtonStyle(
              //             backgroundColor: WidgetStateProperty.all(
              //               AppColors.greyBackground,
              //             ),
              //           ),
              //         )
              //       : OutlinedButton.icon(
              //           onPressed: onOpenStock,
              //           icon: const Icon(Icons.inventory_2_outlined, size: 18),
              //           label: Text(loc.productDetailOpenStock),
              //           style: OutlinedButton.styleFrom(
              //             foregroundColor: AppColors.primary,
              //             side: const BorderSide(color: AppColors.primary),
              //             padding: const EdgeInsets.symmetric(horizontal: 10),
              //             shape: RoundedRectangleBorder(
              //               borderRadius: BorderRadius.circular(10),
              //             ),
              //             visualDensity: VisualDensity.compact,
              //           ),
              //         ),
              // ),
            ],
          ),

          // Baris 2: Atribut (opsional)
          if (attrs.isNotEmpty) ...[
            const SizedBox(height: 6),
            Align(
              alignment: Alignment.centerLeft,
              child: Wrap(
                spacing: 6,
                runSpacing: 6,
                children: attrs
                    .map(
                      (t) => Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.greyBackground,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: AppColors.divider),
                        ),
                        child: Text(
                          t,
                          style: const TextStyle(
                            fontSize: 12,
                            color: AppColors.textPrimary,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    )
                    .toList(),
              ),
            ),
          ],
        ],
      ),
    );
  }
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

/// =========================
/// Image Gallery + Fullscreen Viewer
/// =========================
class _ImageGalleryBox extends StatelessWidget {
  const _ImageGalleryBox({required this.images});
  final List<ProductImage> images;

  @override
  Widget build(BuildContext context) {
    if (images.isEmpty) return _emptyBox(context);

    final w = MediaQuery.of(context).size.width;
    const spacing = 8.0;

    // 1 gambar
    if (images.length == 1) {
      return _frame(
        child: AspectRatio(
          aspectRatio: 16 / 9,
          child: _zoomable(context, images[0].imagePath, tag: 'img_0'),
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
              child: SizedBox(
                height: itemH,
                child: _zoomable(context, images[0].imagePath, tag: 'img_0'),
              ),
            ),
          ),
          const SizedBox(width: spacing),
          Expanded(
            child: _frame(
              child: SizedBox(
                height: itemH,
                child: _zoomable(context, images[1].imagePath, tag: 'img_1'),
              ),
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
      children: [
        for (int i = 0; i < images.length; i++)
          _frame(
            radius: 12,
            child: SizedBox(
              width: itemW,
              height: itemH,
              child: _zoomable(context, images[i].imagePath, tag: 'img_$i'),
            ),
          ),
      ],
    );
  }

  // Zoomable thumbnail → fullscreen viewer
  Widget _zoomable(BuildContext context, String url, {required String tag}) {
    return GestureDetector(
      onTap: () => Navigator.of(context).push(
        PageRouteBuilder(
          opaque: true,
          barrierColor: Colors.black,
          pageBuilder: (_, __, ___) => _ImageViewerPage(url: url, tag: tag),
          transitionsBuilder: (_, a, __, child) =>
              FadeTransition(opacity: a, child: child),
        ),
      ),
      child: Hero(tag: tag, child: _net(url)),
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

  Widget _emptyBox(BuildContext context) => Container(
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

class _ImageViewerPage extends StatelessWidget {
  const _ImageViewerPage({required this.url, required this.tag});

  final String url;
  final String tag;

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context)!;

    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        bottom: false,
        child: Stack(
          children: [
            Center(
              child: Hero(
                tag: tag,
                child: InteractiveViewer(
                  minScale: 0.5,
                  maxScale: 4.0,
                  child: _networkImage(url),
                ),
              ),
            ),
            Positioned(
              top: 8,
              left: 8,
              child: IconButton(
                icon: const Icon(Icons.close_rounded, color: Colors.white),
                onPressed: () => Navigator.pop(context),
                tooltip: loc.productDetailImageViewerCloseTooltip,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _networkImage(String url) {
    return Image.network(
      url,
      fit: BoxFit.contain,
      errorBuilder: (_, __, ___) => const Icon(
        Icons.broken_image_rounded,
        color: Colors.white70,
        size: 64,
      ),
      loadingBuilder: (c, child, p) => p == null
          ? child
          : const SizedBox(
              height: 36,
              width: 36,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: Colors.white,
              ),
            ),
    );
  }
}
