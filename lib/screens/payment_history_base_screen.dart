import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../providers/subscription_provider.dart';

class PlatformPaymentHistoryScreen extends StatefulWidget {
  const PlatformPaymentHistoryScreen({super.key});

  @override
  State<PlatformPaymentHistoryScreen> createState() =>
      _PlatformPaymentHistoryScreenState();
}

class _PlatformPaymentHistoryScreenState
    extends State<PlatformPaymentHistoryScreen> {
  static const String _type = SubscriptionProvider.kHistoryTypeTransactionFee;

  final ScrollController _scrollC = ScrollController();

  @override
  void initState() {
    super.initState();

    // load page 1
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      await context.read<SubscriptionProvider>().fetchPaymentHistory(
        context,
        type: _type,
        refresh: true,
      );
    });

    _scrollC.addListener(() {
      if (!mounted) return;

      final prov = context.read<SubscriptionProvider>();
      if (!_scrollC.hasClients) return;

      final pos = _scrollC.position;
      if (pos.pixels >= (pos.maxScrollExtent - 320)) {
        final hasMore = prov.historyHasMoreOf(_type);
        final loading = prov.isLoadingHistoryOf(_type);
        final loadingMore = prov.isLoadingMoreHistoryOf(_type);

        if (hasMore && !loading && !loadingMore) {
          prov.fetchMorePaymentHistory(context, type: _type);
        }
      }
    });
  }

  @override
  void dispose() {
    _scrollC.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final fMoney = NumberFormat.decimalPattern('id_ID');
    final fDateShort = DateFormat('dd MMM yyyy, HH:mm');
    final fMonth = DateFormat('MMM yyyy');

    return Scaffold(
      backgroundColor: const Color(0xFFF6F7FB),
      body: Consumer<SubscriptionProvider>(
        builder: (context, prov, _) {
          final items = prov.historyOf(_type);
          final isLoading = prov.isLoadingHistoryOf(_type);
          final isLoadingMore = prov.isLoadingMoreHistoryOf(_type);
          final error = prov.historyErrorOf(_type);
          final moreError = prov.historyMoreErrorOf(_type);
          final hasMore = prov.historyHasMoreOf(_type);

          return RefreshIndicator(
            color: const Color(0xFF426FD4),
            onRefresh: () => context
                .read<SubscriptionProvider>()
                .fetchPaymentHistory(context, type: _type, refresh: true),
            child: CustomScrollView(
              controller: _scrollC,
              physics: const AlwaysScrollableScrollPhysics(),
              slivers: [
                const _StickyAppBar(
                  title: 'Platform',
                  subtitle: 'Payment history',
                ),

                // Initial loading skeleton
                if (isLoading && items.isEmpty)
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(16, 10, 16, 24),
                    sliver: SliverList(
                      delegate: SliverChildBuilderDelegate(
                        (context, index) => const Padding(
                          padding: EdgeInsets.only(bottom: 12),
                          child: _SkeletonCard(),
                        ),
                        childCount: 6,
                      ),
                    ),
                  ),

                // Error first page
                if (error != null && items.isEmpty && !isLoading)
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(16, 10, 16, 24),
                      child: _HistoryErrorBox(
                        message: error,
                        onRetry: () => context
                            .read<SubscriptionProvider>()
                            .fetchPaymentHistory(
                              context,
                              type: _type,
                              refresh: true,
                            ),
                      ),
                    ),
                  ),

                // Empty state
                if (!isLoading && error == null && items.isEmpty)
                  const SliverToBoxAdapter(
                    child: Padding(
                      padding: EdgeInsets.fromLTRB(16, 10, 16, 24),
                      child: _HistoryEmptyBox(),
                    ),
                  ),

                // List
                if (items.isNotEmpty)
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
                    sliver: SliverList(
                      delegate: SliverChildBuilderDelegate((context, index) {
                        final row = items[index];

                        final createdAtText = row.createdAt != null
                            ? fDateShort.format(row.createdAt!.toLocal())
                            : '-';

                        final paidAtText = row.paidAt != null
                            ? fDateShort.format(row.paidAt!.toLocal())
                            : null;

                        final amountText = 'Rp ${fMoney.format(row.amount)}';

                        final isPaid =
                            row.paid == 1 ||
                            row.paidStatus.toLowerCase() == 'paid';

                        final currentMonthKey = row.createdAt != null
                            ? fMonth.format(row.createdAt!.toLocal())
                            : 'Unknown date';

                        String? prevMonthKey;
                        if (index > 0) {
                          final prev = items[index - 1];
                          prevMonthKey = prev.createdAt != null
                              ? fMonth.format(prev.createdAt!.toLocal())
                              : 'Unknown date';
                        }

                        final showMonthHeader =
                            index == 0 || currentMonthKey != prevMonthKey;

                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (showMonthHeader) ...[
                              Padding(
                                padding: const EdgeInsets.only(
                                  top: 4,
                                  bottom: 10,
                                ),
                                child: Text(
                                  currentMonthKey,
                                  style: const TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w800,
                                    color: Color(0xFF111827),
                                  ),
                                ),
                              ),
                            ],
                            _TransactionFeeHistoryCard(
                              row: row,
                              createdAtText: createdAtText,
                              paidAtText: paidAtText,
                              amountText: amountText,
                              isPaid: isPaid,
                            ),
                            const SizedBox(height: 12),
                          ],
                        );
                      }, childCount: items.length),
                    ),
                  ),

                // Bottom loader / load-more error / end label
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 6, 16, 24),
                    child: Column(
                      children: [
                        if (isLoadingMore) ...[
                          const SizedBox(height: 8),
                          const SizedBox(
                            height: 22,
                            width: 22,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                          const SizedBox(height: 10),
                          const Text(
                            'Loading more...',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF6B7280),
                            ),
                          ),
                        ] else if (moreError != null) ...[
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              color: const Color(0xFFFFFBEB),
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                color: const Color(0xFFFDE68A),
                              ),
                            ),
                            child: Row(
                              children: [
                                const Icon(
                                  Icons.warning_amber_rounded,
                                  color: Color(0xFF92400E),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Text(
                                    moreError,
                                    style: const TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w700,
                                      color: Color(0xFF92400E),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 10),
                                TextButton(
                                  onPressed: () => context
                                      .read<SubscriptionProvider>()
                                      .fetchMorePaymentHistory(
                                        context,
                                        type: _type,
                                      ),
                                  style: TextButton.styleFrom(
                                    foregroundColor: const Color(0xFF1D4ED8),
                                  ),
                                  child: const Text(
                                    'Retry',
                                    style: TextStyle(
                                      fontWeight: FontWeight.w900,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ] else if (!hasMore && items.isNotEmpty) ...[
                          const SizedBox(height: 6),
                        ] else ...[
                          const SizedBox(height: 8),
                        ],
                      ],
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
///  STICKY APPBAR
/// =======================
class _StickyAppBar extends StatelessWidget {
  final String title;
  final String subtitle;

  const _StickyAppBar({required this.title, required this.subtitle});

  @override
  Widget build(BuildContext context) {
    return SliverAppBar(
      pinned: true,
      elevation: 0,
      backgroundColor: const Color(0xFFF6F7FB),
      surfaceTintColor: const Color(0xFFF6F7FB),
      automaticallyImplyLeading: false,
      toolbarHeight: 72,
      titleSpacing: 6,
      title: Row(
        children: [
          IconButton(
            onPressed: () => Navigator.of(context).pop(),
            icon: const Icon(Icons.arrow_back_ios_new_rounded),
          ),
          const SizedBox(width: 4),
          Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w900,
                    color: Color(0xFF111827),
                    height: 1.1,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF6B7280),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      bottom: PreferredSize(
        preferredSize: const Size.fromHeight(1),
        child: Container(height: 1, color: const Color(0xFFE5E7EB)),
      ),
    );
  }
}

/// =======================
///  TRANSACTION FEE CARD
///  - Unpaid -> Pay again (always)
///  - Paid -> Download invoice
/// =======================
class _TransactionFeeHistoryCard extends StatelessWidget {
  final SubscriptionHistoryItem row;
  final String createdAtText;
  final String? paidAtText;
  final String amountText;
  final bool isPaid;

  const _TransactionFeeHistoryCard({
    required this.row,
    required this.createdAtText,
    required this.paidAtText,
    required this.amountText,
    required this.isPaid,
  });

  @override
  Widget build(BuildContext context) {
    final titleText = row.description.trim().isNotEmpty
        ? row.description.trim()
        : (row.planName.isNotEmpty ? row.planName : 'Platform Fee');

    final invoiceText = row.number.isNotEmpty
        ? row.number
        : (row.id.isNotEmpty ? row.id : '-');

    final methodText = row.paymentMethodName.trim().isNotEmpty
        ? row.paymentMethodName
        : (row.paymentMethod != 0
              ? 'Payment method ${row.paymentMethod}'
              : 'Unknown');

    final statusBg = isPaid ? const Color(0xFFECFDF5) : const Color(0xFFFFF1F2);
    final statusFg = isPaid ? const Color(0xFF047857) : const Color(0xFFBE123C);
    final statusIcon = isPaid
        ? Icons.check_circle_rounded
        : Icons.error_rounded;
    final statusText = row.paidStatus.isNotEmpty
        ? row.paidStatus
        : (isPaid ? 'Paid' : 'Unpaid');

    final showPayAgain = !isPaid; // ✅ for transaction_fee: always allow
    final showDownload = isPaid;

    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: showDownload
            ? () async {
                await context
                    .read<SubscriptionProvider>()
                    .downloadInvoicePdfFromHistory(
                      context: context,
                      item: row,
                      openAfterSave: true,
                    );
              }
            : null,
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: const Color(0xFFE5E7EB)),
            boxShadow: const [
              BoxShadow(
                blurRadius: 18,
                offset: Offset(0, 10),
                color: Color(0x14000000),
              ),
            ],
            color: Colors.white,
          ),
          padding: const EdgeInsets.all(14),
          child: Column(
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(
                    width: 42,
                    height: 42,
                    child: Icon(
                      Icons.receipt_long_rounded,
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
                          titleText,
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w900,
                            color: Color(0xFF111827),
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Invoice • $invoiceText',
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF6B7280),
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Created • $createdAtText',
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF9CA3AF),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 10),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: statusBg,
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(statusIcon, size: 14, color: statusFg),
                            const SizedBox(width: 6),
                            Text(
                              statusText,
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w900,
                                color: statusFg,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        amountText,
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w900,
                          color: Color(0xFF111827),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFFF9FAFB),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: const Color(0xFFF1F5F9)),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.account_balance_wallet_rounded,
                      size: 16,
                      color: Color(0xFF4B5563),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        methodText,
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFF374151),
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (paidAtText != null && paidAtText!.isNotEmpty) ...[
                      const SizedBox(width: 10),
                      const Icon(
                        Icons.schedule_rounded,
                        size: 16,
                        color: Color(0xFF9CA3AF),
                      ),
                      const SizedBox(width: 6),
                      Flexible(
                        child: Text(
                          paidAtText!,
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF6B7280),
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: showPayAgain
                        ? const Color(0xFF111827)
                        : const Color(0xFF426FD4),
                    foregroundColor: Colors.white,
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  onPressed: () async {
                    if (showPayAgain) {
                      await context
                          .read<SubscriptionProvider>()
                          .retryPaymentFromHistory(context: context, item: row);
                      return;
                    }

                    await context
                        .read<SubscriptionProvider>()
                        .downloadInvoicePdfFromHistory(
                          context: context,
                          item: row,
                          openAfterSave: true,
                        );
                  },
                  icon: Icon(
                    showPayAgain
                        ? Icons.refresh_rounded
                        : Icons.download_rounded,
                    size: 18,
                  ),
                  label: Text(
                    showPayAgain ? 'Pay again' : 'Download Invoice',
                    style: const TextStyle(fontWeight: FontWeight.w900),
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

/// =======================
///  Empty & Error
/// =======================
class _HistoryErrorBox extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;
  const _HistoryErrorBox({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF1F2),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFFDA4AF)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Failed to load history',
            style: TextStyle(
              fontWeight: FontWeight.w900,
              color: Color(0xFF9F1239),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            message,
            style: const TextStyle(
              fontWeight: FontWeight.w600,
              color: Color(0xFF9F1239),
            ),
          ),
          const SizedBox(height: 12),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Retry'),
              style: TextButton.styleFrom(
                foregroundColor: const Color(0xFF9F1239),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _HistoryEmptyBox extends StatelessWidget {
  const _HistoryEmptyBox();

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
            blurRadius: 18,
            offset: Offset(0, 10),
            color: Color(0x14000000),
          ),
        ],
      ),
      child: Column(
        children: const [
          SizedBox(height: 6),
          Icon(Icons.receipt_long_rounded, size: 38, color: Color(0xFF9CA3AF)),
          SizedBox(height: 12),
          Text(
            'No platform payments yet',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w900,
              color: Color(0xFF111827),
            ),
          ),
          SizedBox(height: 8),
          Text(
            'Platform fee payments will appear here once available.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontWeight: FontWeight.w600,
              color: Color(0xFF6B7280),
              height: 1.3,
            ),
          ),
          SizedBox(height: 6),
        ],
      ),
    );
  }
}

/// =======================
///  Skeleton
/// =======================
class _SkeletonCard extends StatefulWidget {
  const _SkeletonCard();

  @override
  State<_SkeletonCard> createState() => _SkeletonCardState();
}

class _SkeletonCardState extends State<_SkeletonCard>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c;

  @override
  void initState() {
    super.initState();
    _c = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _c,
      builder: (context, _) {
        final t = _c.value;
        final base = 0xFFE5E7EB;
        final hi = 0xFFF1F5F9;
        final c = Color.lerp(Color(base), Color(hi), t)!;

        Widget bar({double w = double.infinity, double h = 12}) {
          return Container(
            width: w,
            height: h,
            decoration: BoxDecoration(
              color: c,
              borderRadius: BorderRadius.circular(999),
            ),
          );
        }

        return Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: const Color(0xFFE5E7EB)),
          ),
          child: Column(
            children: [
              Row(
                children: [
                  Container(
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(
                      color: c,
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        bar(w: 180, h: 12),
                        const SizedBox(height: 8),
                        bar(w: 120, h: 10),
                        const SizedBox(height: 6),
                        bar(w: 160, h: 10),
                      ],
                    ),
                  ),
                  const SizedBox(width: 10),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      bar(w: 64, h: 22),
                      const SizedBox(height: 10),
                      bar(w: 88, h: 12),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFFF9FAFB),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: const Color(0xFFF1F5F9)),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 16,
                      height: 16,
                      decoration: BoxDecoration(
                        color: c,
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(child: bar(h: 10)),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              Row(children: [Expanded(child: bar(h: 44))]),
            ],
          ),
        );
      },
    );
  }
}
