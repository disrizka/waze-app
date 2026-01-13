// lib/screens/stock/widgets/stock_opname_product_sheet.dart
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import 'package:wa_blast/constants/app_colors.dart';
import 'package:wa_blast/models/product_model.dart';
import 'package:wa_blast/providers/product_provider.dart';

/// ==========================================================
/// RESULT OBJECT (yang kamu butuhkan di form Stock Opname)
/// ==========================================================
class StockOpnamePickedSku {
  final String productId;
  final String productSkuId;

  final String productName;
  final String skuCode;

  final String? thumbUrl;
  final int? stockQty; // kalau ada dari sku
  final Map<String, String> selectedAttributes;

  const StockOpnamePickedSku({
    required this.productId,
    required this.productSkuId,
    required this.productName,
    required this.skuCode,
    this.thumbUrl,
    this.stockQty,
    this.selectedAttributes = const {},
  });
}

/// ==========================================================
/// OPEN SHEET
/// ==========================================================
/// - optional: kalau kamu sudah punya storeId (idStoreLocation) dari screen stock opname,
///   kirim supaya product paging langsung pakai store itu.
Future<StockOpnamePickedSku?> openStockOpnameProductSheet(
  BuildContext context, {
  String? idStoreLocation,
}) async {
  return showModalBottomSheet<StockOpnamePickedSku>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: Colors.white,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
    ),
    builder: (_) => _StockOpnameProductSheet(idStoreLocation: idStoreLocation),
  );
}

/// ==========================================================
/// SHEET (GRID PRODUCT)
/// ==========================================================
class _StockOpnameProductSheet extends StatefulWidget {
  final String? idStoreLocation;
  const _StockOpnameProductSheet({this.idStoreLocation});

  @override
  State<_StockOpnameProductSheet> createState() =>
      _StockOpnameProductSheetState();
}

class _StockOpnameProductSheetState extends State<_StockOpnameProductSheet> {
  final _searchC = TextEditingController();
  final _scrollC = ScrollController();

  Timer? _debounce;
  bool _loadMoreArmed = false;
  bool _kicked = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _kickOnOpen());
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchC.dispose();
    _scrollC.dispose();
    super.dispose();
  }

  Future<void> _kickOnOpen() async {
    if (_kicked || !mounted) return;
    _kicked = true;

    final prov = context.read<ProductProvider>();

    // init infinite paging
    prov.initInfinitePaging(context, initialSearch: '');

    // kalau caller sudah kirim store id, sinkronkan ke paging store
    if ((widget.idStoreLocation ?? '').trim().isNotEmpty) {
      try {
        await prov.setInfiniteStoreAndRefresh(context, widget.idStoreLocation!);
      } catch (_) {}
    } else {
      // fallback: pakai default store kalau project kamu pakai pattern ini
      try {
        await prov
            .ensureDefaultStoreLocation(context)
            .timeout(const Duration(seconds: 6));
      } catch (_) {}
      try {
        await prov.refreshInfinite(context);
      } catch (_) {}
    }

    // kick first page
    prov.pagingController?.fetchNextPage();

    // retry ringan kalau kosong
    Future.delayed(const Duration(milliseconds: 300), () {
      if (!mounted) return;
      if (prov.products.isEmpty) {
        prov.pagingController?.fetchNextPage();
      }
    });

    if (mounted) setState(() {});
  }

  Future<void> _manualRetry() async {
    final prov = context.read<ProductProvider>();
    prov.initInfinitePaging(context, initialSearch: _searchC.text.trim());
    if ((widget.idStoreLocation ?? '').trim().isNotEmpty) {
      try {
        await prov.setInfiniteStoreAndRefresh(context, widget.idStoreLocation!);
      } catch (_) {}
    } else {
      try {
        await prov
            .ensureDefaultStoreLocation(context)
            .timeout(const Duration(seconds: 6));
      } catch (_) {}
      try {
        await prov.refreshInfinite(context);
      } catch (_) {}
    }
    prov.pagingController?.fetchNextPage();
    if (mounted) setState(() {});
  }

  void _debouncedSearch(String raw) {
    final q = raw.trim();
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 250), () async {
      final prov = context.read<ProductProvider>();
      await prov.setInfiniteSearch(context, q);
      await prov.refreshInfinite(context);
      if (mounted) setState(() {});
    });
  }

  void _armLoadMore() {
    if (_loadMoreArmed) return;
    _loadMoreArmed = true;
    Future.delayed(const Duration(milliseconds: 220), () {
      _loadMoreArmed = false;
    });
  }

  Future<void> _chooseProduct(Product p) async {
    // kalau single SKU + tanpa attributes → langsung pilih SKU itu
    if (p.productSkus.length == 1) {
      final sku = p.productSkus.first;
      final hasAttrs = sku.attributes.isNotEmpty;
      if (!hasAttrs) {
        Navigator.pop(
          context,
          StockOpnamePickedSku(
            productId: p.idProduct,
            productSkuId: sku.idProductSku,
            productName: p.name,
            skuCode: sku.code,
            thumbUrl: (p.primaryImageUrl?.isNotEmpty == true)
                ? p.primaryImageUrl
                : (p.primaryImageUrl ?? ''),
            stockQty: _safeSkuStock(sku),
            selectedAttributes: const {},
          ),
        );
        return;
      }
    }

    final picked = await showModalBottomSheet<StockOpnamePickedSku>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (_) => _StockOpnameVariantSkuSheet(product: p),
    );

    if (!mounted) return;
    if (picked != null) Navigator.pop(context, picked);
  }

  @override
  Widget build(BuildContext context) {
    final prov = context.watch<ProductProvider>();
    final controller = prov.pagingController;

    if (controller == null) {
      return SafeArea(
        minimum: const EdgeInsets.fromLTRB(16, 12, 16, 16),
        child: SizedBox(
          height: 240,
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const CircularProgressIndicator(),
                const SizedBox(height: 10),
                TextButton.icon(
                  onPressed: _manualRetry,
                  icon: const Icon(Icons.refresh),
                  label: const Text('Retry'),
                ),
              ],
            ),
          ),
        ),
      );
    }

    final list = prov.products;

    final pm = prov.pageProducts;
    final bool isAtEnd = (pm?.currentPage != null && pm?.totalPages != null)
        ? (pm!.currentPage! >= pm.totalPages!)
        : prov.reachedEnd;

    return SafeArea(
      minimum: const EdgeInsets.fromLTRB(16, 12, 16, 16),
      child: SizedBox(
        height: MediaQuery.of(context).size.height * 0.9,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const _SheetHeader(
              title: 'Select Product',
              caption: 'Pick a product, then choose its SKU / variant.',
            ),

            // SEARCH
            Material(
              elevation: 1,
              color: Colors.white,
              borderRadius: BorderRadius.circular(10),
              child: TextField(
                controller: _searchC,
                textInputAction: TextInputAction.search,
                onSubmitted: (_) async {
                  await prov.setInfiniteSearch(context, _searchC.text.trim());
                  await prov.refreshInfinite(context);
                  if (mounted) setState(() {});
                },
                onChanged: (t) {
                  setState(() {});
                  _debouncedSearch(t);
                },
                decoration: InputDecoration(
                  hintText: 'Search product / SKU',
                  prefixIcon: const Icon(Icons.search_rounded),
                  suffixIcon: (_searchC.text.trim().isEmpty)
                      ? null
                      : IconButton(
                          onPressed: () async {
                            _searchC.clear();
                            await prov.setInfiniteSearch(context, '');
                            await prov.refreshInfinite(context);
                            if (mounted) setState(() {});
                          },
                          icon: const Icon(Icons.close_rounded),
                        ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: const BorderSide(color: AppColors.divider),
                  ),
                  isDense: true,
                ),
              ),
            ),
            const SizedBox(height: 8),

            // GRID
            Expanded(
              child: (list.isEmpty)
                  ? RefreshIndicator(
                      onRefresh: _manualRetry,
                      child: ListView(
                        children: const [
                          SizedBox(height: 80),
                          Center(child: Text('No products found')),
                          SizedBox(height: 400),
                        ],
                      ),
                    )
                  : NotificationListener<ScrollNotification>(
                      onNotification: (n) {
                        if (n is ScrollUpdateNotification) {
                          final max = _scrollC.position.maxScrollExtent;
                          final cur = _scrollC.position.pixels;
                          if (!isAtEnd && max > 0 && cur / max > 0.80) {
                            if (!_loadMoreArmed) {
                              _armLoadMore();
                              controller.fetchNextPage();
                            }
                          }
                        }
                        return false;
                      },
                      child: GridView.builder(
                        controller: _scrollC,
                        padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
                        gridDelegate:
                            const SliverGridDelegateWithFixedCrossAxisCount(
                              crossAxisCount: 2,
                              crossAxisSpacing: 12,
                              mainAxisSpacing: 12,
                              childAspectRatio: 0.58,
                            ),
                        itemCount: list.length + (isAtEnd ? 0 : 1),
                        itemBuilder: (_, i) {
                          if (i >= list.length) {
                            return const Center(
                              child: Padding(
                                padding: EdgeInsets.all(8),
                                child: CircularProgressIndicator(),
                              ),
                            );
                          }
                          final p = list[i];
                          return _StockProductCard(
                            product: p,
                            onChoose: () => _chooseProduct(p),
                          );
                        },
                      ),
                    ),
            ),

            // FOOTER CTA
            SafeArea(
              top: false,
              minimum: const EdgeInsets.only(top: 8),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
                child: SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: FilledButton.icon(
                    onPressed: () =>
                        Navigator.pop<StockOpnamePickedSku>(context, null),
                    icon: const Icon(Icons.close_rounded, size: 20),
                    label: const Text('Close'),
                    style: FilledButton.styleFrom(
                      backgroundColor: const Color(0xFFF3F4F6),
                      foregroundColor: const Color(0xFF111827),
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                      textStyle: const TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 14,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// ==========================================================
/// PRODUCT CARD (GRID)
/// ==========================================================
class _StockProductCard extends StatelessWidget {
  final Product product;
  final VoidCallback onChoose;

  const _StockProductCard({required this.product, required this.onChoose});

  int _minPriceOf(Product p) {
    if (p.productPrices.isNotEmpty) {
      final prices = p.productPrices.map((x) => x.price).toList()..sort();
      return prices.first;
    }
    if (p.productSkus.isNotEmpty) {
      final prices = p.productSkus.map((s) => s.price).toList()..sort();
      return prices.first;
    }
    return p.basePrice ?? 0;
  }

  @override
  Widget build(BuildContext context) {
    final name = product.name;
    final minPrice = _minPriceOf(product);
    final thumb = product.primaryImageUrl;

    final money = NumberFormat.decimalPattern('id_ID');

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // IMAGE
          AspectRatio(
            aspectRatio: 1.25,
            child: ClipRRect(
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(14),
              ),
              child: SafeNetImage(
                url: thumb,
                fit: BoxFit.cover,
                crashIcon: Container(
                  color: const Color(0xFFF3F4F6),
                  child: const Center(
                    child: Icon(Icons.image_outlined, size: 30),
                  ),
                ),
              ),
            ),
          ),

          // INFO
          Expanded(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(10, 6, 10, 8), // lebih tipis
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF0F172A),
                      fontSize: 14,
                      height: 1.15, // sedikit rapat
                    ),
                  ),
                  const SizedBox(height: 5), // sebelumnya 6

                  Row(
                    children: [
                      const Icon(
                        Icons.layers_outlined,
                        size: 14,
                        color: Color(0xFF64748B),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        '${product.productSkus.length} SKU',
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFF334155),
                        ),
                      ),
                      const Spacer(),
                      if (product.totalStockQty != null) ...[
                        const Icon(
                          Icons.inventory_2_outlined,
                          size: 14,
                          color: Color(0xFF64748B),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          '${product.totalStockQty}',
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w900,
                            color: Color(0xFF334155),
                          ),
                        ),
                      ],
                    ],
                  ),

                  const Spacer(),

                  SizedBox(
                    width: double.infinity,
                    height: 34,
                    child: ElevatedButton(
                      onPressed: onChoose,
                      style: ElevatedButton.styleFrom(
                        elevation: 0,
                        backgroundColor: const Color(0xFF4069E6),
                        foregroundColor: Colors.white,
                        padding: EdgeInsets.zero,
                        minimumSize: const Size(0, 34), // ✅ paksa min height
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        visualDensity: VisualDensity.compact,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      child: const Text(
                        'Choose',
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 13,
                          height: 1.0,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// ==========================================================
/// VARIANT/SKU SHEET (Choice Chip Attributes)
/// ==========================================================
class _StockOpnameVariantSkuSheet extends StatefulWidget {
  final Product product;
  const _StockOpnameVariantSkuSheet({required this.product});

  @override
  State<_StockOpnameVariantSkuSheet> createState() =>
      _StockOpnameVariantSkuSheetState();
}

class _StockOpnameVariantSkuSheetState
    extends State<_StockOpnameVariantSkuSheet> {
  final Map<String, String> _selected = {}; // attr -> value

  Product get _p => widget.product;

  @override
  void initState() {
    super.initState();

    final attrsMap = _extractAttributes(_p.productSkus);

    // auto-select jika tiap attribute cuma 1 value
    for (final e in attrsMap.entries) {
      if (e.value.length == 1) _selected[e.key] = e.value.first;
    }
  }

  @override
  Widget build(BuildContext context) {
    final attrsMap = _extractAttributes(_p.productSkus);

    ProductSku? matched;
    for (final s in _p.productSkus) {
      if (_isSkuMatch(s, _selected, requiredCount: attrsMap.length)) {
        matched = s;
        break;
      }
    }

    final money = NumberFormat.decimalPattern('id_ID');
    final int unitPrice = matched?.price ?? _p.basePrice ?? 0;

    final int? stock = (matched != null)
        ? _safeSkuStock(matched)
        : _p.totalStockQty;

    final bool canConfirm = matched != null;

    return Container(
      color: Colors.white,
      child: SafeArea(
        minimum: const EdgeInsets.fromLTRB(16, 12, 16, 0),
        child: Column(
          children: [
            _SheetHeader(title: 'Choose SKU', caption: _p.name),
            const SizedBox(height: 6),

            // HERO
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.divider),
                boxShadow: const [
                  BoxShadow(
                    color: Color(0x0F000000),
                    blurRadius: 16,
                    offset: Offset(0, 6),
                  ),
                ],
              ),
              child: Row(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: SafeNetImage(
                      url: _p.primaryImageUrl,
                      width: 72,
                      height: 72,
                      fit: BoxFit.cover,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _p.name,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontWeight: FontWeight.w900),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'Rp ${money.format(unitPrice)}',
                          style: const TextStyle(
                            fontWeight: FontWeight.w900,
                            fontSize: 16,
                          ),
                        ),
                        if (matched != null) ...[
                          const SizedBox(height: 4),
                          Text(
                            matched.code,
                            style: const TextStyle(
                              color: Color(0xFF64748B),
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                        if (stock != null) ...[
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              const Icon(
                                Icons.inventory_2_outlined,
                                size: 16,
                                color: Color(0xFF64748B),
                              ),
                              const SizedBox(width: 6),
                              Text(
                                'Stock: $stock',
                                style: const TextStyle(
                                  color: Color(0xFF475569),
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 12),

            // ATTRIBUTES
            Expanded(
              child: ListView(
                children: attrsMap.entries.map((e) {
                  final attrName = e.key;
                  final values = e.value.toList()..sort();
                  final selectedVal = _selected[attrName];

                  return Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: AppColors.divider),
                        boxShadow: const [
                          BoxShadow(
                            color: Color(0x0F000000),
                            blurRadius: 16,
                            offset: Offset(0, 6),
                          ),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            attrName,
                            style: const TextStyle(fontWeight: FontWeight.w900),
                          ),
                          const SizedBox(height: 10),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: values.map((val) {
                              final isSel = selectedVal == val;
                              final enabled = _isValueEnabled(
                                attrName,
                                val,
                                _selected,
                                _p.productSkus,
                              );

                              return ChoiceChip(
                                label: Text(val),
                                selected: isSel,
                                onSelected: enabled
                                    ? (_) => setState(
                                        () => _selected[attrName] = val,
                                      )
                                    : null,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(999),
                                ),
                                selectedColor: AppColors.primary.withOpacity(
                                  .12,
                                ),
                                labelStyle: TextStyle(
                                  fontWeight: isSel
                                      ? FontWeight.w800
                                      : FontWeight.w600,
                                  color: !enabled
                                      ? AppColors.disabledFg
                                      : (isSel
                                            ? AppColors.primary
                                            : AppColors.textPrimary),
                                ),
                              );
                            }).toList(),
                          ),
                        ],
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),

            // CTA
            Container(
              decoration: const BoxDecoration(
                color: Colors.white,
                border: Border(top: BorderSide(color: AppColors.divider)),
                boxShadow: [
                  BoxShadow(
                    color: Color(0x14000000),
                    blurRadius: 12,
                    offset: Offset(0, -2),
                  ),
                ],
              ),
              child: SafeArea(
                top: false,
                minimum: const EdgeInsets.fromLTRB(16, 10, 16, 12),
                child: SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: !canConfirm
                        ? null
                        : () {
                            final sku = matched!;
                            Navigator.pop<StockOpnamePickedSku>(
                              context,
                              StockOpnamePickedSku(
                                productId: _p.idProduct,
                                productSkuId: sku.idProductSku,
                                productName: _p.name,
                                skuCode: sku.code,
                                thumbUrl: _p.primaryImageUrl,
                                stockQty: _safeSkuStock(sku),
                                selectedAttributes: Map<String, String>.from(
                                  _selected,
                                ),
                              ),
                            );
                          },
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                    child: Text(
                      canConfirm ? 'Select SKU' : 'Select all variants',
                      style: const TextStyle(fontWeight: FontWeight.w800),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// --- ATTR EXTRACTION ---
  Map<String, Set<String>> _extractAttributes(List<ProductSku> skus) {
    final result = <String, Set<String>>{};

    for (final sku in skus) {
      final attrs = _attributesOfSku(sku);
      for (final a in attrs) {
        (result[a.name] ??= <String>{}).add(a.value);
      }
    }
    return result;
  }

  List<_AttrPair> _attributesOfSku(ProductSku sku) {
    // kalau tidak punya attributes, jadikan SKU Code sebagai “attribute”
    if (sku.attributes.isEmpty) {
      return [_AttrPair('SKU', sku.code)];
    }
    return sku.attributes.map((a) => _AttrPair(a.name, a.value)).toList();
  }

  bool _isSkuMatch(
    ProductSku sku,
    Map<String, String> sel, {
    required int requiredCount,
  }) {
    final attrs = _attributesOfSku(sku);
    for (final entry in sel.entries) {
      final ok = attrs.any(
        (a) =>
            a.name.toLowerCase() == entry.key.toLowerCase() &&
            a.value == entry.value,
      );
      if (!ok) return false;
    }
    return sel.length == requiredCount;
  }

  bool _isValueEnabled(
    String attr,
    String val,
    Map<String, String> currentSel,
    List<ProductSku> allSkus,
  ) {
    final trial = Map<String, String>.from(currentSel)..[attr] = val;

    return allSkus.any((sku) {
      final attrs = _attributesOfSku(sku);
      for (final e in trial.entries) {
        final ok = attrs.any(
          (a) =>
              a.name.toLowerCase() == e.key.toLowerCase() && a.value == e.value,
        );
        if (!ok) return false;
      }
      return true;
    });
  }
}

/// ==========================================================
/// SMALL UI WIDGETS
/// ==========================================================
class _SheetHeader extends StatelessWidget {
  final String title;
  final String? caption;
  const _SheetHeader({required this.title, this.caption});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Column(
        children: [
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: const Color(0xFFE5E7EB),
              borderRadius: BorderRadius.circular(999),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontWeight: FontWeight.w900,
                        fontSize: 16,
                        color: Colors.black87,
                      ),
                    ),
                    if (caption != null) ...[
                      const SizedBox(height: 4),
                      Text(
                        caption!,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontSize: 12,
                          color: Colors.black54,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              IconButton(
                onPressed: () => Navigator.pop(context),
                icon: const Icon(Icons.close_rounded, color: Colors.black54),
                tooltip: 'Close',
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Image network yang aman (mirip gaya kamu)
class SafeNetImage extends StatelessWidget {
  final String? url;
  final double? width;
  final double? height;
  final BoxFit fit;
  final Widget? crashIcon;

  const SafeNetImage({
    super.key,
    required this.url,
    this.width,
    this.height,
    this.fit = BoxFit.cover,
    this.crashIcon,
  });

  @override
  Widget build(BuildContext context) {
    final fallback = Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: const Color(0xFFF3F4F6),
        borderRadius: BorderRadius.circular(12),
      ),
      child: const Center(
        child: Icon(Icons.broken_image_rounded, color: Color(0xFFA3A3A3)),
      ),
    );

    if (url == null || url!.isEmpty) return fallback;

    return Image.network(
      url!,
      width: width,
      height: height,
      fit: fit,
      loadingBuilder: (context, child, progress) {
        if (progress == null) return child;
        return SizedBox(width: width, height: height);
      },
      errorBuilder: (_, __, ___) => crashIcon ?? fallback,
    );
  }
}

/// Simple pair helper
class _AttrPair {
  final String name;
  final String value;
  const _AttrPair(this.name, this.value);
}

/// Aman ambil stok SKU (kalau field beda-beda, ini gak crash)
int? _safeSkuStock(ProductSku sku) {
  // beberapa project pakai sku.stockQty, ada yg sku.qty, dll.
  // kita coba aman: kalau field tidak ada, return null.
  try {
    // ignore: unnecessary_cast
    final v = (sku.stockQty as dynamic);
    if (v == null) return null;
    if (v is int) return v;
    return int.tryParse(v.toString());
  } catch (_) {
    return null;
  }
}
