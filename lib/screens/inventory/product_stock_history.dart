import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import 'package:wa_blast/constants/app_colors.dart';
import 'package:wa_blast/models/product_models/product_model.dart';
import 'package:wa_blast/providers/product_provider.dart';
import 'package:wa_blast/widgets/reusable_pickers.dart'; // showPickerSheet, PickerResult

/// ===================================================================
/// SCREEN: ProductSkuStockHistoryScreen
/// - Mirip StockSkuHistory, tapi bisa ganti SKU lewat bottom sheet
///   yang modelnya sama dengan reusable picker.
/// - Kamu kirim productName + list ProductSku ke sini.
/// ===================================================================

class ProductStockHistoryArgs {
  final String productName;
  final List<ProductSku> skus;
  final String? initialSkuId;

  ProductStockHistoryArgs({
    required this.productName,
    required this.skus,
    this.initialSkuId,
  });
}

enum _HistoryTypeFilter { all, inStock, outStock }
enum _HistorySort { dateDesc, dateAsc }

class ProductStockHistoryScreen extends StatefulWidget {
  final String productName;
  final List<ProductSku> skus;
  final String? initialSkuId;

  const ProductStockHistoryScreen({
    super.key,
    required this.productName,
    required this.skus,
    this.initialSkuId,
  });

  @override
  State<ProductStockHistoryScreen> createState() =>
      _ProductSkuStockHistoryScreenState();
}

class _ProductSkuStockHistoryScreenState
    extends State<ProductStockHistoryScreen> {
  final _money = NumberFormat.decimalPattern('id_ID');
  final _dateFmt = DateFormat('dd MMM yyyy • HH:mm');

  final ScrollController _scroll = ScrollController();
  bool _isScrolled = false;

  String? _activeSkuId;
  _HistoryTypeFilter _typeFilter = _HistoryTypeFilter.all;
  _HistorySort _sort = _HistorySort.dateDesc;

  ProductSku? get _activeSku {
    if (_activeSkuId == null) return null;
    try {
      return widget.skus.firstWhere((s) => s.idProductSku == _activeSkuId);
    } catch (_) {
      return widget.skus.isNotEmpty ? widget.skus.first : null;
    }
  }

  @override
  void initState() {
    super.initState();
    _activeSkuId =
        widget.initialSkuId ??
        (widget.skus.isNotEmpty ? widget.skus.first.idProductSku : null);

    _scroll.addListener(() {
      final next = _scroll.offset > 4;
      if (next != _isScrolled) {
        setState(() => _isScrolled = next);
      }
    });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      final skuId = _activeSkuId;
      if (skuId != null && skuId.isNotEmpty) {
        _fetchSkuHistory(skuId: skuId);
      }
    });
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  String _primaryVariant(ProductSku sku) {
    if (sku.attributes.isNotEmpty) {
      final a = sku.attributes.first;
      final name = (a.name).trim();
      final val = (a.value).trim();
      if (name.isNotEmpty && val.isNotEmpty) return '$name: $val';
      if (val.isNotEmpty) return val;
      if (name.isNotEmpty) return name;
    }
    return '';
  }

  String _skuLabel(ProductSku sku) {
    if (sku.code.isNotEmpty) return sku.code;
    final v = _primaryVariant(sku);
    if (v.isNotEmpty) return v;
    return 'SKU';
  }

  String _skuSubtitle(ProductSku sku) {
    final parts = <String>[];
    final v = _primaryVariant(sku);
    if (v.isNotEmpty) parts.add(v);
    parts.add('Rp ${_money.format(sku.price)}');
    return parts.join(' • ');
  }

  Future<void> _openSkuPicker() async {
    if (widget.skus.isEmpty) return;

    final result = await showPickerSheet<ProductSku>(
      context,
      title: 'Select SKU',
      searchHint: 'Search SKU or variant…',
      emptyMessage: 'No SKU for this product',
      selectedId: _activeSkuId,
      loadItems: () async {
        return widget.skus
            .map(
              (sku) => PickerResult<ProductSku>(
                id: sku.idProductSku,
                label: _skuLabel(sku),
                subtitle: _skuSubtitle(sku),
                data: sku,
              ),
            )
            .toList(growable: false);
      },
    );

    if (result != null && result.id != _activeSkuId) {
      setState(() {
        _activeSkuId = result.id;
      });

      await _fetchSkuHistory(skuId: result.id);
    }
  }

  String? _apiType() {
    switch (_typeFilter) {
      case _HistoryTypeFilter.inStock:
        return 'in';
      case _HistoryTypeFilter.outStock:
        return 'out';
      case _HistoryTypeFilter.all:
        return null;
    }
  }

  String? _apiSort() {
    return _sort == _HistorySort.dateAsc ? 'date_asc' : 'date_desc';
  }

  bool _isOutTxn(InventoryHistoryItem it) {
    final t = it.type.toLowerCase();
    if (it.qty < 0) return true;
    if (t == 'out' || t == 'sale' || t == 'sales') return true;
    return false;
  }

  bool _isInTxn(InventoryHistoryItem it) {
    final t = it.type.toLowerCase();
    if (it.qty > 0) return true;
    if (t == 'in' || t == 'purchase' || t == 'purchases') return true;
    return false;
  }

  Future<void> _fetchSkuHistory({String? skuId}) async {
    final id = skuId ?? _activeSkuId;
    if (id == null || id.isEmpty) return;
    await context.read<ProductProvider>().fetchSkuInventoryHistory(
      context: context,
      idProductSKU: id,
      typeFilter: _apiType(),
      sortBy: _apiSort(),
    );
  }

  Future<void> _openAdvancedFilterSheet() async {
    var nextType = _typeFilter;
    var nextSort = _sort;

    final res = await showModalBottomSheet<bool>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setModal) {
            return Container(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
              ),
              child: SafeArea(
                top: false,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Center(
                      child: Container(
                        width: 44,
                        height: 4,
                        decoration: BoxDecoration(
                          color: AppColors.border,
                          borderRadius: BorderRadius.circular(999),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        const Expanded(
                          child: Text(
                            'Advanced Filter',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w800,
                              color: AppColors.textPrimary,
                            ),
                          ),
                        ),
                        TextButton(
                          onPressed: () => setModal(() {
                            nextType = _HistoryTypeFilter.all;
                            nextSort = _HistorySort.dateDesc;
                          }),
                          child: const Text(
                            'Reset',
                            style: TextStyle(fontWeight: FontWeight.w700),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      'Type',
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        color: AppColors.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 8,
                      children: [
                        _FilterChip(
                          label: 'All',
                          selected: nextType == _HistoryTypeFilter.all,
                          onTap: () =>
                              setModal(() => nextType = _HistoryTypeFilter.all),
                        ),
                        _FilterChip(
                          label: 'In',
                          selected: nextType == _HistoryTypeFilter.inStock,
                          onTap: () => setModal(
                            () => nextType = _HistoryTypeFilter.inStock,
                          ),
                        ),
                        _FilterChip(
                          label: 'Out',
                          selected: nextType == _HistoryTypeFilter.outStock,
                          onTap: () => setModal(
                            () => nextType = _HistoryTypeFilter.outStock,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    const Text(
                      'Sort',
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        color: AppColors.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 8,
                      children: [
                        _FilterChip(
                          label: 'Newest',
                          selected: nextSort == _HistorySort.dateDesc,
                          onTap: () => setModal(
                            () => nextSort = _HistorySort.dateDesc,
                          ),
                        ),
                        _FilterChip(
                          label: 'Oldest',
                          selected: nextSort == _HistorySort.dateAsc,
                          onTap: () => setModal(
                            () => nextSort = _HistorySort.dateAsc,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () => Navigator.pop(ctx, false),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: AppColors.textPrimary,
                              side: const BorderSide(color: AppColors.border),
                              padding:
                                  const EdgeInsets.symmetric(vertical: 12),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            child: const Text('Cancel'),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: ElevatedButton(
                            onPressed: () => Navigator.pop(ctx, true),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.primary,
                              foregroundColor: Colors.white,
                              padding:
                                  const EdgeInsets.symmetric(vertical: 12),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            child: const Text('Apply'),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );

    if (res == true) {
      setState(() {
        _typeFilter = nextType;
        _sort = nextSort;
      });
      await _fetchSkuHistory();
    }
  }

  bool get _hasActiveFilter {
    return _typeFilter != _HistoryTypeFilter.all ||
        _sort != _HistorySort.dateDesc;
  }

  Widget _qtyChip(
    int qty, {
    required String tooltipTitle,
    required String tooltipDesc,
    bool showSign = true,
  }) {
    final isMinus = qty < 0;
    final base = isMinus ? AppColors.danger : AppColors.success;
    return Tooltip(
      triggerMode: TooltipTriggerMode.tap,
      showDuration: const Duration(seconds: 2),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      margin: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
        boxShadow: const [
          BoxShadow(
            blurRadius: 10,
            offset: Offset(0, 6),
            color: Color(0x22000000),
          ),
        ],
      ),
      richMessage: TextSpan(
        children: [
          TextSpan(
            text: '$tooltipTitle\n',
            style: const TextStyle(
              color: AppColors.textPrimary,
              fontWeight: FontWeight.w800,
              fontSize: 12.5,
              height: 1.2,
            ),
          ),
          TextSpan(
            text: tooltipDesc,
            style: const TextStyle(
              color: AppColors.textSecondary,
              fontWeight: FontWeight.w600,
              fontSize: 12,
              height: 1.2,
            ),
          ),
        ],
      ),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          color: base.withOpacity(0.09),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: base.withOpacity(0.22)),
        ),
        child: Text(
          '${showSign ? (isMinus ? '' : '+') : ''}$qty',
          style: TextStyle(
            color: base,
            fontWeight: FontWeight.w900,
            letterSpacing: 0.2,
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Kalau tidak ada SKU sama sekali
    if (widget.skus.isEmpty || _activeSkuId == null) {
      return Scaffold(
        backgroundColor: AppColors.white,
        appBar: AppBar(
          centerTitle: false,
          titleSpacing: 0,
          elevation: 0,
          backgroundColor: Colors.transparent,
          foregroundColor: AppColors.textPrimary,
          title: const Text(
            'Stock History',
            style: TextStyle(fontWeight: FontWeight.w800),
          ),
        ),
        body: const Center(
          child: Padding(
            padding: EdgeInsets.all(24),
            child: Text(
              'This product has no SKU yet.\nAdd SKU first to see stock history.',
              textAlign: TextAlign.center,
              style: TextStyle(color: AppColors.textSecondary),
            ),
          ),
        ),
      );
    }

    final activeSkuId = _activeSkuId!;
    final prov = context.watch<ProductProvider>();

    final buckets = prov.skuInventoryBuckets(activeSkuId);
    final loading = prov.isLoadingSkuHistory(activeSkuId);
    final err = prov.skuHistoryError(activeSkuId);

    final latest = prov.skuLatestCurrentStock(activeSkuId);
    final sku = _activeSku;

    final skuCode = (sku?.code.isNotEmpty == true)
        ? sku!.code
        : (latest?.productSku.code ?? '');

    final storeName = latest?.storeLocation.name ?? '';
    final lastUpdated = latest?.updatedAt ?? latest?.createdAt;
    final currentStock = latest == null ? '-' : latest.qty.toString();

    final txItems = buckets?.transactions ?? const <InventoryHistoryItem>[];
    final legacySales = buckets?.sales ?? const <InventoryHistoryItem>[];
    final legacyPurchases = buckets?.purchases ?? const <InventoryHistoryItem>[];

    // Satu list transaksi (fallback ke schema lama jika perlu)
    final allItems = (txItems.isNotEmpty
            ? List<InventoryHistoryItem>.from(txItems)
            : <InventoryHistoryItem>[...legacySales, ...legacyPurchases])
      ..sort((a, b) {
        final aDt = a.createdAt.isAfter(a.updatedAt)
            ? a.createdAt
            : a.updatedAt;
        final bDt = b.createdAt.isAfter(b.updatedAt)
            ? b.createdAt
            : b.updatedAt;
        return bDt.compareTo(aDt);
      });

    final filteredItems = allItems.where((it) {
      if (_typeFilter == _HistoryTypeFilter.inStock && !_isInTxn(it)) {
        return false;
      }
      if (_typeFilter == _HistoryTypeFilter.outStock && !_isOutTxn(it)) {
        return false;
      }
      return true;
    }).toList();

    filteredItems.sort((a, b) {
      final aDt = a.createdAt.isAfter(a.updatedAt) ? a.createdAt : a.updatedAt;
      final bDt = b.createdAt.isAfter(b.updatedAt) ? b.createdAt : b.updatedAt;
      return _sort == _HistorySort.dateAsc
          ? aDt.compareTo(bDt)
          : bDt.compareTo(aDt);
    });

    return Scaffold(
      backgroundColor: AppColors.white,
      appBar: AppBar(
        elevation: 0,
        centerTitle: false,
        titleSpacing: 0,
        backgroundColor: AppColors.white,
        foregroundColor: AppColors.textPrimary,
        surfaceTintColor: AppColors.white,
        scrolledUnderElevation: 0,
        // 🔹 Hanya judul, tanpa nama produk (nama produk dipindah ke hero band)
        title: const Text(
          'Stock History',
          style: TextStyle(fontWeight: FontWeight.w700, fontSize: 20),
        ),
      ),
      body: SafeArea(
        child: Column(
          children: [
            // === Selector SKU (pakai style mirip reusable picker) ===
            AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              curve: Curves.easeOut,
              decoration: BoxDecoration(
                color: AppColors.white,
                border: _isScrolled
                    ? const Border(
                        bottom: BorderSide(color: AppColors.border),
                      )
                    : null,
              ),
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
                    child: Row(
                      children: [
                        Expanded(
                          child: InkWell(
                            onTap: _openSkuPicker,
                            borderRadius: BorderRadius.circular(999),
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 14,
                                vertical: 10,
                              ),
                              decoration: BoxDecoration(
                                color: AppColors.card,
                                borderRadius: BorderRadius.circular(999),
                                border: Border.all(color: AppColors.border),
                              ),
                              child: Row(
                                children: [
                                  const Icon(
                                    Icons.qr_code_2,
                                    size: 18,
                                    color: AppColors.textSecondary,
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      sku != null ? _skuLabel(sku) : 'Select SKU',
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w600,
                                        color: AppColors.textPrimary,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 4),
                                  const Icon(
                                    Icons.keyboard_arrow_down_rounded,
                                    size: 18,
                                    color: AppColors.textSecondary,
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Stack(
                          clipBehavior: Clip.none,
                          children: [
                            OutlinedButton.icon(
                              onPressed: _openAdvancedFilterSheet,
                              icon: const Icon(Icons.tune_rounded, size: 18),
                              label: const Text('Filter'),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: AppColors.textPrimary,
                                side: const BorderSide(color: AppColors.border),
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 10,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(999),
                                ),
                                textStyle:
                                    const TextStyle(fontWeight: FontWeight.w700),
                              ),
                            ),
                            if (_hasActiveFilter)
                              Positioned(
                                right: 6,
                                top: 6,
                                child: Container(
                                  width: 10,
                                  height: 10,
                                  decoration: BoxDecoration(
                                    color: AppColors.primary,
                                    borderRadius: BorderRadius.circular(999),
                                    border: Border.all(
                                      color: Colors.white,
                                      width: 1.5,
                                    ),
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ],
                    ),
                  ),

                  // === HERO BAND (sekarang ada productName di dalam) ===
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
                    child: _HeroBand(
                      productName: widget.productName,
                      skuCode: skuCode.isEmpty ? 'SKU' : skuCode,
                      storeName: storeName,
                    ),
                  ),
                  const SizedBox(height: 12),
                ],
              ),
            ),

            // === LIST CONTENT ===
            Expanded(
              child: RefreshIndicator(
                color: AppColors.primary,
                backgroundColor: AppColors.white,
                onRefresh: () => _fetchSkuHistory(skuId: activeSkuId),
                child: _HistoryPane(
                  items: filteredItems,
                  loading: loading && filteredItems.isEmpty,
                  errorText: err?.toString(),
                  dateFmt: _dateFmt,
                  qtyChip: _qtyChip,
                  fallName: storeName,
                  controller: _scroll,
                  onRetry: () => _fetchSkuHistory(skuId: activeSkuId),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// ===================================================================
/// Helper UI (disalin dari stock_sku_history.dart supaya tampilan sama)
/// ===================================================================

Widget _metricTile(String label, String value, {IconData? icon}) {
  return Container(
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      color: AppColors.card,
      borderRadius: BorderRadius.circular(14),
      border: Border.all(color: AppColors.border),
      boxShadow: const [
        BoxShadow(
          blurRadius: 10,
          offset: Offset(0, 4),
          color: Color(0x0F000000),
        ),
      ],
    ),
    child: Row(
      children: [
        if (icon != null) ...[
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: AppColors.inputBackground,
              borderRadius: BorderRadius.circular(8),
            ),
            alignment: Alignment.center,
            child: Icon(icon, size: 18, color: AppColors.textSecondary),
          ),
          const SizedBox(width: 10),
        ],
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: const TextStyle(
                  fontSize: 11,
                  color: AppColors.textSecondary,
                  fontWeight: FontWeight.w600,
                  height: 1.1,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                value.isEmpty ? '-' : value,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: AppColors.textPrimary,
                  fontWeight: FontWeight.w800,
                  fontSize: 15,
                  height: 1.1,
                ),
              ),
            ],
          ),
        ),
      ],
    ),
  );
}

class _FilterChip extends StatelessWidget {
  const _FilterChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(999),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? AppColors.primary.withOpacity(0.12) : AppColors.card,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(
            color: selected ? AppColors.primary : AppColors.border,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontWeight: FontWeight.w700,
            color: selected ? AppColors.primary : AppColors.textPrimary,
          ),
        ),
      ),
    );
  }
}

class _HistoryPane extends StatelessWidget {
  const _HistoryPane({
    required this.items,
    required this.loading,
    required this.errorText,
    required this.dateFmt,
    required this.qtyChip,
    required this.fallName,
    required this.controller,
    required this.onRetry,
  });

  final List<InventoryHistoryItem> items;
  final bool loading;
  final String? errorText;
  final DateFormat dateFmt;
  final Widget Function(
    int, {
    required String tooltipTitle,
    required String tooltipDesc,
    bool showSign,
  }) qtyChip;
  final String fallName;
  final ScrollController controller;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    if (loading) {
      return const _FullPageLoader();
    }
    if (errorText != null && items.isEmpty) {
      return _FullPageError(onRetry: onRetry);
    }
    if (items.isEmpty) {
      return _EmptyState(
        icon: Icons.north_east,
        title: 'Belum ada transaksi',
        message: 'Catatan akan muncul di sini setelah ada transaksi.',
        cta: 'Tarik ke bawah untuk refresh',
      );
    }
    final monthFmt = DateFormat('MMMM yyyy');
    final rows = <_HistoryRow>[];
    String? activeKey;

    for (final it in items) {
      final dt = it.createdAt.isAfter(it.updatedAt)
          ? it.createdAt
          : it.updatedAt;
      final key = '${dt.year}-${dt.month}';
      if (key != activeKey) {
        rows.add(
          _HistoryRow.header(
            monthFmt.format(DateTime(dt.year, dt.month)),
          ),
        );
        activeKey = key;
      }
      rows.add(_HistoryRow.item(it));
    }

    return ListView.builder(
      controller: controller,
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
      itemCount: rows.length,
      itemBuilder: (_, i) {
        final row = rows[i];
        if (row.isHeader) {
          return Padding(
            padding: const EdgeInsets.only(top: 2, bottom: 10),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    row.header!,
                    style: const TextStyle(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w800,
                      color: AppColors.textSecondary,
                      letterSpacing: 0.2,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                const Expanded(
                  child: Divider(
                    height: 1,
                    color: AppColors.border,
                  ),
                ),
              ],
            ),
          );
        }

        final it = row.item!;
        final dt = it.createdAt.isAfter(it.updatedAt)
            ? it.createdAt
            : it.updatedAt;
        final when = dt.millisecondsSinceEpoch == 0
            ? '-'
            : dateFmt.format(dt.toLocal());
        final store = it.storeLocation.name.isNotEmpty
            ? it.storeLocation.name
            : fallName;
        final txNumber =
            it.number.isNotEmpty ? it.number : (it.referenceId.isNotEmpty ? it.referenceId : '-');
        final t = it.type.toLowerCase();
        IconData icon = Icons.swap_horiz_rounded;
        Color color = AppColors.primary;
        String tooltipTitle = 'Transaction';
        String tooltipDesc = 'General inventory movement.';
        if (t == 'sale' || t == 'sales' || t == 'out') {
          icon = Icons.south_west;
          color = AppColors.danger;
          tooltipTitle = 'Sales';
          tooltipDesc = 'Stock moved out due to a sale.';
        } else if (t == 'purchase' || t == 'purchases' || t == 'in') {
          icon = Icons.north_east;
          color = AppColors.success;
          tooltipTitle = 'Purchase';
          tooltipDesc = 'Stock moved in from a purchase.';
        } else if (t == 'stock_opname' || t == 'stockopname') {
          icon = Icons.fact_check_rounded;
          color = AppColors.primary;
          tooltipTitle = 'Stock Opname';
          tooltipDesc = 'Inventory check adjustment.';
        } else if (t == 'stock_opname_adjustment') {
          icon = Icons.fact_check_rounded;
          color = AppColors.primary;
          tooltipTitle = 'Stock Opname Adjustment';
          tooltipDesc = 'Adjustment from stock opname process.';
        }

        return Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: _HistoryCard(
            icon: icon,
            iconColor: color,
            iconTooltipTitle: tooltipTitle,
            iconTooltipDesc: tooltipDesc,
            title: when,
            subtitle: txNumber,
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                qtyChip(
                  it.balance,
                  tooltipTitle: 'Balance',
                  tooltipDesc: 'Stock balance after this transaction.',
                  showSign: false,
                ),
                const SizedBox(width: 8),
                qtyChip(
                  it.qty,
                  tooltipTitle: 'Qty',
                  tooltipDesc: 'Quantity moved in this transaction.',
                ),
              ],
            ),
            onTap: () {},
          ),
        );
      },
    );
  }
}

class _HistoryRow {
  final String? header;
  final InventoryHistoryItem? item;
  final bool isHeader;

  const _HistoryRow.header(this.header)
      : item = null,
        isHeader = true;
  const _HistoryRow.item(this.item)
      : header = null,
        isHeader = false;
}

class _HistoryCard extends StatelessWidget {
  const _HistoryCard({
    required this.icon,
    required this.iconColor,
    required this.iconTooltipTitle,
    required this.iconTooltipDesc,
    required this.title,
    required this.subtitle,
    required this.trailing,
    this.onTap,
  });

  final IconData icon;
  final Color iconColor;
  final String iconTooltipTitle;
  final String iconTooltipDesc;
  final String title;
  final String subtitle;
  final Widget trailing;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.white,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            color: AppColors.white,
            border: Border.all(color: AppColors.border),
            boxShadow: const [
              BoxShadow(
                blurRadius: 10,
                offset: Offset(0, 4),
                color: Color(0x0F000000),
              ),
            ],
          ),
          child: Row(
            children: [
              Tooltip(
                richMessage: TextSpan(
                  children: [
                    TextSpan(
                      text: '$iconTooltipTitle\n',
                      style: const TextStyle(
                        color: AppColors.textPrimary,
                        fontWeight: FontWeight.w800,
                        fontSize: 12.5,
                        height: 1.2,
                      ),
                    ),
                    TextSpan(
                      text: iconTooltipDesc,
                      style: const TextStyle(
                        color: AppColors.textSecondary,
                        fontWeight: FontWeight.w600,
                        fontSize: 12,
                        height: 1.2,
                      ),
                    ),
                  ],
                ),
                triggerMode: TooltipTriggerMode.tap,
                showDuration: const Duration(seconds: 2),
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                margin: const EdgeInsets.symmetric(horizontal: 16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.border),
                  boxShadow: const [
                    BoxShadow(
                      blurRadius: 10,
                      offset: Offset(0, 6),
                      color: Color(0x22000000),
                    ),
                  ],
                ),
                child: Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: iconColor.withOpacity(0.08),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  alignment: Alignment.center,
                  child: Icon(icon, size: 20, color: iconColor),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: AppColors.textPrimary,
                        fontWeight: FontWeight.w800,
                        fontSize: 15.5,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 12.5,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              trailing,
            ],
          ),
        ),
      ),
    );
  }
}

class _HeroBand extends StatelessWidget {
  const _HeroBand({
    required this.productName,
    required this.skuCode,
    required this.storeName,
  });

  final String productName;
  final String skuCode;
  final String storeName;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [AppColors.inputBackground, AppColors.white],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          // Avatar SKU / Product
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: AppColors.blueAccent.withOpacity(0.25),
              borderRadius: BorderRadius.circular(12),
            ),
            alignment: Alignment.center,
            child: const Icon(
              Icons.inventory_2_rounded,
              size: 24,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(width: 12),
          // Info utama
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 🔹 Nama produk (dipindah dari AppBar)
                Text(
                  productName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.w900,
                    fontSize: 16,
                  ),
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.card,
                        borderRadius: BorderRadius.circular(999),
                        border: Border.all(color: AppColors.border),
                      ),
                      child: Text(
                        skuCode.isEmpty ? 'SKU' : skuCode,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textPrimary,
                          height: 1.1,
                        ),
                      ),
                    ),
                    if (storeName.isNotEmpty) ...[
                      const SizedBox(width: 8),
                      Flexible(
                        child: Text(
                          storeName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 11.5,
                            color: AppColors.textSecondary,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({
    required this.icon,
    required this.title,
    required this.message,
    this.cta,
  });

  final IconData icon;
  final String title;
  final String message;
  final String? cta;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 32, 24, 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 44, color: AppColors.blue400),
            const SizedBox(height: 16),
            Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: AppColors.textPrimary,
                fontSize: 16.5,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(color: AppColors.textSecondary),
            ),
            if (cta != null) ...[
              const SizedBox(height: 12),
              Text(
                cta!,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 12,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _FullPageLoader extends StatelessWidget {
  const _FullPageLoader();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Padding(
        padding: EdgeInsets.all(24.0),
        child: CircularProgressIndicator(color: AppColors.primary),
      ),
    );
  }
}

class _FullPageError extends StatelessWidget {
  const _FullPageError({required this.onRetry});
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 24, 24, 48),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.history, size: 44, color: AppColors.blueButton),
            const SizedBox(height: 12),
            const Text(
              'Tidak ada riwayat',
              style: TextStyle(
                color: AppColors.textPrimary,
                fontWeight: FontWeight.w800,
                fontSize: 16,
              ),
            ),
            const SizedBox(height: 6),
            const Text(
              'Tekan tombol di bawah untuk memuat ulang.',
              textAlign: TextAlign.center,
              style: TextStyle(color: AppColors.textSecondary),
            ),
            const SizedBox(height: 14),
            ElevatedButton.icon(
              onPressed: onRetry,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.blueButton,
                foregroundColor: AppColors.white,
                elevation: 0,
                padding: const EdgeInsets.symmetric(
                  horizontal: 18,
                  vertical: 12,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              icon: const Icon(Icons.refresh, size: 18),
              label: const Text(
                'Coba lagi',
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.2,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
