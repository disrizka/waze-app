// lib/screens/report/sales_report_screen.dart
import 'dart:convert';

import 'package:dotted_border/dotted_border.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:wa_blast/l10n/app_localizations.dart';
import 'package:wa_blast/providers/sales_provider.dart';
import 'package:wa_blast/widgets/reusable_pickers.dart';

/// Sales Report with search + date range + store filter + infinite scroll
class SalesReportScreen extends StatefulWidget {
  const SalesReportScreen({super.key});

  @override
  State<SalesReportScreen> createState() => _SalesReportScreenState();
}

class _SalesReportScreenState extends State<SalesReportScreen> {
  final _searchC = TextEditingController();
  DateTimeRange? _range;

  // infinite scroll
  final ScrollController _scrollController = ScrollController();
  int _currentPage = 1;
  final int _limit = 30;
  bool _isLoadingMore = false;
  bool _hasMore = true;

  // store filter (local)
  String? _selectedStoreId;
  String? _selectedStoreName;
  String? _selectedCustomerId;
  String? _selectedCustomerName;

  // ✅ banned status for active business: null / "semi-ban" / "ban"
  String? _bannedStatus;

  bool get _isHardBanned {
    final s = (_bannedStatus ?? '').trim().toLowerCase();
    return s == 'ban' || s == 'banned';
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;

      // ✅ load banned status first (from prefs)
      await _loadBannedStatusFromPrefs();

      // existing flow
      await _loadFirstPage();
      _scrollController.addListener(_onScroll);
    });
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    _searchC.dispose();
    super.dispose();
  }

  Future<void> _loadBannedStatusFromPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    final activeId = (prefs.getString('activeBizId') ?? '').trim();

    // 1) prefer from business list JSON (most accurate)
    final raw = prefs.getString('business');
    if (raw != null && raw.isNotEmpty && activeId.isNotEmpty) {
      try {
        final list = (jsonDecode(raw) as List).cast<Map<String, dynamic>>();
        final match = list.firstWhere(
          (e) => (e['idBusiness'] ?? '').toString() == activeId,
          orElse: () => <String, dynamic>{},
        );

        final banned = match.isEmpty ? null : match['banned'];
        _bannedStatus = (banned == null) ? null : banned.toString();

        if (mounted) setState(() {});
        return;
      } catch (_) {
        // fallthrough
      }
    }

    // 2) optional fallback key (if you store it yourself)
    final fallback = prefs.getString('activeBizBanned');
    _bannedStatus = (fallback == null || fallback.trim().isEmpty)
        ? null
        : fallback.trim();

    if (mounted) setState(() {});
  }

  Future<void> _showBannedPaywallModal() async {
    if (!mounted) return;

    await showGeneralDialog(
      context: context,
      barrierLabel: 'Paywall',
      barrierDismissible: true,
      barrierColor: Colors.black.withOpacity(0.35),
      transitionDuration: const Duration(milliseconds: 220),
      pageBuilder: (ctx, anim, secondaryAnim) => const SizedBox.shrink(),
      transitionBuilder: (ctx, animation, secondaryAnimation, child) {
        final curved = CurvedAnimation(
          parent: animation,
          curve: Curves.easeOutCubic,
        );
        final scale = Tween<double>(begin: 0.96, end: 1.0).animate(curved);

        return FadeTransition(
          opacity: curved,
          child: ScaleTransition(
            scale: scale,
            child: Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Material(
                  color: Colors.transparent,
                  child: Container(
                    constraints: const BoxConstraints(maxWidth: 420),
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 14),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.18),
                          blurRadius: 24,
                          offset: const Offset(0, 14),
                        ),
                      ],
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Row(
                          children: [
                            Container(
                              width: 44,
                              height: 44,
                              decoration: BoxDecoration(
                                color: const Color(0xFFFEE2E2),
                                borderRadius: BorderRadius.circular(14),
                              ),
                              child: const Icon(
                                Icons.lock_rounded,
                                color: Color(0xFFDC2626),
                              ),
                            ),
                            const SizedBox(width: 12),
                            const Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Sales access locked',
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w800,
                                      color: Color(0xFF111827),
                                    ),
                                  ),
                                  SizedBox(height: 4),
                                  Text(
                                    'Please pay your monthly bill to access Sales features.',
                                    style: TextStyle(
                                      fontSize: 12,
                                      height: 1.35,
                                      color: Color(0xFF6B7280),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 6),
                          ],
                        ),
                        const SizedBox(height: 16),
                        SizedBox(
                          width: double.infinity,
                          height: 48,
                          child: ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFFDC2626),
                              elevation: 0,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14),
                              ),
                            ),
                            onPressed: () {
                              Navigator.of(ctx).pop();
                              Navigator.pushNamed(context, '/subscription');
                            },
                            child: const Text(
                              'Pay now',
                              style: TextStyle(
                                fontWeight: FontWeight.w800,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 8),
                        SizedBox(
                          width: double.infinity,
                          height: 44,
                          child: TextButton(
                            onPressed: () => Navigator.of(ctx).pop(),
                            child: const Text(
                              'Maybe later',
                              style: TextStyle(
                                fontWeight: FontWeight.w700,
                                color: Color(0xFF6B7280),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  void _onScroll() {
    if (!_hasMore || _isLoadingMore) return;
    if (!_scrollController.hasClients) return;

    final pos = _scrollController.position;
    if (pos.pixels >= pos.maxScrollExtent - 200) {
      _loadNextPage();
    }
  }

  Future<void> _loadFirstPage() async {
    final prov = context.read<SalesProvider>();
    _currentPage = 1;
    _hasMore = true;
    _isLoadingMore = false;

    await prov.fetchSalesReports(
      context,
      page: _currentPage,
      limit: _limit,
      append: false,
      storeLocationId: _selectedStoreId,
      customerId: _selectedCustomerId,
    );
    if (mounted) setState(() {});
  }

  Future<void> _loadNextPage() async {
    final prov = context.read<SalesProvider>();
    if (prov.loadingReports) return;

    _isLoadingMore = true;
    if (mounted) setState(() {});

    final before = prov.reports.length;

    await prov.fetchSalesReports(
      context,
      page: _currentPage + 1,
      limit: _limit,
      append: true,
      storeLocationId: _selectedStoreId,
      customerId: _selectedCustomerId,
    );

    final after = prov.reports.length;
    if (after == before) {
      _hasMore = false;
    } else {
      _currentPage += 1;
    }

    _isLoadingMore = false;
    if (mounted) setState(() {});
  }

  Future<DateTimeRange?> _pickRangeDialog({DateTimeRange? initial}) async {
    final l10n = AppLocalizations.of(context)!;
    final now = DateTime.now();
    final firstDate = DateTime(now.year - 3);
    final lastDate = DateTime(now.year + 1, 12, 31);

    final res = await showDateRangePicker(
      context: context,
      initialDateRange:
          initial ??
          DateTimeRange(
            start: DateTime(now.year, now.month, now.day),
            end: DateTime(now.year, now.month, now.day),
          ),
      firstDate: firstDate,
      lastDate: lastDate,
      saveText: l10n.salesDateApply,
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: Color(0xFF426FD4),
              onPrimary: Colors.white,
              surface: Colors.white,
              onSurface: Color(0xFF111827),
            ),
          ),
          child: child!,
        );
      },
    );

    if (res == null) return null;

    return DateTimeRange(
      start: DateTime(res.start.year, res.start.month, res.start.day),
      end: DateTime(res.end.year, res.end.month, res.end.day, 23, 59, 59),
    );
  }

  Future<void> _openAdvancedFilter() async {
    final result = await showModalBottomSheet<_SalesAdvancedFilterResult>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => _SalesAdvancedFilterSheet(
        initialRange: _range,
        initialStoreId: _selectedStoreId,
        initialStoreName: _selectedStoreName,
        initialCustomerId: _selectedCustomerId,
        initialCustomerName: _selectedCustomerName,
        onPickRange: (initial) => _pickRangeDialog(initial: initial),
      ),
    );

    if (!mounted || result == null) return;

    final prevStore = _selectedStoreId;
    final prevCustomer = _selectedCustomerId;
    setState(() {
      _range = result.range;
      _selectedStoreId = result.storeId;
      _selectedStoreName = result.storeName;
      _selectedCustomerId = result.customerId;
      _selectedCustomerName = result.customerName;
    });

    // store/customer filter affects backend fetch
    if (prevStore != _selectedStoreId || prevCustomer != _selectedCustomerId) {
      await _loadFirstPage();
    } else {
      // only date change => client-side filter, cukup rebuild
      if (mounted) setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    final fTime = DateFormat('dd MMM yyyy, HH:mm');
    final fMoney = NumberFormat.decimalPattern('id_ID');

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        scrolledUnderElevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded),
          onPressed: () => Navigator.pop(context),
        ),
        title: Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.baseline,
          textBaseline: TextBaseline.alphabetic,
          children: [
            Text(
              l10n.salesTitle,
              style: const TextStyle(fontWeight: FontWeight.w800),
            ),
            const SizedBox(width: 8),
            Text(
              l10n.salesHistorySuffix,
              style: const TextStyle(
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
      body: Consumer<SalesProvider>(
        builder: (context, prov, _) {
          final items = prov.reports;
          final isLoading = prov.loadingReports;
          final error = prov.reportError;

          // client-side filter search & date
          final filtered = items.where((it) {
            final q = _searchC.text.trim().toLowerCase();
            final matchesQuery = q.isEmpty
                ? true
                : [
                    it.code,
                    it.reference,
                    it.status,
                  ].whereType<String>().any((s) => s.toLowerCase().contains(q));

            final matchesRange = _range == null
                ? true
                : (it.time.isAfter(_range!.start) ||
                          it.time.isAtSameMomentAs(_range!.start)) &&
                      (it.time.isBefore(_range!.end) ||
                          it.time.isAtSameMomentAs(_range!.end));

            return matchesQuery && matchesRange;
          }).toList();

          // ===== top controls: SAME FEEL as ProductScreen =====
          final topControls = Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _searchC,
                    onChanged: (_) => setState(() {}),
                    textInputAction: TextInputAction.search,
                    decoration: InputDecoration(
                      hintText: l10n.salesSearchHint,
                      isDense: true,
                      filled: true,
                      fillColor: const Color(0xFFF3F4F6),
                      prefixIcon: const Icon(Icons.search, size: 20),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 12,
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderSide: const BorderSide(color: Color(0xFFCBD5E1)),
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                SizedBox(
                  height: 42,
                  width: 42,
                  child: ElevatedButton(
                    onPressed: _openAdvancedFilter,
                    style: ElevatedButton.styleFrom(
                      padding: EdgeInsets.zero,
                      backgroundColor: const Color(0xFF426FD4),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                      elevation: 0,
                    ),
                    child: const Icon(Icons.tune_rounded, size: 20),
                  ),
                ),
              ],
            ),
          );

          return RefreshIndicator(
            onRefresh: () async {
              // ✅ refresh banned status too (in case it changed)
              await _loadBannedStatusFromPrefs();
              await _loadFirstPage();
            },
            color: const Color(0xFF426FD4),
            child: CustomScrollView(
              controller: _scrollController,
              physics: const AlwaysScrollableScrollPhysics(),
              slivers: [
                // TOP BAR
                SliverToBoxAdapter(child: topControls),

                // OPTIONAL: tiny minimal info line (subtle)
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 2, 16, 10),
                    child: _FiltersHintLine(
                      storeName: _selectedStoreName,
                      customerName: _selectedCustomerName,
                      range: _range,
                    ),
                  ),
                ),

                // STATES
                if (isLoading && items.isEmpty)
                  const SliverToBoxAdapter(
                    child: Padding(
                      padding: EdgeInsets.fromLTRB(16, 24, 16, 24),
                      child: Center(child: CircularProgressIndicator()),
                    ),
                  )
                else if (error != null && items.isEmpty)
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(16, 24, 16, 24),
                      child: _ErrorBox(message: error, onRetry: _loadFirstPage),
                    ),
                  )
                else if (items.isEmpty)
                  const SliverToBoxAdapter(
                    child: Padding(
                      padding: EdgeInsets.fromLTRB(16, 24, 16, 24),
                      child: _EmptyBox(),
                    ),
                  )
                else ...[
                  // HEADER (keep existing behavior)
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(16, 6, 16, 8),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              (_selectedStoreName == null ||
                                      _selectedStoreName!.isEmpty)
                                  ? l10n.salesStoreLabelAll
                                  : l10n.salesStoreLabelWithName(
                                      _selectedStoreName!,
                                    ),
                              style: const TextStyle(
                                fontSize: 12,
                                color: Color(0xFF9CA3AF),
                              ),
                            ),
                          ),
                          if (isLoading)
                            const SizedBox(
                              height: 16,
                              width: 16,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            ),
                        ],
                      ),
                    ),
                  ),

                  // LIST
                  SliverList.separated(
                    itemCount: filtered.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 12),
                    itemBuilder: (context, index) {
                      final it = filtered[index];
                      final title = it.code.isEmpty ? it.reference : it.code;

                      final card = DottedBorder(
                        options: const RoundedRectDottedBorderOptions(
                          color: Color(0xFFD1D5DB),
                          dashPattern: [6, 6],
                          strokeWidth: 1.4,
                          radius: Radius.circular(12),
                          padding: EdgeInsets.all(0),
                        ),
                        child: Container(
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Container(
                                    width: 44,
                                    height: 44,
                                    decoration: BoxDecoration(
                                      color: Colors.indigo.shade50,
                                      shape: BoxShape.circle,
                                    ),
                                    child: Icon(
                                      Icons.receipt_long_rounded,
                                      size: 20,
                                      color: Colors.indigo.shade700,
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          title,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: const TextStyle(
                                            fontSize: 16,
                                            fontWeight: FontWeight.w700,
                                            color: Color(0xFF111827),
                                          ),
                                        ),
                                        const SizedBox(height: 2),
                                        Text(
                                          fTime.format(it.time),
                                          style: const TextStyle(
                                            fontSize: 12,
                                            color: Color(0xFF9CA3AF),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  _StatusChip(status: it.status),
                                ],
                              ),
                              const SizedBox(height: 16),
                              Row(
                                children: [
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          l10n.salesTotalAmount,
                                          style: const TextStyle(
                                            fontSize: 12,
                                            color: Color(0xFF6B7280),
                                          ),
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          'Rp ${fMoney.format(it.totalAmount)}',
                                          style: const TextStyle(
                                            fontSize: 16,
                                            fontWeight: FontWeight.w700,
                                            color: Color(0xFF111827),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  Column(
                                    crossAxisAlignment: CrossAxisAlignment.end,
                                    children: [
                                      Text(
                                        l10n.salesQuantity,
                                        style: const TextStyle(
                                          fontSize: 12,
                                          color: Color(0xFF6B7280),
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        '${it.quantity}',
                                        style: const TextStyle(
                                          fontSize: 18,
                                          fontWeight: FontWeight.w700,
                                          color: Color(0xFF111827),
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      );

                      return Padding(
                        padding: const EdgeInsets.fromLTRB(16, 0, 16, 0),
                        child: GestureDetector(
                          behavior: HitTestBehavior.opaque,
                          onTap: () {
                            Navigator.pushNamed(
                              context,
                              '/sales/list/detail',
                              arguments: {'id': it.idTransaction},
                            );
                          },
                          child: card,
                        ),
                      );
                    },
                  ),

                  // FOOTER LOADER
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
                      child: Center(
                        child: _isLoadingMore
                            ? const SizedBox(
                                height: 24,
                                width: 24,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : const SizedBox.shrink(),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          );
        },
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
          child: SizedBox(
            width: double.infinity,
            height: 56,
            child: FilledButton.icon(
              onPressed: () async {
                // ✅ if business is hard-banned, block and show pay modal
                if (_isHardBanned) {
                  await _showBannedPaywallModal();
                  return;
                }
                Navigator.pushNamed(context, '/sales/add');
              },
              icon: const Icon(Icons.add, size: 20),
              label: Text(
                l10n.salesAddButton,
                style: const TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 16,
                ),
              ),
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFF426FD4),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// =======================================================
// Helpers & widgets
// =======================================================

String formatRangeCompact(DateTimeRange r) {
  final s = r.start;
  final e = r.end;
  final mS = DateFormat('MMM').format(s);
  final mE = DateFormat('MMM').format(e);

  if (s.year == e.year && s.month == e.month) {
    return '${s.day} $mS — ${e.day}';
  } else if (s.year == e.year) {
    return '${s.day} $mS — ${e.day} $mE';
  } else {
    return '${s.day} $mS ${s.year} — ${e.day} $mE ${e.year}';
  }
}

class _FiltersHintLine extends StatelessWidget {
  const _FiltersHintLine({
    required this.storeName,
    required this.customerName,
    required this.range,
  });
  final String? storeName;
  final String? customerName;
  final DateTimeRange? range;

  @override
  Widget build(BuildContext context) {
    final parts = <String>[];
    if (storeName != null && storeName!.trim().isNotEmpty) {
      parts.add(storeName!.trim());
    }
    if (customerName != null && customerName!.trim().isNotEmpty) {
      parts.add(customerName!.trim());
    }
    if (range != null) {
      parts.add(formatRangeCompact(range!));
    }

    if (parts.isEmpty) return const SizedBox.shrink();

    return Row(
      children: [
        const Icon(
          Icons.filter_alt_rounded,
          size: 14,
          color: Color(0xFF9CA3AF),
        ),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            parts.join(' • '),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 12, color: Color(0xFF9CA3AF)),
          ),
        ),
      ],
    );
  }
}

class _SalesAdvancedFilterResult {
  final DateTimeRange? range;
  final String? storeId;
  final String? storeName;
  final String? customerId;
  final String? customerName;

  const _SalesAdvancedFilterResult({
    required this.range,
    required this.storeId,
    required this.storeName,
    required this.customerId,
    required this.customerName,
  });
}

class _SalesAdvancedFilterSheet extends StatefulWidget {
  const _SalesAdvancedFilterSheet({
    required this.initialRange,
    required this.initialStoreId,
    required this.initialStoreName,
    required this.initialCustomerId,
    required this.initialCustomerName,
    required this.onPickRange,
  });

  final DateTimeRange? initialRange;
  final String? initialStoreId;
  final String? initialStoreName;
  final String? initialCustomerId;
  final String? initialCustomerName;

  final Future<DateTimeRange?> Function(DateTimeRange? initial) onPickRange;

  @override
  State<_SalesAdvancedFilterSheet> createState() =>
      _SalesAdvancedFilterSheetState();
}

class _SalesAdvancedFilterSheetState extends State<_SalesAdvancedFilterSheet> {
  DateTimeRange? _range;
  String? _storeId;
  String? _storeName;
  String? _customerId;
  String? _customerName;

  @override
  void initState() {
    super.initState();
    _range = widget.initialRange;
    _storeId = widget.initialStoreId;
    _storeName = widget.initialStoreName;
    _customerId = widget.initialCustomerId;
    _customerName = widget.initialCustomerName;
  }

  Future<void> _pickStore() async {
    final result = await showStorePickerSheet(
      context,
      selectedId: _storeId,
      autoSelectWhenSingle: false,
    );
    if (result == null) return;

    setState(() {
      _storeId = result.id;
      _storeName = result.label;
    });
  }

  Future<void> _pickRange() async {
    final picked = await widget.onPickRange(_range);
    if (picked == null) return;
    setState(() => _range = picked);
  }

  Future<void> _pickCustomer() async {
    final picked = await showCustomerPickerSheet(
      context,
      selectedId: _customerId,
    );
    if (picked == null) return;
    setState(() {
      _customerId = picked.id;
      _customerName = picked.label;
    });
  }

  void _resetAll() {
    setState(() {
      _range = null;
      _storeId = null;
      _storeName = null;
      _customerId = null;
      _customerName = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    final rangeLabel = _range == null
        ? l10n.salesFilterAnyTime
        : formatRangeCompact(_range!);

    final storeLabel = (_storeName == null || _storeName!.trim().isEmpty)
        ? l10n.salesStoreAll
        : _storeName!.trim();
    final customerLabel =
        (_customerName == null || _customerName!.trim().isEmpty)
        ? 'All customer'
        : _customerName!.trim();

    return DraggableScrollableSheet(
      initialChildSize: 0.78,
      minChildSize: 0.55,
      maxChildSize: 0.92,
      expand: false,
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
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                children: [
                  const Expanded(
                    child: Text(
                      'Advanced Filter',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF111827),
                      ),
                    ),
                  ),
                  TextButton(
                    onPressed: _resetAll,
                    child: const Text(
                      'Reset all',
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF111827),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton(
                    onPressed: () {
                      Navigator.pop(
                        context,
                        _SalesAdvancedFilterResult(
                          range: _range,
                          storeId: _storeId,
                          storeName: _storeName,
                          customerId: _customerId,
                          customerName: _customerName,
                        ),
                      );
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF426FD4),
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: const Text(
                      'Apply',
                      style: TextStyle(fontWeight: FontWeight.w800),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            const Divider(height: 1, color: Color(0xFFE5E7EB)),
            Expanded(
              child: ListView(
                controller: controller,
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
                children: [
                  const Text(
                    'Filter by',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF6B7280),
                      letterSpacing: 0.2,
                    ),
                  ),
                  const SizedBox(height: 10),

                  _FilterPickTile(
                    icon: Icons.store_mall_directory_rounded,
                    title: 'Store Location',
                    value: storeLabel,
                    onTap: _pickStore,
                    isActive: _storeId != null,
                  ),
                  const SizedBox(height: 10),
                  _FilterPickTile(
                    icon: Icons.person_outline_rounded,
                    title: 'Customer',
                    value: customerLabel,
                    onTap: _pickCustomer,
                    isActive: _customerId != null && _customerId!.isNotEmpty,
                  ),
                  const SizedBox(height: 10),
                  _FilterPickTile(
                    icon: Icons.date_range_rounded,
                    title: 'Date Range',
                    value: rangeLabel,
                    onTap: _pickRange,
                    isActive: _range != null,
                  ),

                  const SizedBox(height: 18),
                ],
              ),
            ),
          ],
        );
      },
    );
  }
}

class _FilterPickTile extends StatelessWidget {
  const _FilterPickTile({
    required this.icon,
    required this.title,
    required this.value,
    required this.onTap,
    required this.isActive,
  });

  final IconData icon;
  final String title;
  final String value;
  final VoidCallback onTap;
  final bool isActive;

  @override
  Widget build(BuildContext context) {
    final activeColor = isActive
        ? const Color(0xFF2563EB)
        : const Color(0xFF111827);

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        decoration: BoxDecoration(
          color: const Color(0xFFF3F4F6),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: const Color(0xFFE5E7EB)),
        ),
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFE5E7EB)),
              ),
              child: Icon(icon, size: 18, color: activeColor),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF111827),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    value,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: isActive
                          ? const Color(0xFF2563EB)
                          : const Color(0xFF6B7280),
                    ),
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right_rounded, color: Color(0xFF9CA3AF)),
          ],
        ),
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  final String status;
  const _StatusChip({required this.status});

  @override
  Widget build(BuildContext context) {
    if (status.isEmpty) return const SizedBox.shrink();

    Color bg;
    Color fg;
    switch (status.toLowerCase()) {
      case 'completed':
      case 'paid':
        bg = const Color(0xFFE6F4EA);
        fg = const Color(0xFF166534);
        break;
      case 'canceled':
      case 'void':
        bg = const Color(0xFFFEE2E2);
        fg = const Color(0xFF991B1B);
        break;
      case 'pending':
      default:
        bg = const Color(0xFFFEF3C7);
        fg = const Color(0xFF92400E);
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        status,
        style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: fg),
      ),
    );
  }
}

class _ErrorBox extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;
  const _ErrorBox({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFFEE2E2),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFFCA5A5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            l10n.salesErrorTitle,
            style: const TextStyle(
              fontWeight: FontWeight.w700,
              color: Color(0xFF991B1B),
            ),
          ),
          const SizedBox(height: 6),
          Text(message, style: const TextStyle(color: Color(0xFF7F1D1D))),
          const SizedBox(height: 10),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh_rounded),
              label: Text(l10n.salesErrorRetry),
              style: TextButton.styleFrom(
                foregroundColor: const Color(0xFF991B1B),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptyBox extends StatelessWidget {
  const _EmptyBox();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFF9FAFB),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Column(
        children: [
          const Icon(
            Icons.receipt_long_rounded,
            size: 32,
            color: Color(0xFF9CA3AF),
          ),
          const SizedBox(height: 8),
          Text(
            l10n.salesEmptyTitle,
            style: const TextStyle(
              fontWeight: FontWeight.w700,
              color: Color(0xFF111827),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            l10n.salesEmptySubtitle,
            textAlign: TextAlign.center,
            style: const TextStyle(color: Color(0xFF6B7280)),
          ),
        ],
      ),
    );
  }
}
