// lib/screens/stock/stock_opname_form_screen.dart
import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:wa_blast/constants/app_colors.dart';
import 'package:wa_blast/models/product_models/product_model.dart';
import 'package:wa_blast/providers/product_provider.dart';
import 'package:wa_blast/providers/stock_provider.dart';
import 'package:wa_blast/providers/store_provider.dart' as st;

// ===============================
// STOCK OPNAME FORM SCREEN
// ===============================

class StockOpnameFormScreen extends StatefulWidget {
  /// Optional: kalau kamu sudah punya store terpilih dari screen sebelumnya.
  final String? initialStoreId;
  final String? initialStoreName;

  const StockOpnameFormScreen({
    super.key,
    this.initialStoreId,
    this.initialStoreName,
  });

  @override
  State<StockOpnameFormScreen> createState() => _StockOpnameFormScreenState();
}

class _StockOpnameFormScreenState extends State<StockOpnameFormScreen> {
  String? _storeId;
  String? _storeName;

  _PickedSku? _picked;

  final _qtyC = TextEditingController();
  final _noteC = TextEditingController();

  bool _submitting = false;
  bool _attempted = false;

  @override
  void initState() {
    super.initState();
    _storeId = widget.initialStoreId;
    _storeName = widget.initialStoreName;

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      await _autoSelectSingleStoreIfNeeded();
    });
  }

  @override
  void dispose() {
    _qtyC.dispose();
    _noteC.dispose();
    super.dispose();
  }

  Future<void> _autoSelectSingleStoreIfNeeded() async {
    if ((_storeId ?? '').isNotEmpty) return;

    final sp = context.read<st.StoreProvider>();
    if (sp.stores.isEmpty && !sp.loadingList) {
      await sp.fetchStoreLocations(context);
    }
    if (!mounted) return;

    if (sp.stores.length == 1) {
      final s = sp.stores.first;
      setState(() {
        _storeId = (s.idStoreLocation ?? '').toString();
        _storeName = (s.name ?? '').toString();
      });

      // optional: sinkronkan paging product ke store itu
      try {
        await context.read<ProductProvider>().setInfiniteStoreAndRefresh(
          context,
          _storeId!,
        );
      } catch (_) {}
    }
  }

  Future<void> _pickStore() async {
    final picked = await _showStorePickerSheet(context, selectedId: _storeId);
    if (picked == null || !mounted) return;

    setState(() {
      _storeId = picked.id;
      _storeName = picked.label;
      // reset pick sku kalau store berubah (biar ga nyangkut)
      _picked = null;
    });

    // sinkronkan filter product paging
    try {
      await context.read<ProductProvider>().setInfiniteStoreAndRefresh(
        context,
        picked.id,
      );
    } catch (_) {}
  }

  Future<void> _openProductSheet() async {
    if ((_storeId ?? '').isEmpty) {
      setState(() => _attempted = true);
      return;
    }

    final res = await openStockOpnameProductSheet(
      context,
      storeId: _storeId!,
      initiallyPicked: _picked,
    );

    if (!mounted || res == null) return;
    setState(() => _picked = res);
  }

  int _toInt(String s) {
    final digits = s.replaceAll('.', '').replaceAll(',', '').trim();
    return int.tryParse(digits) ?? 0;
  }

  bool get _canSubmit {
    final storeOk = (_storeId ?? '').isNotEmpty;
    final skuOk = _picked != null;
    final qtyOk = _toInt(_qtyC.text) >= 0; // stock opname boleh 0
    return storeOk && skuOk && qtyOk && !_submitting;
  }

  Future<void> _submit() async {
    setState(() => _attempted = true);
    if (!_canSubmit) return;

    final qty = _toInt(_qtyC.text);
    final note = _noteC.text.trim();

    setState(() => _submitting = true);
    try {
      final created = await context.read<StockProvider>().createStockOpname(
        context: context,
        idStoreLocation: _storeId!,
        productId: _picked!.productId,
        productSkuId: _picked!.skuId,
        qty: qty,
      );

      debugPrint('created=${created != null}');

      if (!mounted) return;

      if (created != null) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Stock opname saved.')));
        Navigator.of(
          context,
        ).pushNamedAndRemoveUntil('/stock/opname', (r) => false);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              context.read<StockProvider>().lastError ??
                  'Failed to save stock opname.',
            ),
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Failed: $e')));
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final money = NumberFormat.decimalPattern('id_ID');

    final storeErr = _attempted && ((_storeId ?? '').isEmpty)
        ? 'Required'
        : null;
    final productErr = _attempted && _picked == null ? 'Required' : null;

    return Scaffold(
      backgroundColor: _UI.bg,
      appBar: AppBar(
        title: const Text('Stock Opname'),
        elevation: 0,
        backgroundColor: Colors.white,
        foregroundColor: const Color(0xFF111827),
      ),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 980),
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
              children: [
                _Section(
                  titleWidget: Row(
                    children: [
                      const Icon(
                        Icons.store_mall_directory_outlined,
                        size: 18,
                        color: _UI.sub,
                      ),
                      const SizedBox(width: 8),
                      const Text('Store Location', style: _UI.tsSub),
                      const SizedBox(width: 8),
                      _RequiredPill(error: storeErr != null),
                    ],
                  ),
                  child: SelectFieldTile(
                    label: 'Choose a store',
                    valueText: _storeName,
                    emptyHint: 'Select store…',
                    onTap: _pickStore,
                    errorText: storeErr,
                  ),
                ),
                const SizedBox(height: 12),
                _Section(
                  titleWidget: Row(
                    children: [
                      const Icon(
                        Icons.inventory_2_outlined,
                        size: 18,
                        color: _UI.sub,
                      ),
                      const SizedBox(width: 8),
                      const Text('Product SKU', style: _UI.tsSub),
                      const SizedBox(width: 8),
                      _RequiredPill(error: productErr != null),
                      const Spacer(),
                      TextButton.icon(
                        onPressed: ((_storeId ?? '').isEmpty)
                            ? null
                            : _openProductSheet,
                        icon: const Icon(Icons.add_circle_outline, size: 18),
                        label: const Text(
                          'Pick',
                          style: TextStyle(fontWeight: FontWeight.w800),
                        ),
                        style: TextButton.styleFrom(
                          foregroundColor: AppColors.primary,
                        ),
                      ),
                    ],
                  ),
                  child: Column(
                    children: [
                      if (_picked == null)
                        SelectFieldTile(
                          label: 'Pick a product & SKU',
                          valueText: null,
                          emptyHint: 'Tap Pick to select…',
                          onTap: ((_storeId ?? '').isEmpty)
                              ? () {}
                              : _openProductSheet,
                          errorText: productErr,
                        )
                      else
                        _PickedSkuCard(
                          picked: _picked!,
                          onChange: _openProductSheet,
                          onClear: () => setState(() => _picked = null),
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                _Section(
                  titleWidget: Row(
                    children: const [
                      Icon(Icons.edit_note_outlined, size: 18, color: _UI.sub),
                      SizedBox(width: 8),
                      Text('Counted Stock', style: _UI.tsSub),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _LabeledField(
                        label: 'Actual quantity in store',
                        child: TextFormField(
                          controller: _qtyC,
                          keyboardType: TextInputType.number,
                          inputFormatters: [
                            FilteringTextInputFormatter.digitsOnly,
                          ],
                          decoration: InputDecoration(
                            hintText: 'e.g. 120',
                            isDense: true,
                            filled: true,
                            fillColor: const Color(0xFFF3F4F6),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: const BorderSide(color: _UI.line),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide(
                                color: _attempted && _qtyC.text.trim().isEmpty
                                    ? const Color(0xFFEF4444)
                                    : _UI.line,
                              ),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: const BorderSide(
                                color: AppColors.primary,
                              ),
                            ),
                          ),
                          onChanged: (_) => setState(() {}),
                        ),
                      ),
                      const SizedBox(height: 10),
                      if (_picked != null) ...[
                        const SizedBox(height: 10),
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: AppColors.background,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: AppColors.divider),
                          ),
                          child: Row(
                            children: [
                              const Icon(
                                Icons.info_outline,
                                size: 18,
                                color: _UI.sub,
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  'This will set the stock count for the selected SKU in this store.',
                                  style: _UI.tsSub.copyWith(fontSize: 12),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Text(
                                'Rp ${money.format(_picked!.price)}',
                                style: const TextStyle(
                                  fontWeight: FontWeight.w900,
                                  color: Color(0xFF0F172A),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
      bottomNavigationBar: SafeArea(
        top: false,
        minimum: const EdgeInsets.fromLTRB(16, 8, 16, 16),
        child: SizedBox(
          height: 50,
          child: FilledButton.icon(
            onPressed: _canSubmit ? _submit : null,
            icon: _submitting
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.save_rounded),
            label: Text(
              _submitting ? 'Saving…' : 'Save Stock Opname',
              style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15),
            ),
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              disabledBackgroundColor: const Color(0xFFE5E7EB),
              disabledForegroundColor: const Color(0xFF9CA3AF),
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ===============================
// STOCK OPNAME PRODUCT SHEET
// ===============================

Future<_PickedSku?> openStockOpnameProductSheet(
  BuildContext context, {
  required String storeId,
  _PickedSku? initiallyPicked,
}) async {
  final parent = context.read<ProductProvider>();

  return showModalBottomSheet<_PickedSku>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: Colors.white,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
    ),
    builder: (_) => ChangeNotifierProvider<ProductProvider>.value(
      value: parent,
      child: _StockOpnameProductSheet(
        storeId: storeId,
        initiallyPicked: initiallyPicked,
      ),
    ),
  );
}

class _StockOpnameProductSheet extends StatefulWidget {
  final String storeId;
  final _PickedSku? initiallyPicked;

  const _StockOpnameProductSheet({required this.storeId, this.initiallyPicked});

  @override
  State<_StockOpnameProductSheet> createState() =>
      _StockOpnameProductSheetState();
}

class _StockOpnameProductSheetState extends State<_StockOpnameProductSheet> {
  final _searchC = TextEditingController();
  final _gridScrollC = ScrollController();
  Timer? _debounce;
  bool _loadMoreArmed = false;
  bool _kicked = false;

  bool _canSellOutOfStock = false;
  bool _isFreePlan = false;

  ProductProvider? _pp;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _pp ??= Provider.of<ProductProvider>(context, listen: false);
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _kickOnOpen());
    _loadOutOfStockFlag();
    _loadPlanFlag();
  }

  Future<void> _loadPlanFlag() async {
    try {
      final prefs = await SharedPreferences.getInstance();

      bool isPremium = false;
      final direct = prefs.getBool('activeBizIsPremium');
      if (direct != null) {
        isPremium = direct == true;
      } else {
        final alt1 = prefs.getBool('isPremiumUser');
        if (alt1 != null) isPremium = alt1 == true;
      }

      if (!isPremium) {
        final activeBizId = (prefs.getString('activeBizId') ?? '').trim();
        final rawFull = (prefs.getString('business_full') ?? '').trim();

        if (activeBizId.isNotEmpty && rawFull.isNotEmpty) {
          try {
            final list = (jsonDecode(rawFull) as List);
            Map<String, dynamic>? found;

            for (final e in list) {
              if (e is Map<String, dynamic>) {
                final id = (e['idBusiness'] ?? '').toString();
                if (id == activeBizId) {
                  found = e;
                  break;
                }
              }
            }

            bool truthy(dynamic v) {
              if (v == null) return false;
              if (v is bool) return v;
              final s = v.toString().trim().toLowerCase();
              return s == '1' || s == 'true' || s == 'yes' || s == 'premium';
            }

            if (found != null) {
              final p1 = found['isPremium'];
              final p2 = found['premium'];
              final p3 = found['is_premium'];
              final p4 = found['premiumStatus'];

              final exp1 = found['premiumExpiresAt'];
              final exp2 = found['premium_expires_at'];

              isPremium =
                  truthy(p1) ||
                  truthy(p2) ||
                  truthy(p3) ||
                  truthy(p4) ||
                  ((exp1 != null && exp1.toString().trim().isNotEmpty) ||
                      (exp2 != null && exp2.toString().trim().isNotEmpty));
            }
          } catch (_) {}
        }
      }

      if (!mounted) return;
      setState(() => _isFreePlan = !isPremium);
    } catch (_) {
      if (!mounted) return;
      setState(() => _isFreePlan = false);
    }
  }

  Future<void> _loadOutOfStockFlag() async {
    try {
      final prefs = await SharedPreferences.getInstance();

      bool flag = prefs.getBool('activeBizCanSellOutOfStock') ?? false;

      if (!flag) {
        final activeBizId = prefs.getString('activeBizId');
        final rawFull = prefs.getString('business_full');
        if (activeBizId != null &&
            activeBizId.isNotEmpty &&
            rawFull != null &&
            rawFull.isNotEmpty) {
          try {
            final list = (jsonDecode(rawFull) as List);
            final Map<String, dynamic>? found = list
                .cast<Map<String, dynamic>?>()
                .firstWhere(
                  (e) => (e?['idBusiness'] ?? '').toString() == activeBizId,
                  orElse: () => null,
                );

            if (found != null) {
              flag =
                  (found['canBeSoldOutOfStock'] ??
                      found['canSellOutOfStock'] ??
                      false) ==
                  true;
            }
          } catch (_) {}
        }
      }

      if (!mounted) return;
      setState(() => _canSellOutOfStock = flag);
    } catch (_) {}
  }

  Future<void> _kickOnOpen() async {
    if (_kicked || !mounted) return;
    _kicked = true;

    final prov = context.read<ProductProvider>();

    // ✅ urutan aman: init dulu, baru set store
    prov.initInfinitePaging(context, initialSearch: '');

    try {
      await prov.setInfiniteStoreAndRefresh(context, widget.storeId);
    } catch (_) {}

    try {
      await prov
          .ensureDefaultStoreLocation(context)
          .timeout(const Duration(seconds: 6));
    } catch (_) {}

    try {
      await prov.refreshInfinite(context);
    } catch (_) {}

    prov.pagingController?.fetchNextPage();

    Future.delayed(const Duration(milliseconds: 250), () {
      if (!mounted) return;
      if (prov.products.isEmpty) prov.pagingController?.fetchNextPage();
    });

    if (mounted) setState(() {});
  }

  Future<void> _manualRetry() async {
    final prov = context.read<ProductProvider>();
    prov.initInfinitePaging(context, initialSearch: _searchC.text.trim());
    try {
      await prov.setInfiniteStoreAndRefresh(context, widget.storeId);
    } catch (_) {}
    await prov.refreshInfinite(context);
    prov.pagingController?.fetchNextPage();
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchC.dispose();
    _gridScrollC.dispose();
    super.dispose();
  }

  void _debouncedSearch(String raw) {
    final q = raw.trim();
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 250), () async {
      await _pp?.setInfiniteSearch(context, q);
      await _pp?.refreshInfinite(context);
      if (mounted) setState(() {});
    });
  }

  void _armLoadMore() {
    if (_loadMoreArmed) return;
    _loadMoreArmed = true;
    Future.delayed(const Duration(milliseconds: 200), () {
      _loadMoreArmed = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final prov = context.watch<ProductProvider>();
    final controller = prov.pagingController;

    final bool showStockUI = !_isFreePlan;
    final bool effectiveAllowOutOfStock = _isFreePlan
        ? true
        : _canSellOutOfStock;

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

    final visible = prov.products;

    final pm = prov.pageProducts;
    final bool isAtEnd = (pm?.currentPage != null && pm?.totalPages != null)
        ? (pm!.currentPage! >= pm.totalPages!)
        : prov.reachedEnd;

    return SafeArea(
      minimum: const EdgeInsets.fromLTRB(16, 12, 16, 16),
      child: SizedBox(
        height: MediaQuery.of(context).size.height * 0.90,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const _SheetHeader(
              title: 'Select Product',
              caption: 'Pick a product, then choose the exact SKU.',
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
                  await _pp?.setInfiniteSearch(context, _searchC.text.trim());
                  await _pp?.refreshInfinite(context);
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
                            await _pp?.setInfiniteSearch(context, '');
                            await _pp?.refreshInfinite(context);
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
              child: (visible.isEmpty)
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
                          final max = _gridScrollC.position.maxScrollExtent;
                          final cur = _gridScrollC.position.pixels;
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
                        controller: _gridScrollC,
                        padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),

                        // ✅ FIX: bikin cell lebih TINGGI biar ga overflow
                        gridDelegate:
                            const SliverGridDelegateWithFixedCrossAxisCount(
                              crossAxisCount: 2,
                              crossAxisSpacing: 12,
                              mainAxisSpacing: 12,
                              childAspectRatio:
                                  0.58, // <-- lebih tinggi dari 0.62/0.66
                            ),
                        itemCount: visible.length + (isAtEnd ? 0 : 1),
                        itemBuilder: (_, i) {
                          if (i >= visible.length) {
                            return const Center(
                              child: Padding(
                                padding: EdgeInsets.all(8),
                                child: CircularProgressIndicator(),
                              ),
                            );
                          }

                          final p = visible[i];
                          final g = _toGroup(p);

                          final bool isOut = showStockUI
                              ? (p.totalStockQty <= 0)
                              : false;
                          final bool hardBlock =
                              isOut && showStockUI && !effectiveAllowOutOfStock;

                          return AbsorbPointer(
                            absorbing: hardBlock,
                            child: Opacity(
                              opacity: hardBlock ? 0.6 : 1.0,
                              child: _StockProductCard(
                                group: g,
                                allowOutOfStock: effectiveAllowOutOfStock,
                                showStockUI: showStockUI,
                                onChoose: () async {
                                  final picked =
                                      await showModalBottomSheet<_PickedSku>(
                                        context: context,
                                        isScrollControlled: true,
                                        useSafeArea: true,
                                        backgroundColor: Colors.white,
                                        shape: const RoundedRectangleBorder(
                                          borderRadius: BorderRadius.vertical(
                                            top: Radius.circular(16),
                                          ),
                                        ),
                                        builder: (_) => _StockVariantSheet(
                                          group: g,
                                          allowOutOfStock:
                                              effectiveAllowOutOfStock,
                                          showStockUI: showStockUI,
                                        ),
                                      );

                                  if (!mounted || picked == null) return;
                                  Navigator.pop<_PickedSku>(context, picked);
                                },
                              ),
                            ),
                          );
                        },
                      ),
                    ),
            ),

            SafeArea(
              top: false,
              minimum: const EdgeInsets.only(top: 8),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                child: Text(
                  'Tip: Choose the exact SKU before saving stock opname.',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    color: AppColors.textSecondary,
                    fontSize: 12,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  _StockProductGroup _toGroup(Product p) {
    int minPriceOf(Product p) {
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

    return _StockProductGroup(
      product: p,
      productId: p.idProduct,
      productName: p.name,
      thumbUrl: p.primaryImageUrl,
      skus: p.productSkus,
      minPrice: minPriceOf(p),
    );
  }
}

// ===============================
// SHEET UI PIECES
// ===============================

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
                        fontWeight: FontWeight.w800,
                        fontSize: 16,
                        color: Colors.black87,
                      ),
                    ),
                    if (caption != null) ...[
                      const SizedBox(height: 4),
                      Text(
                        caption!,
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

class _StockProductGroup {
  final Product product;
  final String productId;
  final String productName;
  final String? thumbUrl;
  final List<ProductSku> skus;
  final int minPrice;

  _StockProductGroup({
    required this.product,
    required this.productId,
    required this.productName,
    required this.skus,
    required this.minPrice,
    this.thumbUrl,
  });
}

class _StockProductCard extends StatelessWidget {
  final _StockProductGroup group;
  final VoidCallback onChoose;
  final bool allowOutOfStock;
  final bool showStockUI;

  const _StockProductCard({
    required this.group,
    required this.onChoose,
    this.allowOutOfStock = false,
    this.showStockUI = true,
  });

  @override
  Widget build(BuildContext context) {
    final p = group.product;
    final name = group.productName;
    final thumb = group.thumbUrl;

    final bool isOut = showStockUI ? (p.totalStockQty <= 0) : false;
    final bool disabled = isOut && showStockUI && !allowOutOfStock;

    final Color stockColor = (showStockUI && isOut)
        ? const Color(0xFFEF4444)
        : const Color(0xFF475569);

    return LayoutBuilder(
      builder: (context, c) {
        // ✅ compact mode lebih agresif (biar aman di device kecil)
        final bool compact = c.maxHeight < 265;

        final double btnH = compact ? 30 : 34;
        final EdgeInsets infoPad = compact
            ? const EdgeInsets.fromLTRB(10, 6, 10, 8)
            : const EdgeInsets.fromLTRB(10, 8, 10, 10);

        final double titleSize = compact ? 13.0 : 13.5;
        final double rowSize = compact ? 11.5 : 12.0;

        return Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 4,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          clipBehavior: Clip.antiAlias,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              AspectRatio(
                aspectRatio: 1,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    if (thumb != null && thumb.isNotEmpty)
                      Image.network(
                        thumb,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => Container(
                          color: const Color(0xFFF3F4F6),
                          child: const Center(
                            child: Icon(Icons.image_outlined, size: 30),
                          ),
                        ),
                      )
                    else
                      Container(
                        color: const Color(0xFFF3F4F6),
                        child: const Center(
                          child: Icon(Icons.image_outlined, size: 30),
                        ),
                      ),

                    // ✅ overlay empty stock (collection-if)
                    if (showStockUI && isOut)
                      Container(
                        color: Colors.white.withOpacity(0.50),
                        alignment: Alignment.center,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 6,
                          ),
                          margin: const EdgeInsets.symmetric(horizontal: 10),
                          decoration: BoxDecoration(
                            color: Colors.black.withOpacity(0.65),
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: const Text(
                            'Empty Stock',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),

              // INFO
              Expanded(
                child: Padding(
                  padding: infoPad,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontWeight: FontWeight.w800,
                          color: const Color(0xFF0F172A),
                          fontSize: titleSize,
                          height: 1.10,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          const Icon(
                            Icons.layers_rounded,
                            size: 13,
                            color: Color(0xFF64748B),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            '${group.skus.length} SKU',
                            style: TextStyle(
                              fontSize: rowSize,
                              fontWeight: FontWeight.w800,
                              color: const Color(0xFF0F172A),
                            ),
                          ),
                          const Spacer(),
                          if (showStockUI) ...[
                            const Icon(
                              Icons.inventory_2_outlined,
                              size: 13,
                              color: Color(0xFF64748B),
                            ),
                            const SizedBox(width: 6),
                            Text(
                              '${p.totalStockQty}',
                              style: TextStyle(
                                fontSize: rowSize,
                                fontWeight: FontWeight.w900,
                                color: stockColor,
                              ),
                            ),
                          ],
                        ],
                      ),
                      const Spacer(),

                      // ✅ tombol dibuat lebih kecil + aman dari overflow
                      SizedBox(
                        width: double.infinity,
                        height: btnH,
                        child: ElevatedButton(
                          onPressed: disabled ? null : onChoose,
                          style: ElevatedButton.styleFrom(
                            elevation: 0,
                            backgroundColor: disabled
                                ? const Color(0xFFE5E7EB)
                                : const Color(0xFF4069E6),
                            foregroundColor: disabled
                                ? const Color(0xFF6B7280)
                                : Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            padding: EdgeInsets.zero,
                          ),
                          child: const Text(
                            'Choose',
                            style: TextStyle(
                              fontWeight: FontWeight.w800,
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
      },
    );
  }
}

// ===============================
// VARIANT/SKU PICK SHEET
// ===============================

class _StockVariantSheet extends StatefulWidget {
  final _StockProductGroup group;
  final bool allowOutOfStock;
  final bool showStockUI;

  const _StockVariantSheet({
    required this.group,
    this.allowOutOfStock = false,
    this.showStockUI = true,
  });

  @override
  State<_StockVariantSheet> createState() => _StockVariantSheetState();
}

class _StockVariantSheetState extends State<_StockVariantSheet> {
  final Map<String, String> _selected = {};
  late final Product _p;

  @override
  void initState() {
    super.initState();
    _p = widget.group.product;

    final attrsMap = _extractAttributes(_p.productSkus);
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

    final bool stockEnabled = widget.showStockUI;
    final bool allowOversell = stockEnabled ? widget.allowOutOfStock : true;

    final int displayStock = (matched?.stockQty ?? _p.totalStockQty);
    final bool nonPositive = displayStock <= 0;

    final Color stockColor = (stockEnabled && allowOversell && nonPositive)
        ? const Color(0xFFEF4444)
        : AppColors.textSecondary;

    final bool disabled = stockEnabled
        ? (allowOversell
              ? (matched == null)
              : (matched == null || displayStock <= 0))
        : (matched == null);

    final int basePrice = matched?.price ?? _p.basePrice ?? 0;

    return Container(
      color: Colors.white,
      child: SafeArea(
        minimum: const EdgeInsets.fromLTRB(16, 12, 16, 0),
        child: Column(
          children: [
            const _SheetHeader(
              title: 'Choose SKU',
              caption: 'Select the exact variant/SKU.',
            ),
            const SizedBox(height: 4),

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
                    child:
                        (_p.primaryImageUrl != null &&
                            _p.primaryImageUrl!.isNotEmpty)
                        ? Image.network(
                            _p.primaryImageUrl!,
                            width: 72,
                            height: 72,
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) => Container(
                              width: 72,
                              height: 72,
                              color: AppColors.greyBackground,
                              child: const Icon(
                                Icons.image,
                                color: AppColors.disabledFg,
                              ),
                            ),
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
                          'Rp ${money.format(basePrice)} / pcs',
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
                              color: AppColors.textSecondary,
                              fontSize: 12,
                            ),
                          ),
                        ],
                        if (stockEnabled) ...[
                          const SizedBox(height: 6),
                          Row(
                            children: [
                              const Icon(
                                Icons.inventory_2_outlined,
                                size: 16,
                                color: AppColors.textSecondary,
                              ),
                              const SizedBox(width: 6),
                              Text(
                                'Stock: $displayStock',
                                style: TextStyle(
                                  color: stockColor,
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

            Expanded(
              child: (attrsMap.isEmpty)
                  ? ListView(
                      children: const [
                        SizedBox(height: 8),
                        _InfoBox(
                          icon: Icons.tune_rounded,
                          text:
                              'This product has no variant attributes. You can select the SKU directly.',
                        ),
                        SizedBox(height: 300),
                      ],
                    )
                  : ListView(
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
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w900,
                                  ),
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
                                        borderRadius: BorderRadius.circular(
                                          999,
                                        ),
                                      ),
                                      selectedColor: AppColors.primary
                                          .withOpacity(.12),
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
                    onPressed: disabled
                        ? null
                        : () {
                            Navigator.pop<_PickedSku>(
                              context,
                              _PickedSku(
                                productId: _p.idProduct,
                                skuId: matched!.idProductSku,
                                productName: _p.name,
                                skuCode: matched.code,
                                price: matched.price,
                                thumbUrl: _p.primaryImageUrl ?? '',
                                stockQty: (matched.stockQty ?? 0), // ✅ aman
                                attributesText: _attrsText(matched),
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
                      (matched == null)
                          ? 'Select all variants'
                          : (stockEnabled &&
                                !widget.allowOutOfStock &&
                                displayStock <= 0)
                          ? 'Out of stock'
                          : 'Use this SKU',
                      style: const TextStyle(fontWeight: FontWeight.w900),
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

  String _attrsText(ProductSku sku) {
    if (sku.attributes.isEmpty) return '';
    return sku.attributes.map((a) => '${a.name}: ${a.value}').join(' • ');
  }

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

// ===============================
// PICKED RESULT MODEL + UI
// ===============================

class _PickedSku {
  final String productId;
  final String skuId;
  final String productName;
  final String skuCode;
  final int price;
  final String thumbUrl;
  final int stockQty;
  final String attributesText;

  const _PickedSku({
    required this.productId,
    required this.skuId,
    required this.productName,
    required this.skuCode,
    required this.price,
    required this.thumbUrl,
    required this.stockQty,
    required this.attributesText,
  });
}

class _PickedSkuCard extends StatelessWidget {
  final _PickedSku picked;
  final VoidCallback onChange;
  final VoidCallback onClear;

  const _PickedSkuCard({
    required this.picked,
    required this.onChange,
    required this.onClear,
  });

  @override
  Widget build(BuildContext context) {
    final money = NumberFormat.decimalPattern('id_ID');

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.divider),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0B000000),
            blurRadius: 16,
            offset: Offset(0, 6),
          ),
        ],
      ),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: (picked.thumbUrl.isNotEmpty)
                ? Image.network(
                    picked.thumbUrl,
                    width: 64,
                    height: 64,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => Container(
                      width: 64,
                      height: 64,
                      color: AppColors.greyBackground,
                      child: const Icon(
                        Icons.image,
                        color: AppColors.disabledFg,
                      ),
                    ),
                  )
                : Container(
                    width: 64,
                    height: 64,
                    color: AppColors.greyBackground,
                    child: const Icon(Icons.image, color: AppColors.disabledFg),
                  ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  picked.productName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontWeight: FontWeight.w900,
                    color: Color(0xFF0F172A),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  picked.skuCode,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF475569),
                    fontSize: 12,
                  ),
                ),
                if (picked.attributesText.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    picked.attributesText,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Color(0xFF64748B),
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
                const SizedBox(height: 6),
                Row(
                  children: [
                    Text(
                      'Rp ${money.format(picked.price)}',
                      style: const TextStyle(
                        fontWeight: FontWeight.w900,
                        color: Color(0xFF0F172A),
                      ),
                    ),
                    const Spacer(),
                    const Icon(
                      Icons.inventory_2_outlined,
                      size: 16,
                      color: AppColors.textSecondary,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      '${picked.stockQty}',
                      style: const TextStyle(
                        fontWeight: FontWeight.w900,
                        color: Color(0xFF0F172A),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          Column(
            children: [
              IconButton(
                onPressed: onChange,
                icon: const Icon(Icons.swap_horiz_rounded),
                tooltip: 'Change',
              ),
              IconButton(
                onPressed: onClear,
                icon: const Icon(Icons.close_rounded),
                tooltip: 'Clear',
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ===============================
// STORE PICKER (SELF-CONTAINED)
// ===============================

class PickerOption {
  final String id;
  final String label;
  final String? subtitle;
  const PickerOption({required this.id, required this.label, this.subtitle});
}

Future<PickerOption?> _showStorePickerSheet(
  BuildContext context, {
  String? selectedId,
}) async {
  final sp = context.read<st.StoreProvider>();
  if (sp.stores.isEmpty && !sp.loadingList) {
    await sp.fetchStoreLocations(context);
  }

  if (!context.mounted) return null;

  final stores = sp.stores;

  return showModalBottomSheet<PickerOption>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: Colors.transparent,
    builder: (ctx) {
      return Container(
        margin: const EdgeInsets.fromLTRB(12, 12, 12, 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          boxShadow: const [
            BoxShadow(
              color: Color(0x22000000),
              blurRadius: 18,
              offset: Offset(0, 10),
            ),
          ],
        ),
        clipBehavior: Clip.antiAlias,
        child: SafeArea(
          top: false,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 10),
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
                  const SizedBox(width: 16),
                  const Expanded(
                    child: Text(
                      'Choose Store',
                      style: TextStyle(
                        fontWeight: FontWeight.w900,
                        fontSize: 16,
                        color: Color(0xFF0F172A),
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(ctx),
                    icon: const Icon(Icons.close_rounded),
                  ),
                ],
              ),
              const Divider(height: 1, color: Color(0xFFE5E7EB)),
              Flexible(
                child: ListView.separated(
                  shrinkWrap: true,
                  padding: const EdgeInsets.fromLTRB(8, 8, 8, 12),
                  itemCount: stores.length,
                  separatorBuilder: (_, __) =>
                      const Divider(height: 1, color: Color(0xFFF3F4F6)),
                  itemBuilder: (_, i) {
                    final s = stores[i];
                    final id = (s.idStoreLocation ?? '').toString();
                    final name = (s.name ?? '').toString();
                    final isSel = id == selectedId;

                    return ListTile(
                      onTap: () =>
                          Navigator.pop(ctx, PickerOption(id: id, label: name)),
                      leading: Radio<String>(
                        value: id,
                        groupValue: selectedId,
                        onChanged: (_) => Navigator.pop(
                          ctx,
                          PickerOption(id: id, label: name),
                        ),
                      ),
                      title: Text(
                        name,
                        style: const TextStyle(
                          fontWeight: FontWeight.w800,
                          color: Color(0xFF0F172A),
                        ),
                      ),
                      trailing: isSel
                          ? const Icon(
                              Icons.check_circle,
                              color: AppColors.primary,
                            )
                          : null,
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      );
    },
  );
}

// ===============================
// GENERIC UI HELPERS
// ===============================

class _Section extends StatelessWidget {
  final String? title;
  final Widget? titleWidget;
  final Widget child;

  const _Section({this.title, this.titleWidget, required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: _UI.card,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _UI.line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (titleWidget != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: titleWidget!,
            )
          else if (title != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Text(title!, style: _UI.tsBody.copyWith(color: _UI.sub)),
            ),
          child,
        ],
      ),
    );
  }
}

class _RequiredPill extends StatelessWidget {
  final bool error;
  const _RequiredPill({required this.error});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: error ? const Color(0xFFFEE2E2) : AppColors.background,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(
          color: error ? const Color(0xFFEF4444) : AppColors.blueAccent,
        ),
      ),
      child: Text(
        'Required',
        style: TextStyle(
          color: error ? const Color(0xFFB91C1C) : AppColors.blue,
          fontWeight: FontWeight.w800,
          fontSize: 11,
        ),
      ),
    );
  }
}

class _InfoBox extends StatelessWidget {
  final IconData icon;
  final String text;
  const _InfoBox({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.divider),
      ),
      child: Row(
        children: [
          Icon(icon, color: AppColors.textSecondary),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(
                color: AppColors.textSecondary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _LabeledField extends StatelessWidget {
  final String label;
  final Widget child;
  const _LabeledField({required this.label, required this.child});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontWeight: FontWeight.w800,
            color: Color(0xFF0F172A),
          ),
        ),
        const SizedBox(height: 6),
        child,
      ],
    );
  }
}

class SelectFieldTile extends StatelessWidget {
  final String label;
  final String? valueText;
  final String emptyHint;
  final VoidCallback onTap;
  final String? errorText;

  const SelectFieldTile({
    super.key,
    required this.label,
    required this.valueText,
    required this.emptyHint,
    required this.onTap,
    this.errorText,
  });

  @override
  Widget build(BuildContext context) {
    final hasValue = (valueText != null && valueText!.trim().isNotEmpty);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontWeight: FontWeight.w700,
            color: Color(0xFF111827),
          ),
        ),
        const SizedBox(height: 8),
        InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
            decoration: BoxDecoration(
              color: const Color(0xFFF3F4F6),
              borderRadius: BorderRadius.circular(12),
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
                    hasValue ? valueText! : emptyHint,
                    style: TextStyle(
                      color: hasValue
                          ? const Color(0xFF111827)
                          : const Color(0xFF9CA3AF),
                      fontWeight: hasValue ? FontWeight.w800 : FontWeight.w600,
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
            style: const TextStyle(
              color: Color(0xFFEF4444),
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ],
    );
  }
}

// ===============================
// LOCAL THEME TOKENS
// ===============================

class _UI {
  static const Color bg = Color(0xFFF7FAFF);
  static const Color card = Colors.white;
  static const Color line = Color(0xFFE5E7EB);
  static const Color text = Color(0xFF0F172A);
  static const Color sub = Color(0xFF64748B);

  static const TextStyle tsSub = TextStyle(
    fontWeight: FontWeight.w800,
    color: sub,
    fontSize: 13,
  );

  static const TextStyle tsBody = TextStyle(
    fontWeight: FontWeight.w700,
    color: text,
    fontSize: 14,
  );
}
