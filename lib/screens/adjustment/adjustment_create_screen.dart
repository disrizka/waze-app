import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import 'package:wa_blast/constants/app_colors.dart';
import 'package:wa_blast/models/product_model.dart';
import 'package:wa_blast/providers/adjustment_provider.dart';
import 'package:wa_blast/providers/product_provider.dart';
import 'package:wa_blast/providers/store_provider.dart' as st;
import 'package:wa_blast/widgets/reusable_pickers.dart';

class AdjustmentCreateScreen extends StatefulWidget {
  const AdjustmentCreateScreen({super.key});

  @override
  State<AdjustmentCreateScreen> createState() => _AdjustmentCreateScreenState();
}

class _AdjustmentCreateScreenState extends State<AdjustmentCreateScreen> {
  final TextEditingController _notesC = TextEditingController();

  String? _storeLocationId;
  String? _storeLocationName;

  final List<_AdjSelectedItem> _items = [];
  bool _booted = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => _autoSelectSingleStoreIfNeeded(),
    );
  }

  @override
  void dispose() {
    _notesC.dispose();
    super.dispose();
  }

  Future<void> _autoSelectSingleStoreIfNeeded() async {
    if (!mounted) return;
    if (_booted) return;
    _booted = true;

    final sp = context.read<st.StoreProvider>();
    if (sp.stores.isEmpty && !sp.loadingList) {
      await sp.fetchStoreLocations(context);
    }
    if (!mounted) return;

    if (sp.stores.length == 1) {
      final s = sp.stores.first;
      setState(() {
        _storeLocationId = s.idStoreLocation;
        _storeLocationName = s.name;
      });

      try {
        await context.read<ProductProvider>().setInfiniteStoreAndRefresh(
          context,
          s.idStoreLocation,
        );
      } catch (_) {}
    }
  }

  Future<void> _pickStore() async {
    final picked = await showStorePickerSheet(
      context,
      autoSelectWhenSingle: true,
      selectedId: _storeLocationId,
    );
    if (picked == null || !mounted) return;

    setState(() {
      _storeLocationId = picked.id;
      _storeLocationName = picked.label;
    });

    try {
      await context.read<ProductProvider>().setInfiniteStoreAndRefresh(
        context,
        picked.id,
      );
    } catch (_) {}
  }

  Future<void> _openAddProductSheet() async {
    if ((_storeLocationId ?? '').isEmpty) {
      _showToastSheet(
        title: 'Pilih store dulu',
        message: 'Store location wajib dipilih sebelum menambahkan produk.',
        icon: Icons.store_mall_directory_outlined,
      );
      return;
    }

    final res = await openAdjustmentAddProductSheet(
      context,
      initialStoreId: _storeLocationId!,
    );

    if (!mounted || res == null || res.isEmpty) return;

    setState(() {
      for (final picked in res) {
        final idx = _items.indexWhere((x) => x.skuId == picked.skuId);
        if (idx >= 0) {
          // ✅ qty 0 boleh: jangan dihapus
          _items[idx] = _items[idx].copyWith(qty: _items[idx].qty + picked.qty);
        } else {
          // ✅ qty 0 boleh: tetap add
          _items.add(picked);
        }
      }
    });
  }

  void _removeItem(String skuId) {
    setState(() {
      _items.removeWhere((x) => x.skuId == skuId);
    });
  }

  void _setQty(String skuId, int qty) {
    setState(() {
      final i = _items.indexWhere((x) => x.skuId == skuId);
      if (i >= 0) {
        // ✅ qty 0 boleh: jangan remove
        _items[i] = _items[i].copyWith(qty: qty);
      }
    });
  }

  Future<void> _submit() async {
    final storeId = (_storeLocationId ?? '').trim();
    if (storeId.isEmpty) {
      _showToastSheet(
        title: 'Store belum dipilih',
        message: 'Silakan pilih store location terlebih dahulu.',
        icon: Icons.store_mall_directory_outlined,
      );
      return;
    }

    // ✅ qty 0 dianggap valid: asal item tidak kosong
    if (_items.isEmpty) {
      _showToastSheet(
        title: 'Item masih kosong',
        message: 'Tambahkan minimal 1 SKU.',
        icon: Icons.playlist_add_rounded,
      );
      return;
    }

    final ok = await _confirmSubmit();
    if (!ok) return;

    final prov = context.read<AdjustmentProvider>();

    final payloadItems = _items
        .map(
          (e) => CreateAdjustmentItemPayload(
            productId: e.productId,
            productSkuId: e.skuId,
            qty: e.qty, // ✅ 0 juga boleh dikirim
          ),
        )
        .toList();

    final success = await prov.createAdjustment(
      context: context,
      storeLocationId: storeId,
      note: _notesC.text.trim(),
      items: payloadItems,
      refreshListAfter: true,
      refreshLimit: 30,
    );

    if (!mounted) return;

    if (success) {
      Navigator.pop<bool>(context, true);
      return;
    }

    _showToastSheet(
      title: 'Gagal membuat adjustment',
      message:
          prov.createAdjustmentError ?? prov.lastError ?? 'Terjadi kesalahan.',
      icon: Icons.error_outline_rounded,
    );
  }

  Future<bool> _confirmSubmit() async {
    return (await showDialog<bool>(
          context: context,
          barrierDismissible: false,
          builder: (_) {
            return AlertDialog(
              title: const Text('Submit Adjustment?'),
              content: const Text(
                'Please double-check your items and quantities before submitting. This action will create a new adjustment transaction.',
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context, false),
                  child: const Text('Cancel'),
                ),
                FilledButton(
                  onPressed: () => Navigator.pop(context, true),
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                  ),
                  child: const Text('Submit'),
                ),
              ],
            );
          },
        )) ??
        false;
  }

  void _showToastSheet({
    required String title,
    required String message,
    required IconData icon,
  }) {
    showModalBottomSheet(
      context: context,
      useSafeArea: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
      ),
      builder: (_) {
        return Padding(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 44,
                height: 4,
                decoration: BoxDecoration(
                  color: const Color(0xFFE5E7EB),
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Container(
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(
                      color: const Color(0xFFF3F4F6),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: const Color(0xFFE5E7EB)),
                    ),
                    child: Icon(icon, color: const Color(0xFF111827)),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      title,
                      style: const TextStyle(
                        fontWeight: FontWeight.w900,
                        fontSize: 16,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  message,
                  style: const TextStyle(
                    color: Color(0xFF6B7280),
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              const SizedBox(height: 14),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: () => Navigator.pop(context),
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                  child: const Text(
                    'OK',
                    style: TextStyle(fontWeight: FontWeight.w800),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  int get _netQtySum => _items.fold<int>(0, (s, e) => s + e.qty);

  @override
  Widget build(BuildContext context) {
    final creating = context.watch<AdjustmentProvider>().creatingAdjustment;

    final storeNotSelected = (_storeLocationId ?? '').isEmpty;
    final itemCount = _items.length;
    final canSubmit = !creating && !storeNotSelected && itemCount > 0;

    return Scaffold(
      backgroundColor: const Color(0xFFF6F7FB),
      appBar: AppBar(
        backgroundColor: Colors.white,
        scrolledUnderElevation: 0,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded),
          onPressed: () => Navigator.pop(context),
        ),
        title: Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment:
              CrossAxisAlignment.baseline, // ⬅️ ini pakai CrossAxisAlignment
          textBaseline:
              TextBaseline.alphabetic, // ⬅️ ini baru pakai TextBaseline
          children: const [
            Text(
              'Adjustment Stock',
              style: TextStyle(fontWeight: FontWeight.w800),
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
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
              children: [
                _Section(
                  titleWidget: Row(
                    children: [
                      const Icon(
                        Icons.store_mall_directory_outlined,
                        size: 18,
                        color: Color(0xFF6B7280),
                      ),
                      const SizedBox(width: 8),
                      const Text(
                        'Store Location',
                        style: TextStyle(
                          fontWeight: FontWeight.w800,
                          color: Color(0xFF374151),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFFEFF6FF),
                          borderRadius: BorderRadius.circular(999),
                          border: Border.all(color: const Color(0xFFBFDBFE)),
                        ),
                        child: const Text(
                          'Wajib',
                          style: TextStyle(
                            color: Color(0xFF1D4ED8),
                            fontWeight: FontWeight.w900,
                            fontSize: 11,
                          ),
                        ),
                      ),
                    ],
                  ),
                  child: _SelectFieldTile(
                    label: 'Choose a store',
                    valueText: _storeLocationName,
                    emptyHint: 'Select store…',
                    onTap: _pickStore,
                  ),
                ),
                const SizedBox(height: 12),
                _Section(
                  titleWidget: Row(
                    children: [
                      const Icon(
                        Icons.playlist_add_rounded,
                        size: 18,
                        color: Color(0xFF6B7280),
                      ),
                      const SizedBox(width: 8),
                      const Text(
                        'Items',
                        style: TextStyle(
                          fontWeight: FontWeight.w800,
                          color: Color(0xFF374151),
                        ),
                      ),
                      const Spacer(),
                      TextButton.icon(
                        onPressed: _openAddProductSheet,
                        icon: const Icon(Icons.add_rounded, size: 18),
                        label: const Text(
                          'Add',
                          style: TextStyle(fontWeight: FontWeight.w900),
                        ),
                        style: TextButton.styleFrom(
                          foregroundColor: AppColors.primary,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 8,
                          ),
                          minimumSize: Size.zero,
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        ),
                      ),
                    ],
                  ),
                  child: _items.isEmpty
                      ? Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF9FAFB),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: const Color(0xFFE5E7EB)),
                          ),
                          child: Row(
                            children: const [
                              Icon(
                                Icons.inventory_2_outlined,
                                color: Color(0xFF6B7280),
                              ),
                              SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  'Belum ada item. Tekan "Add" untuk memilih SKU.',
                                  style: TextStyle(
                                    color: Color(0xFF6B7280),
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        )
                      : Column(
                          children: _items.map((it) {
                            return Padding(
                              padding: const EdgeInsets.only(bottom: 10),
                              child: _SelectedItemCard(
                                item: it,
                                onRemove: () => _removeItem(it.skuId),
                                onQtyChanged: (q) => _setQty(it.skuId, q),
                              ),
                            );
                          }).toList(),
                        ),
                ),
                const SizedBox(height: 12),
                _Section(
                  titleWidget: Row(
                    children: const [
                      Icon(
                        Icons.note_alt_outlined,
                        size: 18,
                        color: Color(0xFF6B7280),
                      ),
                      SizedBox(width: 8),
                      Text(
                        'Notes',
                        style: TextStyle(
                          fontWeight: FontWeight.w800,
                          color: Color(0xFF374151),
                        ),
                      ),
                    ],
                  ),
                  child: TextFormField(
                    controller: _notesC,
                    decoration: InputDecoration(
                      hintText: 'Catatan (opsional) untuk adjustment ini...',
                      isDense: true,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: AppColors.primary),
                      ),
                    ),
                    maxLines: 3,
                  ),
                ),
              ],
            ),
          ),
          Container(
            decoration: const BoxDecoration(
              color: Colors.white,
              border: Border(top: BorderSide(color: Color(0xFFE5E7EB))),
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
              child: Column(
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          '$itemCount SKU • Net qty: ${_fmtSigned(_netQtySum)}',
                          style: const TextStyle(
                            color: Color(0xFF6B7280),
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      if (creating) const SizedBox(width: 10),
                      if (creating)
                        const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      onPressed: canSubmit ? _submit : null,
                      style: FilledButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        textStyle: const TextStyle(
                          fontWeight: FontWeight.w900,
                          fontSize: 15,
                        ),
                      ),
                      child: Text(
                        creating ? 'Submitting...' : 'Submit Adjustment',
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

/// ===============================
/// Add Product Bottom Sheet (Infinite + Variant Picker + Multi-select)
/// ===============================

Future<List<_AdjSelectedItem>?> openAdjustmentAddProductSheet(
  BuildContext context, {
  required String initialStoreId,
}) async {
  return showModalBottomSheet<List<_AdjSelectedItem>>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: Colors.white,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
    ),
    builder: (_) => _AdjustmentAddProductSheet(initialStoreId: initialStoreId),
  );
}

class _AdjustmentAddProductSheet extends StatefulWidget {
  final String initialStoreId;
  const _AdjustmentAddProductSheet({required this.initialStoreId});

  @override
  State<_AdjustmentAddProductSheet> createState() =>
      _AdjustmentAddProductSheetState();
}

class _AdjustmentAddProductSheetState
    extends State<_AdjustmentAddProductSheet> {
  final TextEditingController _searchC = TextEditingController();
  final ScrollController _gridScrollC = ScrollController();
  Timer? _debounce;
  bool _loadMoreArmed = false;
  bool _kicked = false;

  // selected in sheet
  final Map<String, _AdjSelectedItem> _pickedBySkuId = {};

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
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchC.dispose();
    _gridScrollC.dispose();
    super.dispose();
  }

  Future<void> _kickOnOpen() async {
    if (_kicked || !mounted) return;
    _kicked = true;

    final prov = context.read<ProductProvider>();
    prov.initInfinitePaging(context, initialSearch: '');

    try {
      await prov.setInfiniteStoreAndRefresh(context, widget.initialStoreId);
    } catch (_) {}

    await prov.refreshInfinite(context);
    prov.pagingController?.fetchNextPage();

    Future.delayed(const Duration(milliseconds: 280), () {
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
    try {
      await prov.setInfiniteStoreAndRefresh(context, widget.initialStoreId);
    } catch (_) {}
    await prov.refreshInfinite(context);
    prov.pagingController?.fetchNextPage();
    if (mounted) setState(() {});
  }

  void _armLoadMore() {
    if (_loadMoreArmed) return;
    _loadMoreArmed = true;
    Future.delayed(const Duration(milliseconds: 200), () {
      _loadMoreArmed = false;
    });
  }

  void _debouncedSearch(String raw) {
    final q = raw.trim();
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 250), () async {
      await _pp?.setInfiniteSearch(context, q);
      await _pp?.refreshInfinite(context);
      _pp?.pagingController?.fetchNextPage();
      if (_gridScrollC.hasClients) _gridScrollC.jumpTo(0);
    });
  }

  // ✅ qty 0 ikut dihitung sebagai item terpilih
  int get _pickedSkuCount => _pickedBySkuId.length;

  int get _pickedNetQtySum =>
      _pickedBySkuId.values.fold<int>(0, (s, e) => s + e.qty);

  @override
  Widget build(BuildContext context) {
    final prov = context.watch<ProductProvider>();
    final controller = prov.pagingController;

    if (controller == null) {
      return SafeArea(
        minimum: const EdgeInsets.fromLTRB(16, 12, 16, 16),
        child: SizedBox(
          height: 260,
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

    final all = prov.products;
    final pm = prov.pageProducts;
    final bool isAtEnd = (pm?.currentPage != null && pm?.totalPages != null)
        ? (pm!.currentPage! >= pm.totalPages!)
        : prov.reachedEnd;

    return SafeArea(
      minimum: const EdgeInsets.fromLTRB(16, 10, 16, 12),
      child: SizedBox(
        height: MediaQuery.of(context).size.height * 0.92,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const _SheetHeader(title: 'Select Products'),
            const SizedBox(height: 10),
            Material(
              elevation: 0,
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              child: TextField(
                controller: _searchC,
                textInputAction: TextInputAction.search,
                onSubmitted: (_) async {
                  final q = _searchC.text.trim();
                  await _pp?.setInfiniteSearch(context, q);
                  await _pp?.refreshInfinite(context);
                  _pp?.pagingController?.fetchNextPage();
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
                            _pp?.pagingController?.fetchNextPage();
                            if (mounted) setState(() {});
                          },
                          icon: const Icon(Icons.close_rounded),
                        ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: AppColors.divider),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: AppColors.divider),
                  ),
                  isDense: true,
                ),
              ),
            ),
            const SizedBox(height: 10),
            Expanded(
              child: (all.isEmpty)
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
                        padding: const EdgeInsets.fromLTRB(8, 6, 8, 10),
                        gridDelegate:
                            const SliverGridDelegateWithFixedCrossAxisCount(
                              crossAxisCount: 2,
                              crossAxisSpacing: 12,
                              mainAxisSpacing: 12,
                              mainAxisExtent: 270,
                            ),
                        itemCount: all.length + (isAtEnd ? 0 : 1),
                        itemBuilder: (_, i) {
                          if (i >= all.length) {
                            return const Center(
                              child: Padding(
                                padding: EdgeInsets.all(8),
                                child: CircularProgressIndicator(),
                              ),
                            );
                          }
                          final p = all[i];

                          final selectedNetForProduct = _pickedBySkuId.values
                              .where((x) => x.productId == p.idProduct)
                              .fold<int>(0, (s, e) => s + e.qty);

                          return _ProductCardFixed(
                            product: p,
                            selectedNet: selectedNetForProduct,
                            onChoose: () async {
                              final picked =
                                  await showModalBottomSheet<_AdjSelectedItem>(
                                    context: context,
                                    isScrollControlled: true,
                                    useSafeArea: true,
                                    backgroundColor: Colors.white,
                                    shape: const RoundedRectangleBorder(
                                      borderRadius: BorderRadius.vertical(
                                        top: Radius.circular(18),
                                      ),
                                    ),
                                    builder: (_) =>
                                        _VariantPickerSheet(product: p),
                                  );

                              if (!mounted || picked == null) return;

                              setState(() {
                                final exist = _pickedBySkuId[picked.skuId];
                                if (exist != null) {
                                  // ✅ qty 0 boleh: jangan remove
                                  _pickedBySkuId[picked.skuId] = exist.copyWith(
                                    qty: exist.qty + picked.qty,
                                  );
                                } else {
                                  // ✅ qty 0 boleh: tetap simpan
                                  _pickedBySkuId[picked.skuId] = picked;
                                }
                              });
                            },
                          );
                        },
                      ),
                    ),
            ),
            SafeArea(
              top: false,
              minimum: const EdgeInsets.only(top: 8),
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(12, 8, 12, 6),
                    child: Text(
                      (_pickedSkuCount > 0)
                          ? '$_pickedSkuCount SKU • Net qty: ${_fmtSigned(_pickedNetQtySum)}'
                          : 'Pilih produk lalu tentukan variannya',
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        color: AppColors.textSecondary,
                        fontSize: 12,
                      ),
                    ),
                  ),
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: FilledButton.icon(
                      onPressed: () {
                        // ✅ qty 0 ikut dikembalikan
                        final list = _pickedBySkuId.values.toList();
                        Navigator.pop<List<_AdjSelectedItem>>(context, list);
                      },
                      icon: const Icon(Icons.check_rounded, size: 22),
                      label: const Text('Use selected'),
                      style: FilledButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                        textStyle: const TextStyle(
                          fontWeight: FontWeight.w900,
                          fontSize: 16,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// ===============================
/// Variant Picker Sheet (choose SKU + signed qty)
/// ===============================

class _VariantPickerSheet extends StatefulWidget {
  final Product product;
  const _VariantPickerSheet({required this.product});

  @override
  State<_VariantPickerSheet> createState() => _VariantPickerSheetState();
}

class _VariantPickerSheetState extends State<_VariantPickerSheet> {
  final Map<String, String> _selected = {}; // name -> value
  int _qty = 1; // signed. minus => OUT, plus => IN (0 sekarang boleh)

  @override
  void initState() {
    super.initState();
    final attrsMap = _extractAttributes(widget.product.productSkus);
    for (final e in attrsMap.entries) {
      if (e.value.length == 1) _selected[e.key] = e.value.first;
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = widget.product;
    final attrsMap = _extractAttributes(p.productSkus);

    ProductSku? matched;
    for (final s in p.productSkus) {
      if (_isSkuMatch(s, _selected, requiredCount: attrsMap.length)) {
        matched = s;
        break;
      }
    }

    final skuCode = matched?.code ?? '-';
    final imageUrl = (p.primaryImageUrl ?? '').trim();

    // ✅ qty 0 boleh
    final canConfirm = matched != null;

    return SafeArea(
      minimum: const EdgeInsets.fromLTRB(16, 10, 16, 0),
      child: SizedBox(
        height: MediaQuery.of(context).size.height * 0.92,
        child: Column(
          children: [
            _PSheetHeader(title: 'Choose Variants', caption: p.name),
            const SizedBox(height: 6),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFFE5E7EB)),
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
                  SafeNetImage(
                    url: imageUrl.isEmpty ? null : imageUrl,
                    width: 72,
                    height: 72,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          p.name,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontWeight: FontWeight.w900),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          skuCode,
                          style: const TextStyle(
                            color: AppColors.textSecondary,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 10),
                        const Text(
                          'Tip: gunakan minus untuk OUT, plus untuk IN',
                          style: TextStyle(
                            fontSize: 12,
                            color: Color(0xFF6B7280),
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Expanded(
              child: ListView(
                children: attrsMap.entries.map((e) {
                  final attrName = e.key;
                  final values = e.value.toList()..sort();
                  final selectedVal = _selected[attrName];

                  return Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: _PSection(
                      title: attrName,
                      child: Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: values.map((val) {
                          final isSel = selectedVal == val;
                          final enabled = _isValueEnabled(
                            attrName,
                            val,
                            _selected,
                            p.productSkus,
                          );
                          return ChoiceChip(
                            label: Text(val),
                            selected: isSel,
                            onSelected: enabled
                                ? (_) =>
                                      setState(() => _selected[attrName] = val)
                                : null,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(999),
                            ),
                            selectedColor: AppColors.primary.withOpacity(.12),
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
                    ),
                  );
                }).toList(),
              ),
            ),
            Container(
              decoration: const BoxDecoration(
                color: Colors.white,
                border: Border(top: BorderSide(color: Color(0xFFE5E7EB))),
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
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Quantity (signed)',
                          style: TextStyle(fontWeight: FontWeight.w900),
                        ),
                        _SignedQtyPill(
                          value: _qty,
                          onMinus: () => setState(() => _qty = _qty - 1),
                          onPlus: () => setState(() => _qty = _qty + 1),
                          onTyped: (v) => setState(() => _qty = v),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton(
                        onPressed: canConfirm
                            ? () {
                                final sku = matched!;
                                Navigator.pop<_AdjSelectedItem>(
                                  context,
                                  _AdjSelectedItem(
                                    productId: p.idProduct,
                                    productName: p.name,
                                    imageUrl: p.primaryImageUrl ?? '',
                                    skuId: sku.idProductSku,
                                    skuCode: sku.code,
                                    qty: _qty, // ✅ 0 boleh
                                  ),
                                );
                              }
                            : null,
                        style: FilledButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                        ),
                        child: Text(
                          (matched == null)
                              ? 'Pilih semua varian'
                              : 'Add item (${_fmtSigned(_qty)})',
                          style: const TextStyle(fontWeight: FontWeight.w900),
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
/// UI Widgets
/// ===============================

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
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE5E7EB)),
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
          if (titleWidget != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: titleWidget!,
            )
          else if (title != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Text(
                title!,
                style: const TextStyle(
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF6B7280),
                ),
              ),
            ),
          child,
        ],
      ),
    );
  }
}

class _SelectFieldTile extends StatelessWidget {
  final String label;
  final String? valueText;
  final String emptyHint;
  final VoidCallback onTap;

  const _SelectFieldTile({
    required this.label,
    required this.valueText,
    required this.emptyHint,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final hasValue = (valueText ?? '').trim().isNotEmpty;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        decoration: BoxDecoration(
          color: const Color(0xFFF9FAFB),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFFE5E7EB)),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: const TextStyle(
                      color: Color(0xFF6B7280),
                      fontWeight: FontWeight.w700,
                      fontSize: 12,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    hasValue ? valueText! : emptyHint,
                    style: TextStyle(
                      fontWeight: FontWeight.w900,
                      color: hasValue
                          ? const Color(0xFF111827)
                          : const Color(0xFF9CA3AF),
                    ),
                  ),
                ],
              ),
            ),
            const Icon(Icons.expand_more_rounded, color: Color(0xFF9CA3AF)),
          ],
        ),
      ),
    );
  }
}

class _SelectedItemCard extends StatelessWidget {
  final _AdjSelectedItem item;
  final VoidCallback onRemove;
  final void Function(int qty) onQtyChanged;

  const _SelectedItemCard({
    required this.item,
    required this.onRemove,
    required this.onQtyChanged,
  });

  @override
  Widget build(BuildContext context) {
    final isNeg = item.qty < 0;
    final chipColor = isNeg ? const Color(0xFFFEE2E2) : const Color(0xFFDCFCE7);
    final chipFg = isNeg ? const Color(0xFF991B1B) : const Color(0xFF166534);

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFF9FAFB),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Row(
        children: [
          SafeNetImage(
            url: item.imageUrl.isEmpty ? null : item.imageUrl,
            width: 54,
            height: 54,
            borderRadius: BorderRadius.circular(14),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.productName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontWeight: FontWeight.w900),
                ),
                const SizedBox(height: 3),
                Text(
                  item.skuCode,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: AppColors.textSecondary,
                    fontWeight: FontWeight.w700,
                    fontSize: 12,
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: chipColor,
                        borderRadius: BorderRadius.circular(999),
                        border: Border.all(color: chipColor.withOpacity(.85)),
                      ),
                      child: Text(
                        _fmtSigned(item.qty),
                        style: TextStyle(
                          fontWeight: FontWeight.w900,
                          fontSize: 12,
                          color: chipFg,
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    const Expanded(
                      child: Text(
                        'Minus = OUT, Plus = IN',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: Color(0xFF6B7280),
                          fontWeight: FontWeight.w600,
                          fontSize: 12,
                        ),
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
              _SignedQtyMini(
                value: item.qty,
                onMinus: () => onQtyChanged(item.qty - 1),
                onPlus: () => onQtyChanged(item.qty + 1),
                onTyped: (v) => onQtyChanged(v),
              ),
              const SizedBox(height: 8),
              IconButton(
                onPressed: onRemove,
                icon: const Icon(
                  Icons.delete_outline_rounded,
                  color: Color(0xFF6B7280),
                ),
                tooltip: 'Remove',
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ProductCardFixed extends StatelessWidget {
  final Product product;
  final int selectedNet;
  final VoidCallback onChoose;

  const _ProductCardFixed({
    required this.product,
    required this.selectedNet,
    required this.onChoose,
  });

  @override
  Widget build(BuildContext context) {
    final thumb = (product.primaryImageUrl ?? '').trim();
    final hasBadge = selectedNet != 0;

    final badgeBg = selectedNet < 0
        ? const Color(0xFFFEE2E2)
        : const Color(0xFFDCFCE7);
    final badgeFg = selectedNet < 0
        ? const Color(0xFF991B1B)
        : const Color(0xFF166534);

    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE5E7EB)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0F000000),
            blurRadius: 14,
            offset: Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        children: [
          AspectRatio(
            aspectRatio: 1,
            child: Stack(
              fit: StackFit.expand,
              children: [
                SafeNetImage(
                  url: thumb.isEmpty ? null : thumb,
                  fit: BoxFit.cover,
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(16),
                  ),
                ),
                if (hasBadge)
                  Positioned(
                    top: 8,
                    right: 8,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: badgeBg,
                        borderRadius: BorderRadius.circular(999),
                        border: Border.all(color: badgeBg.withOpacity(.95)),
                      ),
                      child: Text(
                        _fmtSigned(selectedNet),
                        style: TextStyle(
                          fontWeight: FontWeight.w900,
                          fontSize: 12,
                          color: badgeFg,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(10, 8, 10, 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    product.name,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontWeight: FontWeight.w900,
                      color: Color(0xFF111827),
                      fontSize: 13,
                      height: 1.15,
                    ),
                  ),
                  const Spacer(),
                  SizedBox(
                    width: double.infinity,
                    height: 34,
                    child: ElevatedButton(
                      onPressed: onChoose,
                      style: ElevatedButton.styleFrom(
                        elevation: 0,
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                        padding: EdgeInsets.zero,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: const Text(
                        'Choose',
                        style: TextStyle(fontWeight: FontWeight.w800),
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

class _SheetHeader extends StatelessWidget {
  final String title;
  final String? caption;
  const _SheetHeader({required this.title, this.caption});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
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
    );
  }
}

class _PSheetHeader extends StatelessWidget {
  final String title;
  final String? caption;
  const _PSheetHeader({required this.title, this.caption});

  @override
  Widget build(BuildContext context) {
    return Column(
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
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontWeight: FontWeight.w900,
                      fontSize: 16,
                      color: Color(0xFF111827),
                    ),
                  ),
                  if (caption != null) ...[
                    const SizedBox(height: 4),
                    Text(
                      caption!,
                      style: const TextStyle(
                        fontSize: 12,
                        color: Color(0xFF6B7280),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            IconButton(
              onPressed: () => Navigator.pop(context),
              icon: const Icon(Icons.close_rounded, color: Color(0xFF6B7280)),
              tooltip: 'Close',
            ),
          ],
        ),
        const SizedBox(height: 4),
      ],
    );
  }
}

class _PSection extends StatelessWidget {
  final String? title;
  final Widget child;
  const _PSection({this.title, required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
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
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (title != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Text(
                title!,
                style: const TextStyle(
                  fontWeight: FontWeight.w900,
                  color: Color(0xFF111827),
                ),
              ),
            ),
          child,
        ],
      ),
    );
  }
}

class _SignedQtyMini extends StatelessWidget {
  final int value;
  final VoidCallback onMinus;
  final VoidCallback onPlus;
  final void Function(int v) onTyped;

  const _SignedQtyMini({
    required this.value,
    required this.onMinus,
    required this.onPlus,
    required this.onTyped,
  });

  @override
  Widget build(BuildContext context) {
    final c = TextEditingController(text: value.toString());
    return Container(
      height: 34,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _btn(Icons.remove_rounded, onMinus),
          SizedBox(
            width: 52,
            child: TextField(
              controller: c,
              textAlign: TextAlign.center,
              keyboardType: TextInputType.number,
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'^-?\d*$')),
              ],
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w900),
              decoration: const InputDecoration(
                border: InputBorder.none,
                isDense: true,
                contentPadding: EdgeInsets.symmetric(vertical: 8),
              ),
              onChanged: (t) => onTyped(int.tryParse(t) ?? 0),
              onSubmitted: (t) => onTyped(int.tryParse(t) ?? 0),
            ),
          ),
          _btn(Icons.add_rounded, onPlus),
        ],
      ),
    );
  }

  Widget _btn(IconData icon, VoidCallback onTap) {
    return SizedBox(
      width: 34,
      height: 34,
      child: IconButton(
        onPressed: onTap,
        icon: Icon(icon, size: 18),
        padding: EdgeInsets.zero,
        constraints: const BoxConstraints.tightFor(width: 34, height: 34),
        splashRadius: 18,
      ),
    );
  }
}

class _SignedQtyPill extends StatelessWidget {
  final int value;
  final VoidCallback onMinus;
  final VoidCallback onPlus;
  final void Function(int v) onTyped;

  const _SignedQtyPill({
    required this.value,
    required this.onMinus,
    required this.onPlus,
    required this.onTyped,
  });

  @override
  Widget build(BuildContext context) {
    final c = TextEditingController(text: value.toString());
    return Container(
      height: 36,
      decoration: BoxDecoration(
        border: Border.all(color: const Color(0xFFE5E7EB)),
        borderRadius: BorderRadius.circular(12),
        color: Colors.white,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _btn(Icons.remove_rounded, onMinus),
          SizedBox(
            width: 64,
            child: TextField(
              controller: c,
              textAlign: TextAlign.center,
              keyboardType: TextInputType.number,
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'^-?\d*$')),
              ],
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w900),
              decoration: const InputDecoration(
                border: InputBorder.none,
                isDense: true,
                contentPadding: EdgeInsets.symmetric(vertical: 8),
              ),
              onChanged: (t) => onTyped(int.tryParse(t) ?? 0),
              onSubmitted: (t) => onTyped(int.tryParse(t) ?? 0),
            ),
          ),
          _btn(Icons.add_rounded, onPlus),
        ],
      ),
    );
  }

  Widget _btn(IconData icon, VoidCallback onTap) {
    return SizedBox(
      width: 36,
      height: 36,
      child: IconButton(
        onPressed: onTap,
        icon: Icon(icon, size: 18),
        padding: EdgeInsets.zero,
        constraints: const BoxConstraints.tightFor(width: 36, height: 36),
        splashRadius: 18,
      ),
    );
  }
}

class SafeNetImage extends StatelessWidget {
  final String? url;
  final double? width;
  final double? height;
  final BoxFit fit;
  final BorderRadius? borderRadius;

  const SafeNetImage({
    super.key,
    required this.url,
    this.width,
    this.height,
    this.fit = BoxFit.cover,
    this.borderRadius,
  });

  @override
  Widget build(BuildContext context) {
    final Widget fallback = Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: const Color(0xFFF3F4F6),
        borderRadius: borderRadius ?? BorderRadius.circular(12),
      ),
      child: const Center(
        child: Icon(Icons.broken_image_rounded, color: Color(0xFFA3A3A3)),
      ),
    );

    if (url == null || url!.isEmpty) return fallback;

    Widget img = Image.network(
      url!,
      width: width,
      height: height,
      fit: fit,
      errorBuilder: (_, __, ___) => fallback,
    );

    if (borderRadius != null) {
      img = ClipRRect(borderRadius: borderRadius!, child: img);
    }
    return img;
  }
}

class _AdjSelectedItem {
  final String productId;
  final String productName;
  final String imageUrl;

  final String skuId;
  final String skuCode;

  final int qty;

  const _AdjSelectedItem({
    required this.productId,
    required this.productName,
    required this.imageUrl,
    required this.skuId,
    required this.skuCode,
    required this.qty,
  });

  _AdjSelectedItem copyWith({int? qty}) {
    return _AdjSelectedItem(
      productId: productId,
      productName: productName,
      imageUrl: imageUrl,
      skuId: skuId,
      skuCode: skuCode,
      qty: qty ?? this.qty,
    );
  }
}

// ✅ 0 tampil "0" (bukan "+0")
String _fmtSigned(int v) => v == 0 ? '0' : (v > 0 ? '+$v' : '$v');
