// lib/screens/business/transaction_fee_detail_screen.dart
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../providers/subscription_provider.dart';

class TransactionFeeDetailScreen extends StatefulWidget {
  final String idTransactionFee;

  const TransactionFeeDetailScreen({super.key, required this.idTransactionFee});

  @override
  State<TransactionFeeDetailScreen> createState() =>
      _TransactionFeeDetailScreenState();
}

class _TransactionFeeDetailScreenState
    extends State<TransactionFeeDetailScreen> {
  final _scrollC = ScrollController();

  // ===== Theme (blue/white) =====
  static const Color _bg = Color(0xFFF6F7FB);
  static const Color _card = Colors.white;
  static const Color _border = Color(0xFFE5E7EB);

  static const Color _text = Color(0xFF0F172A);
  static const Color _muted = Color(0xFF64748B);
  static const Color _muted2 = Color(0xFF94A3B8);

  static const Color _blue = Color(0xFF2563EB);
  static const Color _blueSoft = Color(0xFFEFF6FF);
  static const Color _blueBorder = Color(0xFFBFDBFE);

  static const Color _successBg = Color(0xFFECFDF5);
  static const Color _successBd = Color(0xFFA7F3D0);
  static const Color _successFg = Color(0xFF047857);

  static const Color _dangerBg = Color(0xFFFEF2F2);
  static const Color _dangerBd = Color(0xFFFECACA);
  static const Color _dangerFg = Color(0xFFB91C1C);

  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      await _refresh();
    });

    _scrollC.addListener(() async {
      if (!mounted) return;
      final p = context.read<SubscriptionProvider>();
      if (!_scrollC.hasClients) return;

      final pos = _scrollC.position;
      if (pos.pixels >= pos.maxScrollExtent - 320) {
        final hasMore = p.transactionFeeHistoryHasMoreOf(
          widget.idTransactionFee,
        );
        final loading = p.isLoadingTransactionFeeHistoryOf(
          widget.idTransactionFee,
        );
        final loadingMore = p.isLoadingMoreTransactionFeeHistoryOf(
          widget.idTransactionFee,
        );

        if (hasMore && !loading && !loadingMore) {
          await p.fetchMoreTransactionFeeHistoryDetail(
            context,
            idTransactionFee: widget.idTransactionFee,
          );
        }
      }
    });
  }

  Future<void> _refresh() async {
    await context.read<SubscriptionProvider>().fetchTransactionFeeHistoryDetail(
      context,
      idTransactionFee: widget.idTransactionFee,
      refresh: true,
      limit: 10,
    );
  }

  @override
  void dispose() {
    _scrollC.dispose();
    super.dispose();
  }

  String _rupiah(int v) {
    return NumberFormat.currency(
      locale: 'id_ID',
      symbol: 'Rp ',
      decimalDigits: 0,
    ).format(v);
  }

  String _titleCaseStatus(String raw) {
    final s = raw.trim();
    if (s.isEmpty) return '-';
    final lower = s.toLowerCase();
    return lower[0].toUpperCase() + lower.substring(1);
  }

  bool _isPaidStatus(String raw) {
    final s = raw.trim().toLowerCase();
    return s == 'paid' || s == 'success' || s == 'settlement';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      body: Consumer<SubscriptionProvider>(
        builder: (context, p, _) {
          final loading = p.isLoadingTransactionFeeHistoryOf(
            widget.idTransactionFee,
          );
          final err = p.transactionFeeHistoryErrorOf(widget.idTransactionFee);

          final info = p.transactionFeeInfoOf(widget.idTransactionFee);
          final items = p.transactionFeeHistoryOf(widget.idTransactionFee);

          final isFirstLoad = loading && info == null && items.isEmpty;

          // ===== First load skeleton =====
          if (isFirstLoad) {
            return const _SkeletonScaffold();
          }

          // ===== Hard error (no data) =====
          if ((err ?? '').trim().isNotEmpty && info == null && items.isEmpty) {
            return _NiceErrorState(message: err!, onRetry: _refresh);
          }

          // ===== Main UI =====
          final periodLabel = (info == null)
              ? 'Platform Fee'
              : (info.period.trim().isNotEmpty
                    ? info.period.trim()
                    : '${info.month}/${info.year}');

          return RefreshIndicator(
            color: _blue,
            onRefresh: _refresh,
            child: CustomScrollView(
              controller: _scrollC,
              physics: const AlwaysScrollableScrollPhysics(
                parent: BouncingScrollPhysics(),
              ),
              slivers: [
                _StickyHeader(
                  title: 'Platform Fee Detail',
                  subtitle: periodLabel,
                  bg: _bg,
                  text: _text,
                  muted: _muted,
                ),

                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
                  sliver: SliverList(
                    delegate: SliverChildListDelegate([
                      if (info != null) ...[
                        _SummaryCard(
                          period: info.period.trim().isNotEmpty
                              ? info.period.trim()
                              : '${info.month}/${info.year}',
                          status: info.status,
                          totalFeeLabel: _rupiah(info.totalFee),
                          txCount: info.transactionCount,
                          isPaid: _isPaidStatus(info.status),
                        ),
                        const SizedBox(height: 14),
                      ] else ...[
                        // kalau info belum ada tapi list sudah ada, tetap kasih header ringkas
                        _SoftInfoBanner(
                          text: 'Fee summary will appear here when ready.',
                        ),
                        const SizedBox(height: 14),
                      ],

                      Row(
                        children: const [
                          Expanded(
                            child: Text(
                              'Transaction History',
                              style: TextStyle(
                                fontWeight: FontWeight.w900,
                                fontSize: 14,
                                color: _text,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),

                      if (items.isEmpty) ...[
                        const _EmptyState(),
                      ] else ...[
                        for (final it in items) ...[
                          _HistoryItemCard(
                            number: it.number,
                            status: _titleCaseStatus(it.status),
                            createdAt: it.createdAt,
                            amountLabel: _rupiah(it.amount),
                            storeName: it.storeLocationName,
                            cityName: it.cityName,
                            isPaid: _isPaidStatus(it.status),
                            itemPreview: it.items.isNotEmpty
                                ? '${it.items.first.productName} • qty ${it.items.first.qtyIn}'
                                : null,
                          ),
                          const SizedBox(height: 10),
                        ],
                      ],

                      if (p.isLoadingMoreTransactionFeeHistoryOf(
                        widget.idTransactionFee,
                      )) ...[
                        const SizedBox(height: 4),
                        const _BottomLoader(),
                        const SizedBox(height: 6),
                      ],

                      _MoreErrorBar(
                        message: p.transactionFeeHistoryMoreErrorOf(
                          widget.idTransactionFee,
                        ),
                        onRetry: () => p.fetchMoreTransactionFeeHistoryDetail(
                          context,
                          idTransactionFee: widget.idTransactionFee,
                        ),
                      ),

                      const SizedBox(height: 10),
                    ]),
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

// ===========================
// Sticky Header
// ===========================
class _StickyHeader extends StatelessWidget {
  final String title;
  final String subtitle;
  final Color bg;
  final Color text;
  final Color muted;

  const _StickyHeader({
    required this.title,
    required this.subtitle,
    required this.bg,
    required this.text,
    required this.muted,
  });

  @override
  Widget build(BuildContext context) {
    return SliverAppBar(
      pinned: true,
      elevation: 0,
      backgroundColor: bg,
      surfaceTintColor: bg,
      automaticallyImplyLeading: false,
      toolbarHeight: 74,
      titleSpacing: 6,
      title: Row(
        children: [
          IconButton(
            onPressed: () => Navigator.of(context).pop(),
            icon: const Icon(Icons.arrow_back_ios_new_rounded),
            color: text,
          ),
          const SizedBox(width: 2),
          Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 18.5,
                    fontWeight: FontWeight.w900,
                    color: text,
                    height: 1.1,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  subtitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: muted,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      bottom: const PreferredSize(
        preferredSize: Size.fromHeight(1),
        child: Divider(height: 1, thickness: 1, color: Color(0xFFE5E7EB)),
      ),
    );
  }
}

// ===========================
// Summary Card (dashboard feel)
// ===========================
class _SummaryCard extends StatelessWidget {
  final String period;
  final String status;
  final String totalFeeLabel;
  final int txCount;
  final bool isPaid;

  const _SummaryCard({
    required this.period,
    required this.status,
    required this.totalFeeLabel,
    required this.txCount,
    required this.isPaid,
  });

  static const _border = Color(0xFFE5E7EB);
  static const _blue = Color(0xFF2563EB);
  static const _blueSoft = Color(0xFFEFF6FF);
  static const _blueBorder = Color(0xFFBFDBFE);

  static const _text = Color(0xFF0F172A);
  static const _muted = Color(0xFF64748B);

  static const _successBg = Color(0xFFECFDF5);
  static const _successBd = Color(0xFFA7F3D0);
  static const _successFg = Color(0xFF047857);

  static const _dangerBg = Color(0xFFFEF2F2);
  static const _dangerBd = Color(0xFFFECACA);
  static const _dangerFg = Color(0xFFB91C1C);

  @override
  Widget build(BuildContext context) {
    final badgeBg = isPaid ? _successBg : _dangerBg;
    final badgeBd = isPaid ? _successBd : _dangerBd;
    final badgeFg = isPaid ? _successFg : _dangerFg;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: _border),
        boxShadow: const [
          BoxShadow(
            blurRadius: 18,
            offset: Offset(0, 10),
            color: Color(0x12000000),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: _blueSoft,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: _blueBorder),
                ),
                child: const Icon(
                  Icons.receipt_long_rounded,
                  color: _blue,
                  size: 22,
                ),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Text(
                  'Fee period summary',
                  style: TextStyle(
                    fontWeight: FontWeight.w900,
                    fontSize: 14,
                    color: _text,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: badgeBg,
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(color: badgeBd),
                ),
                child: Text(
                  status.trim().isEmpty ? '-' : status,
                  style: TextStyle(
                    color: badgeFg,
                    fontWeight: FontWeight.w900,
                    fontSize: 12,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),

          // Highlights (2 cards)
          Row(
            children: [
              Expanded(
                child: _MetricTile(
                  label: 'Period',
                  value: period,
                  icon: Icons.calendar_month_rounded,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _MetricTile(
                  label: 'Transactions',
                  value: txCount.toString(),
                  icon: Icons.bar_chart_rounded,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),

          // Total fee big
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: _blueSoft,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: _blueBorder),
            ),
            child: Row(
              children: [
                const Icon(Icons.payments_rounded, color: _blue, size: 20),
                const SizedBox(width: 10),
                const Expanded(
                  child: Text(
                    'Total fee',
                    style: TextStyle(
                      color: _muted,
                      fontWeight: FontWeight.w800,
                      fontSize: 12,
                    ),
                  ),
                ),
                Text(
                  totalFeeLabel,
                  style: const TextStyle(
                    color: _text,
                    fontWeight: FontWeight.w900,
                    fontSize: 16,
                    letterSpacing: -0.2,
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

class _MetricTile extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;

  const _MetricTile({
    required this.label,
    required this.value,
    required this.icon,
  });

  static const _border = Color(0xFFE5E7EB);
  static const _text = Color(0xFF0F172A);
  static const _muted = Color(0xFF64748B);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _border),
      ),
      child: Row(
        children: [
          Icon(icon, color: _muted, size: 18),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: _muted,
                    fontWeight: FontWeight.w800,
                    fontSize: 11.5,
                    height: 1.0,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  value.isEmpty ? '-' : value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: _text,
                    fontWeight: FontWeight.w900,
                    fontSize: 13,
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
}

// ===========================
// History Item Card
// ===========================
class _HistoryItemCard extends StatelessWidget {
  final String number;
  final String status;
  final DateTime? createdAt;
  final String amountLabel;
  final String storeName;
  final String cityName;
  final bool isPaid;
  final String? itemPreview;

  const _HistoryItemCard({
    required this.number,
    required this.status,
    required this.createdAt,
    required this.amountLabel,
    required this.storeName,
    required this.cityName,
    required this.isPaid,
    required this.itemPreview,
  });

  static const _border = Color(0xFFE5E7EB);
  static const _text = Color(0xFF0F172A);
  static const _muted = Color(0xFF64748B);
  static const _muted2 = Color(0xFF94A3B8);

  static const _successBg = Color(0xFFECFDF5);
  static const _successBd = Color(0xFFA7F3D0);
  static const _successFg = Color(0xFF047857);

  static const _dangerBg = Color(0xFFFEF2F2);
  static const _dangerBd = Color(0xFFFECACA);
  static const _dangerFg = Color(0xFFB91C1C);

  static const _blueSoft = Color(0xFFEFF6FF);
  static const _blueBorder = Color(0xFFBFDBFE);
  static const _blue = Color(0xFF2563EB);

  @override
  Widget build(BuildContext context) {
    final dtLabel = (createdAt == null)
        ? '-'
        : DateFormat(
            'dd MMM yyyy • HH:mm',
            'id_ID',
          ).format(createdAt!.toLocal());

    final badgeBg = isPaid ? _successBg : _dangerBg;
    final badgeBd = isPaid ? _successBd : _dangerBd;
    final badgeFg = isPaid ? _successFg : _dangerFg;

    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: _border),
        ),
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Top row: number + status
            Row(
              children: [
                Expanded(
                  child: Text(
                    number.trim().isEmpty ? '-' : number.trim(),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontWeight: FontWeight.w900,
                      fontSize: 13.5,
                      color: _text,
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
                    color: badgeBg,
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(color: badgeBd),
                  ),
                  child: Text(
                    status.trim().isEmpty ? '-' : status.trim(),
                    style: TextStyle(
                      color: badgeFg,
                      fontWeight: FontWeight.w900,
                      fontSize: 11.5,
                      height: 1.0,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),

            // time
            Row(
              children: [
                const Icon(Icons.schedule_rounded, size: 16, color: _muted2),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    dtLabel,
                    style: const TextStyle(
                      color: _muted,
                      fontWeight: FontWeight.w700,
                      fontSize: 12,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),

            // store + amount
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: _blueSoft,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: _blueBorder),
                  ),
                  child: const Icon(
                    Icons.storefront_rounded,
                    color: _blue,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        storeName.trim().isEmpty ? '-' : storeName.trim(),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: _text,
                          fontWeight: FontWeight.w900,
                          fontSize: 12.5,
                          height: 1.2,
                        ),
                      ),
                      if (cityName.trim().isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Text(
                          cityName.trim(),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: _muted,
                            fontWeight: FontWeight.w700,
                            fontSize: 11.5,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(width: 10),
                Text(
                  amountLabel,
                  textAlign: TextAlign.right,
                  style: const TextStyle(
                    color: _text,
                    fontWeight: FontWeight.w900,
                    fontSize: 13.5,
                    letterSpacing: -0.2,
                  ),
                ),
              ],
            ),

            // item preview
            if (itemPreview != null && itemPreview!.trim().isNotEmpty) ...[
              const SizedBox(height: 12),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(
                      Icons.shopping_bag_rounded,
                      size: 16,
                      color: _muted,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        itemPreview!.trim(),
                        style: const TextStyle(
                          color: Color(0xFF334155),
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
          ],
        ),
      ),
    );
  }
}

// ===========================
// Empty / Error / More
// ===========================
class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE5E7EB)),
        boxShadow: const [
          BoxShadow(
            blurRadius: 16,
            offset: Offset(0, 10),
            color: Color(0x12000000),
          ),
        ],
      ),
      child: Column(
        children: const [
          SizedBox(height: 4),
          Icon(Icons.inbox_rounded, size: 40, color: Color(0xFF2563EB)),
          SizedBox(height: 10),
          Text(
            'No transaction history yet',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontWeight: FontWeight.w900,
              fontSize: 14,
              color: Color(0xFF0F172A),
            ),
          ),
          SizedBox(height: 6),
          Text(
            'This fee period has no recorded transactions.',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Color(0xFF64748B),
              fontWeight: FontWeight.w700,
              height: 1.3,
            ),
          ),
          SizedBox(height: 4),
        ],
      ),
    );
  }
}

class _NiceErrorState extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;

  const _NiceErrorState({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF6F7FB),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: const Color(0xFFE5E7EB)),
              boxShadow: const [
                BoxShadow(
                  blurRadius: 16,
                  offset: Offset(0, 10),
                  color: Color(0x12000000),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 56,
                  height: 56,
                  decoration: const BoxDecoration(
                    color: Color(0xFFFEE2E2),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.error_outline_rounded,
                    color: Color(0xFFB91C1C),
                    size: 28,
                  ),
                ),
                const SizedBox(height: 12),
                const Text(
                  'Failed to load detail',
                  style: TextStyle(
                    fontWeight: FontWeight.w900,
                    fontSize: 14,
                    color: Color(0xFF0F172A),
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  message,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Color(0xFF64748B),
                    fontWeight: FontWeight.w700,
                    height: 1.3,
                  ),
                ),
                const SizedBox(height: 14),
                SizedBox(
                  width: double.infinity,
                  height: 44,
                  child: ElevatedButton.icon(
                    onPressed: onRetry,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF2563EB),
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    icon: const Icon(Icons.refresh_rounded, size: 18),
                    label: const Text(
                      'Retry',
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

class _MoreErrorBar extends StatelessWidget {
  final String? message;
  final VoidCallback onRetry;

  const _MoreErrorBar({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    final msg = (message ?? '').trim();
    if (msg.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.only(top: 10),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: const Color(0xFFFFF7ED),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: const Color(0xFFFED7AA)),
        ),
        child: Row(
          children: [
            const Icon(Icons.info_rounded, color: Color(0xFF9A3412), size: 18),
            const SizedBox(width: 8),
            const Expanded(
              child: Text(
                'Failed to load more data.',
                style: TextStyle(
                  color: Color(0xFF9A3412),
                  fontWeight: FontWeight.w800,
                  fontSize: 12,
                ),
              ),
            ),
            TextButton(
              onPressed: onRetry,
              style: TextButton.styleFrom(
                foregroundColor: const Color(0xFF9A3412),
              ),
              child: const Text(
                'Retry',
                style: TextStyle(fontWeight: FontWeight.w900),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _BottomLoader extends StatelessWidget {
  const _BottomLoader();

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: const [
        SizedBox(
          width: 18,
          height: 18,
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
        SizedBox(width: 10),
        Text(
          'Loading more…',
          style: TextStyle(
            color: Color(0xFF64748B),
            fontWeight: FontWeight.w800,
            fontSize: 12,
          ),
        ),
      ],
    );
  }
}

class _SoftInfoBanner extends StatelessWidget {
  final String text;
  const _SoftInfoBanner({required this.text});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFEFF6FF),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFBFDBFE)),
      ),
      child: Row(
        children: [
          const Icon(Icons.info_rounded, color: Color(0xFF2563EB), size: 18),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(
                color: Color(0xFF2563EB),
                fontWeight: FontWeight.w800,
                fontSize: 12,
                height: 1.2,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ===========================
// Skeleton (first load)
// ===========================
class _SkeletonScaffold extends StatelessWidget {
  const _SkeletonScaffold();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF6F7FB),
      body: CustomScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        slivers: [
          const SliverAppBar(
            pinned: true,
            elevation: 0,
            backgroundColor: Color(0xFFF6F7FB),
            surfaceTintColor: Color(0xFFF6F7FB),
            automaticallyImplyLeading: false,
            toolbarHeight: 74,
            titleSpacing: 6,
            title: _SkeletonHeader(),
            bottom: PreferredSize(
              preferredSize: Size.fromHeight(1),
              child: Divider(height: 1, thickness: 1, color: Color(0xFFE5E7EB)),
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
            sliver: SliverList(
              delegate: SliverChildListDelegate(const [
                _SkeletonCard(h: 164),
                SizedBox(height: 14),
                _SkeletonBar(w: 160, h: 14),
                SizedBox(height: 10),
                _SkeletonCard(h: 140),
                SizedBox(height: 10),
                _SkeletonCard(h: 140),
                SizedBox(height: 10),
                _SkeletonCard(h: 140),
              ]),
            ),
          ),
        ],
      ),
    );
  }
}

class _SkeletonHeader extends StatelessWidget {
  const _SkeletonHeader();

  @override
  Widget build(BuildContext context) {
    return Row(
      children: const [
        SizedBox(width: 44, height: 44),
        SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              _SkeletonBar(w: 180, h: 14),
              SizedBox(height: 8),
              _SkeletonBar(w: 120, h: 10),
            ],
          ),
        ),
      ],
    );
  }
}

class _SkeletonCard extends StatelessWidget {
  final double h;
  const _SkeletonCard({required this.h});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: h,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: const [
          _SkeletonBar(w: 140, h: 14),
          SizedBox(height: 12),
          _SkeletonBar(w: double.infinity, h: 12),
          SizedBox(height: 10),
          _SkeletonBar(w: 220, h: 12),
          SizedBox(height: 10),
          _SkeletonBar(w: 160, h: 12),
        ],
      ),
    );
  }
}

class _SkeletonBar extends StatelessWidget {
  final double w;
  final double h;
  const _SkeletonBar({required this.w, required this.h});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: w,
      height: h,
      decoration: BoxDecoration(
        color: const Color(0xFFE5E7EB),
        borderRadius: BorderRadius.circular(999),
      ),
    );
  }
}
