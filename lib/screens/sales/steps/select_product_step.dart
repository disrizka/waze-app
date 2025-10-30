// lib/features/sales/steps/select_product_page.dart
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import 'package:wa_blast/constants/app_colors.dart';
import 'package:wa_blast/models/product_model.dart';
import 'package:wa_blast/providers/sales_provider.dart';
import 'package:wa_blast/providers/product_provider.dart' as catalog;

/// =======================================================
/// SELECT PRODUCT PAGE (GRID) — tanpa AppBar (menyatu wrapper)
/// + Variant via BOTTOM SHEET
/// + Quick Decrement di kartu
/// + Floating Cart Bar -> Edit Cart Sheet (per SKU)
/// =======================================================
class SelectProductPage extends StatefulWidget {
  const SelectProductPage({super.key});

  @override
  State<SelectProductPage> createState() => _SelectProductPageState();
}

class _SelectProductPageState extends State<SelectProductPage> {
  final _searchC = TextEditingController();
  String _q = '';

  @override
  void initState() {
    super.initState();
    _searchC.addListener(() {
      final t = _searchC.text.trim();
      if (t != _q) setState(() => _q = t);
    });

    // Pastikan katalog sudah terload
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final sp = context.read<SalesProvider>();
      if (!sp.loadingSkus && sp.skus.isEmpty) {
        await sp.loadCatalog(context);
        if (mounted) setState(() {});
      }
    });
  }

  @override
  void dispose() {
    _searchC.dispose();
    super.dispose();
  }

  // Group & filter produk, min price untuk label "from Rp ... "
  List<_SpGroup> _groupProducts(List<Product> products, String query) {
    final q = query.toLowerCase();

    final filtered = (q.isEmpty)
        ? products
        : products.where((p) {
            final nameHit = p.name.toLowerCase().contains(q);
            final skuHit = p.productSkus.any(
              (s) =>
                  s.code.toLowerCase().contains(q) ||
                  s.attributes.any(
                    (a) =>
                        a.name.toLowerCase().contains(q) ||
                        a.value.toLowerCase().contains(q),
                  ),
            );
            return nameHit || skuHit;
          }).toList();

    int _minPrice(Product p) {
      if (p.productSkus.isNotEmpty) {
        final prices = p.productSkus.map((s) => s.price).toList()..sort();
        return prices.first;
      }
      if (p.productPrices.isNotEmpty) {
        final prices = p.productPrices.map((x) => x.price).toList()..sort();
        return prices.first;
      }
      return 0;
    }

    final groups =
        filtered
            .map(
              (p) => _SpGroup(
                product: p,
                productId: p.idProduct,
                name: p.name,
                thumbUrl: p.primaryImageUrl,
                minPrice: _minPrice(p),
              ),
            )
            .toList()
          ..sort((a, b) => a.name.compareTo(b.name));

    return groups;
  }

  Future<void> _openVariantSheet(BuildContext context, _SpGroup g) async {
    final prov = context.read<SalesProvider>();
    final changed = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (_) => ChangeNotifierProvider.value(
        value: prov,
        child: _VariantAttributeSheet(group: g),
      ),
    );
    if (mounted && changed == true) setState(() {});
  }

  Future<void> _openEditCartSheet(
    BuildContext context, {
    String? filterProductId,
  }) async {
    final prov = context.read<SalesProvider>();
    final changed = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (_) => ChangeNotifierProvider.value(
        value: prov,
        child: _EditCartSheet(filterProductId: filterProductId),
      ),
    );
    if (mounted && changed == true) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final prov = context.watch<SalesProvider>();
    final productProv = context.watch<catalog.ProductProvider>();

    final groups = _groupProducts(productProv.products, _q);
    final selectedItems = prov.cartItems.length;
    final selectedQty = prov.cartItems.fold<int>(0, (s, it) => s + it.qty);

    // total harga (untuk cart bar)
    final money = NumberFormat.decimalPattern('id_ID');
    final totalPrice = prov.cartItems.fold<int>(
      0,
      (sum, it) => sum + (it.sku.price * it.qty),
    );

    return Stack(
      children: [
        // Konten utama
        Column(
          children: [
            // Search
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
              child: TextField(
                controller: _searchC,
                textInputAction: TextInputAction.search,
                decoration: InputDecoration(
                  hintText: 'Search product / SKU',
                  prefixIcon: const Icon(Icons.search_rounded),
                  suffixIcon: (_searchC.text.trim().isEmpty)
                      ? null
                      : IconButton(
                          onPressed: _searchC.clear,
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

            // GRID body
            Expanded(
              child: Builder(
                builder: (_) {
                  if (prov.loadingProducts && prov.products.isEmpty) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  if (prov.catalogError != null) {
                    return Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.error_outline,
                            color: AppColors.danger,
                            size: 32,
                          ),
                          const SizedBox(height: 8),
                          const Text(
                            'Failed to load products',
                            style: TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 16,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            prov.catalogError!,
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              color: AppColors.textSecondary,
                            ),
                          ),
                          const SizedBox(height: 12),
                          OutlinedButton(
                            onPressed: () => prov.loadCatalog(context),
                            child: const Text('Retry'),
                          ),
                        ],
                      ),
                    );
                  }

                  if (groups.isEmpty) {
                    return const Center(child: Text('No products found'));
                  }

                  return GridView.builder(
                    padding: const EdgeInsets.fromLTRB(
                      12,
                      4,
                      12,
                      120,
                    ), // beri ruang untuk cart bar
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 2,
                          crossAxisSpacing: 12,
                          mainAxisSpacing: 12,
                          childAspectRatio: 0.62,
                        ),
                    itemCount: groups.length,
                    itemBuilder: (_, i) {
                      final g = groups[i];

                      final selectedQtyForProduct = prov.cartItems
                          .where((it) => it.sku.productId == g.productId)
                          .fold<int>(0, (s, it) => s + it.qty);

                      return _SpCard(
                        group: g,
                        selectedQty: selectedQtyForProduct,
                        onChoose: () => _openVariantSheet(context, g),
                        onQuickMinus: selectedQtyForProduct == 0
                            ? null
                            : () {
                                // Kurangi 1 dari SKU manapun yg milik produk ini (prefer yang qty>0)
                                final item = prov.cartItems.firstWhere(
                                  (it) => it.sku.productId == g.productId,
                                  orElse: () => null as dynamic,
                                );
                                if (item != null) {
                                  prov.removeOne(item.sku);
                                  setState(() {});
                                }
                              },
                        onOpenEditForThisProduct: selectedQtyForProduct == 0
                            ? null
                            : () => _openEditCartSheet(
                                context,
                                filterProductId: g.productId,
                              ),
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),

        // Floating Cart Bar (menempel di bawah)
        Positioned(
          left: 0,
          right: 0,
          bottom: 0,
          child: SafeArea(
            top: false,
            minimum: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (selectedQty > 0)
                  _CartBar(
                    itemCount: selectedQty,
                    totalText: 'Rp ${money.format(totalPrice)}',
                    onTap: () => _openEditCartSheet(context),
                  ),
                const SizedBox(height: 10),
                // CTA "Check Order"
                SizedBox(
                  height: 50,
                  child: FilledButton(
                    onPressed: () => context.read<SalesProvider>().goTo(1),
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                      textStyle: const TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 17,
                        letterSpacing: .2,
                      ),
                    ),
                    child: Text(
                      selectedQty > 0
                          ? 'Check Order — ${money.format(totalPrice)}'
                          : 'Check Order',
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

/// ===============================
/// VARIANT ATTRIBUTE BOTTOM SHEET
/// ===============================
class _VariantAttributeSheet extends StatefulWidget {
  final _SpGroup group;
  const _VariantAttributeSheet({required this.group});

  @override
  State<_VariantAttributeSheet> createState() => _VariantAttributeSheetState();
}

class _VariantAttributeSheetState extends State<_VariantAttributeSheet> {
  final Map<String, String> _selected = {}; // name -> value
  int _qty = 1;
  late final Product _p;

  @override
  void initState() {
    super.initState();
    _p = widget.group.product;

    // Auto pilih jika atribut hanya 1 opsi
    final attrsMap = _extractAttributes(_p.productSkus);
    for (final e in attrsMap.entries) {
      if (e.value.length == 1) _selected[e.key] = e.value.first;
    }
  }

  @override
  Widget build(BuildContext context) {
    final prov = context.watch<SalesProvider>();
    final attrsMap = _extractAttributes(_p.productSkus);

    // cari SKU cocok
    ProductSku? matched;
    for (final s in _p.productSkus) {
      if (_isSkuMatch(s, _selected, requiredCount: attrsMap.length)) {
        matched = s;
        break;
      }
    }

    final price = matched?.price ?? _p.basePrice ?? 0;
    final money = NumberFormat.decimalPattern('id_ID');

    return Container(
      color: Colors.white,
      child: SafeArea(
        minimum: const EdgeInsets.fromLTRB(16, 12, 16, 0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // header kecil + tombol close
            Column(
              children: [
                const SizedBox(height: 6),
                Container(
                  width: 44,
                  height: 4,
                  decoration: BoxDecoration(
                    color: const Color(0xFFE5E7EB),
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    const Expanded(
                      child: Center(
                        child: Text(
                          'Choose Variants',
                          style: TextStyle(
                            fontWeight: FontWeight.w800,
                            fontSize: 16,
                          ),
                        ),
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.pop(context, false),
                      icon: const Icon(
                        Icons.close_rounded,
                        color: Color(0xFF6B7280),
                      ),
                      tooltip: 'Close',
                    ),
                  ],
                ),
                const SizedBox(height: 4),
              ],
            ),

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
                    child: (_p.primaryImageUrl?.isNotEmpty == true)
                        ? Image.network(
                            _p.primaryImageUrl!,
                            width: 72,
                            height: 72,
                            fit: BoxFit.cover,
                          )
                        : Container(
                            width: 72,
                            height: 72,
                            color: AppColors.greyBackground,
                            child: const Icon(
                              Icons.image,
                              color: AppColors.disabledFg,
                            ),
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
                          style: const TextStyle(fontWeight: FontWeight.w800),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'Rp ${money.format(price)}',
                          style: const TextStyle(
                            fontWeight: FontWeight.w800,
                            fontSize: 16,
                          ),
                        ),
                        if (matched != null) ...[
                          const SizedBox(height: 4),
                          Text(
                            matched.code,
                            style: const TextStyle(
                              color: AppColors.textSecondary,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 12),

            // ATRIBUT (scrollable dengan tinggi maksimal)
            ConstrainedBox(
              constraints: BoxConstraints(
                maxHeight: MediaQuery.of(context).size.height * 0.45,
              ),
              child: ListView(
                shrinkWrap: true,
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
                            style: const TextStyle(fontWeight: FontWeight.w800),
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
                                      ? FontWeight.w700
                                      : FontWeight.w500,
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

            // QTY + CTA
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
                minimum: const EdgeInsets.fromLTRB(0, 10, 0, 4),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Quantity',
                          style: TextStyle(fontWeight: FontWeight.w700),
                        ),
                        _QtyPill(
                          qty: _qty,
                          onMinus: () =>
                              setState(() => _qty = (_qty > 1) ? _qty - 1 : 1),
                          onPlus: () => setState(() => _qty++),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    SizedBox(
                      width: double.infinity,
                      height: 48,
                      child: FilledButton(
                        onPressed:
                            (_selected.length == attrsMap.length &&
                                matched != null)
                            ? () {
                                final inStock = !_p.isHide;
                                final posSku = PosSku(
                                  skuId: matched!.idProductSku,
                                  skuCode: matched!.code,
                                  price: matched!.price,
                                  productId: _p.idProduct,
                                  productName: _p.name,
                                  imageUrl: _p.primaryImageUrl ?? '',
                                  inStock: inStock,
                                );
                                final prov = context.read<SalesProvider>();
                                for (var i = 0; i < _qty; i++) {
                                  prov.add(posSku);
                                }
                                Navigator.pop<bool>(context, true);
                              }
                            : null,
                        style: FilledButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                        child: Text(
                          (_selected.length == attrsMap.length &&
                                  matched != null)
                              ? 'Add to cart — Rp ${money.format(price)}'
                              : 'Pilih semua varian',
                          style: const TextStyle(fontWeight: FontWeight.w700),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// ==== helpers utk ProductSku ====
  Map<String, Set<String>> _extractAttributes(List<ProductSku> skus) {
    final result = <String, Set<String>>{};
    for (final sku in skus) {
      for (final a in sku.attributes) {
        (result[a.name] ??= <String>{}).add(a.value);
      }
    }
    return result;
  }

  bool _isSkuMatch(
    ProductSku sku,
    Map<String, String> sel, {
    required int requiredCount,
  }) {
    for (final entry in sel.entries) {
      final ok = sku.attributes.any(
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
      for (final e in trial.entries) {
        final ok = sku.attributes.any(
          (a) =>
              a.name.toLowerCase() == e.key.toLowerCase() && a.value == e.value,
        );
        if (!ok) return false;
      }
      return true;
    });
  }
}

/// ===============================
/// Edit Cart Sheet (per SKU)
/// ===============================
class _EditCartSheet extends StatelessWidget {
  final String? filterProductId;
  const _EditCartSheet({this.filterProductId});

  @override
  Widget build(BuildContext context) {
    final prov = context.watch<SalesProvider>();
    final items = prov.cartItems.where((it) {
      if (filterProductId == null) return true;
      return it.sku.productId == filterProductId;
    }).toList();

    final money = NumberFormat.decimalPattern('id_ID');
    final total = items.fold<int>(0, (s, it) => s + it.sku.price * it.qty);

    return Container(
      color: Colors.white,
      child: SafeArea(
        minimum: const EdgeInsets.fromLTRB(16, 12, 16, 0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // header
            Column(
              children: [
                const SizedBox(height: 6),
                Container(
                  width: 44,
                  height: 4,
                  decoration: BoxDecoration(
                    color: const Color(0xFFE5E7EB),
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: Center(
                        child: Text(
                          filterProductId == null
                              ? 'Your Cart'
                              : 'Edit Selections',
                          style: const TextStyle(
                            fontWeight: FontWeight.w800,
                            fontSize: 16,
                          ),
                        ),
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.pop(context, false),
                      icon: const Icon(
                        Icons.close_rounded,
                        color: Color(0xFF6B7280),
                      ),
                      tooltip: 'Close',
                    ),
                  ],
                ),
              ],
            ),

            const SizedBox(height: 8),

            // list items
            ConstrainedBox(
              constraints: BoxConstraints(
                maxHeight: MediaQuery.of(context).size.height * 0.55,
              ),
              child: items.isEmpty
                  ? const Padding(
                      padding: EdgeInsets.all(24),
                      child: Text('Cart is empty'),
                    )
                  : ListView.separated(
                      shrinkWrap: true,
                      itemCount: items.length,
                      separatorBuilder: (_, __) =>
                          const Divider(height: 1, color: Color(0xFFE5E7EB)),
                      itemBuilder: (_, i) {
                        final it = items[i];
                        final sku = it.sku;

                        return Padding(
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          child: Row(
                            children: [
                              ClipRRect(
                                borderRadius: BorderRadius.circular(8),
                                child: (sku.imageUrl.isNotEmpty)
                                    ? Image.network(
                                        sku.imageUrl,
                                        width: 48,
                                        height: 48,
                                        fit: BoxFit.cover,
                                      )
                                    : Container(
                                        width: 48,
                                        height: 48,
                                        color: AppColors.greyBackground,
                                        child: const Icon(
                                          Icons.image,
                                          color: AppColors.disabledFg,
                                        ),
                                      ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      sku.productName,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w800,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      sku.skuCode,
                                      style: const TextStyle(
                                        color: AppColors.textSecondary,
                                        fontSize: 12,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 10),
                              Text(
                                'Rp ${money.format(sku.price)}',
                                style: const TextStyle(
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              const SizedBox(width: 10),
                              _QtyPill(
                                qty: it.qty,
                                onMinus: () {
                                  prov.removeOne(sku);
                                },
                                onPlus: () {
                                  prov.add(sku);
                                },
                              ),
                              IconButton(
                                tooltip: 'Remove all',
                                icon: const Icon(
                                  Icons.delete_outline,
                                  color: AppColors.textSecondary,
                                ),
                                onPressed: () {
                                  // kurangi sampai 0
                                  for (var n = 0; n < it.qty; n++) {
                                    prov.removeOne(sku);
                                  }
                                },
                              ),
                            ],
                          ),
                        );
                      },
                    ),
            ),

            const SizedBox(height: 8),
            // total + close
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Subtotal',
                  style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
                ),
                Text(
                  'Rp ${money.format(total)}',
                  style: const TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 16,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: FilledButton(
                onPressed: () => Navigator.pop(context, true),
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text('Done'),
              ),
            ),
            const SizedBox(height: 12),
          ],
        ),
      ),
    );
  }
}

/// ===============================
/// Helpers: group & product card
/// ===============================
class _SpGroup {
  final Product product;
  final String productId;
  final String name;
  final String? thumbUrl;
  final int minPrice;

  _SpGroup({
    required this.product,
    required this.productId,
    required this.name,
    required this.minPrice,
    this.thumbUrl,
  });
}

class _SpCard extends StatelessWidget {
  final _SpGroup group;
  final int selectedQty;
  final VoidCallback onChoose;
  final VoidCallback? onQuickMinus;
  final VoidCallback? onOpenEditForThisProduct;

  const _SpCard({
    required this.group,
    required this.selectedQty,
    required this.onChoose,
    this.onQuickMinus,
    this.onOpenEditForThisProduct,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    Widget image() {
      final url = group.thumbUrl;
      final fallback = Container(
        decoration: BoxDecoration(
          color: AppColors.greyBackground,
          borderRadius: BorderRadius.circular(12),
        ),
        child: const Center(
          child: Icon(Icons.image, color: AppColors.disabledFg),
        ),
      );
      return ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: (url != null && url.isNotEmpty)
            ? Image.network(
                url,
                height: 110,
                width: double.infinity,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) =>
                    SizedBox(height: 110, child: fallback),
              )
            : SizedBox(height: 110, child: fallback),
      );
    }

    String _formatRp(int v) =>
        'Rp ${NumberFormat.decimalPattern('id_ID').format(v)}';

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0F000000),
            blurRadius: 16,
            offset: Offset(0, 6),
          ),
        ],
        border: Border.all(color: AppColors.divider),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Stack(
              clipBehavior: Clip.none,
              children: [
                image(),
                if (selectedQty > 0)
                  Positioned(
                    top: 8,
                    right: 8,
                    child: Row(
                      children: [
                        // quick minus
                        if (onQuickMinus != null)
                          InkWell(
                            onTap: onQuickMinus,
                            borderRadius: BorderRadius.circular(999),
                            child: Container(
                              padding: const EdgeInsets.all(6),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(999),
                                boxShadow: const [
                                  BoxShadow(
                                    color: Color(0x1A000000),
                                    blurRadius: 10,
                                  ),
                                ],
                                border: Border.all(color: AppColors.divider),
                              ),
                              child: const Icon(Icons.remove_rounded, size: 16),
                            ),
                          ),
                        const SizedBox(width: 6),
                        // badge qty (tappable membuka editor cart utk produk ini)
                        GestureDetector(
                          onTap: onOpenEditForThisProduct,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(999),
                              boxShadow: const [
                                BoxShadow(
                                  color: Color(0x1A000000),
                                  blurRadius: 10,
                                ),
                              ],
                              border: Border.all(color: AppColors.divider),
                            ),
                            child: Text(
                              '$selectedQty',
                              style: const TextStyle(
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              group.name,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontWeight: FontWeight.w800,
                color: AppColors.primaryText,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'from ${_formatRp(group.minPrice)}',
              style: const TextStyle(
                fontWeight: FontWeight.w700,
                color: AppColors.textSecondary,
              ),
            ),
            const Spacer(),
            SizedBox(
              height: 40,
              width: double.infinity,
              child: FilledButton(
                onPressed: onChoose,
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text('Choose'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// ===============================
/// Small qty pill
/// ===============================
class _QtyPill extends StatelessWidget {
  final int qty;
  final VoidCallback onMinus;
  final VoidCallback onPlus;

  const _QtyPill({
    required this.qty,
    required this.onMinus,
    required this.onPlus,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 36,
      decoration: BoxDecoration(
        border: Border.all(color: AppColors.divider),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            visualDensity: VisualDensity.compact,
            onPressed: onMinus,
            icon: const Icon(Icons.remove_rounded),
          ),
          Text('$qty', style: const TextStyle(fontWeight: FontWeight.w800)),
          IconButton(
            visualDensity: VisualDensity.compact,
            onPressed: onPlus,
            icon: const Icon(Icons.add_rounded),
          ),
        ],
      ),
    );
  }
}

/// ===============================
/// Floating Cart Bar
/// ===============================
class _CartBar extends StatelessWidget {
  final int itemCount;
  final String totalText;
  final VoidCallback onTap;

  const _CartBar({
    required this.itemCount,
    required this.totalText,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      elevation: 6,
      color: Colors.white,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppColors.divider),
          ),
          child: Row(
            children: [
              Stack(
                clipBehavior: Clip.none,
                children: [
                  const Icon(Icons.shopping_bag_outlined),
                  Positioned(
                    right: -8,
                    top: -6,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.primary,
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(
                        '$itemCount',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(width: 10),
              const Text(
                'View Cart',
                style: TextStyle(fontWeight: FontWeight.w700),
              ),
              const Spacer(),
              Text(
                totalText,
                style: const TextStyle(fontWeight: FontWeight.w800),
              ),
              const SizedBox(width: 6),
              const Icon(Icons.keyboard_arrow_up_rounded),
            ],
          ),
        ),
      ),
    );
  }
}
