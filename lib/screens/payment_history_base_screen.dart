// lib/screens/business/platform_payment_history_screen.dart
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
  // ✅ Theme colors (blue & white base)
  static const Color _blue = Color(0xFF426FD4);
  static const Color _blueDark = Color(0xFF2F5FD0);
  static const Color _blueSoft = Color(0xFFEFF6FF);

  static const Color _bg = Color(0xFFF6F7FB);
  static const Color _border = Color(0xFFE5E7EB);
  static const Color _text = Color(0xFF111827);
  static const Color _muted = Color(0xFF6B7280);
  static const Color _muted2 = Color(0xFF9CA3AF);

  // ✅ Neutral palette for "Payment Method" row (no blue tint)
  static const Color _neutralSoft = Color(0xFFF3F4F6);
  static const Color _neutralBorder = Color(0xFFE5E7EB);
  static const Color _neutralIcon = Color(0xFF374151);
  static const Color _neutralText = Color(0xFF111827);
  static const Color _neutralSubText = Color(0xFF4B5563);

  // ✅ Status palette (green & red)
  static const Color _successBg = Color(0xFFECFDF5);
  static const Color _successBorder = Color(0xFFA7F3D0);
  static const Color _successFg = Color(0xFF047857);

  static const Color _dangerBg = Color(0xFFFEF2F2);
  static const Color _dangerBorder = Color(0xFFFECACA);
  static const Color _dangerFg = Color(0xFFB91C1C);

  final ScrollController _scrollC = ScrollController();

  static const List<String> _allTypes = <String>[
    SubscriptionProvider.kHistoryTypeTransactionFee,
    SubscriptionProvider.kHistoryTypePremiumBusiness,
  ];

  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      await _fetchFirstPageAll();
    });

    _scrollC.addListener(() {
      if (!mounted) return;
      if (!_scrollC.hasClients) return;

      final prov = context.read<SubscriptionProvider>();
      final pos = _scrollC.position;

      if (pos.pixels >= (pos.maxScrollExtent - 320)) {
        for (final t in _allTypes) {
          final hasMore = prov.historyHasMoreOf(t);
          final loading = prov.isLoadingHistoryOf(t);
          final loadingMore = prov.isLoadingMoreHistoryOf(t);

          if (hasMore && !loading && !loadingMore) {
            prov.fetchMorePaymentHistory(context, type: t);
          }
        }
      }
    });
  }

  Future<void> _fetchFirstPageAll() async {
    final prov = context.read<SubscriptionProvider>();
    await Future.wait(
      _allTypes.map(
        (t) => prov.fetchPaymentHistory(context, type: t, refresh: true),
      ),
    );
  }

  Future<void> _fetchMoreAll() async {
    final prov = context.read<SubscriptionProvider>();
    for (final t in _allTypes) {
      final hasMore = prov.historyHasMoreOf(t);
      final loading = prov.isLoadingHistoryOf(t);
      final loadingMore = prov.isLoadingMoreHistoryOf(t);
      if (hasMore && !loading && !loadingMore) {
        await prov.fetchMorePaymentHistory(context, type: t);
      }
    }
  }

  @override
  void dispose() {
    _scrollC.dispose();
    super.dispose();
  }

  String _rowTypeOf(SubscriptionHistoryItem row) {
    final t = row.type.trim();
    if (t == SubscriptionProvider.kHistoryTypePremiumBusiness) {
      return SubscriptionProvider.kHistoryTypePremiumBusiness;
    }
    if (t == SubscriptionProvider.kHistoryTypeTransactionFee) {
      return SubscriptionProvider.kHistoryTypeTransactionFee;
    }
    return SubscriptionProvider.kHistoryTypeTransactionFee;
  }

  IconData _typeIcon(String t) {
    if (t == SubscriptionProvider.kHistoryTypePremiumBusiness) {
      return Icons.workspace_premium_rounded;
    }
    return Icons.receipt_long_rounded;
  }

  @override
  Widget build(BuildContext context) {
    final fMoney = NumberFormat.decimalPattern('id_ID');
    final fDateShort = DateFormat('dd MMM yyyy, HH:mm');
    final fMonthHeader = DateFormat('MMM yyyy');

    // ✅ key untuk grouping “1 bulan”
    final fMonthKey = DateFormat('yyyy-MM');
    final currentMonthKey = fMonthKey.format(DateTime.now());

    return Scaffold(
      backgroundColor: _bg,
      body: Consumer<SubscriptionProvider>(
        builder: (context, prov, _) {
          final itemsA = prov.historyOf(
            SubscriptionProvider.kHistoryTypeTransactionFee,
          );
          final itemsB = prov.historyOf(
            SubscriptionProvider.kHistoryTypePremiumBusiness,
          );

          final merged = <SubscriptionHistoryItem>[...itemsA, ...itemsB]
            ..sort((a, b) {
              final ad = a.createdAt?.toLocal();
              final bd = b.createdAt?.toLocal();
              if (ad == null && bd == null) return 0;
              if (ad == null) return 1;
              if (bd == null) return -1;
              return bd.compareTo(ad); // newest first
            });

          final loadingA = prov.isLoadingHistoryOf(
            SubscriptionProvider.kHistoryTypeTransactionFee,
          );
          final loadingB = prov.isLoadingHistoryOf(
            SubscriptionProvider.kHistoryTypePremiumBusiness,
          );
          final isLoading = loadingA || loadingB;

          final loadingMoreA = prov.isLoadingMoreHistoryOf(
            SubscriptionProvider.kHistoryTypeTransactionFee,
          );
          final loadingMoreB = prov.isLoadingMoreHistoryOf(
            SubscriptionProvider.kHistoryTypePremiumBusiness,
          );
          final isLoadingMore = loadingMoreA || loadingMoreB;

          final errorA = prov.historyErrorOf(
            SubscriptionProvider.kHistoryTypeTransactionFee,
          );
          final errorB = prov.historyErrorOf(
            SubscriptionProvider.kHistoryTypePremiumBusiness,
          );

          final moreErrorA = prov.historyMoreErrorOf(
            SubscriptionProvider.kHistoryTypeTransactionFee,
          );
          final moreErrorB = prov.historyMoreErrorOf(
            SubscriptionProvider.kHistoryTypePremiumBusiness,
          );
          final moreError = moreErrorA ?? moreErrorB;

          final hasMoreA = prov.historyHasMoreOf(
            SubscriptionProvider.kHistoryTypeTransactionFee,
          );
          final hasMoreB = prov.historyHasMoreOf(
            SubscriptionProvider.kHistoryTypePremiumBusiness,
          );
          final hasMore = hasMoreA || hasMoreB;

          // ✅ PRECOMPUTE: bulan mana saja yang sudah ada PAID (per type)
          // key: "$type|$monthKey"
          final Set<String> paidKeys = <String>{};
          for (final it in merged) {
            final paidStatus = (it.paidStatus).toString().toLowerCase();
            final isPaid = it.paid == 1 || paidStatus == 'paid';

            final mk = it.createdAt != null
                ? fMonthKey.format(it.createdAt!.toLocal())
                : 'unknown';

            final type = _rowTypeOf(it);
            if (isPaid) paidKeys.add('$type|$mk');
          }

          String? combinedError;
          if (errorA != null || errorB != null) {
            final parts = <String>[];
            if (errorA != null) parts.add('Transaction fee: $errorA');
            if (errorB != null) parts.add('Premium: $errorB');
            combinedError = parts.join('\n');
          }

          return RefreshIndicator(
            color: _blue,
            onRefresh: _fetchFirstPageAll,
            child: CustomScrollView(
              controller: _scrollC,
              physics: const AlwaysScrollableScrollPhysics(),
              slivers: [
                const _StickyAppBarSimple(
                  title: 'WaveUp',
                  subtitle: 'Payment history',
                ),

                if (isLoading && merged.isEmpty)
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

                if (combinedError != null && merged.isEmpty && !isLoading)
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(16, 10, 16, 24),
                      child: _HistoryErrorBox(
                        message: combinedError,
                        onRetry: _fetchFirstPageAll,
                        blue: _blue,
                        border: _border,
                      ),
                    ),
                  ),

                if (!isLoading && combinedError == null && merged.isEmpty)
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(16, 10, 16, 24),
                      child: _HistoryEmptyBox(blue: _blue, border: _border),
                    ),
                  ),

                if (merged.isNotEmpty)
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
                    sliver: SliverList(
                      delegate: SliverChildBuilderDelegate((context, index) {
                        final row = merged[index];

                        final createdAtText = row.createdAt != null
                            ? fDateShort.format(row.createdAt!.toLocal())
                            : '-';

                        final paidAtText = row.paidAt != null
                            ? fDateShort.format(row.paidAt!.toLocal())
                            : null;

                        final amountText = 'Rp ${fMoney.format(row.amount)}';

                        final paidStatus = (row.paidStatus)
                            .toString()
                            .toLowerCase();
                        final isPaid =
                            row.paid == 1 || paidStatus.toLowerCase() == 'paid';

                        final rowMonthKey = row.createdAt != null
                            ? fMonthKey.format(row.createdAt!.toLocal())
                            : 'unknown';

                        final rowMonthHeader = row.createdAt != null
                            ? fMonthHeader.format(row.createdAt!.toLocal())
                            : 'Unknown date';

                        String? prevMonthHeader;
                        if (index > 0) {
                          final prev = merged[index - 1];
                          prevMonthHeader = prev.createdAt != null
                              ? fMonthHeader.format(prev.createdAt!.toLocal())
                              : 'Unknown date';
                        }

                        final showMonthHeader =
                            index == 0 || rowMonthHeader != prevMonthHeader;

                        final type = _rowTypeOf(row);

                        // ✅ kondisi inti (per type)
                        final monthHasPaid = paidKeys.contains(
                          '$type|$rowMonthKey',
                        );
                        final isCurrentMonth = rowMonthKey == currentMonthKey;

                        final isTxnFee =
                            type ==
                            SubscriptionProvider.kHistoryTypeTransactionFee;

                        // ✅ transaction_fee: boleh muncul pay walaupun bulan lalu/asalkan month tsb belum ada PAID
                        // ✅ premium_business: tetap hanya current month (behavior lama)
                        final showPayAgain =
                            !isPaid &&
                            !monthHasPaid &&
                            (isTxnFee || isCurrentMonth);

                        const showDownloadInvoice = true;

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
                                  rowMonthHeader,
                                  style: const TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w800,
                                    color: _text,
                                  ),
                                ),
                              ),
                            ],
                            _HistoryCard(
                              row: row,
                              createdAtText: createdAtText,
                              paidAtText: paidAtText,
                              amountText: amountText,
                              isPaid: isPaid,
                              showPayAgain: showPayAgain,
                              showDownloadInvoice: showDownloadInvoice,
                              blue: _blue,
                              blueDark: _blueDark,
                              blueSoft: _blueSoft,
                              border: _border,
                              muted: _muted,
                              muted2: _muted2,
                              text: _text,
                              typeIcon: _typeIcon(type),

                              neutralSoft: _neutralSoft,
                              neutralBorder: _neutralBorder,
                              neutralIcon: _neutralIcon,
                              neutralText: _neutralText,
                              neutralSubText: _neutralSubText,
                              successBg: _successBg,
                              successBorder: _successBorder,
                              successFg: _successFg,
                              dangerBg: _dangerBg,
                              dangerBorder: _dangerBorder,
                              dangerFg: _dangerFg,
                            ),
                            const SizedBox(height: 12),
                          ],
                        );
                      }, childCount: merged.length),
                    ),
                  ),

                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 6, 16, 24),
                    child: Column(
                      children: [
                        if (isLoadingMore) ...[
                          const SizedBox(height: 8),
                          SizedBox(
                            height: 22,
                            width: 22,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: _blue,
                            ),
                          ),
                          const SizedBox(height: 10),
                          const Text(
                            'Loading more...',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: _muted,
                            ),
                          ),
                        ] else if (moreError != null) ...[
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              color: _blueSoft,
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(
                                color: const Color(0xFFBFDBFE),
                              ),
                            ),
                            child: Row(
                              children: [
                                const Icon(Icons.info_rounded, color: _blue),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Text(
                                    moreError,
                                    style: const TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w700,
                                      color: _blue,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 10),
                                TextButton(
                                  onPressed: _fetchMoreAll,
                                  style: TextButton.styleFrom(
                                    foregroundColor: _blue,
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
                        ] else if (!hasMore && merged.isNotEmpty) ...[
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

class _StickyAppBarSimple extends StatelessWidget {
  final String title;
  final String subtitle;

  const _StickyAppBarSimple({required this.title, required this.subtitle});

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
            color: const Color(0xFF111827),
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
      bottom: const PreferredSize(
        preferredSize: Size.fromHeight(1),
        child: Divider(height: 1, thickness: 1, color: Color(0xFFE5E7EB)),
      ),
    );
  }
}

/// =======================
///  HISTORY CARD
///  - badge hanya PAID/UNPAID
///  - harga benar-benar kanan (Expanded + Align end)
/// =======================
class _HistoryCard extends StatelessWidget {
  final SubscriptionHistoryItem row;
  final String createdAtText;
  final String? paidAtText;
  final String amountText;
  final bool isPaid;

  final bool showPayAgain;
  final bool showDownloadInvoice;

  final Color blue;
  final Color blueDark;
  final Color blueSoft;
  final Color border;
  final Color muted;
  final Color muted2;
  final Color text;

  final IconData typeIcon;

  final Color neutralSoft;
  final Color neutralBorder;
  final Color neutralIcon;
  final Color neutralText;
  final Color neutralSubText;

  final Color successBg;
  final Color successBorder;
  final Color successFg;

  final Color dangerBg;
  final Color dangerBorder;
  final Color dangerFg;

  const _HistoryCard({
    required this.row,
    required this.createdAtText,
    required this.paidAtText,
    required this.amountText,
    required this.isPaid,
    required this.showPayAgain,
    required this.showDownloadInvoice,
    required this.blue,
    required this.blueDark,
    required this.blueSoft,
    required this.border,
    required this.muted,
    required this.muted2,
    required this.text,
    required this.typeIcon,
    required this.neutralSoft,
    required this.neutralBorder,
    required this.neutralIcon,
    required this.neutralText,
    required this.neutralSubText,
    required this.successBg,
    required this.successBorder,
    required this.successFg,
    required this.dangerBg,
    required this.dangerBorder,
    required this.dangerFg,
  });

  static const double _radius = 18;
  static const double _innerRadius = 14;

  Future<void> _download(BuildContext context) async {
    await context.read<SubscriptionProvider>().downloadInvoicePdfFromHistory(
      context: context,
      item: row,
      openAfterSave: true,
    );
  }

  Future<void> _payAgain(BuildContext context) async {
    await context.read<SubscriptionProvider>().retryPaymentFromHistory(
      context: context,
      item: row,
    );
  }

  Widget _statusPill({
    required String label,
    required IconData icon,
    required Color bg,
    required Color bd,
    required Color fg,
  }) {
    return Container(
      height: 28,
      padding: const EdgeInsets.symmetric(horizontal: 10),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: bd),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: fg),
          const SizedBox(width: 6),
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 11.5,
              fontWeight: FontWeight.w900,
              color: fg,
              height: 1.0,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final titleText = row.description.trim().isNotEmpty
        ? row.description.trim()
        : (row.planName.isNotEmpty ? row.planName : 'Payment');

    final invoiceText = row.number.isNotEmpty
        ? row.number
        : (row.id.isNotEmpty ? row.id : '-');

    final rawMethod = row.paymentMethodName.trim();
    final isUnknownMethod =
        rawMethod.isEmpty || rawMethod.toLowerCase() == 'unknown';

    final isTransactionFee =
        row.type.trim().toLowerCase() ==
        SubscriptionProvider.kHistoryTypeTransactionFee;

    // kalau unknown, kita set null biar gampang hide
    final String? methodText = isUnknownMethod ? null : rawMethod;

    final statusBg = isPaid ? successBg : dangerBg;
    final statusBorder = isPaid ? successBorder : dangerBorder;
    final statusFg = isPaid ? successFg : dangerFg;
    final statusIcon = isPaid
        ? Icons.check_circle_rounded
        : Icons.cancel_rounded;

    final rawStatus = row.paidStatus.trim();
    final statusText = rawStatus.isNotEmpty
        ? rawStatus[0].toUpperCase() + rawStatus.substring(1).toLowerCase()
        : (isPaid ? 'Paid' : 'Unpaid');

    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(_radius),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(_radius),
          border: Border.all(color: border),
          boxShadow: const [
            BoxShadow(
              blurRadius: 18,
              offset: Offset(0, 10),
              color: Color(0x12000000),
            ),
          ],
        ),
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ✅ Header: status kiri, amount benar-benar kanan
            Row(
              children: [
                _statusPill(
                  label: statusText,
                  icon: statusIcon,
                  bg: statusBg,
                  bd: statusBorder,
                  fg: statusFg,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Align(
                    alignment: Alignment.centerRight,
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerRight,
                      child: Text(
                        amountText,
                        textAlign: TextAlign.right,
                        softWrap: false,
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w900,
                          color: text,
                          letterSpacing: -0.2,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 12),

            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: blueSoft,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFFBFDBFE)),
                  ),
                  child: Icon(typeIcon, color: blueDark, size: 20),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        titleText,
                        style: TextStyle(
                          fontSize: 14.5,
                          fontWeight: FontWeight.w900,
                          color: text,
                          height: 1.2,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 6),
                      Wrap(
                        spacing: 8,
                        runSpacing: 4,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          Text(
                            'Invoice $invoiceText',
                            style: TextStyle(
                              fontSize: 11.5,
                              fontWeight: FontWeight.w700,
                              color: muted,
                              height: 1.0,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          Container(
                            width: 4,
                            height: 4,
                            decoration: BoxDecoration(
                              color: muted2,
                              borderRadius: BorderRadius.circular(999),
                            ),
                          ),
                          Text(
                            'Created $createdAtText',
                            style: TextStyle(
                              fontSize: 11.5,
                              fontWeight: FontWeight.w600,
                              color: muted2,
                              height: 1.0,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),

            const SizedBox(height: 12),

            if (methodText != null) ...[
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  color: neutralSoft,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: neutralBorder),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.account_balance_wallet_rounded,
                      size: 16,
                      color: neutralIcon,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        methodText,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                          color: neutralText,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (paidAtText != null && paidAtText!.isNotEmpty) ...[
                      const SizedBox(width: 10),
                      Icon(
                        Icons.schedule_rounded,
                        size: 16,
                        color: neutralSubText,
                      ),
                      const SizedBox(width: 6),
                      Flexible(
                        child: Text(
                          paidAtText!,
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: neutralSubText,
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
            ] else ...[
              const SizedBox(height: 2),
            ],

            const SizedBox(height: 12),

            // ✅ View detail transaction fee
            if (isTransactionFee) ...[
              SizedBox(
                width: double.infinity,
                height: 44,
                child: OutlinedButton.icon(
                  onPressed: () {
                    // ✅ Aman walau field transactionFeeId belum ada di model
                    var feeId = row.id.trim();

                    try {
                      final dyn = row as dynamic;
                      final v = dyn.transactionFeeId;
                      final s = v?.toString().trim() ?? '';
                      if (s.isNotEmpty && s.toLowerCase() != 'null') {
                        feeId = s;
                      }
                    } catch (_) {
                      // ignore: kalau getter tidak ada, tetap pakai row.id
                    }

                    if (feeId.isEmpty) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Transaction fee id not available.'),
                        ),
                      );
                      return;
                    }

                    Navigator.pushNamed(
                      context,
                      '/business/transaction-fee/detail',
                      arguments: {'idTransactionFee': feeId},
                    );
                  },
                  style: OutlinedButton.styleFrom(
                    foregroundColor: blue,
                    side: const BorderSide(color: Color(0xFFBFDBFE)),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(_innerRadius),
                    ),
                    backgroundColor: Colors.white,
                  ),
                  icon: const Icon(Icons.receipt_long_rounded, size: 18),
                  label: const Text(
                    'View detail transaction',
                    style: TextStyle(
                      fontWeight: FontWeight.w900,
                      fontSize: 13.5,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 10),
            ],

            if (showPayAgain && showDownloadInvoice) ...[
              Row(
                children: [
                  Expanded(
                    child: SizedBox(
                      height: 44,
                      child: OutlinedButton.icon(
                        onPressed: () => _download(context),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: blue,
                          side: const BorderSide(color: Color(0xFFBFDBFE)),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(_innerRadius),
                          ),
                          backgroundColor: Colors.white,
                        ),
                        icon: const Icon(Icons.download_rounded, size: 18),
                        label: const Text(
                          'Invoice',
                          style: TextStyle(
                            fontWeight: FontWeight.w900,
                            fontSize: 13.5,
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: SizedBox(
                      height: 44,
                      child: ElevatedButton.icon(
                        onPressed: () => _payAgain(context),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: blue,
                          foregroundColor: Colors.white,
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(_innerRadius),
                          ),
                        ),
                        icon: const Icon(Icons.payment, size: 18),
                        label: const Text(
                          'Pay',
                          style: TextStyle(
                            fontWeight: FontWeight.w900,
                            fontSize: 13.5,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ] else if (showDownloadInvoice) ...[
              SizedBox(
                width: double.infinity,
                height: 44,
                child: ElevatedButton.icon(
                  onPressed: () => _download(context),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: blue,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(_innerRadius),
                    ),
                  ),
                  icon: const Icon(Icons.download_rounded, size: 18),
                  label: const Text(
                    'Download Invoice',
                    style: TextStyle(
                      fontWeight: FontWeight.w900,
                      fontSize: 13.5,
                    ),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _HistoryErrorBox extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;
  final Color blue;
  final Color border;

  const _HistoryErrorBox({
    required this.message,
    required this.onRetry,
    required this.blue,
    required this.border,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFEFF6FF),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFBFDBFE)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Failed to load history',
            style: TextStyle(fontWeight: FontWeight.w900, color: blue),
          ),
          const SizedBox(height: 6),
          Text(
            message,
            style: TextStyle(fontWeight: FontWeight.w600, color: blue),
          ),
          const SizedBox(height: 12),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Retry'),
              style: TextButton.styleFrom(foregroundColor: blue),
            ),
          ),
        ],
      ),
    );
  }
}

class _HistoryEmptyBox extends StatelessWidget {
  final Color blue;
  final Color border;

  const _HistoryEmptyBox({required this.blue, required this.border});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: border),
        boxShadow: const [
          BoxShadow(
            blurRadius: 18,
            offset: Offset(0, 10),
            color: Color(0x14000000),
          ),
        ],
      ),
      child: Column(
        children: [
          const SizedBox(height: 6),
          Icon(Icons.receipt_long_rounded, size: 38, color: blue),
          const SizedBox(height: 12),
          const Text(
            'No payments yet',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w900,
              color: Color(0xFF111827),
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Payments will appear here once available.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontWeight: FontWeight.w600,
              color: Color(0xFF6B7280),
              height: 1.3,
            ),
          ),
          const SizedBox(height: 6),
        ],
      ),
    );
  }
}

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
        const base = 0xFFE5E7EB;
        const hi = 0xFFF1F5F9;
        final c = Color.lerp(const Color(base), const Color(hi), t)!;

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
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: const Color(0xFFE5E7EB)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  bar(w: 86, h: 28),
                  const Spacer(),
                  bar(w: 120, h: 22),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: c,
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        bar(w: 220, h: 12),
                        const SizedBox(height: 8),
                        bar(w: 180, h: 10),
                      ],
                    ),
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
              bar(h: 44),
            ],
          ),
        );
      },
    );
  }
}
