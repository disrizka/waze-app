import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import 'package:wa_blast/constants/app_colors.dart';
import 'package:wa_blast/l10n/app_localizations.dart';
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
  final _apiDateFmt = DateFormat('yyyy-MM-dd');
  final _filterDateFmt = DateFormat('dd MMM yyyy');

  final ScrollController _scroll = ScrollController();
  bool _isScrolled = false;

  String? _activeSkuId;
  _HistoryTypeFilter _typeFilter = _HistoryTypeFilter.all;
  _HistorySort _sort = _HistorySort.dateDesc;
  DateTime? _dateFrom;
  DateTime? _dateTo;

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

  String _skuLabel(ProductSku sku, {required String fallback}) {
    if (sku.code.isNotEmpty) return sku.code;
    final v = _primaryVariant(sku);
    if (v.isNotEmpty) return v;
    return fallback;
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
    final l10n = AppLocalizations.of(context)!;

    final result = await showPickerSheet<ProductSku>(
      context,
      title: l10n.stockHistorySelectSkuTitle,
      searchHint: l10n.stockHistorySelectSkuSearchHint,
      emptyMessage: l10n.stockHistorySelectSkuEmpty,
      selectedId: _activeSkuId,
      loadItems: () async {
        return widget.skus
            .map(
              (sku) => PickerResult<ProductSku>(
                id: sku.idProductSku,
                label: _skuLabel(sku, fallback: l10n.stockHistorySkuFallback),
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
      dateFrom: _dateFrom != null ? _apiDateFmt.format(_dateFrom!) : null,
      dateTo: _dateTo != null ? _apiDateFmt.format(_dateTo!) : null,
    );
  }

  String _dateText(DateTime? d, String fallback) {
    if (d == null) return fallback;
    return _filterDateFmt.format(d);
  }

  Future<DateTime?> _pickDate(
    BuildContext context, {
    required DateTime? initialDate,
    DateTime? firstDate,
    DateTime? lastDate,
    required String helpText,
  }) async {
    final now = DateTime.now();
    return showDatePicker(
      context: context,
      initialDate: initialDate ?? now,
      firstDate: firstDate ?? DateTime(now.year - 3, 1, 1),
      lastDate: lastDate ?? DateTime(now.year + 1, 12, 31),
      helpText: helpText,
      builder: (ctx, child) {
        final base = Theme.of(ctx);
        return Theme(
          data: base.copyWith(
            colorScheme: ColorScheme.fromSeed(
              seedColor: AppColors.primary,
              brightness: Brightness.light,
            ),
            datePickerTheme: DatePickerThemeData(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
              headerBackgroundColor: AppColors.primary,
              headerForegroundColor: Colors.white,
              backgroundColor: Colors.white,
            ),
          ),
          child: child!,
        );
      },
    );
  }

  Future<void> _openInfoOnboarding() async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => const _StockHistoryInfoScreen()),
    );
  }

  Future<void> _openAdvancedFilterSheet() async {
    final l10n = AppLocalizations.of(context)!;
    var nextType = _typeFilter;
    var nextSort = _sort;
    var nextDateFrom = _dateFrom;
    var nextDateTo = _dateTo;

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
                        Expanded(
                          child: Text(
                            l10n.stockHistoryFilterSheetTitle,
                            style: const TextStyle(
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
                            nextDateFrom = null;
                            nextDateTo = null;
                          }),
                          child: Text(
                            l10n.stockHistoryFilterReset,
                            style: const TextStyle(fontWeight: FontWeight.w700),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Text(
                      l10n.stockHistoryFilterTypeLabel,
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        color: AppColors.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 8,
                      children: [
                        _FilterChip(
                          label: l10n.stockHistoryFilterTypeAll,
                          selected: nextType == _HistoryTypeFilter.all,
                          onTap: () =>
                              setModal(() => nextType = _HistoryTypeFilter.all),
                        ),
                        _FilterChip(
                          label: l10n.stockHistoryFilterTypeIn,
                          selected: nextType == _HistoryTypeFilter.inStock,
                          onTap: () => setModal(
                            () => nextType = _HistoryTypeFilter.inStock,
                          ),
                        ),
                        _FilterChip(
                          label: l10n.stockHistoryFilterTypeOut,
                          selected: nextType == _HistoryTypeFilter.outStock,
                          onTap: () => setModal(
                            () => nextType = _HistoryTypeFilter.outStock,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    Text(
                      l10n.stockHistoryFilterSortLabel,
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        color: AppColors.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 8,
                      children: [
                        _FilterChip(
                          label: l10n.stockHistoryFilterNewest,
                          selected: nextSort == _HistorySort.dateDesc,
                          onTap: () =>
                              setModal(() => nextSort = _HistorySort.dateDesc),
                        ),
                        _FilterChip(
                          label: l10n.stockHistoryFilterOldest,
                          selected: nextSort == _HistorySort.dateAsc,
                          onTap: () =>
                              setModal(() => nextSort = _HistorySort.dateAsc),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    Text(
                      l10n.stockHistoryFilterDateLabel,
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        color: AppColors.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: _DateFilterField(
                            label: l10n.stockHistoryFilterDateFromLabel,
                            value: _dateText(
                              nextDateFrom,
                              l10n.stockHistoryFilterDatePickHint,
                            ),
                            active: nextDateFrom != null,
                            onTap: () async {
                              final picked = await _pickDate(
                                ctx,
                                initialDate: nextDateFrom ?? nextDateTo,
                                lastDate: nextDateTo,
                                helpText: l10n.stockHistoryFilterDatePickerHelp,
                              );
                              if (picked == null) return;
                              setModal(() {
                                nextDateFrom = DateTime(
                                  picked.year,
                                  picked.month,
                                  picked.day,
                                );
                                if (nextDateTo != null &&
                                    nextDateFrom!.isAfter(nextDateTo!)) {
                                  nextDateTo = nextDateFrom;
                                }
                              });
                            },
                            onClear: nextDateFrom == null
                                ? null
                                : () => setModal(() => nextDateFrom = null),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: _DateFilterField(
                            label: l10n.stockHistoryFilterDateToLabel,
                            value: _dateText(
                              nextDateTo,
                              l10n.stockHistoryFilterDatePickHint,
                            ),
                            active: nextDateTo != null,
                            onTap: () async {
                              final picked = await _pickDate(
                                ctx,
                                initialDate: nextDateTo ?? nextDateFrom,
                                firstDate: nextDateFrom,
                                helpText: l10n.stockHistoryFilterDatePickerHelp,
                              );
                              if (picked == null) return;
                              setModal(() {
                                nextDateTo = DateTime(
                                  picked.year,
                                  picked.month,
                                  picked.day,
                                );
                                if (nextDateFrom != null &&
                                    nextDateTo!.isBefore(nextDateFrom!)) {
                                  nextDateFrom = nextDateTo;
                                }
                              });
                            },
                            onClear: nextDateTo == null
                                ? null
                                : () => setModal(() => nextDateTo = null),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      children: [
                        _FilterChip(
                          label: l10n.stockHistoryFilterDatePresetLast7Days,
                          selected:
                              nextDateFrom != null &&
                              nextDateTo != null &&
                              DateTime(
                                        nextDateTo!.year,
                                        nextDateTo!.month,
                                        nextDateTo!.day,
                                      )
                                      .difference(
                                        DateTime(
                                          nextDateFrom!.year,
                                          nextDateFrom!.month,
                                          nextDateFrom!.day,
                                        ),
                                      )
                                      .inDays ==
                                  6,
                          onTap: () => setModal(() {
                            final now = DateTime.now();
                            nextDateTo = DateTime(now.year, now.month, now.day);
                            nextDateFrom = nextDateTo!.subtract(
                              const Duration(days: 6),
                            );
                          }),
                        ),
                        _FilterChip(
                          label: l10n.stockHistoryFilterDatePresetThisMonth,
                          selected:
                              nextDateFrom != null &&
                              nextDateTo != null &&
                              nextDateFrom!.day == 1 &&
                              nextDateFrom!.month == DateTime.now().month &&
                              nextDateFrom!.year == DateTime.now().year,
                          onTap: () => setModal(() {
                            final now = DateTime.now();
                            nextDateFrom = DateTime(now.year, now.month, 1);
                            nextDateTo = DateTime(now.year, now.month, now.day);
                          }),
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
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            child: Text(l10n.stockHistoryFilterCancel),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: ElevatedButton(
                            onPressed: () => Navigator.pop(ctx, true),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.primary,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            child: Text(l10n.stockHistoryFilterApply),
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
        _dateFrom = nextDateFrom;
        _dateTo = nextDateTo;
      });
      await _fetchSkuHistory();
    }
  }

  bool get _hasActiveFilter {
    return _typeFilter != _HistoryTypeFilter.all ||
        _sort != _HistorySort.dateDesc ||
        _dateFrom != null ||
        _dateTo != null;
  }

  Widget _qtyChip(
    int qty, {
    required String tooltipTitle,
    required String tooltipDesc,
    bool showSign = true,
    bool neutralStyle = false,
  }) {
    final isMinus = qty < 0;
    final base = neutralStyle
        ? const Color(0xFF9CA3AF)
        : (isMinus ? AppColors.danger : AppColors.success);
    final bg = neutralStyle
        ? const Color(0xFFF1F5F9)
        : base.withValues(alpha: 0.09);
    final border = neutralStyle
        ? const Color(0xFFE2E8F0)
        : base.withValues(alpha: 0.22);
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
        constraints: const BoxConstraints(minWidth: 58, maxWidth: 58),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 7),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: border),
        ),
        child: Center(
          child: Text(
            '${showSign ? (isMinus ? '' : '+') : ''}$qty',
            maxLines: 1,
            overflow: TextOverflow.fade,
            softWrap: false,
            style: TextStyle(
              color: base,
              fontWeight: FontWeight.w900,
              letterSpacing: 0.2,
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
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
          title: Text(
            l10n.stockHistoryTitle,
            style: const TextStyle(fontWeight: FontWeight.w800),
          ),
          actions: [
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: IconButton(
                tooltip: l10n.stockHistoryGuideTooltip,
                onPressed: _openInfoOnboarding,
                icon: const Icon(Icons.info_outline_rounded),
              ),
            ),
          ],
        ),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Text(
              l10n.stockHistoryNoSkuMessage,
              textAlign: TextAlign.center,
              style: const TextStyle(color: AppColors.textSecondary),
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
    final legacyPurchases =
        buckets?.purchases ?? const <InventoryHistoryItem>[];

    // Satu list transaksi (fallback ke schema lama jika perlu)
    final allItems =
        (txItems.isNotEmpty
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
        title: Text(
          l10n.stockHistoryTitle,
          style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 20),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: IconButton(
              tooltip: l10n.stockHistoryGuideTooltip,
              onPressed: _openInfoOnboarding,
              icon: const Icon(Icons.info_outline_rounded),
            ),
          ),
        ],
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
                    ? const Border(bottom: BorderSide(color: AppColors.border))
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
                                      sku != null
                                          ? _skuLabel(
                                              sku,
                                              fallback:
                                                  l10n.stockHistorySkuFallback,
                                            )
                                          : l10n.stockHistorySelectSkuTitle,
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
                              label: Text(l10n.stockHistoryFilterButton),
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
                                textStyle: const TextStyle(
                                  fontWeight: FontWeight.w700,
                                ),
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
                      skuCode: skuCode.isEmpty
                          ? l10n.stockHistorySkuFallback
                          : skuCode,
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
                  l10n: l10n,
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
          color: selected
              ? AppColors.primary.withOpacity(0.12)
              : AppColors.card,
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

class _DateFilterField extends StatelessWidget {
  const _DateFilterField({
    required this.label,
    required this.value,
    required this.active,
    required this.onTap,
    this.onClear,
  });

  final String label;
  final String value;
  final bool active;
  final VoidCallback onTap;
  final VoidCallback? onClear;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.fromLTRB(12, 10, 10, 10),
        decoration: BoxDecoration(
          color: active
              ? AppColors.primary.withValues(alpha: 0.08)
              : AppColors.card,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: active ? AppColors.primary : AppColors.border,
          ),
        ),
        child: Row(
          children: [
            const Icon(
              Icons.calendar_today_rounded,
              size: 16,
              color: AppColors.textSecondary,
            ),
            const SizedBox(width: 8),
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
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    value,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w700,
                      color: active ? AppColors.primary : AppColors.textPrimary,
                    ),
                  ),
                ],
              ),
            ),
            if (onClear != null)
              InkWell(
                onTap: onClear,
                borderRadius: BorderRadius.circular(999),
                child: const Padding(
                  padding: EdgeInsets.all(2),
                  child: Icon(
                    Icons.close_rounded,
                    size: 16,
                    color: AppColors.textSecondary,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _HistoryPane extends StatelessWidget {
  const _HistoryPane({
    required this.l10n,
    required this.items,
    required this.loading,
    required this.errorText,
    required this.dateFmt,
    required this.qtyChip,
    required this.fallName,
    required this.controller,
    required this.onRetry,
  });

  final AppLocalizations l10n;
  final List<InventoryHistoryItem> items;
  final bool loading;
  final String? errorText;
  final DateFormat dateFmt;
  final Widget Function(
    int, {
    required String tooltipTitle,
    required String tooltipDesc,
    bool showSign,
    bool neutralStyle,
  })
  qtyChip;
  final String fallName;
  final ScrollController controller;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    if (loading) {
      return const _FullPageLoader();
    }
    if (errorText != null && items.isEmpty) {
      return _FullPageError(l10n: l10n, onRetry: onRetry);
    }
    if (items.isEmpty) {
      return _EmptyState(
        icon: Icons.north_east,
        title: l10n.stockHistoryEmptyTitle,
        message: l10n.stockHistoryEmptyMessage,
        cta: l10n.stockHistoryEmptyCtaRefresh,
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
          _HistoryRow.header(monthFmt.format(DateTime(dt.year, dt.month))),
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
                  child: Divider(height: 1, color: AppColors.border),
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
        final txNumber = it.number.isNotEmpty
            ? it.number
            : (it.referenceId.isNotEmpty ? it.referenceId : '-');
        final t = it.type.toLowerCase();
        IconData icon = Icons.swap_horiz_rounded;
        Color color = AppColors.primary;
        String tooltipTitle = l10n.stockHistoryTooltipTransactionTitle;
        String tooltipDesc = l10n.stockHistoryTooltipTransactionDesc;
        if (t == 'sale' || t == 'sales' || t == 'out') {
          icon = Icons.south_west;
          color = AppColors.danger;
          tooltipTitle = l10n.stockHistoryTooltipSalesTitle;
          tooltipDesc = l10n.stockHistoryTooltipSalesDesc;
        } else if (t == 'purchase' || t == 'purchases' || t == 'in') {
          icon = Icons.north_east;
          color = AppColors.success;
          tooltipTitle = l10n.stockHistoryTooltipPurchaseTitle;
          tooltipDesc = l10n.stockHistoryTooltipPurchaseDesc;
        } else if (t == 'stock_opname' || t == 'stockopname') {
          icon = Icons.fact_check_rounded;
          color = AppColors.primary;
          tooltipTitle = l10n.stockHistoryTooltipStockOpnameTitle;
          tooltipDesc = l10n.stockHistoryTooltipStockOpnameDesc;
        } else if (t == 'stock_opname_adjustment') {
          icon = Icons.fact_check_rounded;
          color = AppColors.primary;
          tooltipTitle = l10n.stockHistoryTooltipStockOpnameAdjustmentTitle;
          tooltipDesc = l10n.stockHistoryTooltipStockOpnameAdjustmentDesc;
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
            titleIcon: Icons.calendar_today_rounded,
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                qtyChip(
                  it.qty,
                  tooltipTitle: l10n.stockHistoryTooltipQtyTitle,
                  tooltipDesc: l10n.stockHistoryTooltipQtyDesc,
                ),
                const SizedBox(width: 8),
                qtyChip(
                  it.balance,
                  tooltipTitle: l10n.stockHistoryTooltipBalanceTitle,
                  tooltipDesc: l10n.stockHistoryTooltipBalanceDesc,
                  showSign: false,
                  neutralStyle: true,
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

  const _HistoryRow.header(this.header) : item = null, isHeader = true;
  const _HistoryRow.item(this.item) : header = null, isHeader = false;
}

class _HistoryCard extends StatelessWidget {
  const _HistoryCard({
    required this.icon,
    required this.iconColor,
    required this.iconTooltipTitle,
    required this.iconTooltipDesc,
    required this.title,
    required this.subtitle,
    required this.titleIcon,
    required this.trailing,
    this.onTap,
  });

  final IconData icon;
  final Color iconColor;
  final String iconTooltipTitle;
  final String iconTooltipDesc;
  final String title;
  final String subtitle;
  final IconData titleIcon;
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
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 10,
                ),
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
                    Row(
                      children: [
                        Icon(
                          titleIcon,
                          size: 12,
                          color: AppColors.textSecondary,
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: AppColors.textSecondary,
                              fontWeight: FontWeight.w500,
                              fontSize: 11,
                              height: 1.15,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 5),
                    Text(
                      subtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 16,
                        color: AppColors.textPrimary,
                        fontWeight: FontWeight.w800,
                        height: 1.15,
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
    final l10n = AppLocalizations.of(context)!;
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
                        skuCode.isEmpty
                            ? l10n.stockHistorySkuFallback
                            : skuCode,
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
  const _FullPageError({required this.l10n, required this.onRetry});
  final AppLocalizations l10n;
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
            Text(
              l10n.stockHistoryErrorTitle,
              style: const TextStyle(
                color: AppColors.textPrimary,
                fontWeight: FontWeight.w800,
                fontSize: 16,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              l10n.stockHistoryErrorMessage,
              textAlign: TextAlign.center,
              style: const TextStyle(color: AppColors.textSecondary),
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
              label: Text(
                l10n.stockHistoryErrorRetry,
                style: const TextStyle(
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

class _StockHistoryInfoScreen extends StatefulWidget {
  const _StockHistoryInfoScreen();

  @override
  State<_StockHistoryInfoScreen> createState() =>
      _StockHistoryInfoScreenState();
}

class _StockHistoryInfoScreenState extends State<_StockHistoryInfoScreen> {
  final PageController _pageController = PageController();
  int _page = 0;

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _next() {
    if (_page >= 2) {
      Navigator.of(context).pop();
      return;
    }
    _pageController.nextPage(
      duration: const Duration(milliseconds: 280),
      curve: Curves.easeOutCubic,
    );
  }

  void _back() {
    if (_page <= 0) return;
    _pageController.previousPage(
      duration: const Duration(milliseconds: 240),
      curve: Curves.easeOutCubic,
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final slides = <_GuideSlideData>[
      _GuideSlideData(
        title: l10n.stockHistoryGuideSlide1Title,
        subtitle: l10n.stockHistoryGuideSlide1Subtitle,
        surfaceColor: const Color(0xFFEAF0FF),
        accentColor: AppColors.primary,
        illustration: _GuideIllustration(
          children: [
            _TypeBadge(
              icon: Icons.south_west_rounded,
              title: l10n.stockHistoryGuideSlide1BadgeSalesOutbound,
              color: AppColors.danger,
            ),
            _TypeBadge(
              icon: Icons.north_east_rounded,
              title: l10n.stockHistoryGuideSlide1BadgePurchaseInbound,
              color: AppColors.success,
            ),
            _TypeBadge(
              icon: Icons.fact_check_rounded,
              title: l10n.stockHistoryGuideSlide1BadgeStockOpname,
              color: AppColors.primary,
            ),
          ],
        ),
        points: [
          _GuidePoint(
            icon: Icons.south_west_rounded,
            text: l10n.stockHistoryGuideSlide1PointOutbound,
            color: AppColors.danger,
            tag: l10n.stockHistoryGuideTagOutbound,
          ),
          _GuidePoint(
            icon: Icons.north_east_rounded,
            text: l10n.stockHistoryGuideSlide1PointInbound,
            color: AppColors.success,
            tag: l10n.stockHistoryGuideTagInbound,
          ),
          _GuidePoint(
            icon: Icons.fact_check_rounded,
            text: l10n.stockHistoryGuideSlide1PointAdjustment,
            color: AppColors.primary,
            tag: l10n.stockHistoryGuideTagAdjustment,
          ),
        ],
      ),
      _GuideSlideData(
        title: l10n.stockHistoryGuideSlide2Title,
        subtitle: l10n.stockHistoryGuideSlide2Subtitle,
        surfaceColor: const Color(0xFFEAF7F3),
        accentColor: const Color(0xFF169873),
        illustration: _GuideIllustration(
          children: [
            _MiniInfoRow(
              icon: Icons.event_rounded,
              label: l10n.stockHistoryGuideSlide2SampleDate,
              hint: l10n.stockHistoryGuideSlide2DateHint,
            ),
            _MiniInfoRow(
              icon: Icons.tag_rounded,
              label: l10n.stockHistoryGuideSlide2SampleRef,
              hint: l10n.stockHistoryGuideSlide2ReferenceHint,
            ),
          ],
        ),
        points: [
          _GuidePoint(
            icon: Icons.schedule_rounded,
            text: l10n.stockHistoryGuideSlide2PointTimeline,
            color: Color(0xFF169873),
            tag: l10n.stockHistoryGuideTagTimeline,
          ),
          _GuidePoint(
            icon: Icons.confirmation_number_rounded,
            text: l10n.stockHistoryGuideSlide2PointReference,
            color: Color(0xFF0F766E),
            tag: l10n.stockHistoryGuideTagReference,
          ),
        ],
      ),
      _GuideSlideData(
        title: l10n.stockHistoryGuideSlide3Title,
        subtitle: l10n.stockHistoryGuideSlide3Subtitle,
        surfaceColor: const Color(0xFFFFF3EC),
        accentColor: const Color(0xFFDD6B20),
        illustration: _GuideIllustration(
          children: [
            _MetricBadgePreview(
              label: l10n.stockHistoryGuideSlide3BadgeBalanceLabel,
              value: '32',
              color: Color(0xFF9CA3AF),
              description: l10n.stockHistoryGuideSlide3BadgeBalanceDescription,
            ),
            _MetricBadgePreview(
              label: l10n.stockHistoryGuideSlide3BadgeQtyLabel,
              value: '+5',
              color: AppColors.success,
              description: l10n.stockHistoryGuideSlide3BadgeQtyDescription,
            ),
          ],
        ),
        points: [
          _GuidePoint(
            icon: Icons.balance_rounded,
            text: l10n.stockHistoryGuideSlide3PointEnding,
            color: Color(0xFF9CA3AF),
            tag: l10n.stockHistoryGuideTagEnding,
          ),
          _GuidePoint(
            icon: Icons.compare_arrows_rounded,
            text: l10n.stockHistoryGuideSlide3PointMovement,
            color: Color(0xFFDD6B20),
            tag: l10n.stockHistoryGuideTagMovement,
          ),
          _GuidePoint(
            icon: Icons.touch_app_rounded,
            text: l10n.stockHistoryGuideSlide3PointTip,
            color: AppColors.primary,
            tag: l10n.stockHistoryGuideTagTip,
          ),
        ],
      ),
    ];
    final active = slides[_page.clamp(0, slides.length - 1)];

    return Scaffold(
      backgroundColor: active.surfaceColor,
      appBar: AppBar(
        toolbarHeight: 72,
        elevation: 0,
        centerTitle: false,
        backgroundColor: active.surfaceColor,
        foregroundColor: AppColors.textPrimary,
        surfaceTintColor: active.surfaceColor,
        scrolledUnderElevation: 0,
        leadingWidth: 40,
        leading: IconButton(
          onPressed: () => Navigator.of(context).pop(),
          padding: const EdgeInsets.only(left: 8),
          constraints: const BoxConstraints(),
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 22),
        ),
        titleSpacing: 4,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              l10n.stockHistoryGuideAppbarTitle,
              style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 19),
            ),
            const SizedBox(height: 2),
            Text(
              l10n.stockHistoryGuideAppbarSubtitle,
              style: const TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w500,
                color: AppColors.textSecondary,
              ),
            ),
          ],
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
              child: PageView.builder(
                controller: _pageController,
                itemCount: slides.length,
                onPageChanged: (idx) => setState(() => _page = idx),
                itemBuilder: (_, i) => _GuideSlideCard(data: slides[i]),
              ),
            ),
          ),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
            decoration: const BoxDecoration(
              color: AppColors.white,
              border: Border(top: BorderSide(color: AppColors.border)),
            ),
            child: SafeArea(
              top: false,
              child: Row(
                children: [
                  Expanded(
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: List.generate(
                        slides.length,
                        (i) => AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          margin: const EdgeInsets.symmetric(horizontal: 4),
                          width: i == _page ? 26 : 8,
                          height: 8,
                          decoration: BoxDecoration(
                            color: i == _page
                                ? active.accentColor
                                : const Color(0xFFD7DCE5),
                            borderRadius: BorderRadius.circular(999),
                          ),
                        ),
                      ),
                    ),
                  ),
                  TextButton(
                    onPressed: _page == 0 ? null : _back,
                    child: Text(
                      l10n.stockHistoryGuideBack,
                      style: TextStyle(
                        color: _page == 0
                            ? AppColors.disabledFg
                            : AppColors.textSecondary,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton(
                    onPressed: _next,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: active.accentColor,
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
                    child: Text(
                      _page == slides.length - 1
                          ? l10n.stockHistoryGuideDone
                          : l10n.stockHistoryGuideNext,
                      style: const TextStyle(fontWeight: FontWeight.w800),
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

class _GuideSlideData {
  const _GuideSlideData({
    required this.title,
    required this.subtitle,
    required this.surfaceColor,
    required this.accentColor,
    required this.illustration,
    required this.points,
  });

  final String title;
  final String subtitle;
  final Color surfaceColor;
  final Color accentColor;
  final Widget illustration;
  final List<_GuidePoint> points;
}

class _GuidePoint {
  const _GuidePoint({
    required this.icon,
    required this.text,
    required this.color,
    this.tag,
  });

  final IconData icon;
  final String text;
  final Color color;
  final String? tag;
}

class _GuideSlideCard extends StatelessWidget {
  const _GuideSlideCard({required this.data});

  final _GuideSlideData data;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: const Color(0xFFD9DFEB)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x14000000),
            blurRadius: 14,
            offset: Offset(0, 6),
          ),
        ],
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          return SingleChildScrollView(
            physics: const ClampingScrollPhysics(),
            child: ConstrainedBox(
              constraints: BoxConstraints(minHeight: constraints.maxHeight),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  data.illustration,
                  const SizedBox(height: 16),
                  Container(
                    height: 4,
                    width: 56,
                    decoration: BoxDecoration(
                      color: data.accentColor,
                      borderRadius: BorderRadius.circular(999),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    data.title,
                    style: const TextStyle(
                      color: AppColors.textPrimary,
                      fontWeight: FontWeight.w800,
                      fontSize: 23,
                      height: 1.12,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    data.subtitle,
                    style: const TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      height: 1.35,
                    ),
                  ),
                  const SizedBox(height: 14),
                  ...data.points.map(
                    (point) => Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: _GuidePointTile(point: point),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

class _GuidePointTile extends StatelessWidget {
  const _GuidePointTile({required this.point});
  final _GuidePoint point;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(10, 9, 10, 9),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE5EAF1)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 24,
            height: 24,
            decoration: BoxDecoration(
              color: point.color.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(8),
            ),
            alignment: Alignment.center,
            child: Icon(point.icon, size: 14, color: point.color),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if ((point.tag ?? '').isNotEmpty) ...[
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 7,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: point.color.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      point.tag!,
                      style: TextStyle(
                        color: point.color,
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.2,
                      ),
                    ),
                  ),
                  const SizedBox(height: 4),
                ],
                Text(
                  point.text,
                  style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.w600,
                    fontSize: 12.6,
                    height: 1.25,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _GuideIllustration extends StatelessWidget {
  const _GuideIllustration({required this.children});
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFD),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE4E9F2)),
      ),
      child: Column(children: children),
    );
  }
}

class _TypeBadge extends StatelessWidget {
  const _TypeBadge({
    required this.icon,
    required this.title,
    required this.color,
  });

  final IconData icon;
  final String title;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(10),
            ),
            alignment: Alignment.center,
            child: Icon(icon, size: 20, color: color),
          ),
          const SizedBox(width: 10),
          Text(
            title,
            style: const TextStyle(
              color: AppColors.textPrimary,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

class _MiniInfoRow extends StatelessWidget {
  const _MiniInfoRow({
    required this.icon,
    required this.label,
    required this.hint,
  });

  final IconData icon;
  final String label;
  final String hint;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 16, color: AppColors.textSecondary),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  label,
                  style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            hint,
            style: const TextStyle(
              color: AppColors.textSecondary,
              fontSize: 12.5,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _MetricBadgePreview extends StatelessWidget {
  const _MetricBadgePreview({
    required this.label,
    required this.value,
    required this.color,
    required this.description,
  });

  final String label;
  final String value;
  final Color color;
  final String description;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(999),
              border: Border.all(color: color.withValues(alpha: 0.34)),
            ),
            child: Text(
              value,
              style: TextStyle(color: color, fontWeight: FontWeight.w900),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  description,
                  style: const TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
