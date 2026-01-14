// lib/screens/stock-opname/stock_opname_create_screen.dart
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:infinite_scroll_pagination/infinite_scroll_pagination.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:shimmer/shimmer.dart';

import 'package:wa_blast/constants/app_colors.dart';
import 'package:wa_blast/models/product_model.dart';
import 'package:wa_blast/providers/product_provider.dart';
import 'package:wa_blast/providers/stock_provider.dart';
import 'package:wa_blast/providers/store_provider.dart';
import 'package:wa_blast/widgets/app_snackbar.dart';
import 'package:wa_blast/widgets/reusable_pickers.dart';

/// Screen untuk create stock opname:
/// - Menampilkan LIST SKU (bukan produk)
/// - Card: gambar dari induk product, nama produk, kode SKU, current stock SKU
/// - Tap card -> input qty saja (tanpa pilih SKU)
class StockOpnameCreateScreen extends StatefulWidget {
  const StockOpnameCreateScreen({super.key});

  @override
  State<StockOpnameCreateScreen> createState() =>
      _StockOpnameCreateScreenState();
}

class _StockOpnameCreateScreenState extends State<StockOpnameCreateScreen> {
  final TextEditingController _searchC = TextEditingController();
  Timer? _debounce;

  late final ProductProvider _prodProv;

  // filter model ala ProductScreen (tanpa date range)
  _SkuFilters _filters = const _SkuFilters();

  // store (dipakai juga untuk label)
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
    _debounce?.cancel();
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

  void _onSearchChanged(String _) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 300), () async {
      if (!mounted) return;

      final prov = context.read<ProductProvider>();
      final q = _searchC.text.trim();

      final composed = _filters.copyWith(query: q).toSearchString(rawQuery: q);

      await prov.setInfiniteSearch(context, composed);
      await prov.refreshInfinite(context);
    });
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

  // ---- Month label (BULAN-TAHUN) ----
  String _monthYearLabel(DateTime? d) {
    if (d == null) return 'Bulan';
    // label Indonesia: "Januari 2026"
    return DateFormat('MMMM yyyy', 'id_ID').format(d);
  }

  // token backend: "MM-yyyy" (contoh: 01-2026)
  String _monthYearToken(DateTime d) {
    return DateFormat('MM-yyyy').format(d);
  }

  Future<void> _pickMonthYearLocal({
    required DateTime? initial,
    required void Function(DateTime value) onPicked,
  }) async {
    final now = DateTime.now();
    final init = initial ?? DateTime(now.year, now.month, 1);

    final picked = await showDatePicker(
      context: context,
      initialDate: init,
      firstDate: DateTime(now.year - 2, 1, 1),
      lastDate: DateTime(now.year + 1, 12, 31),
      helpText: 'Pilih bulan & tahun',
      fieldHintText: 'dd/mm/yyyy',
      builder: (ctx, child) => Theme(data: Theme.of(ctx), child: child!),
    );
    if (picked == null) return;

    // kita ambil month-year saja (day diabaikan)
    final monthYear = DateTime(picked.year, picked.month, 1);
    onPicked(monthYear);
  }

  // ---- Advanced Filter (bottom sheet) ----
  Future<void> _openAdvancedFilter(ProductProvider prov) async {
    // pastikan data dropdown siap
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

    // apply filter
    setState(() {
      _filters = result;
      _storeId = result.storeLocationId;
      _syncStoreLabel();
    });

    // store wajib -> apply to provider dulu supaya backend fetch benar
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
            tooltip: 'History Stock Opname',
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

            final state = controller.value;

            void next() {
              final pm = provider.pageProducts;
              final cur = pm?.currentPage;
              final tot = pm?.totalPages;
              if (cur != null && tot != null && cur >= tot) return;
              controller.fetchNextPage();
            }

            // ✅ Top controls: Search + Filter button (akan dibuat sticky)
            final topControls = Padding(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _searchC,
                      onChanged: _onSearchChanged,
                      textInputAction: TextInputAction.search,
                      decoration: InputDecoration(
                        hintText: 'Cari nama atau SKU',
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
                ],
              ),
            );

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
                  // ✅ STICKY HEADER WAJIB ADA DI SINI
                  SliverPersistentHeader(
                    pinned: true,
                    delegate: _StickyHeaderDelegate(
                      height: stickyHeight,
                      builder: (context, overlaps) {
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
                                // ✅ INI SEARCH + FILTER (JANGAN KOSONG)
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
                                            onChanged: _onSearchChanged,
                                            textInputAction:
                                                TextInputAction.search,
                                            decoration: InputDecoration(
                                              hintText: 'Cari nama atau SKU',
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
                                          child: ElevatedButton(
                                            onPressed: () =>
                                                _openAdvancedFilter(provider),
                                            style: ElevatedButton.styleFrom(
                                              padding: EdgeInsets.zero,
                                              backgroundColor:
                                                  AppColors.blueButton,
                                              foregroundColor: Colors.white,
                                              shape: RoundedRectangleBorder(
                                                borderRadius:
                                                    BorderRadius.circular(10),
                                              ),
                                            ),
                                            child: const Icon(
                                              Icons.tune_rounded,
                                              size: 20,
                                            ),
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

                  // LIST
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
                                stockQty: p.totalStockQty,
                                onTap: () {
                                  AppSnackbar.show(
                                    context,
                                    type: AppSnackType.error,
                                    title: 'SKU tidak ditemukan',
                                    message: 'Produk ini tidak memiliki SKU.',
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
                                  stockQty: stock,
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
                                        title: 'Store wajib',
                                        message:
                                            'Pilih store location dulu di Filter.',
                                      );
                                      return;
                                    }

                                    if (skuId.trim().isEmpty) {
                                      AppSnackbar.show(
                                        context,
                                        type: AppSnackType.error,
                                        title: 'SKU tidak valid',
                                        message:
                                            'SKU ID tidak ditemukan untuk item ini.',
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

class _StickyHeaderDelegate extends SliverPersistentHeaderDelegate {
  final double height;
  final Widget Function(BuildContext context, bool overlapsContent) builder;

  const _StickyHeaderDelegate({required this.height, required this.builder});

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
    return oldDelegate.height != height;
  }
}

// =====================
// Filter model (tanpa date range)
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

  String toSearchString({String rawQuery = ''}) {
    final tokens = <String>[];
    final q = rawQuery.isNotEmpty ? rawQuery : (query ?? '');
    if (q.isNotEmpty) tokens.add('q:$q');
    if ((brandId ?? '').isNotEmpty) tokens.add('brand:$brandId');
    if ((categoryId ?? '').isNotEmpty) tokens.add('cat:$categoryId');
    if ((storeLocationId ?? '').isNotEmpty)
      tokens.add('store:$storeLocationId');

    // ✅ stock_opname_month = BULAN-TAHUN (token: MM-yyyy)
    if (stockOpnameMonth != null) {
      final token = DateFormat('MM-yyyy').format(stockOpnameMonth!);
      tokens.add('stock_opname_month:$token');
    }

    // ✅ stock_opname_status = SUDAH / BELUM
    if ((stockOpnameStatus ?? '').isNotEmpty) {
      tokens.add('stock_opname_status:${stockOpnameStatus!.trim()}');
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

  // store wajib
  String? _storeId;
  String? _storeName;
  String? _storeError;

  DateTime? _monthYear;
  String? _status; // "SUDAH" / "BELUM"

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
          _storeError = 'Store location wajib diisi';
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

  @override
  Widget build(BuildContext context) {
    final prov = context.watch<ProductProvider>();

    final brandOpts = prov.brands
        .map((b) => _PickerOption(id: b.idProductBrand, label: b.name))
        .toList();
    final catOpts = prov.categories
        .map((c) => _PickerOption(id: c.idProductCategory, label: c.name))
        .toList();

    final statusOpts = const [
      _PickerOption(id: 'SUDAH', label: 'SUDAH'),
      _PickerOption(id: 'BELUM', label: 'BELUM'),
    ];

    return DraggableScrollableSheet(
      initialChildSize: 0.88,
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
                        fontWeight: FontWeight.w900,
                        color: Color(0xFF111827),
                      ),
                    ),
                  ),
                  TextButton(
                    onPressed: () {
                      setState(() {
                        _brandId = null;
                        _categoryId = null;
                        _monthYear = null;
                        _status = null;
                      });
                    },
                    child: const Text(
                      'Reset',
                      style: TextStyle(color: Colors.black),
                    ),
                  ),
                  const SizedBox(width: 6),
                  ElevatedButton(
                    onPressed: () {
                      if (_storeId == null || _storeId!.isEmpty) {
                        setState(
                          () => _storeError = 'Store location wajib diisi',
                        );
                        return;
                      }

                      Navigator.pop(
                        context,
                        widget.initial.copyWith(
                          brandId: _brandId,
                          categoryId: _categoryId,
                          storeLocationId: _storeId,
                          stockOpnameMonth: _monthYear,
                          stockOpnameStatus: _status,
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
                      fontWeight: FontWeight.w900,
                      color: Color(0xFF111827),
                    ),
                  ),
                  const SizedBox(height: 8),
                  _SelectFieldTile(
                    placeholder: 'Pilih store…',
                    valueText: _storeName,
                    onTap: _pickStore,
                  ),
                  if ((_storeError ?? '').isNotEmpty) ...[
                    const SizedBox(height: 6),
                    Text(
                      _storeError!,
                      style: const TextStyle(color: Color(0xFFEF4444)),
                    ),
                  ],

                  const SizedBox(height: 18),

                  Row(
                    children: [
                      const Expanded(
                        child: Text(
                          'Month',
                          style: TextStyle(
                            fontWeight: FontWeight.w900,
                            color: Color(0xFF111827),
                          ),
                        ),
                      ),
                      if (_monthYear != null)
                        TextButton(
                          onPressed: () => setState(() => _monthYear = null),
                          child: const Text('Hapus'),
                        ),
                    ],
                  ),
                  InkWell(
                    onTap: () async {
                      await widget.onPickMonthYear(
                        _monthYear,
                        (picked) => setState(() => _monthYear = picked),
                      );
                    },
                    borderRadius: BorderRadius.circular(10),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 14,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF3F4F6),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: const Color(0xFFE5E7EB)),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              _monthYear == null
                                  ? 'Semua bulan'
                                  : widget.monthYearLabel(_monthYear),
                              style: TextStyle(
                                color: _monthYear == null
                                    ? const Color(0xFF9CA3AF)
                                    : const Color(0xFF111827),
                                fontWeight: _monthYear == null
                                    ? FontWeight.w500
                                    : FontWeight.w800,
                              ),
                            ),
                          ),
                          const Icon(
                            Icons.calendar_month_rounded,
                            color: Color(0xFF6B7280),
                            size: 18,
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 18),

                  Row(
                    children: [
                      const Expanded(
                        child: Text(
                          'Stock Opname Status by Month',
                          style: TextStyle(
                            fontWeight: FontWeight.w900,
                            color: Color(0xFF111827),
                          ),
                        ),
                      ),
                      if (_status != null)
                        TextButton(
                          onPressed: () => setState(() => _status = null),
                          child: const Text('Hapus'),
                        ),
                    ],
                  ),
                  _SelectFieldTile(
                    placeholder: 'Semua status',
                    valueText: _status,
                    onTap: () async {
                      final picked = await _pickOption(
                        title: 'Pilih Status',
                        options: statusOpts,
                        selectedId: _status,
                      );
                      if (!mounted) return;
                      setState(() => _status = picked);
                    },
                  ),

                  const SizedBox(height: 18),

                  Row(
                    children: [
                      const Expanded(
                        child: Text(
                          'Brand',
                          style: TextStyle(
                            fontWeight: FontWeight.w900,
                            color: Color(0xFF111827),
                          ),
                        ),
                      ),
                      if (_brandId != null)
                        TextButton(
                          onPressed: () => setState(() => _brandId = null),
                          child: const Text('Hapus'),
                        ),
                    ],
                  ),
                  _SelectFieldTile(
                    placeholder: 'Semua brand',
                    valueText: _brandName(prov, _brandId),
                    onTap: () async {
                      final picked = await _pickOption(
                        title: 'Pilih Brand',
                        options: brandOpts,
                        selectedId: _brandId,
                      );
                      if (!mounted) return;
                      setState(() => _brandId = picked);
                    },
                  ),

                  const SizedBox(height: 16),

                  Row(
                    children: [
                      const Expanded(
                        child: Text(
                          'Category',
                          style: TextStyle(
                            fontWeight: FontWeight.w900,
                            color: Color(0xFF111827),
                          ),
                        ),
                      ),
                      if (_categoryId != null)
                        TextButton(
                          onPressed: () => setState(() => _categoryId = null),
                          child: const Text('Hapus'),
                        ),
                    ],
                  ),
                  _SelectFieldTile(
                    placeholder: 'Semua category',
                    valueText: _categoryName(prov, _categoryId),
                    onTap: () async {
                      final picked = await _pickOption(
                        title: 'Pilih Category',
                        options: catOpts,
                        selectedId: _categoryId,
                      );
                      if (!mounted) return;
                      setState(() => _categoryId = picked);
                    },
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

// =====================
// Simple picker (search + radio) untuk Brand/Category/Status
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
                        onChanged: (q) => doFilter(setState, q),
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
// UI Components (SKU tiles & sheet qty)
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

/// Card SKU:
class _SkuTile extends StatelessWidget {
  const _SkuTile({
    required this.productName,
    required this.productImage,
    required this.skuCode,
    required this.stockQty,
    required this.onTap,
  });

  final String productName;
  final String productImage;
  final String skuCode;
  final int stockQty;
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
            'Stok',
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
        const Text('Gagal memuat data'),
        const SizedBox(height: 8),
        TextButton.icon(
          onPressed: onRetry,
          icon: const Icon(Icons.refresh),
          label: const Text('Coba lagi'),
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

/// Bottom sheet qty (tetap input qty saja)
class _StockOpnameQtySheet extends StatefulWidget {
  const _StockOpnameQtySheet({
    required this.storeId,
    required this.productId,
    required this.productSkuId,
    required this.productName,
    required this.productImage,
    required this.skuCode,
    required this.currentStock,
  });

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
      AppSnackbar.show(
        context,
        type: AppSnackType.success,
        title: 'Berhasil',
        message: 'Stock opname berhasil dibuat.',
      );
    } else {
      AppSnackbar.show(
        context,
        type: AppSnackType.error,
        title: 'Gagal',
        message: 'Gagal membuat stock opname. ${sp.lastError ?? ''}',
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final padBottom = MediaQuery.of(context).viewInsets.bottom;
    final isOut = widget.currentStock <= 0;

    return Padding(
      padding: EdgeInsets.only(bottom: padBottom),
      child: DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.70,
        minChildSize: 0.45,
        maxChildSize: 0.92,
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
              const SizedBox(height: 10),
              Expanded(
                child: SingleChildScrollView(
                  controller: controller,
                  padding: const EdgeInsets.fromLTRB(18, 8, 18, 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
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
                                  const SizedBox(height: 8),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 10,
                                      vertical: 6,
                                    ),
                                    decoration: BoxDecoration(
                                      color: isOut
                                          ? const Color(0xFFFFF1F2)
                                          : const Color(0xFFEFF6FF),
                                      borderRadius: BorderRadius.circular(999),
                                      border: Border.all(
                                        color: isOut
                                            ? const Color(0xFFFECACA)
                                            : const Color(0xFFDBEAFE),
                                      ),
                                    ),
                                    child: Text(
                                      'Stok saat ini: ${widget.currentStock}',
                                      style: TextStyle(
                                        color: isOut
                                            ? const Color(0xFFDC2626)
                                            : const Color(0xFF1F3D99),
                                        fontWeight: FontWeight.w900,
                                        fontSize: 12,
                                      ),
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
                              inputFormatters: [
                                FilteringTextInputFormatter.digitsOnly,
                              ],
                              decoration: InputDecoration(
                                isDense: true,
                                filled: true,
                                fillColor: const Color(0xFFF3F4F6),
                                hintText: 'Input qty stock opname',
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
                    ],
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 10, 16, 24),
                child: SizedBox(
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
                            'Buat Stock Opname',
                            style: TextStyle(fontWeight: FontWeight.w900),
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
