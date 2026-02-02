import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../providers/stock_provider.dart';

class InitialStockDetailScreen extends StatefulWidget {
  const InitialStockDetailScreen({super.key});

  @override
  State<InitialStockDetailScreen> createState() =>
      _InitialStockDetailScreenState();
}

class _InitialStockDetailScreenState extends State<InitialStockDetailScreen> {
  String? _id;
  StockProvider?
  _stockProv; // simpan reference provider (aman dipakai di dispose)

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    // ambil provider sekali, saat widget masih aktif
    _stockProv ??= context.read<StockProvider>();

    final args = ModalRoute.of(context)?.settings.arguments;
    final id = (args is Map) ? (args['id']?.toString()) : null;

    if (_id == null && id != null && id.isNotEmpty) {
      _id = id;

      WidgetsBinding.instance.addPostFrameCallback((_) async {
        if (!mounted) return;
        // pakai reference provider, bukan context.read di fase rawan
        await _stockProv!.fetchInitialStockDetail(context, id);
      });
    }
  }

  @override
  void dispose() {
    _stockProv?.clearInitialStockDetail();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final fMoney = NumberFormat.decimalPattern('id_ID');

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        scrolledUnderElevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.baseline,
          textBaseline: TextBaseline.alphabetic,
          children: const [
            Text(
              'Initial Stock',
              style: TextStyle(fontWeight: FontWeight.w800),
            ),
            SizedBox(width: 8),
            Text(
              '/detail',
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
      body: Consumer<StockProvider>(
        builder: (context, prov, _) {
          final loading = prov.loadingInitialStockDetail;
          final err = prov.initialStockDetailError;
          final detail = prov.initialStockDetail;

          Future<void> retry() async {
            final id = _id;
            if (id == null || id.isEmpty) return;
            await context.read<StockProvider>().fetchInitialStockDetail(
              context,
              id,
            );
          }

          if ((loading && detail == null) || (_id == null || _id!.isEmpty)) {
            return const _DetailLoading();
          }

          if (err != null && detail == null) {
            return _DetailError(message: err, onRetry: retry);
          }

          if (detail == null) {
            return _DetailError(
              message: 'Initial stock detail is not available.',
              onRetry: retry,
            );
          }

          // summary numbers
          final totalItems = detail.items.length;
          final totalQty = detail.items.fold<int>(0, (sum, it) => sum + it.qty);
          final totalValue = detail.items.fold<int>(
            0,
            (sum, it) => sum + (it.qty * it.price) - (it.discount ?? 0),
          );
          final headerDiscount = detail.discount ?? 0;

          final store = detail.storeLocation;

          return RefreshIndicator(
            onRefresh: retry,
            color: const Color(0xFF426FD4),
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
              children: [
                _HeaderCard(
                  title: store?.name ?? 'Store Location',
                  subtitle: [
                    store?.cityName,
                    store?.provinceName,
                  ].where((e) => e != null && e.isNotEmpty).join(', '),
                  note: detail.note,
                  rightTag: _id!,
                ),
                const SizedBox(height: 12),
                _SummaryRow(
                  items: totalItems,
                  totalQty: totalQty,
                  totalValue: totalValue,
                  headerDiscount: headerDiscount,
                  fMoney: fMoney,
                ),
                const SizedBox(height: 14),
                const Text(
                  'Items',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF111827),
                  ),
                ),
                const SizedBox(height: 8),
                ...detail.items.map((it) {
                  final sku = it.productSku;
                  final attrs = sku?.attributes.isEmpty == true
                      ? null
                      : sku?.attributes
                            .map((a) => '${a.name}: ${a.value}')
                            .join(' • ');

                  final title = it.product?.name ?? 'Product';
                  final skuCode = sku?.code ?? it.productSkuId;

                  return _ItemTile(
                    title: title,
                    skuCode: skuCode,
                    attrsText: attrs,
                    qty: it.qty,
                    price: it.price,
                    discount: it.discount,
                    fMoney: fMoney,
                  );
                }),
                const SizedBox(height: 8),
                if (loading)
                  const Padding(
                    padding: EdgeInsets.only(top: 10),
                    child: Center(
                      child: SizedBox(
                        height: 18,
                        width: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                    ),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }
}

/// =======================
/// UI Components (ringkas)
/// =======================

class _HeaderCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final String note;
  final String rightTag;

  const _HeaderCard({
    required this.title,
    required this.subtitle,
    required this.note,
    required this.rightTag,
  });

  @override
  Widget build(BuildContext context) {
    final hasSubtitle = subtitle.trim().isNotEmpty;
    final hasNote = note.trim().isNotEmpty;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFF7FAFF),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: const Color(0xFFE0EBFF),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(
              Icons.warehouse_rounded,
              color: Color(0xFF426FD4),
              size: 20,
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
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF111827),
                  ),
                ),
                if (hasSubtitle) ...[
                  const SizedBox(height: 3),
                  Text(
                    subtitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 11,
                      color: Color(0xFF6B7280),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
                if (hasNote) ...[
                  const SizedBox(height: 10),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFFE5E7EB)),
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.sticky_note_2_outlined,
                          size: 16,
                          color: Color(0xFF9CA3AF),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            note,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 12,
                              color: Color(0xFF374151),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: 10),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(999),
              border: Border.all(color: const Color(0xFFE5E7EB)),
            ),
            child: Text(
              '#${rightTag.length > 6 ? rightTag.substring(0, 6) : rightTag}',
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: Color(0xFF6B7280),
                fontFamily: 'monospace',
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SummaryRow extends StatelessWidget {
  final int items;
  final int totalQty;
  final int totalValue;
  final int headerDiscount;
  final NumberFormat fMoney;

  const _SummaryRow({
    required this.items,
    required this.totalQty,
    required this.totalValue,
    required this.headerDiscount,
    required this.fMoney,
  });

  @override
  Widget build(BuildContext context) {
    Widget tile({
      required IconData icon,
      required String label,
      required String value,
    }) {
      return Expanded(
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: const Color(0xFFE5E7EB)),
          ),
          child: Row(
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: const Color(0xFFF3F4F6),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, size: 16, color: const Color(0xFF6B7280)),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label,
                      style: const TextStyle(
                        fontSize: 11,
                        color: Color(0xFF9CA3AF),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      value,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF111827),
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

    return Row(
      children: [
        tile(icon: Icons.list_alt_rounded, label: 'Items', value: '$items'),
        const SizedBox(width: 10),
        tile(
          icon: Icons.inventory_2_rounded,
          label: 'Total Qty',
          value: '$totalQty',
        ),
        const SizedBox(width: 10),
        tile(
          icon: Icons.payments_rounded,
          label: headerDiscount > 0 ? 'Discount' : 'Value',
          value: headerDiscount > 0
              ? 'Rp. ${fMoney.format(headerDiscount)}'
              : 'Rp. ${fMoney.format(totalValue)}',
        ),
      ],
    );
  }
}

class _ItemTile extends StatelessWidget {
  final String title;
  final String skuCode;
  final String? attrsText;
  final int qty;
  final int price;
  final int? discount;
  final NumberFormat fMoney;

  const _ItemTile({
    required this.title,
    required this.skuCode,
    required this.attrsText,
    required this.qty,
    required this.price,
    required this.discount,
    required this.fMoney,
  });

  @override
  Widget build(BuildContext context) {
    final subtotal = (qty * price) - (discount ?? 0);

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF111827),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFFEFF3FF),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  'x$qty',
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF426FD4),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFFF3F4F6),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  skuCode,
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF4B5563),
                  ),
                ),
              ),
              if (attrsText != null && attrsText!.trim().isNotEmpty) ...[
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    attrsText!,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 11,
                      color: Color(0xFF9CA3AF),
                    ),
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Rp. ${fMoney.format(price)} / unit',
                style: const TextStyle(
                  fontSize: 11,
                  color: Color(0xFF6B7280),
                  fontWeight: FontWeight.w600,
                ),
              ),
              Row(
                children: [
                  if ((discount ?? 0) > 0) ...[
                    Text(
                      '- Rp. ${fMoney.format(discount)}',
                      style: const TextStyle(
                        fontSize: 11,
                        color: Color(0xFF9CA3AF),
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(width: 10),
                  ],
                  Text(
                    'Rp. ${fMoney.format(subtotal)}',
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w900,
                      color: Color(0xFF111827),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// =======================
/// States
/// ======================= ОБ

class _DetailLoading extends StatelessWidget {
  const _DetailLoading();

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      children: const [
        _SkeletonBox(height: 120),
        SizedBox(height: 12),
        Row(
          children: [
            Expanded(child: _SkeletonBox(height: 64)),
            SizedBox(width: 10),
            Expanded(child: _SkeletonBox(height: 64)),
            SizedBox(width: 10),
            Expanded(child: _SkeletonBox(height: 64)),
          ],
        ),
        SizedBox(height: 14),
        _SkeletonBox(height: 18),
        SizedBox(height: 10),
        _SkeletonBox(height: 92),
        SizedBox(height: 10),
        _SkeletonBox(height: 92),
      ],
    );
  }
}

class _SkeletonBox extends StatelessWidget {
  final double height;
  const _SkeletonBox({required this.height});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: height,
      decoration: BoxDecoration(
        color: const Color(0xFFF3F4F6),
        borderRadius: BorderRadius.circular(16),
      ),
    );
  }
}

class _DetailError extends StatelessWidget {
  final String message;
  final Future<void> Function() onRetry;

  const _DetailError({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
      children: [
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: const Color(0xFFFEE2E2),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFFFCA5A5)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Failed to load detail',
                style: TextStyle(
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF991B1B),
                ),
              ),
              const SizedBox(height: 6),
              Text(message, style: const TextStyle(color: Color(0xFF7F1D1D))),
              const SizedBox(height: 10),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton.icon(
                  onPressed: () => onRetry(),
                  icon: const Icon(Icons.refresh_rounded),
                  label: const Text('Retry'),
                  style: TextButton.styleFrom(
                    foregroundColor: const Color(0xFF991B1B),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
