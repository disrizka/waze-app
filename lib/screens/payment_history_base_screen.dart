// lib/screens/business/platform_payment_history_screen.dart
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../providers/subscription_provider.dart';

class PlatformPaymentHistoryScreen extends StatefulWidget {
  /// initial tab/type ketika screen dibuka dari route
  /// valid:
  /// - SubscriptionProvider.kHistoryTypeTransactionFee
  /// - SubscriptionProvider.kHistoryTypePremiumBusiness
  final String initialType;

  const PlatformPaymentHistoryScreen({
    super.key,
    this.initialType = SubscriptionProvider.kHistoryTypeTransactionFee,
  });

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

  static const Color _border = Color(0xFFE5E7EB);
  static const Color _text = Color(0xFF111827);
  static const Color _muted = Color(0xFF6B7280);

  // ✅ Neutral palette for "Payment Method" row (no blue tint)
  static const Color _neutralSoft = Color(0xFFF3F4F6); // light gray background
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

  /// ✅ current selected filter
  late String _selectedType;

  static const _typeOptions = <_HistoryTypeOption>[
    _HistoryTypeOption(
      type: SubscriptionProvider.kHistoryTypeTransactionFee,
      label: 'Transaction fee',
      icon: Icons.receipt_long_rounded,
    ),
    _HistoryTypeOption(
      type: SubscriptionProvider.kHistoryTypePremiumBusiness,
      label: 'Premium',
      icon: Icons.workspace_premium_rounded,
    ),
  ];

  @override
  void initState() {
    super.initState();

    // ✅ apply initial type from route/widget
    _selectedType = _sanitizeType(widget.initialType);

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      await _fetchFirstPage();
    });

    _scrollC.addListener(() {
      if (!mounted) return;
      if (!_scrollC.hasClients) return;

      final prov = context.read<SubscriptionProvider>();
      final pos = _scrollC.position;

      if (pos.pixels >= (pos.maxScrollExtent - 320)) {
        final hasMore = prov.historyHasMoreOf(_selectedType);
        final loading = prov.isLoadingHistoryOf(_selectedType);
        final loadingMore = prov.isLoadingMoreHistoryOf(_selectedType);

        if (hasMore && !loading && !loadingMore) {
          prov.fetchMorePaymentHistory(context, type: _selectedType);
        }
      }
    });
  }

  String _sanitizeType(String t) {
    final v = t.trim();
    if (v == SubscriptionProvider.kHistoryTypePremiumBusiness ||
        v == SubscriptionProvider.kHistoryTypeTransactionFee) {
      return v;
    }
    return SubscriptionProvider.kHistoryTypeTransactionFee;
  }

  Future<void> _fetchFirstPage() async {
    await context.read<SubscriptionProvider>().fetchPaymentHistory(
      context,
      type: _selectedType,
      refresh: true,
    );
  }

  Future<void> _onChangeType(String newType) async {
    final sanitized = _sanitizeType(newType);
    if (sanitized == _selectedType) return;

    setState(() => _selectedType = sanitized);

    if (!mounted) return;

    if (_scrollC.hasClients) {
      try {
        _scrollC.jumpTo(0);
      } catch (_) {}
    }

    await _fetchFirstPage();
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
    final fMonthHeader = DateFormat('MMM yyyy');

    // ✅ key untuk grouping “1 bulan”
    final fMonthKey = DateFormat('yyyy-MM');
    final currentMonthKey = fMonthKey.format(DateTime.now());

    final selectedLabel = _typeOptions
        .firstWhere(
          (e) => e.type == _selectedType,
          orElse: () => _typeOptions.first,
        )
        .label;

    return Scaffold(
      backgroundColor: const Color(0xFFF6F7FB),
      body: Consumer<SubscriptionProvider>(
        builder: (context, prov, _) {
          final items = prov.historyOf(_selectedType);
          final isLoading = prov.isLoadingHistoryOf(_selectedType);
          final isLoadingMore = prov.isLoadingMoreHistoryOf(_selectedType);
          final error = prov.historyErrorOf(_selectedType);
          final moreError = prov.historyMoreErrorOf(_selectedType);
          final hasMore = prov.historyHasMoreOf(_selectedType);

          // ✅ PRECOMPUTE: bulan mana saja yang sudah ada paid
          final Set<String> monthsWithPaid = <String>{};
          for (final it in items) {
            final paidStatus = (it.paidStatus).toString().toLowerCase();
            final isPaid = it.paid == 1 || paidStatus == 'paid';

            final mk = it.createdAt != null
                ? fMonthKey.format(it.createdAt!.toLocal())
                : 'unknown';

            if (isPaid) monthsWithPaid.add(mk);
          }

          return RefreshIndicator(
            color: _blue,
            onRefresh: _fetchFirstPage,
            child: CustomScrollView(
              controller: _scrollC,
              physics: const AlwaysScrollableScrollPhysics(),
              slivers: [
                _StickyAppBar(
                  title: 'WaveUp',
                  subtitle: 'Payment history',
                  selectedType: _selectedType,
                  options: _typeOptions,
                  onChanged: _onChangeType,
                  blue: _blue,
                  border: _border,
                  muted: _muted,
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
                        onRetry: _fetchFirstPage,
                        blue: _blue,
                        border: _border,
                      ),
                    ),
                  ),

                // Empty state
                if (!isLoading && error == null && items.isEmpty)
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(16, 10, 16, 24),
                      child: _HistoryEmptyBox(
                        label: selectedLabel,
                        blue: _blue,
                        border: _border,
                      ),
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
                          final prev = items[index - 1];
                          prevMonthHeader = prev.createdAt != null
                              ? fMonthHeader.format(prev.createdAt!.toLocal())
                              : 'Unknown date';
                        }

                        final showMonthHeader =
                            index == 0 || rowMonthHeader != prevMonthHeader;

                        // ✅ kondisi inti
                        final monthHasPaid = monthsWithPaid.contains(
                          rowMonthKey,
                        );
                        final isCurrentMonth = rowMonthKey == currentMonthKey;

                        // ✅ pay again hanya saat:
                        // - bulan berjalan
                        // - bulan tsb BELUM ada paid sama sekali
                        // - item ini unpaid
                        final showPayAgain =
                            isCurrentMonth && !monthHasPaid && !isPaid;

                        // ✅ download invoice selalu ada (paid & unpaid)
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
                              text: _text,

                              // ✅ inject neutral + status palette
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
                              borderRadius: BorderRadius.circular(16),
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
                                  onPressed: () => context
                                      .read<SubscriptionProvider>()
                                      .fetchMorePaymentHistory(
                                        context,
                                        type: _selectedType,
                                      ),
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

class _HistoryTypeOption {
  final String type;
  final String label;
  final IconData icon;

  const _HistoryTypeOption({
    required this.type,
    required this.label,
    required this.icon,
  });
}

/// =======================
///  STICKY APPBAR + FILTER
/// =======================
class _StickyAppBar extends StatelessWidget {
  final String title;
  final String subtitle;

  final String selectedType;
  final List<_HistoryTypeOption> options;
  final ValueChanged<String> onChanged;

  final Color blue;
  final Color border;
  final Color muted;

  const _StickyAppBar({
    required this.title,
    required this.subtitle,
    required this.selectedType,
    required this.options,
    required this.onChanged,
    required this.blue,
    required this.border,
    required this.muted,
  });

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
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: muted,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      bottom: PreferredSize(
        preferredSize: const Size.fromHeight(54),
        child: Column(
          children: [
            Container(height: 1, color: border),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
              child: Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(color: border),
                ),
                child: Row(
                  children: options.map((opt) {
                    final selected = opt.type == selectedType;

                    return Expanded(
                      child: InkWell(
                        borderRadius: BorderRadius.circular(999),
                        onTap: () => onChanged(opt.type),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 180),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 10,
                          ),
                          decoration: BoxDecoration(
                            color: selected ? blue : Colors.transparent,
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                opt.icon,
                                size: 16,
                                color: selected ? Colors.white : muted,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                opt.label,
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w900,
                                  color: selected ? Colors.white : muted,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// =======================
///  HISTORY CARD
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
  final Color text;

  // ✅ injected neutral + status palette
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
    required this.text,
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

  @override
  Widget build(BuildContext context) {
    final titleText = row.description.trim().isNotEmpty
        ? row.description.trim()
        : (row.planName.isNotEmpty ? row.planName : 'Payment');

    final invoiceText = row.number.isNotEmpty
        ? row.number
        : (row.id.isNotEmpty ? row.id : '-');

    final methodText = row.paymentMethodName.trim().isNotEmpty
        ? row.paymentMethodName
        : (row.paymentMethod != 0
              ? 'Payment method ${row.paymentMethod}'
              : 'Unknown');

    // ✅ Status: green (paid) / red (unpaid)
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
      borderRadius: BorderRadius.circular(18),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: border),
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
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w900,
                          color: text,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Invoice • $invoiceText',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: muted,
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
                        border: Border.all(color: statusBorder),
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
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w900,
                        color: text,
                      ),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 12),

            // ✅ Payment method row: neutral dark-gray style (not blue)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
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

            // ✅ BUTTONS (blue & white only)
            if (showPayAgain && showDownloadInvoice) ...[
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => _download(context),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: blue,
                        side: const BorderSide(color: Color(0xFFBFDBFE)),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                        backgroundColor: Colors.white,
                      ),
                      icon: const Icon(Icons.download_rounded, size: 18),
                      label: const Text(
                        'Download Invoice',
                        style: TextStyle(fontWeight: FontWeight.w900),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () => _payAgain(context),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: blue,
                        foregroundColor: Colors.white,
                        elevation: 0,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      icon: const Icon(Icons.refresh_rounded, size: 18),
                      label: const Text(
                        'Pay again',
                        style: TextStyle(fontWeight: FontWeight.w900),
                      ),
                    ),
                  ),
                ],
              ),
            ] else if (showDownloadInvoice) ...[
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () => _download(context),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: blue,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  icon: const Icon(Icons.download_rounded, size: 18),
                  label: const Text(
                    'Download Invoice',
                    style: TextStyle(fontWeight: FontWeight.w900),
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

/// =======================
///  Empty & Error
/// =======================
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
  final String label;
  final Color blue;
  final Color border;

  const _HistoryEmptyBox({
    required this.label,
    required this.blue,
    required this.border,
  });

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
          Text(
            'No $label payments yet',
            style: const TextStyle(
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
