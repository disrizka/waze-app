// lib/screens/stock-opname/stock_opname_create_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:infinite_scroll_pagination/infinite_scroll_pagination.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:shimmer/shimmer.dart';

import 'package:wa_blast/constants/app_colors.dart';
import 'package:wa_blast/models/product_models/product_model.dart';
import 'package:wa_blast/providers/product_provider.dart';
import 'package:wa_blast/providers/stock_provider.dart';
import 'package:wa_blast/providers/store_provider.dart';
import 'package:wa_blast/widgets/app_snackbar.dart';
import 'package:wa_blast/widgets/reusable_pickers.dart';

/// Screen to create stock opname:
/// - Shows SKU list (not product list)
/// - Card: parent product image, product name, SKU code, current stock
/// - Tap card -> input qty only (no SKU selection)
class StockOpnameCreateScreen extends StatefulWidget {
  const StockOpnameCreateScreen({super.key});

  @override
  State<StockOpnameCreateScreen> createState() =>
      _StockOpnameCreateScreenState();
}

class _StockOpnameCreateScreenState extends State<StockOpnameCreateScreen> {
  final TextEditingController _searchC = TextEditingController();

  late final ProductProvider _prodProv;

  // Filter model (no date range)
  _SkuFilters _filters = const _SkuFilters();

  // Store (also used for label)
  String? _storeId;
  String? _storeName;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _prodProv = Provider.of<ProductProvider>(context, listen: false);
  }

  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      _prodProv.initInfinitePaging(context, initialSearch: '');

      try {
        final id = await _prodProv
            .ensureDefaultStoreLocation(context)
            .timeout(const Duration(seconds: 6));

        _storeId = id;
        _syncStoreLabel();

        _filters = _filters.copyWith(storeLocationId: _storeId);
      } catch (_) {
        _syncStoreLabel();
        _filters = _filters.copyWith(
          storeLocationId: _storeId ?? _prodProv.currentStoreLocationId,
        );
      }

      if (!mounted) return;

      final composed = _filters.toSearchString(rawQuery: _searchC.text.trim());
      await _prodProv.setInfiniteSearch(context, composed);
      await _prodProv.refreshInfinite(context);
    });
  }

  @override
  void dispose() {
    _prodProv.disposeInfinitePaging();
    _searchC.dispose();
    super.dispose();
  }

  void _syncStoreLabel() {
    if (!mounted) return;

    final sp = context.read<StoreProvider>();
    final id =
        _storeId ?? context.read<ProductProvider>().currentStoreLocationId;

    if (id == null || id.isEmpty) {
      setState(() {
        _storeName = null;
        _storeId = null;
      });
      return;
    }

    final match = sp.stores.firstWhere(
      (s) => s.idStoreLocation == id,
      orElse: () => sp.stores.isNotEmpty ? sp.stores.first : null as dynamic,
    );

    setState(() {
      _storeId = id;
      _storeName = match?.name?.toString();
    });
  }

  Future<void> _onSearchSubmitted(String _) async {
    if (!mounted) return;

    final prov = context.read<ProductProvider>();
    final q = _searchC.text.trim();
    final composed = _filters.copyWith(query: q).toSearchString(rawQuery: q);

    await prov.setInfiniteSearch(context, composed);
    await prov.refreshInfinite(context);
  }

  Future<void> _onPullRefresh() async {
    await context.read<ProductProvider>().refreshInfinite(context);
  }

  int _skuStock(dynamic sku) {
    final dynamic v =
        sku.stockQty ??
        sku.qty ??
        sku.currentStockQty ??
        sku.totalStockQty ??
        sku.stock ??
        0;
    if (v is int) return v;
    return int.tryParse(v.toString()) ?? 0;
  }

  String _skuCode(dynamic sku) {
    final code = (sku.code ?? '').toString().trim();
    return code.isEmpty ? '-' : code;
  }

  // ---- Month label (MONTH-YEAR) ----
  String _monthYearLabel(DateTime? d) {
    if (d == null) return 'Month';
    return DateFormat('MMMM yyyy', 'en_US').format(d);
  }

  // Backend token: "MM-yyyy" (example: 01-2026)
  String _monthYearToken(DateTime d) {
    return DateFormat('MM-yyyy').format(d);
  }

  Future<void> _pickMonthYearLocal({
    required DateTime? initial,
    required void Function(DateTime value) onPicked,
  }) async {
    final now = DateTime.now();
    final init = initial ?? DateTime(now.year, now.month, 1);

    final seedBlue = AppColors.blueButton;
    final base = Theme.of(context);

    final picked = await showDatePicker(
      context: context,
      initialDate: init,
      firstDate: DateTime(now.year - 2, 1, 1),
      lastDate: DateTime(now.year + 1, 12, 31),
      helpText: 'Select month & year',
      fieldHintText: 'dd/mm/yyyy',
      builder: (ctx, child) {
        final cs =
            ColorScheme.fromSeed(
              seedColor: seedBlue,
              brightness: Brightness.light,
            ).copyWith(
              primary: seedBlue,
              onPrimary: Colors.white,
              surface: Colors.white,
              onSurface: const Color(0xFF111827),
            );

        return Theme(
          data: base.copyWith(
            colorScheme: cs,
            dialogBackgroundColor: Colors.white,
            // Works on newer Flutter versions; harmless on older if unused.
            datePickerTheme: DatePickerThemeData(
              backgroundColor: Colors.white,
              headerBackgroundColor: seedBlue,
              headerForegroundColor: Colors.white,
              dayForegroundColor: WidgetStateProperty.resolveWith((states) {
                if (states.contains(WidgetState.disabled)) {
                  return const Color(0xFF9CA3AF);
                }
                if (states.contains(WidgetState.selected)) {
                  return Colors.white;
                }
                return const Color(0xFF111827);
              }),
              dayBackgroundColor: WidgetStateProperty.resolveWith((states) {
                if (states.contains(WidgetState.selected)) {
                  return seedBlue;
                }
                return Colors.transparent;
              }),
              todayForegroundColor: WidgetStateProperty.all(seedBlue),
              todayBackgroundColor: WidgetStateProperty.all(
                const Color(0x1A4C6EF5),
              ),
              yearForegroundColor: WidgetStateProperty.resolveWith((states) {
                if (states.contains(WidgetState.selected)) {
                  return seedBlue;
                }
                return const Color(0xFF111827);
              }),
              yearBackgroundColor: WidgetStateProperty.resolveWith((states) {
                if (states.contains(WidgetState.selected)) {
                  return const Color(0x144C6EF5);
                }
                return Colors.transparent;
              }),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(18),
              ),
            ),
            textButtonTheme: TextButtonThemeData(
              style: TextButton.styleFrom(
                foregroundColor: seedBlue,
                textStyle: const TextStyle(fontWeight: FontWeight.w800),
              ),
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked == null) return;

    // Use month-year only (day ignored)
    final monthYear = DateTime(picked.year, picked.month, 1);
    onPicked(monthYear);
  }

  // ---- Advanced Filter (bottom sheet) ----
  Future<void> _openAdvancedFilter(ProductProvider prov) async {
    // Ensure dropdown data is ready
    if (prov.brands.isEmpty) {
      await prov.fetchProductBrands(context);
    }
    if (prov.categories.isEmpty) {
      await prov.fetchProductCategories(context);
    }

    final result = await showModalBottomSheet<_SkuFilters>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => _AdvancedFilterSheet(
        initial: _filters,
        monthYearLabel: _monthYearLabel,
        onPickMonthYear: (initial, onPicked) =>
            _pickMonthYearLocal(initial: initial, onPicked: onPicked),
      ),
    );

    if (!mounted) return;
    if (result == null) return;

    // Apply filter
    setState(() {
      _filters = result;
      _storeId = result.storeLocationId;
      _syncStoreLabel();
    });

    // Store is required -> apply to provider first so backend fetch matches
    if ((_filters.storeLocationId ?? '').isNotEmpty) {
      await context.read<ProductProvider>().setStoreLocationAndRefresh(
        context,
        _filters.storeLocationId!,
      );
    }

    final composed = _filters.toSearchString(rawQuery: _searchC.text.trim());
    await prov.setInfiniteSearch(context, composed);
    await prov.refreshInfinite(context);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,

      appBar: AppBar(
        backgroundColor: Colors.white,
        scrolledUnderElevation: 0,
        elevation: 0,
        foregroundColor: const Color(0xFF1F2937),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded),
          onPressed: () => Navigator.pop(context),
        ),
        title: Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.baseline,
          textBaseline: TextBaseline.alphabetic,
          children: const [
            Text(
              'Stock Opname',
              style: TextStyle(
                fontWeight: FontWeight.w900,
                color: Color(0xFF1F2937),
              ),
            ),
            SizedBox(width: 8),
            Text(
              '/create',
              style: TextStyle(
                fontSize: 12,
                color: Color(0xFF9CA3AF),
                fontFamily: 'monospace',
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
        centerTitle: false,
        actions: [
          IconButton(
            tooltip: 'Stock Opname History',
            icon: const Icon(Icons.history_rounded),
            onPressed: () => Navigator.pushNamed(context, '/stock/opname'),
          ),
          const SizedBox(width: 6),
        ],
      ),

      body: SafeArea(
        child: Consumer<ProductProvider>(
          builder: (context, provider, _) {
            final controller = provider.pagingController;
            if (controller == null) {
              return _buildLoadingSkeleton();
            }

            final bool hasOptionalActive = _filters.hasOptionalFilters;

            final state = controller.value;

            void next() {
              final pm = provider.pageProducts;
              final cur = pm?.currentPage;
              final tot = pm?.totalPages;
              if (cur != null && tot != null && cur >= tot) return;
              controller.fetchNextPage();
            }

            const double _kStickyTopPadding = 10;
            const double _kStickyControlsHeight = 48;
            const double _kStickyBottomPadding = 10;
            const double _kStickyDividerHeight = 1;

            final double stickyHeight =
                _kStickyTopPadding +
                _kStickyControlsHeight +
                _kStickyBottomPadding +
                _kStickyDividerHeight;

            return RefreshIndicator(
              onRefresh: _onPullRefresh,
              child: CustomScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                slivers: [
                  SliverPersistentHeader(
                    pinned: true,
                    delegate: _StickyHeaderDelegate(
                      height: stickyHeight,
                      // ✅ token supaya delegate tau harus rebuild saat filter berubah
                      rebuildToken: _filters.rebuildToken,
                      builder: (context, overlaps) {
                        final bool isActive = _filters.hasOptionalFilters;

                        return Material(
                          color: Colors.white,
                          child: Container(
                            decoration: BoxDecoration(
                              color: Colors.white,
                              boxShadow: overlaps
                                  ? const [
                                      BoxShadow(
                                        color: Color(0x14000000),
                                        blurRadius: 14,
                                        offset: Offset(0, 6),
                                      ),
                                    ]
                                  : const [],
                            ),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Padding(
                                  padding: const EdgeInsets.fromLTRB(
                                    16,
                                    10,
                                    16,
                                    10,
                                  ),
                                  child: SizedBox(
                                    height: _kStickyControlsHeight,
                                    child: Row(
                                      children: [
                                        Expanded(
                                          child: TextField(
                                            controller: _searchC,
                                            onSubmitted: _onSearchSubmitted,
                                            textInputAction:
                                                TextInputAction.search,
                                            decoration: InputDecoration(
                                              hintText:
                                                  'Search product name or SKU',
                                              isDense: true,
                                              filled: true,
                                              fillColor: const Color(
                                                0xFFF3F4F6,
                                              ),
                                              prefixIcon: const Icon(
                                                Icons.search,
                                                size: 20,
                                              ),
                                              contentPadding:
                                                  const EdgeInsets.symmetric(
                                                    horizontal: 14,
                                                    vertical: 12,
                                                  ),
                                              enabledBorder: OutlineInputBorder(
                                                borderSide: const BorderSide(
                                                  color: Color(0xFFE5E7EB),
                                                ),
                                                borderRadius:
                                                    BorderRadius.circular(10),
                                              ),
                                              focusedBorder: OutlineInputBorder(
                                                borderSide: const BorderSide(
                                                  color: Color(0xFFCBD5E1),
                                                ),
                                                borderRadius:
                                                    BorderRadius.circular(10),
                                              ),
                                            ),
                                          ),
                                        ),
                                        const SizedBox(width: 10),
                                        SizedBox(
                                          height: 42,
                                          width: 42,
                                          child: _AdvancedFilterIconButton(
                                            // ✅ compute inside builder so it always reflects latest state
                                            isActive: isActive,
                                            onPressed: () =>
                                                _openAdvancedFilter(provider),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                                const Divider(
                                  height: 1,
                                  thickness: 1,
                                  color: Color(0xFFF3F4F6),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  ),

                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
                    sliver: PagedSliverList<int, Product>(
                      state: state,
                      fetchNextPage: next,
                      builderDelegate: PagedChildBuilderDelegate<Product>(
                        itemBuilder: (_, p, __) {
                          final skus = p.productSkus;
                          final productImage =
                              p.primaryImageUrl ?? 'assets/empty_box.png';

                          if (skus.isEmpty) {
                            return Padding(
                              padding: const EdgeInsets.symmetric(vertical: 6),
                              child: _SkuTile(
                                productName: p.name,
                                productImage: productImage,
                                skuCode: '-',
                                onTap: () {
                                  AppSnackbar.show(
                                    context,
                                    type: AppSnackType.error,
                                    title: 'SKU not found',
                                    message:
                                        'This product does not have any SKU.',
                                  );
                                },
                              ),
                            );
                          }

                          return Column(
                            children: skus.map((sku) {
                              final dynamic s = sku;
                              final skuId = (s.idProductSku ?? '').toString();
                              final skuCode = _skuCode(s);
                              final stock = _skuStock(s);

                              return Padding(
                                padding: const EdgeInsets.symmetric(
                                  vertical: 6,
                                ),
                                child: _SkuTile(
                                  productName: p.name,
                                  productImage: productImage,
                                  skuCode: skuCode,
                                  onTap: () async {
                                    final sid =
                                        _filters.storeLocationId ??
                                        _storeId ??
                                        context
                                            .read<ProductProvider>()
                                            .currentStoreLocationId;

                                    if (sid == null || sid.isEmpty) {
                                      AppSnackbar.show(
                                        context,
                                        type: AppSnackType.error,
                                        title: 'Store is required',
                                        message:
                                            'Please select a store location in Filter.',
                                      );
                                      return;
                                    }

                                    if (skuId.trim().isEmpty) {
                                      AppSnackbar.show(
                                        context,
                                        type: AppSnackType.error,
                                        title: 'Invalid SKU',
                                        message:
                                            'SKU ID is missing for this item.',
                                      );
                                      return;
                                    }

                                    await showModalBottomSheet<bool>(
                                      context: context,
                                      isScrollControlled: true,
                                      useSafeArea: true,
                                      backgroundColor: Colors.white,
                                      shape: const RoundedRectangleBorder(
                                        borderRadius: BorderRadius.vertical(
                                          top: Radius.circular(20),
                                        ),
                                      ),
                                      builder: (_) => _StockOpnameQtySheet(
                                        hostContext: context,
                                        onOpenHistory: () {
                                          if (!context.mounted) return;
                                          Navigator.pushNamed(
                                            context,
                                            '/stock/opname',
                                          );
                                        },
                                        storeId: sid,
                                        productId: p.idProduct,
                                        productSkuId: skuId,
                                        productName: p.name,
                                        productImage: productImage,
                                        skuCode: skuCode,
                                        currentStock: stock,
                                      ),
                                    );
                                  },
                                ),
                              );
                            }).toList(),
                          );
                        },
                        firstPageProgressIndicatorBuilder: (_) =>
                            _buildShimmerColumn(),
                        newPageProgressIndicatorBuilder: (_) => const Padding(
                          padding: EdgeInsets.symmetric(vertical: 14),
                          child: Center(
                            child: SizedBox(
                              width: 22,
                              height: 22,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            ),
                          ),
                        ),
                        firstPageErrorIndicatorBuilder: (_) => _ErrorRetry(
                          onRetry: () => provider.refreshInfinite(context),
                        ),
                        newPageErrorIndicatorBuilder: (_) =>
                            _ErrorRetry(onRetry: next),
                        noMoreItemsIndicatorBuilder: (_) =>
                            const SizedBox.shrink(),
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}

/// ✅ Advanced Filter button:
/// - Dot ONLY appears when OPTIONAL filters are active.
/// - No dot at all when inactive.
/// - Store(required) should NOT affect isActive (pass _filters.hasOptionalFilters)
class _AdvancedFilterIconButton extends StatelessWidget {
  const _AdvancedFilterIconButton({
    required this.isActive,
    required this.onPressed,
  });

  final bool isActive;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    // Base (soft grey)
    const Color bg = Color(0xFFF3F4F6);
    const Color bd = Color(0xFFE5E7EB);
    const Color iconColor = Color(0xFF111827);

    // When active: keep grey, but add subtle border + shadow (optional)
    final Color activeBorder = AppColors.blueButton.withOpacity(0.35);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(10),
        child: Ink(
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: isActive ? activeBorder : bd),
            boxShadow: isActive
                ? const [
                    BoxShadow(
                      color: Color(0x144C6EF5),
                      blurRadius: 12,
                      offset: Offset(0, 6),
                    ),
                  ]
                : const [],
          ),
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              const Center(
                child: Icon(Icons.tune_rounded, size: 20, color: iconColor),
              ),

              // ✅ Dot appears only when active
              if (isActive)
                Positioned(
                  right: 9,
                  top: 9,
                  child: Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: AppColors.blueButton,
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 1.5),
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

class _StickyHeaderDelegate extends SliverPersistentHeaderDelegate {
  final double height;
  final int rebuildToken;
  final Widget Function(BuildContext context, bool overlapsContent) builder;

  const _StickyHeaderDelegate({
    required this.height,
    required this.rebuildToken,
    required this.builder,
  });

  @override
  double get minExtent => height;

  @override
  double get maxExtent => height;

  @override
  Widget build(
    BuildContext context,
    double shrinkOffset,
    bool overlapsContent,
  ) {
    return builder(context, overlapsContent);
  }

  @override
  bool shouldRebuild(covariant _StickyHeaderDelegate oldDelegate) {
    return oldDelegate.height != height ||
        oldDelegate.rebuildToken != rebuildToken ||
        oldDelegate.builder != builder;
  }
}

// =====================
// Filter model (no date range)
// =====================
@immutable
class _SkuFilters {
  final String? query; // q
  final String? brandId; // brand:
  final String? categoryId; // cat:
  final String? storeLocationId; // store:
  final DateTime? stockOpnameMonth; // stock_opname_month:
  final String? stockOpnameStatus; // stock_opname_status: SUDAH/BELUM

  const _SkuFilters({
    this.query,
    this.brandId,
    this.categoryId,
    this.storeLocationId,
    this.stockOpnameMonth,
    this.stockOpnameStatus,
  });

  _SkuFilters copyWith({
    String? query,
    String? brandId,
    String? categoryId,
    String? storeLocationId,
    DateTime? stockOpnameMonth,
    String? stockOpnameStatus,
    bool clearBrand = false,
    bool clearCategory = false,
    bool clearStore = false,
    bool clearMonth = false,
    bool clearStatus = false,
  }) {
    return _SkuFilters(
      query: query ?? this.query,
      brandId: clearBrand ? null : (brandId ?? this.brandId),
      categoryId: clearCategory ? null : (categoryId ?? this.categoryId),
      storeLocationId: clearStore
          ? null
          : (storeLocationId ?? this.storeLocationId),
      stockOpnameMonth: clearMonth
          ? null
          : (stockOpnameMonth ?? this.stockOpnameMonth),
      stockOpnameStatus: clearStatus
          ? null
          : (stockOpnameStatus ?? this.stockOpnameStatus),
    );
  }

  int get rebuildToken => Object.hash(
    (brandId ?? '').trim(),
    (categoryId ?? '').trim(),
    storeLocationId ??
        '', // store tidak bikin dot, tapi boleh ikut token supaya UI tetap sync
    stockOpnameMonth?.year,
    stockOpnameMonth?.month,
    (stockOpnameStatus ?? '').trim(),
  );

  bool get hasOptionalFilters {
    final b = (brandId ?? '').trim().isNotEmpty;
    final c = (categoryId ?? '').trim().isNotEmpty;
    final m = stockOpnameMonth != null;

    final s = (stockOpnameStatus ?? '').trim();
    final statusActive = (s == 'SUDAH' || s == 'BELUM');

    return b || c || m || statusActive;
  }

  String toSearchString({String rawQuery = ''}) {
    final tokens = <String>[];
    final q = rawQuery.isNotEmpty ? rawQuery : (query ?? '');
    if (q.isNotEmpty) tokens.add('q:$q');
    if ((brandId ?? '').isNotEmpty) tokens.add('brand:$brandId');
    if ((categoryId ?? '').isNotEmpty) tokens.add('cat:$categoryId');
    if ((storeLocationId ?? '').isNotEmpty) {
      tokens.add('store:$storeLocationId');
    }

    // stock_opname_month = MONTH-YEAR (token: MM-yyyy)
    if (stockOpnameMonth != null) {
      final token = DateFormat('MM-yyyy').format(stockOpnameMonth!);
      tokens.add('stock_opname_month:$token');
    }

    // Backend token values must remain: SUDAH / BELUM
    final s = (stockOpnameStatus ?? '').trim();
    if (s == 'SUDAH' || s == 'BELUM') {
      tokens.add('stock_opname_status:$s');
    }

    return tokens.join(' ');
  }
}

// =====================
// Advanced Filter Sheet
// =====================
class _AdvancedFilterSheet extends StatefulWidget {
  const _AdvancedFilterSheet({
    required this.initial,
    required this.monthYearLabel,
    required this.onPickMonthYear,
  });

  final _SkuFilters initial;
  final String Function(DateTime? d) monthYearLabel;

  final Future<void> Function(
    DateTime? initial,
    void Function(DateTime picked) onPicked,
  )
  onPickMonthYear;

  @override
  State<_AdvancedFilterSheet> createState() => _AdvancedFilterSheetState();
}

class _AdvancedFilterSheetState extends State<_AdvancedFilterSheet> {
  String? _brandId;
  String? _categoryId;

  // Store is required
  String? _storeId;
  String? _storeName;
  String? _storeError;

  DateTime? _monthYear;

  /// Backend token values:
  /// - "SUDAH"
  /// - "BELUM"
  String? _status;

  @override
  void initState() {
    super.initState();
    _brandId = widget.initial.brandId;
    _categoryId = widget.initial.categoryId;
    _storeId = widget.initial.storeLocationId;
    _monthYear = widget.initial.stockOpnameMonth;
    _status = widget.initial.stockOpnameStatus;

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final pp = context.read<ProductProvider>();
      final id =
          _storeId ??
          pp.currentStoreLocationId ??
          await pp.ensureDefaultStoreLocation(context);

      if (!mounted) return;

      final sp = context.read<StoreProvider>();
      if (id == null || id.isEmpty) {
        setState(() {
          _storeId = null;
          _storeName = null;
          _storeError = 'Store location is required';
        });
        return;
      }

      final match = sp.stores.firstWhere(
        (s) => s.idStoreLocation == id,
        orElse: () => sp.stores.isNotEmpty ? sp.stores.first : null as dynamic,
      );

      setState(() {
        _storeId = id;
        _storeName = match?.name?.toString();
        _storeError = null;
      });
    });
  }

  bool get _hasAnyOptional =>
      _brandId != null ||
      _categoryId != null ||
      _monthYear != null ||
      _status != null;

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

  String _statusLabel(String token) {
    switch (token) {
      case 'SUDAH':
        return 'Done';
      case 'BELUM':
        return 'Not yet';
      default:
        return token;
    }
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

  Future<String?> _pickOption({
    required String title,
    required List<_PickerOption> options,
    String? selectedId,
  }) {
    return _showOptionPicker(
      context: context,
      title: title,
      options: options,
      selectedId: selectedId,
    );
  }

  Future<void> _resetOptionalFilters() async {
    setState(() {
      _brandId = null;
      _categoryId = null;
      _monthYear = null;
      _status = null;
    });
  }

  void _apply() {
    if (_storeId == null || _storeId!.isEmpty) {
      setState(() => _storeError = 'Store location is required');
      return;
    }

    final s = (_status ?? '').trim();
    final sanitizedStatus = (s == 'SUDAH' || s == 'BELUM') ? s : null;

    final next = _SkuFilters(
      query: widget.initial.query,
      storeLocationId: _storeId,
      brandId: _brandId,
      categoryId: _categoryId,
      stockOpnameMonth: _monthYear,
      stockOpnameStatus: sanitizedStatus,
    );

    Navigator.pop(context, next);
  }

  @override
  Widget build(BuildContext context) {
    final prov = context.watch<ProductProvider>();

    final brandOpts = prov.brands
        .map((b) => _PickerOption(id: b.idProductBrand, label: b.name))
        .toList();
    final catOpts = prov.categories
        .map((c) => _PickerOption(id: c.idProductCategory, label: c.name))
        .toList();

    final seedBlue = AppColors.blueButton;

    return DraggableScrollableSheet(
      initialChildSize: 0.90,
      minChildSize: 0.55,
      maxChildSize: 0.95,
      expand: false,
      builder: (context, controller) {
        final chips = <Widget>[];

        if (_monthYear != null) {
          chips.add(
            _MiniChip(
              label: widget.monthYearLabel(_monthYear),
              onClear: () => setState(() => _monthYear = null),
            ),
          );
        }
        if ((_status ?? '').isNotEmpty) {
          chips.add(
            _MiniChip(
              label: 'Status: ${_statusLabel(_status!)}',
              onClear: () => setState(() => _status = null),
            ),
          );
        }
        final bn = _brandName(prov, _brandId);
        if ((bn ?? '').isNotEmpty) {
          chips.add(
            _MiniChip(
              label: 'Brand: $bn',
              onClear: () => setState(() => _brandId = null),
            ),
          );
        }
        final cn = _categoryName(prov, _categoryId);
        if ((cn ?? '').isNotEmpty) {
          chips.add(
            _MiniChip(
              label: 'Category: $cn',
              onClear: () => setState(() => _categoryId = null),
            ),
          );
        }

        return SafeArea(
          top: false,
          child: Column(
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

              // Header (minimal + reset only when needed)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 18),
                child: Row(
                  children: [
                    const Expanded(
                      child: Text(
                        'Filter',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w900,
                          color: Color(0xFF111827),
                        ),
                      ),
                    ),
                    if (_hasAnyOptional)
                      TextButton.icon(
                        onPressed: _resetOptionalFilters,
                        icon: const Icon(Icons.restart_alt_rounded, size: 18),
                        label: const Text('Reset'),
                        style: TextButton.styleFrom(
                          foregroundColor: const Color(0xFF111827),
                        ),
                      ),
                  ],
                ),
              ),

              // Active chips (compact)
              if (chips.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.fromLTRB(18, 2, 18, 10),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Wrap(spacing: 8, runSpacing: 8, children: chips),
                  ),
                )
              else
                const SizedBox(height: 6),

              Expanded(
                child: ListView(
                  controller: controller,
                  padding: const EdgeInsets.fromLTRB(18, 8, 18, 100),
                  children: [
                    const _SectionLabel('Required'),
                    const SizedBox(height: 10),
                    _FilterTile(
                      icon: Icons.store_rounded,
                      title: 'Store Location',
                      value: _storeName ?? 'Select store…',
                      isPlaceholder: (_storeName ?? '').isEmpty,
                      onTap: _pickStore,
                      onClear: null, // required, cannot be cleared
                    ),
                    if ((_storeError ?? '').isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Text(
                        _storeError!,
                        style: const TextStyle(
                          color: Color(0xFFEF4444),
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],

                    const SizedBox(height: 18),
                    const _SectionLabel('Optional'),
                    const SizedBox(height: 10),

                    _FilterTile(
                      icon: Icons.calendar_month_rounded,
                      title: 'Month',
                      value: _monthYear == null
                          ? 'All months'
                          : widget.monthYearLabel(_monthYear),
                      isPlaceholder: _monthYear == null,
                      onTap: () async {
                        await widget.onPickMonthYear(
                          _monthYear,
                          (picked) => setState(() => _monthYear = picked),
                        );
                      },
                      onClear: _monthYear == null
                          ? null
                          : () => setState(() => _monthYear = null),
                    ),

                    const SizedBox(height: 12),

                    // ✅ Status as colored chips (only a few options)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 12,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF9FAFB),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: const Color(0xFFE5E7EB)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Container(
                                width: 34,
                                height: 34,
                                decoration: BoxDecoration(
                                  color: const Color(0xFFF3F4F6),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                    color: const Color(0xFFE5E7EB),
                                  ),
                                ),
                                child: const Icon(
                                  Icons.fact_check_rounded,
                                  size: 18,
                                  color: Color(0xFF6B7280),
                                ),
                              ),
                              const SizedBox(width: 12),
                              const Expanded(
                                child: Text(
                                  'Stock Opname Status',
                                  style: TextStyle(
                                    fontWeight: FontWeight.w900,
                                    color: Color(0xFF111827),
                                    fontSize: 13,
                                  ),
                                ),
                              ),
                              if ((_status ?? '').isNotEmpty)
                                IconButton(
                                  tooltip: 'Clear',
                                  onPressed: () =>
                                      setState(() => _status = null),
                                  icon: const Icon(
                                    Icons.close_rounded,
                                    size: 18,
                                  ),
                                  color: const Color(0xFF6B7280),
                                ),
                            ],
                          ),
                          const SizedBox(height: 10),
                          Wrap(
                            spacing: 10,
                            runSpacing: 10,
                            children: [
                              _StatusChip(
                                label: 'Done',
                                selected: _status == 'SUDAH',
                                selectedColor: seedBlue,
                                onTap: () => setState(() {
                                  _status = (_status == 'SUDAH')
                                      ? null
                                      : 'SUDAH';
                                }),
                              ),
                              _StatusChip(
                                label: 'Not yet',
                                selected: _status == 'BELUM',
                                selectedColor: seedBlue,
                                onTap: () => setState(() {
                                  _status = (_status == 'BELUM')
                                      ? null
                                      : 'BELUM';
                                }),
                              ),
                              _StatusChip(
                                label: 'All',
                                selected: (_status ?? '').isEmpty,
                                selectedColor: const Color(0xFF111827),
                                onTap: () => setState(() => _status = null),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 12),

                    _FilterTile(
                      icon: Icons.sell_rounded,
                      title: 'Brand',
                      value: _brandName(prov, _brandId) ?? 'All brands',
                      isPlaceholder: _brandId == null,
                      onTap: () async {
                        final picked = await _pickOption(
                          title: 'Select Brand',
                          options: brandOpts,
                          selectedId: _brandId,
                        );
                        if (!mounted) return;
                        setState(() => _brandId = picked);
                      },
                      onClear: _brandId == null
                          ? null
                          : () => setState(() => _brandId = null),
                    ),

                    const SizedBox(height: 12),

                    _FilterTile(
                      icon: Icons.category_rounded,
                      title: 'Category',
                      value:
                          _categoryName(prov, _categoryId) ?? 'All categories',
                      isPlaceholder: _categoryId == null,
                      onTap: () async {
                        final picked = await _pickOption(
                          title: 'Select Category',
                          options: catOpts,
                          selectedId: _categoryId,
                        );
                        if (!mounted) return;
                        setState(() => _categoryId = picked);
                      },
                      onClear: _categoryId == null
                          ? null
                          : () => setState(() => _categoryId = null),
                    ),
                  ],
                ),
              ),

              // Bottom actions (sticky style)
              Container(
                padding: const EdgeInsets.fromLTRB(16, 10, 16, 16),
                decoration: const BoxDecoration(
                  color: Colors.white,
                  border: Border(top: BorderSide(color: Color(0xFFE5E7EB))),
                ),
                child: SizedBox(
                  height: 50,
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _apply,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.blueButton,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    child: const Text(
                      'Apply Filter',
                      style: TextStyle(fontWeight: FontWeight.w900),
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({
    required this.label,
    required this.selected,
    required this.selectedColor,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final Color selectedColor;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final bg = selected ? selectedColor : const Color(0xFFF3F4F6);
    final bd = selected ? selectedColor : const Color(0xFFE5E7EB);
    final fg = selected ? Colors.white : const Color(0xFF111827);

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(999),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: bd),
          boxShadow: selected
              ? const [
                  BoxShadow(
                    color: Color(0x1A4C6EF5),
                    blurRadius: 12,
                    offset: Offset(0, 6),
                  ),
                ]
              : const [],
        ),
        child: Text(
          label,
          style: TextStyle(
            color: fg,
            fontWeight: FontWeight.w900,
            fontSize: 12,
          ),
        ),
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  final String text;
  const _SectionLabel(this.text);

  @override
  Widget build(BuildContext context) {
    return Text(
      text.toUpperCase(),
      style: const TextStyle(
        fontSize: 12,
        letterSpacing: 1.1,
        fontWeight: FontWeight.w900,
        color: Color(0xFF6B7280),
      ),
    );
  }
}

class _MiniChip extends StatelessWidget {
  const _MiniChip({required this.label, required this.onClear});
  final String label;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: const Color(0xFFF3F4F6),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontWeight: FontWeight.w800,
              color: Color(0xFF111827),
              fontSize: 12,
            ),
          ),
          const SizedBox(width: 6),
          InkWell(
            onTap: onClear,
            borderRadius: BorderRadius.circular(999),
            child: const Icon(
              Icons.close_rounded,
              size: 16,
              color: Color(0xFF6B7280),
            ),
          ),
        ],
      ),
    );
  }
}

class _FilterTile extends StatelessWidget {
  const _FilterTile({
    required this.icon,
    required this.title,
    required this.value,
    required this.isPlaceholder,
    required this.onTap,
    required this.onClear,
  });

  final IconData icon;
  final String title;
  final String value;
  final bool isPlaceholder;
  final VoidCallback onTap;
  final VoidCallback? onClear;

  @override
  Widget build(BuildContext context) {
    final valueColor = isPlaceholder
        ? const Color(0xFF9CA3AF)
        : const Color(0xFF111827);

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: const Color(0xFFF9FAFB),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: const Color(0xFFE5E7EB)),
        ),
        child: Row(
          children: [
            Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(
                color: const Color(0xFFF3F4F6),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFE5E7EB)),
              ),
              child: Icon(icon, size: 18, color: const Color(0xFF6B7280)),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontWeight: FontWeight.w900,
                      color: Color(0xFF111827),
                      fontSize: 13,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    value,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: valueColor,
                      fontWeight: isPlaceholder
                          ? FontWeight.w600
                          : FontWeight.w900,
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            ),
            if (onClear != null)
              IconButton(
                tooltip: 'Clear',
                onPressed: onClear,
                icon: const Icon(Icons.close_rounded, size: 18),
                color: const Color(0xFF6B7280),
              )
            else
              const Icon(Icons.chevron_right_rounded, color: Color(0xFF6B7280)),
          ],
        ),
      ),
    );
  }
}

// =====================
// Simple picker (search + radio) for Brand/Category
// =====================
class _PickerOption {
  final String id;
  final String label;
  final String? subtitle;
  const _PickerOption({required this.id, required this.label, this.subtitle});
}

Future<String?> _showOptionPicker({
  required BuildContext context,
  required String title,
  required List<_PickerOption> options,
  String? selectedId,
}) async {
  final controller = TextEditingController();
  List<_PickerOption> filtered = List.of(options);

  void doFilter(void Function(void Function()) setState, String q) {
    final query = q.trim().toLowerCase();
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
                                fontWeight: FontWeight.w900,
                                color: Color(0xFF111827),
                              ),
                            ),
                          ),
                          TextButton(
                            onPressed: () => Navigator.pop(ctx),
                            child: const Text('Close'),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 8),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: TextField(
                        controller: controller,
                        onChanged: (q) => doFilter(setState, q),
                        decoration: InputDecoration(
                          hintText: 'Search…',
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
                                fontWeight: FontWeight.w800,
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

// =====================
// UI Components (SKU tiles & qty sheet)
// =====================
class _SelectFieldTile extends StatelessWidget {
  const _SelectFieldTile({
    required this.placeholder,
    required this.valueText,
    required this.onTap,
  });

  final String placeholder;
  final String? valueText;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final hasValue = valueText != null && valueText!.trim().isNotEmpty;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        decoration: BoxDecoration(
          color: const Color(0xFFF3F4F6),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: const Color(0xFFE5E7EB)),
        ),
        child: Row(
          children: [
            Expanded(
              child: Text(
                hasValue ? valueText!.trim() : placeholder,
                style: TextStyle(
                  color: hasValue
                      ? const Color(0xFF111827)
                      : const Color(0xFF9CA3AF),
                  fontWeight: hasValue ? FontWeight.w800 : FontWeight.w500,
                ),
              ),
            ),
            const Icon(Icons.expand_more, color: Color(0xFF6B7280)),
          ],
        ),
      ),
    );
  }
}

/// SKU card
class _SkuTile extends StatelessWidget {
  const _SkuTile({
    required this.productName,
    required this.productImage,
    required this.skuCode,
    required this.onTap,
  });

  final String productName;
  final String productImage;
  final String skuCode;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    const Color border = Color(0xFFE5E7EB);

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: border),
          boxShadow: const [
            BoxShadow(
              blurRadius: 16,
              offset: Offset(0, 10),
              color: Color(0x08000000),
            ),
          ],
        ),
        padding: const EdgeInsets.all(10),
        child: Row(
          children: [
            _ThumbImage(image: productImage),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    productName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontWeight: FontWeight.w900,
                      color: Color(0xFF111827),
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 7),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 5,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF3F4F6),
                      borderRadius: BorderRadius.circular(999),
                      border: Border.all(color: const Color(0xFFE5E7EB)),
                    ),
                    child: Text(
                      'SKU: $skuCode',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Color(0xFF6B7280),
                        fontWeight: FontWeight.w800,
                        fontSize: 11,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 10),
            Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(
                color: const Color(0xFFF3F4F6),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFE5E7EB)),
              ),
              child: const Icon(
                Icons.chevron_right_rounded,
                color: Color(0xFF6B7280),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StockBadge extends StatelessWidget {
  const _StockBadge({required this.stockQty});
  final int stockQty;

  @override
  Widget build(BuildContext context) {
    final isOut = stockQty <= 0;

    final bg = isOut ? const Color(0xFFFFF1F2) : const Color(0xFFF9FAFB);
    final bd = isOut ? const Color(0xFFFECACA) : const Color(0xFFE5E7EB);
    final numColor = isOut ? const Color(0xFFDC2626) : const Color(0xFF111827);
    final labelColor = isOut
        ? const Color(0xFFB91C1C)
        : const Color(0xFF6B7280);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: bd),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'Stock',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w900,
              color: labelColor,
            ),
          ),
          const SizedBox(width: 8),
          Text(
            '$stockQty',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w900,
              color: numColor,
            ),
          ),
        ],
      ),
    );
  }
}

class _ThumbImage extends StatelessWidget {
  const _ThumbImage({required this.image});
  final String image;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(14),
      child: Container(
        width: 56,
        height: 56,
        color: const Color(0xFFF3F4F6),
        child: _SquareImage(image: image),
      ),
    );
  }
}

class _SquareImage extends StatelessWidget {
  const _SquareImage({required this.image});
  final String image;

  @override
  Widget build(BuildContext context) {
    final isNetwork =
        image.isNotEmpty &&
        (image.startsWith('http://') || image.startsWith('https://'));

    Widget fallback() => const Center(
      child: Icon(
        Icons.broken_image_rounded,
        size: 26,
        color: Color(0xFF9CA3AF),
      ),
    );

    if (isNetwork) {
      return Image.network(
        image,
        fit: BoxFit.cover,
        loadingBuilder: (ctx, child, progress) => progress == null
            ? child
            : const Center(
                child: SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              ),
        errorBuilder: (ctx, err, stack) => fallback(),
      );
    }

    if (image.isNotEmpty) {
      return Image.asset(
        image,
        fit: BoxFit.cover,
        errorBuilder: (ctx, err, stack) => fallback(),
      );
    }

    return fallback();
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
          label: const Text('Try again'),
        ),
      ],
    ),
  );
}

Widget _buildLoadingSkeleton() {
  return Padding(
    padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
    child: Column(
      children: [
        Container(
          height: 48,
          width: double.infinity,
          decoration: BoxDecoration(
            color: const Color(0xFFF3F4F6),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFFE5E7EB)),
          ),
        ),
        const SizedBox(height: 14),
        Expanded(child: _buildShimmerColumn()),
      ],
    ),
  );
}

Widget _buildShimmerColumn() {
  return Padding(
    padding: const EdgeInsets.only(top: 8),
    child: Column(
      children: List.generate(8, (i) {
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 7),
          child: Shimmer.fromColors(
            baseColor: Colors.grey.shade300,
            highlightColor: Colors.grey.shade100,
            child: Row(
              children: [
                Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(14),
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
                      const SizedBox(height: 8),
                      Container(height: 12, width: 160, color: Colors.white),
                    ],
                  ),
                ),
                const SizedBox(width: 10),
                Container(
                  width: 92,
                  height: 28,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
                const SizedBox(width: 10),
                Container(
                  width: 34,
                  height: 34,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ],
            ),
          ),
        );
      }),
    ),
  );
}

class _StockOpnameQtySheet extends StatefulWidget {
  const _StockOpnameQtySheet({
    required this.hostContext,
    required this.onOpenHistory,
    required this.storeId,
    required this.productId,
    required this.productSkuId,
    required this.productName,
    required this.productImage,
    required this.skuCode,
    required this.currentStock,
  });

  /// ✅ Use this context for snackbar + navigation (parent screen context)
  final BuildContext hostContext;

  /// ✅ Navigation callback from parent
  final VoidCallback onOpenHistory;

  final String storeId;
  final String productId;
  final String productSkuId;
  final String productName;
  final String productImage;
  final String skuCode;
  final int currentStock;

  @override
  State<_StockOpnameQtySheet> createState() => _StockOpnameQtySheetState();
}

class _StockOpnameQtySheetState extends State<_StockOpnameQtySheet> {
  final TextEditingController _qtyC = TextEditingController(text: '1');
  bool _submitting = false;

  @override
  void dispose() {
    _qtyC.dispose();
    super.dispose();
  }

  int _qty() => int.tryParse(_qtyC.text.trim()) ?? 0;

  bool get _canSubmit =>
      !_submitting &&
      widget.storeId.trim().isNotEmpty &&
      widget.productId.trim().isNotEmpty &&
      widget.productSkuId.trim().isNotEmpty &&
      _qty() > 0;

  Future<void> _submit() async {
    if (!_canSubmit) return;

    setState(() => _submitting = true);

    final sp = context.read<StockProvider>();
    final res = await sp.createStockOpname(
      context: context,
      idStoreLocation: widget.storeId,
      productId: widget.productId,
      productSkuId: widget.productSkuId,
      qty: _qty(),
      refreshListAfter: true,
    );

    if (!mounted) return;

    setState(() => _submitting = false);

    if (res != null) {
      Navigator.pop(context, true);

      // ✅ Use the host context (parent screen), not the bottom sheet context
      if (!widget.hostContext.mounted) return;

      AppSnackbar.show(
        widget.hostContext,
        type: AppSnackType.success,
        title: 'Success',
        message:
            'Open stock opname history list to adjust stock opname into the system.',
        actionLabel: 'Open',
        onAction: () {
          if (!widget.hostContext.mounted) return;
          widget.onOpenHistory();
        },
        duration: const Duration(seconds: 6),
      );
    } else {
      AppSnackbar.show(
        context,
        type: AppSnackType.error,
        title: 'Failed',
        message: 'Failed to create stock opname. ${sp.lastError ?? ''}',
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final padBottom = MediaQuery.of(context).viewInsets.bottom;

    return Padding(
      padding: EdgeInsets.only(bottom: padBottom),
      child: SafeArea(
        top: false,
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(context).size.height * 0.72,
          ),
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(18, 8, 18, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 44,
                    height: 4,
                    decoration: BoxDecoration(
                      color: const Color(0xFFE5E7EB),
                      borderRadius: BorderRadius.circular(999),
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                const Text(
                  'Stock Opname',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w900,
                    color: Color(0xFF111827),
                  ),
                ),
                const SizedBox(height: 10),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF9FAFB),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: const Color(0xFFE5E7EB)),
                  ),
                  child: Row(
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(14),
                        child: Container(
                          width: 62,
                          height: 62,
                          color: const Color(0xFFF3F4F6),
                          child: _SquareImage(image: widget.productImage),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              widget.productName,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontWeight: FontWeight.w900,
                                color: Color(0xFF111827),
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              'SKU: ${widget.skuCode}',
                              style: const TextStyle(
                                color: Color(0xFF6B7280),
                                fontWeight: FontWeight.w800,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                const Text(
                  'Qty',
                  style: TextStyle(
                    fontWeight: FontWeight.w900,
                    color: Color(0xFF111827),
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    _QtyBtn(
                      icon: Icons.remove_rounded,
                      onTap: () {
                        final v = _qty();
                        final next = (v <= 1) ? 1 : v - 1;
                        setState(() => _qtyC.text = '$next');
                      },
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: TextFormField(
                        controller: _qtyC,
                        keyboardType: TextInputType.number,
                        inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                        decoration: InputDecoration(
                          isDense: true,
                          filled: true,
                          fillColor: const Color(0xFFF3F4F6),
                          hintText: 'Enter stock opname qty',
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 14,
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderSide: const BorderSide(
                              color: Color(0xFFE5E7EB),
                            ),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderSide: const BorderSide(
                              color: Color(0xFFCBD5E1),
                            ),
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        onChanged: (_) => setState(() {}),
                      ),
                    ),
                    const SizedBox(width: 10),
                    _QtyBtn(
                      icon: Icons.add_rounded,
                      onTap: () {
                        final v = _qty();
                        final next = (v <= 0) ? 1 : v + 1;
                        setState(() => _qtyC.text = '$next');
                      },
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                SizedBox(
                  height: 50,
                  width: double.infinity,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _canSubmit
                          ? AppColors.blueButton
                          : const Color(0xFFE5E7EB),
                      foregroundColor: _canSubmit
                          ? Colors.white
                          : const Color(0xFF9CA3AF),
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    onPressed: _canSubmit ? _submit : null,
                    child: _submitting
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation<Color>(
                                Colors.white,
                              ),
                            ),
                          )
                        : const Text(
                            'Create Stock Opname',
                            style: TextStyle(fontWeight: FontWeight.w900),
                          ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _QtyBtn extends StatelessWidget {
  const _QtyBtn({required this.icon, required this.onTap});

  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        width: 46,
        height: 46,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFFE5E7EB)),
        ),
        child: Icon(icon, color: const Color(0xFF111827)),
      ),
    );
  }
}
