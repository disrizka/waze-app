import 'dart:async';
import 'dart:io';
import 'package:intl/intl.dart';

import 'package:dotted_border/dotted_border.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import 'package:shimmer/shimmer.dart';
import 'package:wa_blast/constants/app_colors.dart';
import 'package:wa_blast/models/product_model.dart';
import 'package:wa_blast/providers/product_provider.dart';
import 'package:wa_blast/providers/store_provider.dart';
import 'package:wa_blast/screens/inventory/product_stock_history.dart';
import 'package:wa_blast/screens/products/create_edit_sheet/add_product_sheet.dart';
import 'package:infinite_scroll_pagination/infinite_scroll_pagination.dart';
import 'package:wa_blast/widgets/app_snackbar.dart';
import 'package:wa_blast/widgets/empty_state.dart';
import 'package:wa_blast/widgets/reusable_pickers.dart';
import 'package:wa_blast/widgets/variant_section_dynamic.dart';

String _formatRp(int value) {
  final f = NumberFormat.currency(
    locale: 'id',
    symbol: 'Rp. ',
    decimalDigits: 0,
  );
  return f.format(value);
}

final GlobalKey<VariantsSectionDynamicState> variantsKey =
    GlobalKey<VariantsSectionDynamicState>();

class PickerOption {
  final String id;
  final String label;
  final String? subtitle;
  PickerOption({required this.id, required this.label, this.subtitle});
}

// =====================
// ProductScreen (with Search & Advanced Filter)
// =====================
class InventoryScreen extends StatefulWidget {
  const InventoryScreen({super.key});

  @override
  State<InventoryScreen> createState() => _InventoryScreenState();
}

class _InventoryScreenState extends State<InventoryScreen> {
  final TextEditingController _searchC = TextEditingController();
  final ScrollController _listCtrl =
      ScrollController(); // ⬅️ for infinite scroll
  Timer? _debounce;

  _ProductFilters _filters = const _ProductFilters();

  int _globalMinPrice = 0;
  int _globalMaxPrice = 0;

  DateTimeRange? _dateRange;

  Future<void> _pickDateRange() async {
    final now = DateTime.now();
    final first = DateTime(now.year - 2, 1, 1);
    final last = DateTime(now.year + 1, 12, 31);

    final picked = await showDateRangePicker(
      context: context,
      firstDate: first,
      lastDate: last,
      initialDateRange: _dateRange,
      helpText: 'Filter by date',
      builder: (ctx, child) => Theme(data: Theme.of(ctx), child: child!),
    );
    if (picked == null) return;

    setState(() {
      _dateRange = picked;
      _filters = _filters.copyWith(createdRange: picked);
    });

    final prov = context.read<ProductProvider>();
    final composed = _filters.toSearchString(rawQuery: _searchC.text.trim());
    await prov.setInfiniteSearch(context, composed);
  }

  String _dateShortLabel(DateTimeRange? r) {
    if (r == null) return 'Date';
    // "12–18 Oct"
    final sM = DateFormat('MMM').format(r.start);
    final eM = DateFormat('MMM').format(r.end);
    final sD = r.start.day;
    final eD = r.end.day;
    return sM == eM ? '$sD–$eD $sM' : '$sD $sM–$eD $eM';
  }

  late final ProductProvider _prov; // ⬅️ simpan ref

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _prov = Provider.of<ProductProvider>(context, listen: false);
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      _prov.initInfinitePaging(context, initialSearch: '');
      try {
        await _prov
            .ensureDefaultStoreLocation(context)
            .timeout(const Duration(seconds: 6));
      } catch (_) {}
      await _prov.refreshInfinite(context);
    });
  }

  @override
  void dispose() {
    _prov.disposeInfinitePaging();
    _listCtrl.dispose();
    _debounce?.cancel();
    _searchC.dispose();
    super.dispose();
  }

  Future<void> _onPullRefresh() async {
    final prov = context.read<ProductProvider>();
    await prov.refreshInfinite(context);
  }

  void _onSearchChanged(String _) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 300), () async {
      if (!mounted) return;

      final prov = context.read<ProductProvider>();
      final composed = _filters
          .copyWith(query: _searchC.text.trim())
          .toSearchString(rawQuery: _searchC.text.trim());

      await prov.setInfiniteSearch(context, composed);
      await prov.refreshInfinite(context);
    });
  }

  void _openAdvancedFilter(ProductProvider prov) async {
    _rebuildGlobalRange();

    if (prov.brands.isEmpty) {
      await prov.fetchProductBrands(context);
    }
    if (prov.categories.isEmpty) {
      await prov.fetchProductCategories(context);
    }

    final result = await showModalBottomSheet<_ProductFilters>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => _AdvancedFilterSheet(
        initial: _filters,
        globalMin: _globalMinPrice.toDouble(),
        globalMax: _globalMaxPrice.toDouble(),
      ),
    );

    if (!mounted) return;
    if (result != null) {
      setState(() => _filters = result);
      final composed = _filters.toSearchString(rawQuery: _searchC.text.trim());
      await prov.setInfiniteSearch(context, composed);
    }
  }

  int _priceOf(Product p) {
    if (p.basePrice != null) return p.basePrice!;
    final skuPrices = p.productSkus.map((s) => s.price).toList();
    if (skuPrices.isEmpty) return 0;
    skuPrices.sort();
    return skuPrices.first;
  }

  void _rebuildGlobalRange() {
    final items = context.read<ProductProvider>().products;
    if (items.isEmpty) {
      _globalMinPrice = 0;
      _globalMaxPrice = 0;
      return;
    }
    int minP = 1 << 30;
    int maxP = 0;
    for (final p in items) {
      final price = _priceOf(p);
      if (price < minP) minP = price;
      if (price > maxP) maxP = price;
    }
    if (minP == (1 << 30)) minP = 0;
    _globalMinPrice = minP;
    _globalMaxPrice = maxP;

    if (_filters.minPrice == null && _filters.maxPrice == null) {
      _filters = _filters.copyWith(
        minPrice: _globalMinPrice,
        maxPrice: _globalMaxPrice,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.white,
        scrolledUnderElevation: 0,
        foregroundColor: const Color(0xFF1F2937),
        title: const Text(
          'Inventory',
          style: TextStyle(
            fontWeight: FontWeight.w700,
            color: Color(0xFF1F2937),
          ),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SafeArea(
        child: Consumer<ProductProvider>(
          builder: (context, provider, _) {
            final controller = provider.pagingController;
            if (controller == null) {
              return Center(
                child: Container(
                  margin: const EdgeInsets.symmetric(
                    vertical: 24,
                    horizontal: 16,
                  ),
                  padding: const EdgeInsets.symmetric(
                    vertical: 12,
                    horizontal: 20,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.grey[100],
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.grey[300]!),
                  ),
                  child: const Text(
                    'No more products',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.black54,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              );
            }

            final state = controller.value;

            void next() {
              final pm = provider.pageProducts;
              final cur = pm?.currentPage;
              final tot = pm?.totalPages;
              if (cur != null && tot != null && cur >= tot) {
                return;
              }
              controller.fetchNextPage();
            }

            final topControls = Padding(
              padding: const EdgeInsets.fromLTRB(0, 8, 0, 8),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _searchC,
                      onChanged: _onSearchChanged,
                      textInputAction: TextInputAction.search,
                      decoration: InputDecoration(
                        hintText: 'Search by name or SKU',
                        isDense: true,
                        filled: true,
                        fillColor: const Color(0xFFF3F4F6),
                        prefixIcon: const Icon(Icons.search, size: 20),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 12,
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderSide: const BorderSide(
                            color: Color(0xFFE5E7EB),
                          ),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderSide: const BorderSide(
                            color: Color(0xFFCBD5E1),
                          ),
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  SizedBox(
                    height: 42,
                    width: 42,
                    child: ElevatedButton(
                      onPressed: () => _openAdvancedFilter(provider),
                      style: ElevatedButton.styleFrom(
                        padding: EdgeInsets.zero,
                        backgroundColor: AppColors.blueButton,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      child: const Icon(Icons.tune_rounded, size: 20),
                    ),
                  ),
                  if (_filters.createdRange != null) ...[
                    const SizedBox(width: 6),
                    SizedBox(
                      height: 42,
                      width: 42,
                      child: IconButton(
                        tooltip: 'Clear date',
                        onPressed: () async {
                          setState(() {
                            _dateRange = null;
                            _filters = _filters.copyWith(clearDate: true);
                          });
                          final prov = context.read<ProductProvider>();
                          final composed = _filters.toSearchString(
                            rawQuery: _searchC.text.trim(),
                          );
                          await prov.setInfiniteSearch(context, composed);
                        },
                        icon: const Icon(Icons.close_rounded, size: 18),
                        style: IconButton.styleFrom(
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            );

            final firstPageDoneEmpty = provider.isFirstPageDoneEmpty;

            return Column(
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: topControls,
                ),
                Expanded(
                  child: firstPageDoneEmpty
                      ? _buildShimmerList()
                      : RefreshIndicator(
                          onRefresh: _onPullRefresh,
                          child: PagedListView<int, Product>(
                            state: state,
                            fetchNextPage: next,
                            padding: const EdgeInsets.fromLTRB(
                              16,
                              0,
                              16,
                              24 + 56,
                            ),
                            builderDelegate: PagedChildBuilderDelegate<Product>(
                              itemBuilder: (_, p, __) {
                                final img =
                                    p.primaryImageUrl ?? 'assets/empty_box.png';

                                final int stockQty = p.totalStockQty;
                                final bool isOut = stockQty <= 0;

                                return Padding(
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 6,
                                  ),
                                  child: _ProductTile(
                                    title: p.name,
                                    priceLabel: '',
                                    stockQty: stockQty,
                                    isOutOfStock: isOut,
                                    image: img,
                                    skus: p.productSkus,
                                    onTap: () {
                                      // Kalau produk nggak punya SKU, nggak usah dibawa ke history
                                      if (p.productSkus.isEmpty) {
                                        return;
                                      }

                                      final args = ProductStockHistoryArgs(
                                        productName: p.name,
                                        skus: p.productSkus,
                                        initialSkuId:
                                            p.productSkus.first.idProductSku,
                                      );

                                      Navigator.pushNamed(
                                        context,
                                        '/product/inventory/detail',
                                        arguments: args,
                                      );
                                    },

                                    onEdit: () => showEditProductSheetById(
                                      context,
                                      p.idProduct,
                                    ),
                                    onDelete: () async {
                                      final confirm = await showDialog<bool>(
                                        context: context,
                                        builder: (context) {
                                          return AlertDialog(
                                            backgroundColor: Colors.white,
                                            shape: RoundedRectangleBorder(
                                              borderRadius:
                                                  BorderRadius.circular(16),
                                            ),
                                            title: Row(
                                              children: const [
                                                Icon(
                                                  Icons.warning_amber_rounded,
                                                  color: Colors.red,
                                                  size: 28,
                                                ),
                                                SizedBox(width: 8),
                                                Text(
                                                  'Delete Product',
                                                  style: TextStyle(
                                                    fontWeight: FontWeight.bold,
                                                    color: Colors.black,
                                                  ),
                                                ),
                                              ],
                                            ),
                                            content: Text(
                                              'Are you sure you want to permanently delete "${p.name}"?',
                                              style: const TextStyle(
                                                fontSize: 15,
                                                color: Colors.black87,
                                              ),
                                            ),
                                            actionsPadding:
                                                const EdgeInsets.symmetric(
                                                  horizontal: 16,
                                                  vertical: 8,
                                                ),
                                            actions: [
                                              TextButton(
                                                onPressed: () => Navigator.pop(
                                                  context,
                                                  false,
                                                ),
                                                child: const Text('Cancel'),
                                              ),
                                              ElevatedButton(
                                                onPressed: () => Navigator.pop(
                                                  context,
                                                  true,
                                                ),
                                                style: ElevatedButton.styleFrom(
                                                  backgroundColor: Colors.red,
                                                  foregroundColor: Colors.white,
                                                  shape: RoundedRectangleBorder(
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                          8,
                                                        ),
                                                  ),
                                                ),
                                                child: const Text('Delete'),
                                              ),
                                            ],
                                          );
                                        },
                                      );

                                      if (confirm == true) {
                                        final ok = await context
                                            .read<ProductProvider>()
                                            .deleteProduct(
                                              context,
                                              p.idProduct,
                                            );
                                        if (ok && context.mounted) {
                                          AppSnackbar.show(
                                            context,
                                            type: AppSnackType.success,
                                            message:
                                                'Product successfully deleted',
                                          );
                                          await provider.refreshInfinite(
                                            context,
                                          );
                                        }
                                      }
                                    },
                                  ),
                                );
                              },
                              firstPageProgressIndicatorBuilder: (_) =>
                                  const Center(
                                    child: Padding(
                                      padding: EdgeInsets.all(24),
                                      child: Text(
                                        'No more products',
                                        style: TextStyle(
                                          fontSize: 14,
                                          color: Colors.black54,
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                    ),
                                  ),
                              newPageProgressIndicatorBuilder: (_) =>
                                  const SizedBox.shrink(),
                              firstPageErrorIndicatorBuilder: (_) =>
                                  _ErrorRetry(
                                    onRetry: () =>
                                        provider.refreshInfinite(context),
                                  ),
                              newPageErrorIndicatorBuilder: (_) =>
                                  _ErrorRetry(onRetry: next),
                              noMoreItemsIndicatorBuilder: (_) =>
                                  const SizedBox.shrink(),
                            ),
                          ),
                        ),
                ),
              ],
            );
          },
        ),
      ),
      bottomNavigationBar: SafeArea(
        minimum: const EdgeInsets.fromLTRB(12, 8, 12, 30),
        child: SizedBox(
          height: 48,
          width: double.infinity,
          child: ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.blueButton,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            onPressed: () async {
              Navigator.pushNamed(context, '/purchase/add');
            },
            child: const Text(
              'Add initial stock',
              style: TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
        ),
      ),
    );
  }
}

class _CircleBtn extends StatelessWidget {
  const _CircleBtn({required this.icon, required this.enabled, this.onTap});
  final IconData icon;
  final bool enabled;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: enabled ? onTap : null,
      borderRadius: BorderRadius.circular(999),
      child: Container(
        width: 32,
        height: 32,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: enabled ? Colors.white : const Color(0xFFF3F4F6),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: const Color(0xFFE5E7EB)),
          boxShadow: enabled
              ? const [
                  BoxShadow(
                    blurRadius: 10,
                    offset: Offset(0, 4),
                    color: Color(0x11000000),
                  ),
                ]
              : null,
        ),
        child: Icon(
          icon,
          size: 20,
          color: enabled ? const Color(0xFF111827) : const Color(0xFF9CA3AF),
        ),
      ),
    );
  }
}

class _ErrorRetry extends StatelessWidget {
  final VoidCallback onRetry;
  const _ErrorRetry({required this.onRetry});

  @override
  Widget build(BuildContext context) => Center(
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Icon(Icons.error_outline, color: Colors.redAccent),
        const SizedBox(height: 8),
        const Text('Failed to load data'),
        const SizedBox(height: 8),
        TextButton.icon(
          onPressed: onRetry,
          icon: const Icon(Icons.refresh),
          label: const Text('Retry'),
        ),
      ],
    ),
  );
}

// =====================
// Filter model
// =====================
@immutable
class _ProductFilters {
  final String? query; // name / sku
  final String? brandId; // idProductBrand
  final String? categoryId; // idProductCategory
  final int? minPrice; // inclusive
  final int? maxPrice; // inclusive
  final String? storeLocationId; // store filter
  final DateTimeRange? createdRange;

  const _ProductFilters({
    this.query,
    this.brandId,
    this.categoryId,
    this.minPrice,
    this.maxPrice,
    this.storeLocationId,
    this.createdRange,
  });

  _ProductFilters copyWith({
    String? query,
    String? brandId,
    String? categoryId,
    int? minPrice,
    int? maxPrice,
    String? storeLocationId,
    DateTimeRange? createdRange,
    bool clearBrand = false,
    bool clearCategory = false,
    bool clearStore = false,
    bool clearDate = false,
  }) {
    return _ProductFilters(
      query: query ?? this.query,
      brandId: clearBrand ? null : (brandId ?? this.brandId),
      categoryId: clearCategory ? null : (categoryId ?? this.categoryId),
      minPrice: minPrice ?? this.minPrice,
      maxPrice: maxPrice ?? this.maxPrice,
      storeLocationId: clearStore
          ? null
          : (storeLocationId ?? this.storeLocationId),
      createdRange: clearDate ? null : (createdRange ?? this.createdRange),
    );
  }

  bool get isDefault =>
      (query == null || query!.isEmpty) &&
      (brandId == null || brandId!.isEmpty) &&
      (categoryId == null || categoryId!.isEmpty) &&
      (storeLocationId == null || storeLocationId!.isEmpty) &&
      (minPrice == null && maxPrice == null) &&
      createdRange == null;

  String toSearchString({String rawQuery = ''}) {
    final tokens = <String>[];
    final q = rawQuery.isNotEmpty ? rawQuery : (query ?? '');
    if (q.isNotEmpty) tokens.add('q:$q');
    if ((brandId ?? '').isNotEmpty) tokens.add('brand:$brandId');
    if ((categoryId ?? '').isNotEmpty) tokens.add('cat:$categoryId');
    if (minPrice != null) tokens.add('min:${minPrice!}');
    if (maxPrice != null) tokens.add('max:${maxPrice!}');
    if ((storeLocationId ?? '').isNotEmpty)
      tokens.add('store:$storeLocationId');

    if (createdRange != null) {
      final f = DateFormat('yyyy-MM-dd');
      tokens.add('date_from:${f.format(createdRange!.start)}');
      tokens.add('date_to:${f.format(createdRange!.end)}');
    }
    return tokens.join(' ');
  }
}

///
/// TILE PRODUK + ACCORDION SKU
///

class _ProductTile extends StatefulWidget {
  const _ProductTile({
    required this.title,
    required this.priceLabel,
    required this.image,
    required this.stockQty,
    required this.isOutOfStock,
    required this.skus,
    this.onTap,
    this.onEdit,
    this.onDelete,
  });

  final String title;
  final String priceLabel;
  final String image;
  final int stockQty;
  final bool isOutOfStock;
  final List<ProductSku> skus;
  final VoidCallback? onTap;
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;

  @override
  State<_ProductTile> createState() => _ProductTileState();
}

class _ProductTileState extends State<_ProductTile>
    with SingleTickerProviderStateMixin {
  bool _expanded = false;

  int _stockForSku(ProductSku sku) {
    final int qty = sku.stockQty ?? 0;
    return qty > 0 ? qty : 0; // kalau <= 0 tampilkan 0
  }

  void _toggleExpanded() {
    if (widget.skus.isEmpty) return;
    setState(() {
      _expanded = !_expanded;
    });
  }

  @override
  Widget build(BuildContext context) {
    final bool isOut = widget.isOutOfStock;
    final Color bg = isOut ? const Color(0xFFF3F4F6) : Colors.white;
    final Color border = const Color(0xFFE5E7EB);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        // klik card → ke halaman detail
        onTap: widget.onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: border),
          ),
          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ===== HEADER: gambar + info + more menu =====
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _SquareImage(image: widget.image, dimmed: isOut),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Title
                        Text(
                          widget.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontWeight: FontWeight.w700,
                            color: isOut
                                ? const Color(0xFF6B7280)
                                : const Color(0xFF111827),
                          ),
                        ),
                        const SizedBox(height: 4),
                        // Stock summary
                        Text(
                          isOut ? 'Out of stock' : 'Stock: ${widget.stockQty}',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: isOut
                                ? const Color(0xFFEF4444)
                                : const Color(0xFF16A34A),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  // _MoreButtonAnchored(
                  //   onEdit: widget.onEdit,
                  //   onDelete: widget.onDelete,
                  // ),
                ],
              ),

              const SizedBox(height: 8),

              // ===== TOMBOL VIEW SUMMARY STOCK (hitam, dengan animasi icon) =====
              if (widget.skus.isNotEmpty)
                Align(
                  alignment: Alignment.centerLeft,
                  child: InkWell(
                    onTap: _toggleExpanded,
                    borderRadius: BorderRadius.circular(8),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 2,
                        vertical: 4,
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          AnimatedRotation(
                            turns: _expanded
                                ? 0.5
                                : 0.0, // panah muter naik/turun
                            duration: const Duration(milliseconds: 220),
                            curve: Curves.easeOutCubic,
                            child: const Icon(
                              Icons.keyboard_arrow_down_rounded,
                              size: 18,
                              color: Colors.black87,
                            ),
                          ),
                          const SizedBox(width: 4),
                          const Text(
                            'View summary stock',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                              color: Colors.black87, // ⬅️ warna hitam
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),

              // ===== ACCORDION DENGAN ANIMASI =====
              AnimatedSize(
                duration: const Duration(milliseconds: 220),
                curve: Curves.easeOutCubic,
                alignment: Alignment.topCenter,
                child: (!_expanded || widget.skus.isNotEmpty == false)
                    ? const SizedBox.shrink()
                    : Padding(
                        padding: const EdgeInsets.only(top: 6),
                        child: Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 10,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF9FAFB),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: const Color(0xFFE5E7EB)),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // header kecil untuk kolom
                              Row(
                                children: const [
                                  Expanded(
                                    child: Text(
                                      'SKU',
                                      style: TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w600,
                                        color: Color(0xFF6B7280),
                                      ),
                                    ),
                                  ),
                                  SizedBox(width: 8),
                                  Text(
                                    'Stock',
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w600,
                                      color: Color(0xFF6B7280),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 6),
                              ...widget.skus.map((sku) {
                                final skuStock = _stockForSku(sku);
                                return Container(
                                  margin: const EdgeInsets.symmetric(
                                    vertical: 3,
                                  ),
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 6,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(10),
                                    border: Border.all(
                                      color: const Color(0xFFE5E7EB),
                                    ),
                                  ),
                                  child: Row(
                                    children: [
                                      Expanded(
                                        child: Text(
                                          sku.code,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: const TextStyle(
                                            fontSize: 12,
                                            fontWeight: FontWeight.w500,
                                            color: Color(0xFF111827),
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 8,
                                          vertical: 3,
                                        ),
                                        decoration: BoxDecoration(
                                          color: const Color(0xFFE0F2FE),
                                          borderRadius: BorderRadius.circular(
                                            999,
                                          ),
                                        ),
                                        child: Text(
                                          skuStock.toString(),
                                          style: const TextStyle(
                                            fontSize: 11,
                                            fontWeight: FontWeight.w600,
                                            color: Color(0xFF0F172A),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                );
                              }).toList(),
                            ],
                          ),
                        ),
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SquareImage extends StatelessWidget {
  const _SquareImage({required this.image, this.dimmed = false});
  final String image;
  final bool dimmed;

  @override
  Widget build(BuildContext context) {
    final isNetwork =
        image.isNotEmpty &&
        (image.startsWith('http://') || image.startsWith('https://'));
    Widget _fallback() => const _ImageErrorPlaceholder();

    final Widget raw = isNetwork
        ? Image.network(
            image,
            fit: BoxFit.cover,
            loadingBuilder: (ctx, child, progress) => progress == null
                ? child
                : const Center(
                    child: SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  ),
            errorBuilder: (ctx, err, stack) => _fallback(),
          )
        : (image.isNotEmpty
              ? Image.asset(
                  image,
                  fit: BoxFit.cover,
                  errorBuilder: (ctx, err, stack) => _fallback(),
                )
              : _fallback());

    final Widget child = dimmed
        ? ColorFiltered(
            colorFilter: const ColorFilter.matrix(<double>[
              0.2126,
              0.7152,
              0.0722,
              0,
              0,
              0.2126,
              0.7152,
              0.0722,
              0,
              0,
              0.2126,
              0.7152,
              0.0722,
              0,
              0,
              0,
              0,
              0,
              1,
              0,
            ]),
            child: raw,
          )
        : raw;

    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: Container(
        width: 90,
        height: 90,
        color: const Color(0xFFF3F4F6),
        child: child,
      ),
    );
  }
}

class _ImageErrorPlaceholder extends StatelessWidget {
  const _ImageErrorPlaceholder();
  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Icon(
        Icons.broken_image_rounded,
        size: 32,
        color: Color(0xFF9CA3AF),
      ),
    );
  }
}

Widget _buildShimmerList() {
  return ListView.builder(
    padding: const EdgeInsets.fromLTRB(16, 24, 16, 24),
    itemCount: 6,
    itemBuilder: (_, i) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Shimmer.fromColors(
          baseColor: Colors.grey.shade300,
          highlightColor: Colors.grey.shade100,
          child: Row(
            children: [
              Container(
                width: 60,
                height: 60,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      height: 14,
                      width: double.infinity,
                      color: Colors.white,
                    ),
                    const SizedBox(height: 6),
                    Container(height: 12, width: 120, color: Colors.white),
                  ],
                ),
              ),
            ],
          ),
        ),
      );
    },
  );
}

/// --------------------------------------------------------------------------
/// EDIT PRODUCT
/// --------------------------------------------------------------------------

Future<void> openEditProductById(BuildContext context, String idProduct) async {
  final prov = context.read<ProductProvider>();

  await Future.wait([prov.fetchProductBrands(context)]);

  final detail = await prov.fetchProductDetail(context, idProduct);
  if (detail == null) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Gagal memuat detail produk: ${prov.lastError ?? ''}'),
        ),
      );
    }
    return;
  }

  if (!context.mounted) return;
  await showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: Colors.white,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (_) => _EditProductSheet(product: detail),
  );

  if (!context.mounted) return;
  context.read<ProductProvider>().fetchProducts(context);
}

Future<void> showEditProductSheetById(
  BuildContext context,
  String idProduct,
) async {
  final prov = context.read<ProductProvider>();

  final detail = await prov.fetchProductDetail(context, idProduct);
  if (detail == null) {
    if (context.mounted) {
      AppSnackbar.show(
        context,
        type: AppSnackType.error,
        title: 'Gagal',
        message: 'Tidak bisa mengambil detail produk. ${prov.lastError ?? ''}',
      );
    }
    return;
  }

  // ignore: use_build_context_synchronously
  await showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: Colors.white,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (_) => _EditProductSheet(product: detail),
  );
}

class _EditProductSheet extends StatefulWidget {
  const _EditProductSheet({required this.product});
  final Product product;

  @override
  State<_EditProductSheet> createState() => _EditProductSheetState();
}

class _EditProductSheetState extends State<_EditProductSheet> {
  final _formKey = GlobalKey<FormState>();
  bool _attemptedSubmit = false;
  late final TextEditingController _nameC;
  late final TextEditingController _descC;

  String? _selectedBrandId;
  String? _selectedCategoryId;

  final ImagePicker _picker = ImagePicker();
  XFile? _picked;
  String? _existingImageUrl;
  String? _existingImageFilename;

  final List<_PriceRow> _prices = [];
  final List<_SkuRow> _skus = [];

  @override
  void initState() {
    super.initState();
    final p = widget.product;

    _nameC = TextEditingController(text: p.name);
    _descC = TextEditingController(text: p.description);

    _selectedBrandId = p.productBrand?.idProductBrand;
    _selectedCategoryId = p.productCategory?.idProductCategory;

    if (p.productImages.isNotEmpty) {
      final imgs = [...p.productImages]
        ..sort((a, b) => a.position.compareTo(b.position));
      final first = imgs.first;
      _existingImageUrl = first.imagePath;
      _existingImageFilename = first.image;
    }

    if (p.productPrices.isNotEmpty) {
      for (final pr in p.productPrices) {
        final row = _PriceRow()
          ..minQty.text = '${pr.minQty}'
          ..price.text = NumberFormat.decimalPattern('id').format(pr.price);
        _prices.add(row);
      }
    } else {
      _prices.add(_PriceRow());
    }

    if (p.productSkus.isNotEmpty) {
      for (final s in p.productSkus) {
        final skuRow = _SkuRow()
          ..code.text = s.code
          ..price.text = NumberFormat.decimalPattern('id').format(s.price);

        if (s.attributes.isNotEmpty) {
          skuRow.attrs.clear();
          for (final a in s.attributes) {
            final ar = _AttrRow()
              ..name.text = a.name
              ..value.text = a.value;
            skuRow.attrs.add(ar);
          }
        }
        _skus.add(skuRow);
      }
    } else {
      _skus.add(_SkuRow());
    }

    final prov = context.read<ProductProvider>();
    prov.fetchProductBrands(context);
    prov.fetchProductCategories(context);
  }

  @override
  void dispose() {
    _nameC.dispose();
    _descC.dispose();
    for (final r in _prices) {
      r.dispose();
    }
    for (final s in _skus) {
      s.dispose();
    }
    super.dispose();
  }

  bool get _isValid =>
      (_formKey.currentState?.validate() ?? false) &&
      _selectedBrandId != null &&
      _selectedCategoryId != null &&
      _prices.where((e) => e.isFilled).isNotEmpty &&
      _skus.where((e) => e.isFilled).isNotEmpty;

  Future<void> _chooseImageSource() async {
    final src = await showModalBottomSheet<ImageSource>(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 36,
              height: 4,
              margin: const EdgeInsets.only(top: 8, bottom: 12),
              decoration: BoxDecoration(
                color: const Color(0xFFE5E7EB),
                borderRadius: BorderRadius.circular(99),
              ),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library_outlined),
              title: const Text('Pilih dari Galeri'),
              onTap: () => Navigator.pop(ctx, ImageSource.gallery),
            ),
            ListTile(
              leading: const Icon(Icons.photo_camera_outlined),
              title: const Text('Ambil dari Kamera'),
              onTap: () => Navigator.pop(ctx, ImageSource.camera),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
    if (src == null) return;
    try {
      final picked = await _picker.pickImage(
        source: src,
        maxWidth: 1600,
        maxHeight: 1600,
        imageQuality: 88,
      );
      if (picked != null) {
        setState(() {
          _picked = picked;
          _existingImageUrl = null;
          _existingImageFilename = null;
        });
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Gagal memilih gambar: $e')));
    }
  }

  void _removeImage() {
    setState(() {
      _picked = null;
      _existingImageUrl = null;
      _existingImageFilename = null;
    });
  }

  int _toInt(String s) {
    final digits = s.replaceAll('.', '').replaceAll(',', '').trim();
    return int.tryParse(digits) ?? 0;
  }

  Future<void> _onSubmit() async {
    setState(() => _attemptedSubmit = true);

    if (!_formKey.currentState!.validate()) return;
    if (_selectedBrandId == null || _selectedCategoryId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Pilih brand & category terlebih dahulu.'),
        ),
      );
      return;
    }

    final provider = context.read<ProductProvider>();

    String? uploadedFilename;
    if (_picked != null) {
      uploadedFilename = await provider.uploadProductImage(
        context,
        File(_picked!.path),
      );
      if (uploadedFilename == null) {
        if (!mounted) return;
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Upload gambar gagal')));
        return;
      }
    }

    final images = <NewImage>[];
    if (uploadedFilename != null) {
      images.add(NewImage(filename: uploadedFilename, position: 1));
    } else if (_existingImageFilename != null &&
        _existingImageFilename!.isNotEmpty) {
      images.add(NewImage(filename: _existingImageFilename!, position: 1));
    }

    final prices = _prices
        .where((e) => e.isFilled)
        .map(
          (e) => NewPrice(
            minQty: _toInt(e.minQty.text),
            price: _toInt(e.price.text),
          ),
        )
        .toList();

    final skus = _skus
        .where((e) => e.isFilled)
        .map(
          (e) => NewSku(
            code: e.code.text.trim(),
            price: _toInt(e.price.text),
            attributes: e.attrs
                .where((a) => a.isFilled)
                .map(
                  (a) => NewSkuAttribute(
                    name: a.name.text.trim(),
                    value: a.value.text.trim(),
                  ),
                )
                .toList(),
          ),
        )
        .toList();

    final ok = await provider.updateProduct(
      context: context,
      idProduct: widget.product.idProduct,
      name: _nameC.text.trim(),
      description: _descC.text.trim(),
      productBrandId: _selectedBrandId!,
      productCategoryId: _selectedCategoryId!,
      images: images,
      skus: skus,
      prices: prices,
    );

    if (!mounted) return;
    if (ok) {
      Navigator.of(context).pop();
      AppSnackbar.show(
        context,
        type: AppSnackType.success,
        title: 'Updated',
        message: 'Product updated successfully.',
      );
    } else {
      AppSnackbar.show(
        context,
        type: AppSnackType.error,
        title: 'Failed',
        message: 'Failed to update product: ${provider.lastError ?? ''}',
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final padBottom = MediaQuery.of(context).viewInsets.bottom;

    return Padding(
      padding: EdgeInsets.only(bottom: padBottom),
      child: DraggableScrollableSheet(
        initialChildSize: 0.85,
        minChildSize: 0.5,
        maxChildSize: 0.95,
        expand: false,
        builder: (context, controller) {
          return Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 8),
              Container(
                width: 44,
                height: 4,
                decoration: BoxDecoration(
                  color: const Color(0xFFE5E7EB),
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
              const SizedBox(height: 8),
              Expanded(
                child: SingleChildScrollView(
                  controller: controller,
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
                  child: Form(
                    autovalidateMode: AutovalidateMode.onUserInteraction,
                    key: _formKey,
                    onChanged: () => setState(() {}),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Edit Product',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF111827),
                          ),
                        ),
                        const SizedBox(height: 16),
                        const Text(
                          'Product Photo',
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF111827),
                          ),
                        ),
                        const SizedBox(height: 8),
                        InkWell(
                          onTap: _chooseImageSource,
                          borderRadius: BorderRadius.circular(12),
                          child: DottedBorder(
                            options: const RoundedRectDottedBorderOptions(
                              color: Color(0xFF4C6EF5),
                              strokeWidth: 2,
                              dashPattern: <double>[8, 6],
                              radius: Radius.circular(12),
                              padding: EdgeInsets.all(0),
                            ),
                            child: Container(
                              height: 120,
                              width: double.infinity,
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              clipBehavior: Clip.antiAlias,
                              child: Builder(
                                builder: (_) {
                                  if (_picked != null) {
                                    return Stack(
                                      fit: StackFit.expand,
                                      children: [
                                        Image.file(
                                          File(_picked!.path),
                                          fit: BoxFit.cover,
                                          errorBuilder: (c, e, s) =>
                                              const _ImageErrorPlaceholder(),
                                        ),
                                        Positioned(
                                          top: 8,
                                          right: 8,
                                          child: _closeBtn(_removeImage),
                                        ),
                                      ],
                                    );
                                  }
                                  if (_existingImageUrl != null &&
                                      _existingImageUrl!.isNotEmpty) {
                                    return Stack(
                                      fit: StackFit.expand,
                                      children: [
                                        Image.network(
                                          _existingImageUrl!,
                                          fit: BoxFit.cover,
                                          errorBuilder: (c, e, s) =>
                                              const _ImageErrorPlaceholder(),
                                        ),
                                        Positioned(
                                          top: 8,
                                          right: 8,
                                          child: _closeBtn(_removeImage),
                                        ),
                                      ],
                                    );
                                  }
                                  return const Center(
                                    child: Text(
                                      'Upload file',
                                      style: TextStyle(color: Colors.black54),
                                    ),
                                  );
                                },
                              ),
                            ),
                          ),
                        ),

                        const SizedBox(height: 16),

                        const Text(
                          'Product Name',
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF111827),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Field(
                          controller: _nameC,
                          hintText: 'E.g iPhone 15 Pro +',
                          validator: (v) => (v == null || v.trim().isEmpty)
                              ? 'Required'
                              : null,
                        ),

                        const SizedBox(height: 16),

                        const Text(
                          'Description',
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF111827),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Field(
                          controller: _descC,
                          hintText: 'Deskripsi produk',
                          keyboardType: TextInputType.multiline,
                          validator: (v) => (v == null || v.trim().isEmpty)
                              ? 'Required'
                              : null,
                        ),

                        const SizedBox(height: 16),

                        Consumer<ProductProvider>(
                          builder: (context, prov, _) {
                            final brandOpts = prov.brands
                                .map(
                                  (b) => PickerOption(
                                    id: b.idProductBrand,
                                    label: b.name,
                                  ),
                                )
                                .toList();

                            final catOpts = prov.categories
                                .map(
                                  (c) => PickerOption(
                                    id: c.idProductCategory,
                                    label: c.name,
                                  ),
                                )
                                .toList();

                            String? selectedBrandName;
                            if (_selectedBrandId != null) {
                              final idx = prov.brands.indexWhere(
                                (b) => b.idProductBrand == _selectedBrandId,
                              );
                              if (idx != -1 &&
                                  prov.brands[idx].name.isNotEmpty) {
                                selectedBrandName = prov.brands[idx].name;
                              } else {
                                selectedBrandName =
                                    widget.product.productBrand?.name;
                              }
                            }

                            String? selectedCategoryName;
                            if (_selectedCategoryId != null) {
                              final idx = prov.categories.indexWhere(
                                (c) =>
                                    c.idProductCategory == _selectedCategoryId,
                              );
                              if (idx != -1 &&
                                  prov.categories[idx].name.isNotEmpty) {
                                selectedCategoryName =
                                    prov.categories[idx].name;
                              } else {
                                selectedCategoryName =
                                    widget.product.productCategory?.name;
                              }
                            }

                            return Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                _SelectFieldTile(
                                  label: 'Brand',
                                  placeholder: 'Pilih brand',
                                  valueText:
                                      (selectedBrandName?.isNotEmpty ?? false)
                                      ? selectedBrandName
                                      : null,
                                  onTap: () async {
                                    final picked = await showListPicker(
                                      context: context,
                                      title: 'Pilih Brand',
                                      options: brandOpts,
                                      selectedId: _selectedBrandId,
                                    );
                                    if (picked != null) {
                                      setState(() => _selectedBrandId = picked);
                                    }
                                  },
                                  errorText:
                                      (_attemptedSubmit &&
                                          _selectedBrandId == null)
                                      ? 'Required'
                                      : null,
                                ),
                                const SizedBox(height: 16),
                                _SelectFieldTile(
                                  label: 'Category',
                                  placeholder: 'Pilih category',
                                  valueText:
                                      (selectedCategoryName?.isNotEmpty ??
                                          false)
                                      ? selectedCategoryName
                                      : null,
                                  onTap: () async {
                                    final picked = await showListPicker(
                                      context: context,
                                      title: 'Pilih Category',
                                      options: catOpts,
                                      selectedId: _selectedCategoryId,
                                    );
                                    if (picked != null) {
                                      setState(
                                        () => _selectedCategoryId = picked,
                                      );
                                    }
                                  },
                                  errorText:
                                      (_attemptedSubmit &&
                                          _selectedCategoryId == null)
                                      ? 'Required'
                                      : null,
                                ),
                              ],
                            );
                          },
                        ),

                        const SizedBox(height: 16),

                        const Text(
                          'Prices',
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF111827),
                          ),
                        ),
                        const SizedBox(height: 8),
                        ..._prices.asMap().entries.map((entry) {
                          final idx = entry.key;
                          final row = entry.value;
                          return Padding(
                            padding: EdgeInsets.only(
                              bottom: idx == _prices.length - 1 ? 0 : 10,
                            ),
                            child: Row(
                              children: [
                                Expanded(
                                  child: Field(
                                    controller: row.minQty,
                                    hintText: 'Min Qty',
                                    keyboardType: TextInputType.number,
                                    inputFormatters: [
                                      FilteringTextInputFormatter.digitsOnly,
                                    ],
                                    validator: (v) =>
                                        (v == null || v.trim().isEmpty)
                                        ? 'Required'
                                        : null,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Field(
                                    controller: row.price,
                                    hintText: 'Price',
                                    keyboardType: TextInputType.number,
                                    inputFormatters: [
                                      FilteringTextInputFormatter.digitsOnly,
                                    ],
                                    validator: (v) =>
                                        (v == null || v.trim().isEmpty)
                                        ? 'Required'
                                        : null,
                                    onChanged: (t) {
                                      if (t.isEmpty) return;
                                      final sel = row.price.selection;
                                      final f = NumberFormat.decimalPattern(
                                        'id',
                                      );
                                      final digits = t.replaceAll('.', '');
                                      final newText = f.format(
                                        int.tryParse(digits) ?? 0,
                                      );
                                      row.price
                                        ..text = newText
                                        ..selection = sel.copyWith(
                                          baseOffset: newText.length,
                                          extentOffset: newText.length,
                                        );
                                    },
                                  ),
                                ),
                                const SizedBox(width: 8),
                                _IconBtn(
                                  icon: idx == _prices.length - 1
                                      ? Icons.add_circle_outline
                                      : Icons.remove_circle_outline,
                                  onTap: () {
                                    setState(() {
                                      if (idx == _prices.length - 1) {
                                        _prices.add(_PriceRow());
                                      } else {
                                        _prices.removeAt(idx).dispose();
                                      }
                                    });
                                  },
                                ),
                              ],
                            ),
                          );
                        }).toList(),

                        const SizedBox(height: 16),

                        const Text(
                          'SKUs',
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF111827),
                          ),
                        ),
                        const SizedBox(height: 8),
                        ..._skus.asMap().entries.map((entry) {
                          final i = entry.key;
                          final sku = entry.value;
                          return Container(
                            margin: const EdgeInsets.only(bottom: 12),
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF9FAFB),
                              border: Border.all(
                                color: const Color(0xFFE5E7EB),
                              ),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Column(
                              children: [
                                Row(
                                  children: [
                                    Expanded(
                                      child: Field(
                                        controller: sku.code,
                                        hintText: 'SKU Code',
                                        validator: (v) =>
                                            (v == null || v.trim().isEmpty)
                                            ? 'Required'
                                            : null,
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Field(
                                        controller: sku.price,
                                        hintText: 'SKU Price',
                                        keyboardType: TextInputType.number,
                                        inputFormatters: [
                                          FilteringTextInputFormatter
                                              .digitsOnly,
                                        ],
                                        validator: (v) =>
                                            (v == null || v.trim().isEmpty)
                                            ? 'Required'
                                            : null,
                                        onChanged: (t) {
                                          if (t.isEmpty) return;
                                          final sel = sku.price.selection;
                                          final f = NumberFormat.decimalPattern(
                                            'id',
                                          );
                                          final digits = t.replaceAll('.', '');
                                          final newText = f.format(
                                            int.tryParse(digits) ?? 0,
                                          );
                                          sku.price
                                            ..text = newText
                                            ..selection = sel.copyWith(
                                              baseOffset: newText.length,
                                              extentOffset: newText.length,
                                            );
                                        },
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    _IconBtn(
                                      icon: i == _skus.length - 1
                                          ? Icons.add_circle_outline
                                          : Icons.remove_circle_outline,
                                      onTap: () {
                                        setState(() {
                                          if (i == _skus.length - 1) {
                                            _skus.add(_SkuRow());
                                          } else {
                                            _skus.removeAt(i).dispose();
                                          }
                                        });
                                      },
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 8),
                                Align(
                                  alignment: Alignment.centerLeft,
                                  child: Text(
                                    'Attributes',
                                    style: Theme.of(context)
                                        .textTheme
                                        .bodyMedium
                                        ?.copyWith(fontWeight: FontWeight.w600),
                                  ),
                                ),
                                const SizedBox(height: 8),
                                ...sku.attrs.asMap().entries.map((aEntry) {
                                  final ai = aEntry.key;
                                  final attr = aEntry.value;
                                  return Padding(
                                    padding: EdgeInsets.only(
                                      bottom: ai == sku.attrs.length - 1
                                          ? 0
                                          : 8,
                                    ),
                                    child: Row(
                                      children: [
                                        Expanded(
                                          child: Field(
                                            controller: attr.name,
                                            hintText: 'Name',
                                            validator: (v) =>
                                                (v == null || v.trim().isEmpty)
                                                ? 'Required'
                                                : null,
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        Expanded(
                                          child: Field(
                                            controller: attr.value,
                                            hintText: 'Value',
                                            validator: (v) =>
                                                (v == null || v.trim().isEmpty)
                                                ? 'Required'
                                                : null,
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        _IconBtn(
                                          icon: ai == sku.attrs.length - 1
                                              ? Icons.add_circle_outline
                                              : Icons.remove_circle_outline,
                                          onTap: () {
                                            setState(() {
                                              if (ai == sku.attrs.length - 1) {
                                                sku.attrs.add(_AttrRow());
                                              } else {
                                                sku.attrs
                                                    .removeAt(ai)
                                                    .dispose();
                                              }
                                            });
                                          },
                                        ),
                                      ],
                                    ),
                                  );
                                }).toList(),
                              ],
                            ),
                          );
                        }).toList(),

                        const SizedBox(height: 20),
                      ],
                    ),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 40),
                child: SizedBox(
                  height: 48,
                  width: double.infinity,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _isValid
                          ? AppColors.primary
                          : const Color(0xFFE5E7EB),
                      foregroundColor: _isValid
                          ? Colors.white
                          : const Color(0xFF9CA3AF),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    onPressed: _isValid ? _onSubmit : null,
                    child: const Text(
                      'Save changes',
                      style: TextStyle(fontWeight: FontWeight.w600),
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _closeBtn(VoidCallback onTap) => InkWell(
    onTap: onTap,
    child: Container(
      padding: const EdgeInsets.all(6),
      decoration: BoxDecoration(
        color: Colors.black54,
        borderRadius: BorderRadius.circular(8),
      ),
      child: const Icon(Icons.close_rounded, color: Colors.white, size: 16),
    ),
  );
}

/// Reusable Field
class Field extends StatelessWidget {
  const Field({
    required this.controller,
    this.hintText,
    this.keyboardType,
    this.inputFormatters,
    this.prefix,
    this.validator,
    this.onChanged,
  });

  final TextEditingController controller;
  final String? hintText;
  final TextInputType? keyboardType;
  final List<TextInputFormatter>? inputFormatters;
  final Widget? prefix;
  final String? Function(String?)? validator;
  final ValueChanged<String>? onChanged;

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      onChanged: onChanged,
      keyboardType: keyboardType,
      inputFormatters: inputFormatters,
      validator: validator,
      decoration: InputDecoration(
        isDense: true,
        hintText: hintText,
        filled: true,
        fillColor: const Color(0xFFF3F4F6),
        prefixIconConstraints: const BoxConstraints(minWidth: 0, minHeight: 0),
        prefixIcon: prefix,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 14,
          vertical: 14,
        ),
        enabledBorder: OutlineInputBorder(
          borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
          borderRadius: BorderRadius.circular(10),
        ),
        focusedBorder: OutlineInputBorder(
          borderSide: const BorderSide(color: Color(0xFFCBD5E1)),
          borderRadius: BorderRadius.circular(10),
        ),
      ),
    );
  }
}

class _IconBtn extends StatelessWidget {
  const _IconBtn({required this.icon, required this.onTap});
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkResponse(
      onTap: onTap,
      child: Icon(icon, color: const Color(0xFF4B5563)),
    );
  }
}

class _PriceRow {
  final TextEditingController minQty = TextEditingController();
  final TextEditingController price = TextEditingController();
  bool get isFilled =>
      minQty.text.trim().isNotEmpty && price.text.trim().isNotEmpty;
  void dispose() {
    minQty.dispose();
    price.dispose();
  }
}

class _SkuRow {
  final TextEditingController code = TextEditingController();
  final TextEditingController price = TextEditingController();
  final List<_AttrRow> attrs = [_AttrRow()];
  bool get isFilled =>
      code.text.trim().isNotEmpty && price.text.trim().isNotEmpty;
  void dispose() {
    code.dispose();
    price.dispose();
    for (final a in attrs) {
      a.dispose();
    }
  }
}

// === Signature showListPicker: GANTI dengan yang ini ===
Future<String?> showListPicker({
  required BuildContext context,
  required String title,
  required List<PickerOption> options,
  String? selectedId,
  bool enableCreate = false,
  String Function(String keyword)? createRowLabel,
  Future<PickerOption?> Function(String keyword)? onCreate,
}) async {
  final controller = TextEditingController();
  List<PickerOption> filtered = List.of(options);
  String lastQuery = '';

  bool containsLabel(String q) {
    final low = q.toLowerCase();
    return filtered.any((o) => o.label.toLowerCase() == low);
  }

  return showModalBottomSheet<String>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.white,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (ctx) {
      return SafeArea(
        top: false,
        child: DraggableScrollableSheet(
          expand: false,
          initialChildSize: 0.85,
          minChildSize: 0.5,
          maxChildSize: 0.95,
          builder: (_, sheetCtrl) {
            return StatefulBuilder(
              builder: (context, setState) {
                void _doFilter(String q) {
                  final query = q.trim().toLowerCase();
                  lastQuery = q.trim();
                  setState(() {
                    filtered = options
                        .where(
                          (o) =>
                              o.label.toLowerCase().contains(query) ||
                              (o.subtitle ?? '').toLowerCase().contains(query),
                        )
                        .toList();
                  });
                }

                final canShowCreate =
                    enableCreate &&
                    lastQuery.isNotEmpty &&
                    !containsLabel(lastQuery) &&
                    onCreate != null;

                return Column(
                  children: [
                    const SizedBox(height: 8),
                    Container(
                      width: 44,
                      height: 4,
                      decoration: BoxDecoration(
                        color: const Color(0xFFE5E7EB),
                        borderRadius: BorderRadius.circular(999),
                      ),
                    ),
                    const SizedBox(height: 10),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              title,
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w700,
                                color: Color(0xFF111827),
                              ),
                            ),
                          ),
                          TextButton(
                            onPressed: () => Navigator.pop(ctx),
                            child: const Text('Tutup'),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 8),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: TextField(
                        controller: controller,
                        onChanged: _doFilter,
                        decoration: InputDecoration(
                          hintText: 'Cari…',
                          isDense: true,
                          filled: true,
                          fillColor: const Color(0xFFF3F4F6),
                          prefixIcon: const Icon(Icons.search, size: 20),
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 12,
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderSide: const BorderSide(
                              color: Color(0xFFE5E7EB),
                            ),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderSide: const BorderSide(
                              color: Color(0xFFCBD5E1),
                            ),
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Divider(height: 1, color: Color(0xFFE5E7EB)),
                    if (canShowCreate)
                      Material(
                        color: Colors.transparent,
                        child: ListTile(
                          onTap: () async {
                            final created = await onCreate!(lastQuery);
                            if (created != null) {
                              setState(() {
                                options.add(created);
                                filtered.insert(0, created);
                                selectedId = created.id;
                              });
                              // ignore: use_build_context_synchronously
                              Navigator.pop(ctx, created.id);
                            }
                          },
                          leading: const Icon(
                            Icons.add_circle_outline,
                            color: Color(0xFF4C6EF5),
                          ),
                          title: Text(
                            createRowLabel?.call(lastQuery) ??
                                '"$lastQuery" not found — + Add New',
                            style: const TextStyle(
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF111827),
                            ),
                          ),
                        ),
                      ),
                    Expanded(
                      child: ListView.separated(
                        controller: sheetCtrl,
                        padding: const EdgeInsets.fromLTRB(8, 8, 8, 16),
                        itemCount: filtered.length,
                        separatorBuilder: (_, __) =>
                            const Divider(height: 1, color: Color(0xFFF3F4F6)),
                        itemBuilder: (_, i) {
                          final o = filtered[i];
                          final isSel = o.id == selectedId;
                          return ListTile(
                            onTap: () => Navigator.pop(ctx, o.id),
                            leading: Radio<String>(
                              value: o.id,
                              groupValue: selectedId,
                              onChanged: (_) => Navigator.pop(ctx, o.id),
                            ),
                            title: Text(
                              o.label,
                              style: const TextStyle(
                                fontWeight: FontWeight.w600,
                                color: Color(0xFF111827),
                              ),
                            ),
                            subtitle: (o.subtitle?.isNotEmpty ?? false)
                                ? Text(o.subtitle!)
                                : null,
                            trailing: isSel
                                ? const Icon(
                                    Icons.check_circle,
                                    color: Color(0xFF4C6EF5),
                                  )
                                : null,
                          );
                        },
                      ),
                    ),
                  ],
                );
              },
            );
          },
        ),
      );
    },
  );
}

Future<String?> pickBrandId(BuildContext context, {String? selectedId}) async {
  final prov = context.read<ProductProvider>();
  final opts = prov.brands
      .map((b) => PickerOption(id: b.idProductBrand, label: b.name))
      .toList();

  return showListPicker(
    context: context,
    title: 'Pilih Brand',
    options: opts,
    selectedId: selectedId,
    enableCreate: true,
    createRowLabel: (kw) => '"$kw" is not exists, add new brand',
    onCreate: (kw) async {
      final created = await prov.createBrandNoFetch(context, kw);
      if (created == null) return null;
      return PickerOption(id: created.idProductBrand, label: created.name);
    },
  );
}

Future<String?> pickCategoryId(
  BuildContext context, {
  String? selectedId,
}) async {
  final prov = context.read<ProductProvider>();
  final opts = prov.categories
      .map((c) => PickerOption(id: c.idProductCategory, label: c.name))
      .toList();

  return showListPicker(
    context: context,
    title: 'Pilih Category',
    options: opts,
    selectedId: selectedId,
    enableCreate: true,
    createRowLabel: (kw) => '"$kw" is not exists, add new category',
    onCreate: (kw) async {
      final created = await prov.createCategoryNoFetch(context, kw);
      if (created == null) return null;
      return PickerOption(id: created.idProductCategory, label: created.name);
    },
  );
}

class _PhotoSlotBox extends StatelessWidget {
  const _PhotoSlotBox({
    required this.enabled,
    required this.file,
    required this.onPick,
    required this.onRemove,
  });

  final bool enabled;
  final XFile? file;
  final VoidCallback onPick;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final borderColor = enabled
        ? const Color(0xFF4C6EF5)
        : const Color(0xFFE5E7EB);

    return InkWell(
      onTap: enabled ? onPick : null,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        height: 72,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: borderColor, width: 2),
        ),
        clipBehavior: Clip.antiAlias,
        child: Stack(
          fit: StackFit.expand,
          children: [
            if (file == null)
              Center(
                child: Icon(
                  enabled
                      ? Icons.add_photo_alternate_rounded
                      : Icons.add_photo_alternate_rounded,
                  size: 22,
                  color: enabled
                      ? const Color(0xFF4C6EF5)
                      : const Color(0xFF9CA3AF),
                ),
              )
            else
              Image.file(
                File(file!.path),
                fit: BoxFit.cover,
                errorBuilder: (c, e, s) => const _ImageErrorPlaceholder(),
              ),
            if (file != null)
              Positioned(
                top: 6,
                right: 6,
                child: InkWell(
                  onTap: onRemove,
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: Colors.black54,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(
                      Icons.close_rounded,
                      size: 14,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
            if (!enabled) Container(color: Colors.white.withOpacity(0.55)),
          ],
        ),
      ),
    );
  }
}

class _SelectFieldTile extends StatelessWidget {
  const _SelectFieldTile({
    required this.label,
    required this.placeholder,
    required this.valueText,
    required this.onTap,
    this.errorText,
    this.showLabel = true,
  });

  final String label;
  final String placeholder;
  final String? valueText;
  final VoidCallback onTap;
  final String? errorText;
  final bool showLabel;

  @override
  Widget build(BuildContext context) {
    final hasValue = valueText != null && valueText!.isNotEmpty;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (showLabel)
          Text(
            label,
            style: const TextStyle(
              fontWeight: FontWeight.w600,
              color: Color(0xFF111827),
            ),
          ),
        if (showLabel) const SizedBox(height: 8),
        InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(10),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
            decoration: BoxDecoration(
              color: const Color(0xFFF3F4F6),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: errorText == null
                    ? const Color(0xFFE5E7EB)
                    : const Color(0xFFEF4444),
              ),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    hasValue ? valueText! : placeholder,
                    style: TextStyle(
                      color: hasValue
                          ? const Color(0xFF111827)
                          : const Color(0xFF9CA3AF),
                      fontWeight: hasValue ? FontWeight.w600 : FontWeight.w400,
                    ),
                  ),
                ),
                const Icon(Icons.expand_more, color: Color(0xFF6B7280)),
              ],
            ),
          ),
        ),
        if (errorText != null) ...[
          const SizedBox(height: 6),
          Text(
            errorText!,
            style: const TextStyle(color: Color(0xFFEF4444), fontSize: 12),
          ),
        ],
      ],
    );
  }
}

class _AttrRow {
  final TextEditingController name = TextEditingController();
  final TextEditingController value = TextEditingController();
  bool get isFilled =>
      name.text.trim().isNotEmpty && value.text.trim().isNotEmpty;
  void dispose() {
    name.dispose();
    value.dispose();
  }
}

class _MoreButtonAnchored extends StatefulWidget {
  const _MoreButtonAnchored({this.onEdit, this.onDelete, Key? key})
    : super(key: key);
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;

  @override
  State<_MoreButtonAnchored> createState() => _MoreButtonAnchoredState();
}

class _MoreButtonAnchoredState extends State<_MoreButtonAnchored> {
  final LayerLink _link = LayerLink();
  final GlobalKey _btnKey = GlobalKey();
  OverlayEntry? _entry;
  bool _isOpen = false;

  void _toggleMenu() {
    if (_isOpen) {
      _hideMenu();
    } else {
      _showMenu();
    }
  }

  void _showMenu() {
    final box = _btnKey.currentContext!.findRenderObject() as RenderBox;
    final buttonSize = box.size;

    const double menuWidth = 200;
    const double gap = 8;

    final offset = Offset(
      buttonSize.width - menuWidth,
      buttonSize.height + gap,
    );

    _entry = OverlayEntry(
      builder: (context) {
        return Stack(
          children: [
            Positioned.fill(
              child: GestureDetector(
                behavior: HitTestBehavior.translucent,
                onTap: _hideMenu,
                onPanDown: (_) => _hideMenu(),
              ),
            ),
            CompositedTransformFollower(
              link: _link,
              showWhenUnlinked: false,
              offset: offset,
              child: _PopoverMenu(
                width: menuWidth,
                onEdit: () {
                  _hideMenu();
                  widget.onEdit?.call();
                },
                onDelete: () {
                  _hideMenu();
                  widget.onDelete?.call();
                },
              ),
            ),
          ],
        );
      },
    );

    Overlay.of(context).insert(_entry!);
    setState(() => _isOpen = true);
  }

  void _hideMenu() {
    _entry?.remove();
    _entry = null;
    if (_isOpen) setState(() => _isOpen = false);
  }

  @override
  void dispose() {
    _hideMenu();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bgColor = _isOpen ? const Color(0xFF4C6EF5) : const Color(0xFFF3F4F6);
    final iconColor = _isOpen ? Colors.white : const Color(0xFF4B5563);

    return CompositedTransformTarget(
      link: _link,
      child: InkWell(
        key: _btnKey,
        borderRadius: BorderRadius.circular(10),
        onTap: _toggleMenu,
        child: Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: bgColor,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: const Color(0xFFE5E7EB)),
          ),
          child: Icon(Icons.more_vert_rounded, color: iconColor),
        ),
      ),
    );
  }
}

class _PopoverMenu extends StatelessWidget {
  const _PopoverMenu({
    required this.width,
    required this.onEdit,
    required this.onDelete,
    Key? key,
  }) : super(key: key);

  final double width;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: Container(
        width: width,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: const Color(0xFFE5E7EB)),
          boxShadow: const [
            BoxShadow(
              blurRadius: 20,
              offset: Offset(0, 10),
              color: Color(0x1A000000),
            ),
          ],
        ),
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _MenuRow(icon: Icons.edit_rounded, label: 'Edit', onTap: onEdit),
            _MenuRow(
              icon: Icons.delete_rounded,
              label: 'Delete',
              isDestructive: true,
              onTap: onDelete,
            ),
          ],
        ),
      ),
    );
  }
}

class _MenuRow extends StatelessWidget {
  const _MenuRow({
    required this.icon,
    required this.label,
    required this.onTap,
    this.isDestructive = false,
    Key? key,
  }) : super(key: key);

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool isDestructive;

  @override
  Widget build(BuildContext context) {
    final color = isDestructive
        ? const Color(0xFFEF4444)
        : const Color(0xFF111827);
    final iconBg = isDestructive
        ? const Color(0xFFFFF1F2)
        : const Color(0xFFF3F4F6);

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        child: Row(
          children: [
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: iconBg,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(icon, size: 18, color: color),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                label,
                style: TextStyle(fontWeight: FontWeight.w600, color: color),
              ),
            ),
            const Icon(
              Icons.chevron_right_rounded,
              size: 18,
              color: Color(0xFF9CA3AF),
            ),
          ],
        ),
      ),
    );
  }
}

// =====================
// Bottom sheet: Advanced Filter
// =====================
class _AdvancedFilterSheet extends StatefulWidget {
  const _AdvancedFilterSheet({
    required this.initial,
    required this.globalMin,
    required this.globalMax,
  });

  final _ProductFilters initial;
  final double globalMin;
  final double globalMax;

  @override
  State<_AdvancedFilterSheet> createState() => _AdvancedFilterSheetState();
}

class _AdvancedFilterSheetState extends State<_AdvancedFilterSheet> {
  String? _brandId;
  String? _categoryId;
  late RangeValues _range;

  String? _storeId;
  DateTimeRange? _created;
  String? _storeName;
  String? _storeError;

  @override
  void initState() {
    super.initState();
    _created = widget.initial.createdRange;
    _brandId = widget.initial.brandId;
    _categoryId = widget.initial.categoryId;

    final gMin = widget.globalMin;
    final gMax = widget.globalMax <= widget.globalMin
        ? widget.globalMin + 1
        : widget.globalMax;

    final initMin = (widget.initial.minPrice?.toDouble() ?? gMin).clamp(
      gMin,
      gMax,
    );
    final initMax = (widget.initial.maxPrice?.toDouble() ?? gMax).clamp(
      gMin,
      gMax,
    );
    _range = RangeValues(initMin, initMax);

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final pp = context.read<ProductProvider>();
      final id = await pp.ensureDefaultStoreLocation(context);
      if (!mounted) return;

      final sp = context.read<StoreProvider>();
      final sel = sp.stores.firstWhere(
        (s) => s.idStoreLocation == (id ?? ''),
        orElse: () => sp.stores.isNotEmpty ? sp.stores.first : null as dynamic,
      );

      setState(() {
        _storeId = id ?? sel?.idStoreLocation;
        _storeName = sel?.name;
        _storeError = (_storeId == null || _storeId!.isEmpty)
            ? 'Store location is required'
            : null;
      });
    });
  }

  String _formatRpD(double v) => _formatRp(v.round());

  String? _brandName(ProductProvider prov, String? id) {
    if (id == null) return null;
    final i = prov.brands.indexWhere((b) => b.idProductBrand == id);
    return i == -1 ? null : prov.brands[i].name;
  }

  String? _categoryName(ProductProvider prov, String? id) {
    if (id == null) return null;
    final i = prov.categories.indexWhere((c) => c.idProductCategory == id);
    return i == -1 ? null : prov.categories[i].name;
  }

  Future<void> _pickBrand(BuildContext context) async {
    final picked = await pickBrandId(context, selectedId: _brandId);
    if (!mounted) return;
    setState(() => _brandId = picked);
  }

  Future<void> _pickCategory(BuildContext context) async {
    final picked = await pickCategoryId(context, selectedId: _categoryId);
    if (!mounted) return;
    setState(() => _categoryId = picked);
  }

  Future<void> _pickStore() async {
    final picked = await showStorePickerSheet(context, selectedId: _storeId);
    if (picked == null) return;
    setState(() {
      _storeId = picked.id;
      _storeName = picked.label;
      _storeError = null;
    });
    await context.read<ProductProvider>().setStoreLocationAndRefresh(
      context,
      picked.id,
    );
  }

  @override
  Widget build(BuildContext context) {
    final prov = context.watch<ProductProvider>();

    if ((_storeId == null || _storeName == null) &&
        prov.currentStoreLocationId != null) {
      final sp = context.read<StoreProvider>();
      final match = sp.stores.firstWhere(
        (s) => s.idStoreLocation == prov.currentStoreLocationId,
        orElse: () => sp.stores.isNotEmpty ? sp.stores.first : null as dynamic,
      );
      if (match != null) {
        _storeId ??= match.idStoreLocation;
        _storeName ??= match.name;
      }
    }

    return DraggableScrollableSheet(
      initialChildSize: 0.85,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      expand: false,
      builder: (context, controller) {
        return Column(
          children: [
            const SizedBox(height: 8),
            Container(
              width: 44,
              height: 4,
              decoration: BoxDecoration(
                color: const Color(0xFFE5E7EB),
                borderRadius: BorderRadius.circular(999),
              ),
            ),
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                children: [
                  const Expanded(
                    child: Text(
                      'Advanced Filter',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF111827),
                      ),
                    ),
                  ),
                  TextButton(
                    onPressed: () =>
                        Navigator.pop(context, const _ProductFilters()),
                    child: const Text(
                      'Reset',
                      style: TextStyle(color: Colors.black),
                    ),
                  ),
                  const SizedBox(width: 6),
                  ElevatedButton(
                    onPressed: () async {
                      if (_storeId == null || _storeId!.isEmpty) {
                        setState(
                          () => _storeError = 'Store location is required',
                        );
                        return;
                      }
                      await context
                          .read<ProductProvider>()
                          .setStoreLocationAndRefresh(context, _storeId!);

                      if (!mounted) return;
                      Navigator.pop(
                        context,
                        _ProductFilters(
                          brandId: _brandId,
                          categoryId: _categoryId,
                          query: widget.initial.query,
                        ),
                      );
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.blueButton,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    child: const Text('Apply'),
                  ),
                ],
              ),
            ),
            Expanded(
              child: ListView(
                controller: controller,
                padding: const EdgeInsets.fromLTRB(20, 14, 20, 24),
                children: [
                  const Text(
                    'Store Location',
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF111827),
                    ),
                  ),
                  const SizedBox(height: 8),
                  _SelectFieldTile(
                    label: 'Store Location',
                    showLabel: false,
                    placeholder: 'Select store…',
                    valueText: _storeName,
                    onTap: _pickStore,
                  ),
                  if ((_storeError ?? '').isNotEmpty) ...[
                    const SizedBox(height: 6),
                    Text(
                      _storeError!,
                      style: const TextStyle(color: Colors.red),
                    ),
                  ],
                  const SizedBox(height: 20),
                  Row(
                    children: [
                      const Expanded(
                        child: Text(
                          'Brand',
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF111827),
                          ),
                        ),
                      ),
                      if (_brandId != null)
                        TextButton(
                          onPressed: () => setState(() => _brandId = null),
                          child: const Text('Clear'),
                        ),
                    ],
                  ),
                  _SelectFieldTile(
                    label: 'Brand',
                    showLabel: false,
                    placeholder: 'All brands',
                    valueText: _brandName(prov, _brandId),
                    onTap: () => _pickBrand(context),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      const Expanded(
                        child: Text(
                          'Category',
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF111827),
                          ),
                        ),
                      ),
                      if (_categoryId != null)
                        TextButton(
                          onPressed: () => setState(() => _categoryId = null),
                          child: const Text('Clear'),
                        ),
                    ],
                  ),
                  _SelectFieldTile(
                    label: 'Category',
                    showLabel: false,
                    placeholder: 'All categories',
                    valueText: _categoryName(prov, _categoryId),
                    onTap: () => _pickCategory(context),
                  ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }
}

class _DropdownBox<T> extends StatelessWidget {
  const _DropdownBox({
    required this.value,
    required this.items,
    required this.onChanged,
    this.hint,
  });

  final T? value;
  final List<DropdownMenuItem<T?>> items;
  final ValueChanged<T?> onChanged;
  final String? hint;

  @override
  Widget build(BuildContext context) {
    return DropdownButtonFormField<T?>(
      value: value,
      isDense: true,
      isExpanded: true,
      items: items,
      onChanged: onChanged,
      decoration: InputDecoration(
        hintText: hint,
        isDense: true,
        filled: true,
        fillColor: const Color(0xFFF3F4F6),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 14,
          vertical: 12,
        ),
        enabledBorder: OutlineInputBorder(
          borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
          borderRadius: BorderRadius.circular(10),
        ),
        focusedBorder: OutlineInputBorder(
          borderSide: const BorderSide(color: Color(0xFFCBD5E1)),
          borderRadius: BorderRadius.circular(10),
        ),
      ),
    );
  }
}
