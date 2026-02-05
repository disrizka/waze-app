// lib/screens/orders/store_order_list_screen.dart
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import 'package:wa_blast/models/store_order_model.dart';
import 'package:wa_blast/providers/order_provider.dart';
import 'package:wa_blast/screens/order/order_detail_screen.dart';

class StoreOrderListScreen extends StatefulWidget {
  const StoreOrderListScreen({super.key});

  @override
  State<StoreOrderListScreen> createState() => _StoreOrderListScreenState();
}

class _StoreOrderListScreenState extends State<StoreOrderListScreen> {
  // Theme
  static const Color _blue = Color(0xFF426FD4);

  final ScrollController _scrollC = ScrollController();
  final int _limit = 20;

  // Search + debounce
  final TextEditingController _searchC = TextEditingController();

  // Advanced filter (state)
  _OrderFilters _filters = const _OrderFilters();

  @override
  void initState() {
    super.initState();

    _scrollC.addListener(_onScroll);

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;

      // initial load
      await context.read<OrderProvider>().fetchStoreOrders(
        context,
        page: 1,
        limit: _limit,
        append: false,
      );
    });
  }

  @override
  void dispose() {
    _searchC.dispose();

    _scrollC.removeListener(_onScroll);
    _scrollC.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (!mounted) return;
    final prov = context.read<OrderProvider>();
    if (!prov.hasMore || prov.loadingMore) return;
    if (!_scrollC.hasClients) return;

    final pos = _scrollC.position;
    if (pos.pixels >= pos.maxScrollExtent - 240) {
      prov.loadNextPage(context, limit: _limit);
    }
  }

  DateTime _resolveCreatedAt(StoreOrder it) {
    if (it.createTimeEpoch > 0) {
      return DateTime.fromMillisecondsSinceEpoch(it.createTimeEpoch * 1000);
    }

    final s = it.createTimeLabel.trim();
    if (s.isNotEmpty) {
      try {
        return DateFormat('dd-MM-yyyy HH:mm', 'id_ID').parseStrict(s);
      } catch (_) {
        // ignore
      }

      final dt2 = DateTime.tryParse(s);
      if (dt2 != null) return dt2;
    }

    return DateTime.now();
  }

  void _applyFilters({required OrderProvider prov, bool scrollToTop = true}) {
    final search = _searchC.text.trim();

    prov.setFilters(
      context,
      search: search.isEmpty ? null : search,
      status: _filters.status,
      startDate: _filters.startDate,
      endDate: _filters.endDate,
      platformName: (_filters.platformKey ?? '').trim().isEmpty
          ? null
          : _filters.platformKey!.trim(),
      autoRefresh: true,
    );

    if (scrollToTop && _scrollC.hasClients) {
      _scrollC.animateTo(
        0,
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOut,
      );
    }
  }

  void _onSearchSubmitted(String _) {
    if (!mounted) return;
    final prov = context.read<OrderProvider>();
    _applyFilters(prov: prov, scrollToTop: true);
  }

  Future<DateTime?> _pickDateLocal({
    required DateTime initial,
    required DateTime firstDate,
    required DateTime lastDate,
    required String helpText,
  }) async {
    final seedBlue = _blue;
    final base = Theme.of(context);

    return showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: firstDate,
      lastDate: lastDate,
      helpText: helpText,
      builder: (ctx, child) {
        final cs =
            ColorScheme.fromSeed(
              seedColor: seedBlue,
              brightness: Brightness.light,
            ).copyWith(
              primary: seedBlue,
              onPrimary: Colors.white,
              surface: Colors.white,
              onSurface: const Color(0xFF111827),
            );

        return Theme(
          data: base.copyWith(
            colorScheme: cs,
            dialogBackgroundColor: Colors.white,
            datePickerTheme: DatePickerThemeData(
              backgroundColor: Colors.white,
              headerBackgroundColor: seedBlue,
              headerForegroundColor: Colors.white,
              dayForegroundColor: WidgetStateProperty.resolveWith((states) {
                if (states.contains(WidgetState.disabled)) {
                  return const Color(0xFF9CA3AF);
                }
                if (states.contains(WidgetState.selected)) {
                  return Colors.white;
                }
                return const Color(0xFF111827);
              }),
              dayBackgroundColor: WidgetStateProperty.resolveWith((states) {
                if (states.contains(WidgetState.selected)) return seedBlue;
                return Colors.transparent;
              }),
              todayForegroundColor: WidgetStateProperty.all(seedBlue),
              todayBackgroundColor: WidgetStateProperty.all(
                const Color(0x1A426FD4),
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(18),
              ),
            ),
            textButtonTheme: TextButtonThemeData(
              style: TextButton.styleFrom(
                foregroundColor: seedBlue,
                textStyle: const TextStyle(fontWeight: FontWeight.w800),
              ),
            ),
          ),
          child: child!,
        );
      },
    );
  }

  Future<void> _openAdvancedFilterSheet(OrderProvider prov) async {
    final result = await showModalBottomSheet<_OrderFilters>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => _AdvancedFilterSheet(
        initial: _filters,
        blue: _blue,
        pickDateLocal:
            ({
              required DateTime initial,
              required DateTime firstDate,
              required DateTime lastDate,
              required String helpText,
            }) => _pickDateLocal(
              initial: initial,
              firstDate: firstDate,
              lastDate: lastDate,
              helpText: helpText,
            ),
      ),
    );

    if (!mounted) return;
    if (result == null) return;

    setState(() => _filters = result);
    _applyFilters(prov: prov, scrollToTop: true);
  }

  int get _stickyToken =>
      Object.hash(_filters.rebuildToken, _searchC.text.trim().isNotEmpty);

  @override
  Widget build(BuildContext context) {
    final fTime = DateFormat('dd MMM yyyy, HH:mm', 'id_ID');
    final fMoney = NumberFormat.decimalPattern('id_ID');

    const double kStickyTopPadding = 10;
    const double kStickyControlsHeight = 48;
    const double kStickyBottomPadding = 10;
    const double kStickyDividerHeight = 1;
    final double stickyHeight =
        kStickyTopPadding +
        kStickyControlsHeight +
        kStickyBottomPadding +
        kStickyDividerHeight;

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
        scrolledUnderElevation: 0,
        elevation: 0,
        foregroundColor: const Color(0xFF1F2937),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded),
          onPressed: () => Navigator.pop(context),
        ),
        titleSpacing: 0,
        title: const _AppBarTitle(),
        actions: [
          IconButton(
            tooltip: 'Refresh',
            onPressed: () =>
                context.read<OrderProvider>().refresh(context, limit: _limit),
            icon: const Icon(Icons.refresh_rounded),
          ),
          const SizedBox(width: 6),
        ],
      ),
      body: SafeArea(
        child: Consumer<OrderProvider>(
          builder: (context, prov, _) {
            final items = prov.orders;
            final isLoading = prov.loading;
            final error = prov.error;

            void retryFirstPage() {
              prov.fetchStoreOrders(
                context,
                page: 1,
                limit: _limit,
                append: false,
              );
            }

            return RefreshIndicator(
              onRefresh: () => prov.refresh(context, limit: _limit),
              color: _blue,
              child: CustomScrollView(
                controller: _scrollC,
                physics: const AlwaysScrollableScrollPhysics(),
                slivers: [
                  SliverPersistentHeader(
                    pinned: true,
                    delegate: _StickyHeaderDelegate(
                      height: stickyHeight,
                      rebuildToken: _stickyToken,
                      builder: (context, overlaps) {
                        final isActive = _filters.hasOptionalFilters;

                        return Material(
                          color: Colors.white,
                          child: Container(
                            decoration: BoxDecoration(
                              color: Colors.white,
                              boxShadow: overlaps
                                  ? const [
                                      BoxShadow(
                                        color: Color(0x14000000),
                                        blurRadius: 14,
                                        offset: Offset(0, 6),
                                      ),
                                    ]
                                  : const [],
                            ),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Padding(
                                  padding: const EdgeInsets.fromLTRB(
                                    16,
                                    10,
                                    16,
                                    10,
                                  ),
                                  child: SizedBox(
                                    height: kStickyControlsHeight,
                                    child: Row(
                                      children: [
                                        Expanded(
                                          child: TextField(
                                            controller: _searchC,
                                            onSubmitted: _onSearchSubmitted,
                                            textInputAction:
                                                TextInputAction.search,
                                            decoration: InputDecoration(
                                              hintText: 'Search order…',
                                              isDense: true,
                                              filled: true,
                                              fillColor: const Color(
                                                0xFFF3F4F6,
                                              ),
                                              prefixIcon: const Icon(
                                                Icons.search,
                                                size: 20,
                                              ),
                                              contentPadding:
                                                  const EdgeInsets.symmetric(
                                                    horizontal: 14,
                                                    vertical: 12,
                                                  ),
                                              enabledBorder: OutlineInputBorder(
                                                borderSide: const BorderSide(
                                                  color: Color(0xFFE5E7EB),
                                                ),
                                                borderRadius:
                                                    BorderRadius.circular(10),
                                              ),
                                              focusedBorder: OutlineInputBorder(
                                                borderSide: const BorderSide(
                                                  color: Color(0xFFCBD5E1),
                                                ),
                                                borderRadius:
                                                    BorderRadius.circular(10),
                                              ),
                                            ),
                                          ),
                                        ),
                                        const SizedBox(width: 10),
                                        SizedBox(
                                          height: 42,
                                          width: 42,
                                          child: _AdvancedFilterIconButton(
                                            isActive: isActive,
                                            onPressed: () =>
                                                _openAdvancedFilterSheet(prov),
                                            blue: _blue,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                                const Divider(
                                  height: 1,
                                  thickness: 1,
                                  color: Color(0xFFF3F4F6),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  ),

                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                      child: Row(
                        children: [
                          _InfoPill(
                            icon: Icons.list_alt_rounded,
                            text: isLoading && items.isEmpty
                                ? 'Loading…'
                                : '${items.length} order',
                          ),
                          const SizedBox(width: 10),
                          if (_filters.hasOptionalFilters)
                            _InfoPill(
                              icon: Icons.tune_rounded,
                              text: 'Filtered',
                            ),
                        ],
                      ),
                    ),
                  ),

                  if (isLoading && items.isEmpty)
                    const SliverToBoxAdapter(
                      child: Padding(
                        padding: EdgeInsets.fromLTRB(16, 28, 16, 24),
                        child: Center(child: CircularProgressIndicator()),
                      ),
                    )
                  else if (error != null && items.isEmpty)
                    SliverPadding(
                      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
                      sliver: SliverToBoxAdapter(
                        child: _ErrorBox(
                          detail: error,
                          onRetry: retryFirstPage,
                        ),
                      ),
                    )
                  else if (items.isEmpty)
                    const SliverPadding(
                      padding: EdgeInsets.fromLTRB(16, 12, 16, 24),
                      sliver: SliverToBoxAdapter(child: _EmptyBox()),
                    )
                  else ...[
                    SliverPadding(
                      padding: const EdgeInsets.fromLTRB(16, 6, 16, 18),
                      sliver: SliverList.separated(
                        itemCount: items.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 12),
                        itemBuilder: (context, index) {
                          final StoreOrder it = items[index];

                          final title = it.externalId.trim().isNotEmpty
                              ? it.externalId.trim()
                              : it.idStoreOrder;

                          final dt = _resolveCreatedAt(it);

                          return _OrderCard(
                            title: title,
                            timeText: fTime.format(dt),
                            status: it.status,
                            totalText: 'Rp ${fMoney.format(it.totalAmount)}',
                            itemsCount: it.items.length,
                            platformName: it.platformName.trim(),
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => OrderDetailScreen(
                                    idStoreOrder: it.idStoreOrder,
                                    externalId: it.externalId.trim().isEmpty
                                        ? null
                                        : it.externalId.trim(),
                                    platformName: it.platformName.trim().isEmpty
                                        ? null
                                        : it.platformName.trim(),
                                  ),
                                ),
                              );
                            },
                          );
                        },
                      ),
                    ),
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(16, 0, 16, 28),
                        child: Center(
                          child: prov.loadingMore
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
      ),
    );
  }
}

// =====================
// Sticky header delegate
// =====================
class _StickyHeaderDelegate extends SliverPersistentHeaderDelegate {
  final double height;
  final int rebuildToken;
  final Widget Function(BuildContext context, bool overlapsContent) builder;

  const _StickyHeaderDelegate({
    required this.height,
    required this.rebuildToken,
    required this.builder,
  });

  @override
  double get minExtent => height;

  @override
  double get maxExtent => height;

  @override
  Widget build(
    BuildContext context,
    double shrinkOffset,
    bool overlapsContent,
  ) {
    return builder(context, overlapsContent);
  }

  @override
  bool shouldRebuild(covariant _StickyHeaderDelegate oldDelegate) {
    return oldDelegate.height != height ||
        oldDelegate.rebuildToken != rebuildToken ||
        oldDelegate.builder != builder;
  }
}

/// Advanced Filter button
class _AdvancedFilterIconButton extends StatelessWidget {
  const _AdvancedFilterIconButton({
    required this.isActive,
    required this.onPressed,
    required this.blue,
  });

  final bool isActive;
  final VoidCallback onPressed;
  final Color blue;

  @override
  Widget build(BuildContext context) {
    const Color bg = Color(0xFFF3F4F6);
    const Color bd = Color(0xFFE5E7EB);
    const Color iconColor = Color(0xFF111827);

    final Color activeBorder = blue.withOpacity(0.35);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(10),
        child: Ink(
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: isActive ? activeBorder : bd),
            boxShadow: isActive
                ? const [
                    BoxShadow(
                      color: Color(0x14426FD4),
                      blurRadius: 12,
                      offset: Offset(0, 6),
                    ),
                  ]
                : const [],
          ),
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              const Center(
                child: Icon(Icons.tune_rounded, size: 20, color: iconColor),
              ),
              if (isActive)
                Positioned(
                  right: 9,
                  top: 9,
                  child: Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: blue,
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 1.5),
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

// =====================
// Filter model
// =====================
@immutable
class _OrderFilters {
  final String? status;
  final DateTime? startDate;
  final DateTime? endDate;

  /// ✅ Selectbox platform: null = all, 'tiktok', 'shopee'
  final String? platformKey;

  const _OrderFilters({
    this.status,
    this.startDate,
    this.endDate,
    this.platformKey,
  });

  bool get hasOptionalFilters {
    final s = (status ?? '').trim();
    final hasStatus = s.isNotEmpty;
    final hasDate = startDate != null || endDate != null;
    final hasPlatform = (platformKey ?? '').trim().isNotEmpty;
    return hasStatus || hasDate || hasPlatform;
  }

  int get rebuildToken => Object.hash(
    (status ?? '').trim(),
    startDate?.millisecondsSinceEpoch,
    endDate?.millisecondsSinceEpoch,
    (platformKey ?? '').trim(),
  );
}

// =====================
// Advanced Filter Sheet
// =====================
class _AdvancedFilterSheet extends StatefulWidget {
  const _AdvancedFilterSheet({
    required this.initial,
    required this.blue,
    required this.pickDateLocal,
  });

  final _OrderFilters initial;
  final Color blue;

  final Future<DateTime?> Function({
    required DateTime initial,
    required DateTime firstDate,
    required DateTime lastDate,
    required String helpText,
  })
  pickDateLocal;

  @override
  State<_AdvancedFilterSheet> createState() => _AdvancedFilterSheetState();
}

class _AdvancedFilterSheetState extends State<_AdvancedFilterSheet> {
  String? _status;
  DateTime? _start;
  DateTime? _end;

  /// platform dropdown value: null/all, 'tiktok', 'shopee'
  String? _platformKey;

  @override
  void initState() {
    super.initState();
    _status = widget.initial.status;
    _start = widget.initial.startDate;
    _end = widget.initial.endDate;
    _platformKey = widget.initial.platformKey;
  }

  bool get _hasAnyOptional =>
      (_status ?? '').trim().isNotEmpty ||
      _start != null ||
      _end != null ||
      (_platformKey ?? '').trim().isNotEmpty;

  String _statusLabel(String token) {
    switch (token) {
      case 'ON_HOLD':
        return 'On hold';
      case 'AWAITING_COLLECTION':
        return 'Awaiting Collection';
      case 'COMPLETED':
        return 'Completed';
      case 'CANCELLED':
        return 'Cancelled';
      case 'FAILED':
        return 'Failed';
      default:
        return token;
    }
  }

  String _platformLabel(String? key) {
    switch ((key ?? '').trim().toLowerCase()) {
      case 'tiktok':
        return 'TikTok';
      case 'shopee':
        return 'Shopee';
      default:
        return 'All platform';
    }
  }

  Future<void> _pickStart() async {
    final now = DateTime.now();
    final init = _start ?? now;
    final picked = await widget.pickDateLocal(
      initial: init,
      firstDate: DateTime(2000, 1, 1),
      lastDate: DateTime(2100, 12, 31),
      helpText: 'Select start date',
    );
    if (picked == null) return;
    setState(() {
      _start = DateTime(picked.year, picked.month, picked.day);
      if (_end != null && _end!.isBefore(_start!)) _end = _start;
    });
  }

  Future<void> _pickEnd() async {
    final now = DateTime.now();
    final init = _end ?? _start ?? now;
    final picked = await widget.pickDateLocal(
      initial: init,
      firstDate: DateTime(2000, 1, 1),
      lastDate: DateTime(2100, 12, 31),
      helpText: 'Select end date',
    );
    if (picked == null) return;
    setState(() => _end = DateTime(picked.year, picked.month, picked.day));
  }

  void _resetOptionalFilters() {
    setState(() {
      _status = null;
      _start = null;
      _end = null;
      _platformKey = null;
    });
  }

  void _apply() {
    final s = (_status ?? '').trim();
    final sanitizedStatus = s.isEmpty ? null : s;

    final p = (_platformKey ?? '').trim().toLowerCase();
    final sanitizedPlatform = (p == 'tiktok' || p == 'shopee') ? p : null;

    final next = _OrderFilters(
      status: sanitizedStatus,
      startDate: _start,
      endDate: _end,
      platformKey: sanitizedPlatform,
    );

    Navigator.pop(context, next);
  }

  @override
  Widget build(BuildContext context) {
    final f = DateFormat('dd MMM yyyy', 'id_ID');

    final chips = <Widget>[];
    if (_start != null || _end != null) {
      final a = _start == null ? 'Any' : f.format(_start!);
      final b = _end == null ? 'Any' : f.format(_end!);
      chips.add(
        _MiniChip(
          label: 'Date: $a → $b',
          onClear: () => setState(() {
            _start = null;
            _end = null;
          }),
        ),
      );
    }
    if ((_platformKey ?? '').trim().isNotEmpty) {
      chips.add(
        _MiniChip(
          label: 'Platform: ${_platformLabel(_platformKey)}',
          onClear: () => setState(() => _platformKey = null),
        ),
      );
    }
    if ((_status ?? '').trim().isNotEmpty) {
      chips.add(
        _MiniChip(
          label: 'Status: ${_statusLabel(_status!)}',
          onClear: () => setState(() => _status = null),
        ),
      );
    }

    return DraggableScrollableSheet(
      initialChildSize: 0.90,
      minChildSize: 0.55,
      maxChildSize: 0.95,
      expand: false,
      builder: (context, controller) {
        return SafeArea(
          top: false,
          child: Column(
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
                padding: const EdgeInsets.symmetric(horizontal: 18),
                child: Row(
                  children: [
                    const Expanded(
                      child: Text(
                        'Filter',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w900,
                          color: Color(0xFF111827),
                        ),
                      ),
                    ),
                    if (_hasAnyOptional)
                      TextButton.icon(
                        onPressed: _resetOptionalFilters,
                        icon: const Icon(Icons.restart_alt_rounded, size: 18),
                        label: const Text('Reset'),
                        style: TextButton.styleFrom(
                          foregroundColor: const Color(0xFF111827),
                        ),
                      ),
                  ],
                ),
              ),

              if (chips.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.fromLTRB(18, 2, 18, 10),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Wrap(spacing: 8, runSpacing: 8, children: chips),
                  ),
                )
              else
                const SizedBox(height: 6),

              Expanded(
                child: ListView(
                  controller: controller,
                  padding: const EdgeInsets.fromLTRB(18, 8, 18, 100),
                  children: [
                    const _SectionLabel('Optional'),
                    const SizedBox(height: 10),

                    // Platform dropdown (selectbox)
                    _FilterTile(
                      icon: Icons.public_rounded,
                      title: 'Platform',
                      value: _platformLabel(_platformKey),
                      isPlaceholder: (_platformKey ?? '').trim().isEmpty,
                      onTap: () async {
                        final picked = await _showPlatformPicker(
                          context: context,
                          selectedKey: _platformKey,
                        );
                        if (!mounted) return;
                        setState(() => _platformKey = picked);
                      },
                      onClear: (_platformKey ?? '').trim().isEmpty
                          ? null
                          : () => setState(() => _platformKey = null),
                    ),

                    const SizedBox(height: 12),

                    // Date range
                    Row(
                      children: [
                        Expanded(
                          child: _FilterTile(
                            icon: Icons.calendar_month_rounded,
                            title: 'Start date',
                            value: _start == null ? 'Any' : f.format(_start!),
                            isPlaceholder: _start == null,
                            onTap: _pickStart,
                            onClear: _start == null
                                ? null
                                : () => setState(() => _start = null),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: _FilterTile(
                            icon: Icons.event_rounded,
                            title: 'End date',
                            value: _end == null ? 'Any' : f.format(_end!),
                            isPlaceholder: _end == null,
                            onTap: _pickEnd,
                            onClear: _end == null
                                ? null
                                : () => setState(() => _end = null),
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 12),

                    // Status chips
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 12,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF9FAFB),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: const Color(0xFFE5E7EB)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Container(
                                width: 34,
                                height: 34,
                                decoration: BoxDecoration(
                                  color: const Color(0xFFF3F4F6),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                    color: const Color(0xFFE5E7EB),
                                  ),
                                ),
                                child: const Icon(
                                  Icons.fact_check_rounded,
                                  size: 18,
                                  color: Color(0xFF6B7280),
                                ),
                              ),
                              const SizedBox(width: 12),
                              const Expanded(
                                child: Text(
                                  'Order Status',
                                  style: TextStyle(
                                    fontWeight: FontWeight.w900,
                                    color: Color(0xFF111827),
                                    fontSize: 13,
                                  ),
                                ),
                              ),
                              if ((_status ?? '').isNotEmpty)
                                IconButton(
                                  tooltip: 'Clear',
                                  onPressed: () =>
                                      setState(() => _status = null),
                                  icon: const Icon(
                                    Icons.close_rounded,
                                    size: 18,
                                  ),
                                  color: const Color(0xFF6B7280),
                                ),
                            ],
                          ),
                          const SizedBox(height: 10),
                          Wrap(
                            spacing: 10,
                            runSpacing: 10,
                            children: [
                              _FilterStatusChip(
                                label: 'All',
                                selected: (_status ?? '').isEmpty,
                                selectedColor: const Color(0xFF111827),
                                onTap: () => setState(() => _status = null),
                              ),
                              _FilterStatusChip(
                                label: 'On hold',
                                selected: _status == 'ON_HOLD',
                                selectedColor: widget.blue,
                                onTap: () => setState(() {
                                  _status = (_status == 'ON_HOLD')
                                      ? null
                                      : 'ON_HOLD';
                                }),
                              ),
                              _FilterStatusChip(
                                label: 'Awaiting Collection',
                                selected: _status == 'AWAITING_COLLECTION',
                                selectedColor: widget.blue,
                                onTap: () => setState(() {
                                  _status = (_status == 'AWAITING_COLLECTION')
                                      ? null
                                      : 'AWAITING_COLLECTION';
                                }),
                              ),
                              _FilterStatusChip(
                                label: 'Completed',
                                selected: _status == 'COMPLETED',
                                selectedColor: widget.blue,
                                onTap: () => setState(() {
                                  _status = (_status == 'COMPLETED')
                                      ? null
                                      : 'COMPLETED';
                                }),
                              ),
                              _FilterStatusChip(
                                label: 'Cancelled',
                                selected: _status == 'CANCELLED',
                                selectedColor: widget.blue,
                                onTap: () => setState(() {
                                  _status = (_status == 'CANCELLED')
                                      ? null
                                      : 'CANCELED';
                                }),
                              ),
                              _FilterStatusChip(
                                label: 'Failed',
                                selected: _status == 'FAILED',
                                selectedColor: widget.blue,
                                onTap: () => setState(() {
                                  _status = (_status == 'FAILED')
                                      ? null
                                      : 'FAILED';
                                }),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              Container(
                padding: const EdgeInsets.fromLTRB(16, 10, 16, 16),
                decoration: const BoxDecoration(
                  color: Colors.white,
                  border: Border(top: BorderSide(color: Color(0xFFE5E7EB))),
                ),
                child: SizedBox(
                  height: 50,
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _apply,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: widget.blue,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    child: const Text(
                      'Apply Filter',
                      style: TextStyle(fontWeight: FontWeight.w900),
                    ),
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

Future<String?> _showPlatformPicker({
  required BuildContext context,
  String? selectedKey,
}) async {
  String label(String? k) {
    switch ((k ?? '').trim().toLowerCase()) {
      case 'tiktok':
        return 'TikTok';
      case 'shopee':
        return 'Shopee';
      default:
        return 'All platform';
    }
  }

  final options = const <String?>[null, 'tiktok', 'shopee'];

  return showModalBottomSheet<String?>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.white,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (ctx) {
      return SafeArea(
        top: false,
        child: DraggableScrollableSheet(
          expand: false,
          initialChildSize: 0.55,
          minChildSize: 0.35,
          maxChildSize: 0.75,
          builder: (_, ctrl) {
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
                          'Select Platform',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w900,
                            color: Color(0xFF111827),
                          ),
                        ),
                      ),
                      TextButton(
                        onPressed: () => Navigator.pop(ctx),
                        child: const Text('Close'),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
                const Divider(height: 1, color: Color(0xFFE5E7EB)),
                Expanded(
                  child: ListView.separated(
                    controller: ctrl,
                    padding: const EdgeInsets.fromLTRB(8, 8, 8, 16),
                    itemCount: options.length,
                    separatorBuilder: (_, __) =>
                        const Divider(height: 1, color: Color(0xFFF3F4F6)),
                    itemBuilder: (_, i) {
                      final v = options[i];
                      final isSel = v == selectedKey;
                      return ListTile(
                        onTap: () => Navigator.pop(ctx, v),
                        leading: Radio<String?>(
                          value: v,
                          groupValue: selectedKey,
                          onChanged: (_) => Navigator.pop(ctx, v),
                        ),
                        title: Text(
                          label(v),
                          style: const TextStyle(
                            fontWeight: FontWeight.w800,
                            color: Color(0xFF111827),
                          ),
                        ),
                        trailing: isSel
                            ? const Icon(
                                Icons.check_circle,
                                color: Color(0xFF426FD4),
                              )
                            : null,
                      );
                    },
                  ),
                ),
              ],
            );
          },
        ),
      );
    },
  );
}

class _FilterStatusChip extends StatelessWidget {
  const _FilterStatusChip({
    required this.label,
    required this.selected,
    required this.selectedColor,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final Color selectedColor;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final bg = selected ? selectedColor : const Color(0xFFF3F4F6);
    final bd = selected ? selectedColor : const Color(0xFFE5E7EB);
    final fg = selected ? Colors.white : const Color(0xFF111827);

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(999),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: bd),
          boxShadow: selected
              ? const [
                  BoxShadow(
                    color: Color(0x1A426FD4),
                    blurRadius: 12,
                    offset: Offset(0, 6),
                  ),
                ]
              : const [],
        ),
        child: Text(
          label,
          style: TextStyle(
            color: fg,
            fontWeight: FontWeight.w900,
            fontSize: 12,
          ),
        ),
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  final String text;
  const _SectionLabel(this.text);

  @override
  Widget build(BuildContext context) {
    return Text(
      text.toUpperCase(),
      style: const TextStyle(
        fontSize: 12,
        letterSpacing: 1.1,
        fontWeight: FontWeight.w900,
        color: Color(0xFF6B7280),
      ),
    );
  }
}

class _MiniChip extends StatelessWidget {
  const _MiniChip({required this.label, required this.onClear});
  final String label;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: const Color(0xFFF3F4F6),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontWeight: FontWeight.w800,
              color: Color(0xFF111827),
              fontSize: 12,
            ),
          ),
          const SizedBox(width: 6),
          InkWell(
            onTap: onClear,
            borderRadius: BorderRadius.circular(999),
            child: const Icon(
              Icons.close_rounded,
              size: 16,
              color: Color(0xFF6B7280),
            ),
          ),
        ],
      ),
    );
  }
}

class _FilterTile extends StatelessWidget {
  const _FilterTile({
    required this.icon,
    required this.title,
    required this.value,
    required this.isPlaceholder,
    required this.onTap,
    required this.onClear,
  });

  final IconData icon;
  final String title;
  final String value;
  final bool isPlaceholder;
  final VoidCallback onTap;
  final VoidCallback? onClear;

  @override
  Widget build(BuildContext context) {
    final valueColor = isPlaceholder
        ? const Color(0xFF9CA3AF)
        : const Color(0xFF111827);

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: const Color(0xFFF9FAFB),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: const Color(0xFFE5E7EB)),
        ),
        child: Row(
          children: [
            Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(
                color: const Color(0xFFF3F4F6),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFE5E7EB)),
              ),
              child: Icon(icon, size: 18, color: const Color(0xFF6B7280)),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontWeight: FontWeight.w900,
                      color: Color(0xFF111827),
                      fontSize: 13,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    value,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: valueColor,
                      fontWeight: isPlaceholder
                          ? FontWeight.w600
                          : FontWeight.w900,
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            ),
            if (onClear != null)
              IconButton(
                tooltip: 'Clear',
                onPressed: onClear,
                icon: const Icon(Icons.close_rounded, size: 18),
                color: const Color(0xFF6B7280),
              )
            else
              const Icon(Icons.chevron_right_rounded, color: Color(0xFF6B7280)),
          ],
        ),
      ),
    );
  }
}

// =====================
// Existing UI bits (kept)
// =====================
class _AppBarTitle extends StatelessWidget {
  const _AppBarTitle();

  @override
  Widget build(BuildContext context) {
    return const Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Orders',
          style: TextStyle(
            fontWeight: FontWeight.w900,
            color: Color(0xFF111827),
          ),
        ),
        SizedBox(height: 2),
        Text(
          'History',
          style: TextStyle(
            fontSize: 12,
            color: Color(0xFF6B7280),
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }
}

class _InfoPill extends StatelessWidget {
  final IconData icon;
  final String text;

  const _InfoPill({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
      decoration: BoxDecoration(
        color: const Color(0xFFEFF6FF),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: const Color(0xFF2F5FD0)),
          const SizedBox(width: 8),
          Text(
            text,
            style: const TextStyle(
              fontSize: 12,
              color: Color(0xFF1F3D99),
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }
}

class _OrderCard extends StatelessWidget {
  static const Color _border = Color(0xFFE5E7EB);

  static const Color _textMain = Color(0xFF111827);
  static const Color _textSub = Color(0xFF6B7280);
  static const Color _textMuted = Color(0xFF9CA3AF);

  static const Color _blueDark = Color(0xFF2F5FD0);
  static const Color _blueSoft = Color(0xFFEFF6FF);

  final String title;
  final String timeText;
  final String status;

  final String totalText;
  final int itemsCount;

  final String platformName;

  final VoidCallback? onTap;

  const _OrderCard({
    required this.title,
    required this.timeText,
    required this.status,
    required this.totalText,
    required this.itemsCount,
    required this.platformName,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onTap,
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: _border),
          ),
          padding: const EdgeInsets.fromLTRB(14, 14, 14, 12),
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
                      color: _blueSoft,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: _border),
                    ),
                    child: const Icon(
                      Icons.shopping_bag_rounded,
                      size: 20,
                      color: _blueDark,
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
                            fontSize: 16,
                            fontWeight: FontWeight.w900,
                            color: _textMain,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          timeText,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 12,
                            color: _textMuted,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 10),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      _StatusChip(status: status),
                      const SizedBox(height: 8),
                      const Icon(
                        Icons.chevron_right_rounded,
                        color: _textMuted,
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Container(height: 1, color: _border),
              const SizedBox(height: 12),
              Row(
                children: [
                  _PlatformPill(platformName: platformName),
                  const Spacer(),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      const Text(
                        'Total',
                        style: TextStyle(
                          fontSize: 12,
                          color: _textSub,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        totalText,
                        textAlign: TextAlign.right,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w900,
                          color: _textMain,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PlatformPill extends StatelessWidget {
  final String platformName;
  const _PlatformPill({required this.platformName});

  bool get _isTiktok {
    final k = platformName.trim().toLowerCase();
    return k.contains('tiktok');
  }

  @override
  Widget build(BuildContext context) {
    final name = platformName.trim().isEmpty ? '-' : platformName.trim();
    final bg = _isTiktok ? const Color(0xFF111827) : const Color(0xFFEFF6FF);
    final fg = _isTiktok ? Colors.white : const Color(0xFF2F5FD0);
    final bd = _isTiktok ? const Color(0xFF111827) : const Color(0xFFE5E7EB);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: bd),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.public_rounded, size: 16, color: fg),
          const SizedBox(width: 8),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 220),
            child: Text(
              name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 12,
                color: fg,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  final String status;
  const _StatusChip({required this.status});

  String _pretty(String s) {
    final cleaned = s.trim().replaceAll(RegExp(r'[_\\-]+'), ' ');
    if (cleaned.isEmpty) return cleaned;

    return cleaned
        .split(RegExp(r'\\s+'))
        .where((w) => w.isNotEmpty)
        .map((w) => w[0].toUpperCase() + w.substring(1).toLowerCase())
        .join(' ');
  }

  @override
  Widget build(BuildContext context) {
    final raw = status.trim();
    if (raw.isEmpty) return const SizedBox.shrink();

    final key = raw.toLowerCase();

    Color bg;
    Color fg;
    Color border;

    switch (key) {
      case 'completed':
      case 'paid':
      case 'success':
        bg = const Color(0xFFE6F4EA);
        fg = const Color(0xFF166534);
        border = const Color(0xFFBBF7D0);
        break;
      case 'canceled':
      case 'cancelled':
      case 'void':
      case 'failed':
        bg = const Color(0xFFFEE2E2);
        fg = const Color(0xFF991B1B);
        border = const Color(0xFFFECACA);
        break;
      default:
        bg = const Color(0xFFFEF3C7);
        fg = const Color(0xFF92400E);
        border = const Color(0xFFFDE68A);
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: border),
      ),
      child: Text(
        _pretty(raw),
        style: TextStyle(fontSize: 12, fontWeight: FontWeight.w900, color: fg),
      ),
    );
  }
}

class _ErrorBox extends StatelessWidget {
  final String? detail;
  final VoidCallback onRetry;
  const _ErrorBox({required this.detail, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFFEE2E2),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFFCA5A5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Gagal memuat data',
            style: TextStyle(
              fontWeight: FontWeight.w900,
              color: Color(0xFF991B1B),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            detail ?? '-',
            style: const TextStyle(
              color: Color(0xFF7F1D1D),
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 10),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Coba lagi'),
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
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE5E7EB)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0A111827),
            blurRadius: 10,
            offset: Offset(0, 6),
          ),
        ],
      ),
      child: const Column(
        children: [
          Icon(Icons.receipt_long_rounded, size: 34, color: Color(0xFF9CA3AF)),
          SizedBox(height: 10),
          Text(
            'Belum ada order',
            style: TextStyle(
              fontWeight: FontWeight.w900,
              color: Color(0xFF111827),
            ),
          ),
          SizedBox(height: 6),
          Text(
            'Store order akan muncul di sini setelah ada transaksi.',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Color(0xFF6B7280),
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}
