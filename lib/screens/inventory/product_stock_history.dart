import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import 'package:wa_blast/constants/app_colors.dart';
import 'package:wa_blast/models/product_model.dart';
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
    extends State<ProductStockHistoryScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tab;
  final _money = NumberFormat.decimalPattern('id_ID');
  final _dateFmt = DateFormat('dd MMM yyyy • HH:mm');

  String? _activeSkuId;

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
    _tab = TabController(length: 2, vsync: this);

    _activeSkuId =
        widget.initialSkuId ??
        (widget.skus.isNotEmpty ? widget.skus.first.idProductSku : null);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      final skuId = _activeSkuId;
      if (skuId != null && skuId.isNotEmpty) {
        context.read<ProductProvider>().fetchSkuInventoryHistory(
          context: context,
          idProductSKU: skuId,
        );
      }
    });
  }

  @override
  void dispose() {
    _tab.dispose();
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

      await context.read<ProductProvider>().fetchSkuInventoryHistory(
        context: context,
        idProductSKU: result.id,
      );
    }
  }

  Widget _qtyChip(int qty) {
    final isMinus = qty < 0;
    final base = isMinus ? AppColors.danger : AppColors.success;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      decoration: BoxDecoration(
        color: base.withOpacity(0.09),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: base.withOpacity(0.22)),
      ),
      child: Text(
        '${isMinus ? '' : '+'}$qty',
        style: TextStyle(
          color: base,
          fontWeight: FontWeight.w900,
          letterSpacing: 0.2,
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

    final priceNum = sku?.price ?? latest?.productSku.price;
    final priceLabel = priceNum == null ? '-' : 'Rp ${_money.format(priceNum)}';
    final storeName = latest?.storeLocation.name ?? '';
    final lastUpdated = latest?.updatedAt ?? latest?.createdAt;
    final currentStock = latest == null ? '-' : latest.qty.toString();

    final sales = buckets?.sales ?? const <InventoryHistoryItem>[];
    final purchases = buckets?.purchases ?? const <InventoryHistoryItem>[];

    return Scaffold(
      backgroundColor: AppColors.white,
      appBar: AppBar(
        elevation: 0,
        centerTitle: false,
        titleSpacing: 0,
        backgroundColor: Colors.transparent,
        foregroundColor: AppColors.textPrimary,
        title: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start, // ⬅️ rata kiri
          children: [
            const Text(
              'Stock History',
              style: TextStyle(fontWeight: FontWeight.w700, fontSize: 20),
            ),
            Text(
              widget.productName,
              style: const TextStyle(fontSize: 12, color: Color(0xFF6B7280)),
            ),
          ],
        ),
      ),
      body: SafeArea(
        child: Column(
          children: [
            // === Selector SKU (pakai style mirip reusable picker) ===
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
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

            // === HERO BAND ===
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
              child: _HeroBand(
                skuCode: skuCode.isEmpty ? 'SKU' : skuCode,
                priceLabel: priceLabel,
                storeName: storeName,
                lastUpdated: lastUpdated != null
                    ? _dateFmt.format(lastUpdated.toLocal())
                    : '-',
                // currentStock: currentStock,
              ),
            ),

            // === METRICS GRID ===
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: GridView.count(
                crossAxisCount: 2,
                childAspectRatio: 2.7,
                shrinkWrap: true,
                mainAxisSpacing: 12,
                crossAxisSpacing: 12,
                physics: const NeverScrollableScrollPhysics(),
                children: [
                  // _metricTile(
                  //   'Current Stock',
                  //   currentStock,
                  //   icon: Icons.inventory_2_outlined,
                  // ),
                  _metricTile(
                    'SKU',
                    skuCode.isEmpty ? 'SKU' : skuCode,
                    icon: Icons.confirmation_number,
                  ),
                  _metricTile('Price', priceLabel, icon: Icons.sell_outlined),
                  // _metricTile('Store', storeName, icon: Icons.storefront),
                ],
              ),
            ),

            // === TABS ===
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 6, 16, 6),
              child: _PillTabs(
                controller: _tab,
                tabs: const ['Sales', 'Purchases'],
              ),
            ),

            // === LIST CONTENT ===
            Expanded(
              child: RefreshIndicator(
                color: AppColors.primary,
                backgroundColor: AppColors.white,
                onRefresh: () => prov.fetchSkuInventoryHistory(
                  context: context,
                  idProductSKU: activeSkuId,
                ),
                child: TabBarView(
                  controller: _tab,
                  children: [
                    _HistoryPane(
                      items: sales,
                      loading: loading && sales.isEmpty,
                      errorText: err?.toString(),
                      dateFmt: _dateFmt,
                      qtyChip: _qtyChip,
                      fallName: storeName,
                      isSaleList: true,
                      onRetry: () => prov.fetchSkuInventoryHistory(
                        context: context,
                        idProductSKU: activeSkuId,
                      ),
                    ),
                    _HistoryPane(
                      items: purchases,
                      loading: loading && purchases.isEmpty,
                      errorText: err?.toString(),
                      dateFmt: _dateFmt,
                      qtyChip: _qtyChip,
                      fallName: storeName,
                      isSaleList: false,
                      onRetry: () => prov.fetchSkuInventoryHistory(
                        context: context,
                        idProductSKU: activeSkuId,
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

class _HistoryPane extends StatelessWidget {
  const _HistoryPane({
    required this.items,
    required this.loading,
    required this.errorText,
    required this.dateFmt,
    required this.qtyChip,
    required this.fallName,
    required this.isSaleList,
    required this.onRetry,
  });

  final List<InventoryHistoryItem> items;
  final bool loading;
  final String? errorText;
  final DateFormat dateFmt;
  final Widget Function(int) qtyChip;
  final String fallName;
  final bool isSaleList;
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
        icon: isSaleList ? Icons.south_west : Icons.north_east,
        title: isSaleList ? 'Belum ada penjualan' : 'Belum ada pembelian',
        message: 'Catatan akan muncul di sini setelah ada transaksi.',
        cta: 'Tarik ke bawah untuk refresh',
      );
    }
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
      itemCount: items.length,
      separatorBuilder: (_, __) =>
          const Divider(height: 1, color: AppColors.divider),
      itemBuilder: (_, i) {
        final it = items[i];
        final dt = it.createdAt.isAfter(it.updatedAt)
            ? it.createdAt
            : it.updatedAt;
        final when = dt.millisecondsSinceEpoch == 0
            ? '-'
            : dateFmt.format(dt.toLocal());
        final store = it.storeLocation.name.isNotEmpty
            ? it.storeLocation.name
            : fallName;
        final isSale = (it.type.toLowerCase() == 'sale');

        return _HistoryCard(
          isSale: isSale,
          title: it.note.isNotEmpty ? it.note : (isSale ? 'Sales' : 'Purchase'),
          subtitle: '${store.isEmpty ? "-" : store} • $when',
          trailing: qtyChip(it.qty),
          onTap: () {},
        );
      },
    );
  }
}

class _HistoryCard extends StatelessWidget {
  const _HistoryCard({
    required this.isSale,
    required this.title,
    required this.subtitle,
    required this.trailing,
    this.onTap,
  });

  final bool isSale;
  final String title;
  final String subtitle;
  final Widget trailing;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final arrowColor = isSale ? AppColors.danger : AppColors.success;
    final arrowIcon = isSale ? Icons.south_west : Icons.north_east;

    return Material(
      color: AppColors.card,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
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
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: arrowColor.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(12),
                ),
                alignment: Alignment.center,
                child: Icon(arrowIcon, size: 20, color: arrowColor),
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
    required this.skuCode,
    required this.priceLabel,
    required this.storeName,
    required this.lastUpdated,
  });

  final String skuCode;
  final String priceLabel;
  final String storeName;
  final String lastUpdated;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [AppColors.inputBackground, AppColors.white],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          // Avatar SKU
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: AppColors.blueAccent.withOpacity(0.25),
              borderRadius: BorderRadius.circular(14),
            ),
            alignment: Alignment.center,
            child: const Icon(
              Icons.qr_code_2,
              size: 26,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(width: 14),
          // Info
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  skuCode.isEmpty ? 'SKU' : skuCode,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.w900,
                    fontSize: 18,
                  ),
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    const Icon(
                      Icons.update,
                      size: 14,
                      color: AppColors.textSecondary,
                    ),
                    const SizedBox(width: 6),
                    Flexible(
                      child: Text(
                        'Last: $lastUpdated',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                if (priceLabel.isNotEmpty && priceLabel != '-')
                  Text(
                    priceLabel,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary,
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 14),
          // Current stock badge
          // Container(
          //   padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          //   decoration: BoxDecoration(
          //     color: AppColors.primaryDark,
          //     borderRadius: BorderRadius.circular(12),
          //   ),
          //   child: Column(
          //     children: [
          //       const Text(
          //         'Stock',
          //         style: TextStyle(
          //           color: Colors.white70,
          //           fontSize: 11,
          //           fontWeight: FontWeight.w600,
          //         ),
          //       ),
          //       const SizedBox(height: 2),
          //       Text(
          //         currentStock,
          //         style: const TextStyle(
          //           color: AppColors.white,
          //           fontWeight: FontWeight.w900,
          //           fontSize: 16,
          //         ),
          //       ),
          //     ],
          //   ),
          // ),
        ],
      ),
    );
  }
}

class _PillTabs extends StatelessWidget {
  const _PillTabs({required this.controller, required this.tabs});

  final TabController controller;
  final List<String> tabs;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 44,
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: AppColors.border),
        boxShadow: const [
          BoxShadow(
            blurRadius: 8,
            offset: Offset(0, 3),
            color: Color(0x0F000000),
          ),
        ],
      ),
      child: TabBar(
        controller: controller,
        labelPadding: const EdgeInsets.symmetric(horizontal: 18),
        indicatorSize: TabBarIndicatorSize.tab,
        dividerColor: Colors.transparent,
        splashBorderRadius: BorderRadius.circular(999),
        indicator: BoxDecoration(
          color: AppColors.blueButton,
          borderRadius: BorderRadius.circular(999),
        ),
        labelColor: AppColors.white,
        unselectedLabelColor: AppColors.textPrimary,
        tabs: tabs.map((t) => Tab(text: t)).toList(),
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
