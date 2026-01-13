// lib/screens/stock-opname/stock_opname_create_screen.dart
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:infinite_scroll_pagination/infinite_scroll_pagination.dart';
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
      } catch (_) {
        _syncStoreLabel();
      }

      if (!mounted) return;
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
      setState(() => _storeName = null);
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

  Future<void> _pickStore() async {
    final picked = await showStorePickerSheet(context, selectedId: _storeId);
    if (picked == null) return;

    setState(() {
      _storeId = picked.id;
      _storeName = picked.label;
    });

    await context.read<ProductProvider>().setStoreLocationAndRefresh(
      context,
      picked.id,
    );

    if (!mounted) return;
    await context.read<ProductProvider>().refreshInfinite(context);
  }

  void _onSearchChanged(String _) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 300), () async {
      if (!mounted) return;

      final prov = context.read<ProductProvider>();
      final q = _searchC.text.trim();
      final composed = q.isEmpty ? '' : 'q:$q';

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

  @override
  Widget build(BuildContext context) {
    final storeLabel = (_storeName?.trim().isNotEmpty ?? false)
        ? _storeName!.trim()
        : 'Select store';

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

        // bentuk title dibuat mirip: baseline row + suffix monospace
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

        // action dipertahankan sama persis
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

            return RefreshIndicator(
              onRefresh: _onPullRefresh,
              child: CustomScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                slivers: [
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
                      child: Column(
                        children: [
                          _SelectTile(
                            label: 'Store Location',
                            value: storeLabel,
                            onTap: _pickStore,
                            leading: const Icon(
                              Icons.storefront_rounded,
                              color: Color(0xFF4C6EF5),
                              size: 18,
                            ),
                          ),
                          const SizedBox(height: 10),
                          TextField(
                            controller: _searchC,
                            onChanged: _onSearchChanged,
                            textInputAction: TextInputAction.search,
                            decoration: InputDecoration(
                              hintText: 'Search product / SKU',
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
                                borderRadius: BorderRadius.circular(12),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderSide: const BorderSide(
                                  color: Color(0xFFCBD5E1),
                                ),
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SliverToBoxAdapter(
                    child: Divider(height: 1, color: Color(0xFFF3F4F6)),
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
                                stockQty: p.totalStockQty,
                                onTap: () {
                                  AppSnackbar.show(
                                    context,
                                    type: AppSnackType.error,
                                    title: 'SKU not found',
                                    message: 'This product does not have SKU.',
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
                                        _storeId ??
                                        context
                                            .read<ProductProvider>()
                                            .currentStoreLocationId;

                                    if (sid == null || sid.isEmpty) {
                                      AppSnackbar.show(
                                        context,
                                        type: AppSnackType.error,
                                        title: 'Store required',
                                        message:
                                            'Please select store location first.',
                                      );
                                      return;
                                    }

                                    if (skuId.trim().isEmpty) {
                                      AppSnackbar.show(
                                        context,
                                        type: AppSnackType.error,
                                        title: 'SKU invalid',
                                        message:
                                            'SKU ID not found for this item.',
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

class _SelectTile extends StatelessWidget {
  const _SelectTile({
    required this.label,
    required this.value,
    required this.onTap,
    this.leading,
  });

  final String label;
  final String value;
  final VoidCallback onTap;
  final Widget? leading;

  @override
  Widget build(BuildContext context) {
    final hasValue = value.trim().isNotEmpty && value != 'Select store';

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: const Color(0xFFF3F4F6),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFFE5E7EB)),
        ),
        child: Row(
          children: [
            if (leading != null) ...[leading!, const SizedBox(width: 10)],
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF6B7280),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    value,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontWeight: FontWeight.w800,
                      color: hasValue
                          ? const Color(0xFF111827)
                          : const Color(0xFF9CA3AF),
                    ),
                  ),
                ],
              ),
            ),
            const Icon(Icons.expand_more, color: Color(0xFF6B7280)),
          ],
        ),
      ),
    );
  }
}

/// Card SKU (rapih + UX):
/// - thumbnail dari induk product
/// - nama product
/// - SKU code
/// - stock badge kecil (bukan box besar)
/// - chevron button
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

            // ✅ Stock badge dibuat compact (tidak “gede sebelah”)
            _StockBadge(stockQty: stockQty),

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
        mainAxisSize: MainAxisSize.min, // ✅ biar ngikut konten, gak melebar
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
        child: Stack(
          fit: StackFit.expand,
          children: [
            _SquareImage(image: image),
            Positioned(
              bottom: 6,
              left: 6,
              child: Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.45),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.qr_code_2_rounded,
                  size: 14,
                  color: Colors.white,
                ),
              ),
            ),
          ],
        ),
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
          label: const Text('Retry'),
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
        const SizedBox(height: 12),
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

/// shimmer dibuat Column biar aman (tidak intrinsic viewport).
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

/// Bottom sheet: input qty saja untuk SKU terpilih (dari card yang di-tap).
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
        title: 'Success',
        message: 'Stock opname created.',
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
                                      'Current stock: ${widget.currentStock}',
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
                      const SizedBox(height: 18),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: const Color(0xFFEFF6FF),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: const Color(0xFFDBEAFE)),
                        ),
                        child: const Row(
                          children: [
                            Icon(
                              Icons.info_outline_rounded,
                              color: Color(0xFF1F3D99),
                              size: 18,
                            ),
                            SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                'Input the stock opname quantity for this SKU.',
                                style: TextStyle(
                                  color: Color(0xFF1F3D99),
                                  fontWeight: FontWeight.w800,
                                  fontSize: 12,
                                  height: 1.25,
                                ),
                              ),
                            ),
                          ],
                        ),
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
                            'Create Stock Opname',
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
