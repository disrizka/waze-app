import 'dart:async';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../providers/store_provider.dart';
import '../../providers/stock_provider.dart';
import '../../widgets/reusable_pickers.dart';

class StockScreen extends StatefulWidget {
  const StockScreen({super.key});

  @override
  State<StockScreen> createState() => _StockScreenState();
}

class _StockScreenState extends State<StockScreen> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded),
          onPressed: () => Navigator.of(
            context,
          ).popUntil((route) => route.settings.name == '/stock'),
        ),
        title: Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.baseline,
          textBaseline: TextBaseline.alphabetic,
          children: const [
            Text('Stock', style: TextStyle(fontWeight: FontWeight.w800)),
            SizedBox(width: 8),
            Text(
              '/initial',
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
        scrolledUnderElevation: 0,
      ),
      body: const _StockList(),
      bottomNavigationBar: SafeArea(
        minimum: const EdgeInsets.fromLTRB(16, 8, 16, 20),
        child: SizedBox(
          height: 50,
          child: FilledButton.icon(
            icon: const Icon(Icons.add_rounded),
            label: const Text(
              'Add Initial Stock',
              style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
            ),
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFF426FD4),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
              minimumSize: const Size.fromHeight(50),
            ),
            onPressed: () {
              Navigator.pushNamed(context, '/stock/initial-stock/add');
            },
          ),
        ),
      ),
    );
  }
}

class _StockList extends StatefulWidget {
  const _StockList();

  @override
  State<_StockList> createState() => _StockListState();
}

@immutable
class _InitialStockFilters {
  final String? storeLocationId;
  final DateTime? dateFrom;
  final DateTime? dateTo;

  const _InitialStockFilters({
    this.storeLocationId,
    this.dateFrom,
    this.dateTo,
  });

  bool get hasOptionalFilters =>
      (storeLocationId ?? '').trim().isNotEmpty ||
      dateFrom != null ||
      dateTo != null;

  int get rebuildToken => Object.hash(
    (storeLocationId ?? '').trim(),
    dateFrom?.millisecondsSinceEpoch,
    dateTo?.millisecondsSinceEpoch,
  );
}

class _StockListState extends State<_StockList> {
  static const int _pageSize = 50;

  final TextEditingController _searchC = TextEditingController();
  final ScrollController _scrollC = ScrollController();
  Timer? _searchDebounce;
  _InitialStockFilters _filters = const _InitialStockFilters();
  int _page = 1;
  bool _hasMore = true;
  bool _booted = false;

  @override
  void initState() {
    super.initState();
    _scrollC.addListener(_onScroll);

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      await _ensureStoreOptionsLoaded();
      await _reloadFirstPage();
      if (!mounted) return;
      setState(() => _booted = true);
    });
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
    _scrollC.removeListener(_onScroll);
    _scrollC.dispose();
    _searchC.dispose();
    super.dispose();
  }

  Future<void> _ensureStoreOptionsLoaded() async {
    final sp = context.read<StoreProvider>();
    if (sp.stores.isEmpty && !sp.loadingList) {
      await sp.fetchStoreLocations(context);
    }
  }

  String _fmtDate(DateTime? dt) {
    if (dt == null) return 'Any date';
    return DateFormat('dd MMM yyyy', 'id_ID').format(dt.toLocal());
  }

  String _fmtCardDate(DateTime? dt) {
    if (dt == null) return '-';
    return DateFormat('dd MMM yyyy • HH:mm', 'id_ID').format(dt.toLocal());
  }

  List<_InitialStockMonthYearGroup> _buildGroups(List<InitialStockRow> rows) {
    final sorted = [...rows]
      ..sort((a, b) {
        final ad = a.createdAt?.toLocal();
        final bd = b.createdAt?.toLocal();
        if (ad == null && bd == null) return 0;
        if (ad == null) return 1;
        if (bd == null) return -1;
        return bd.compareTo(ad);
      });

    final grouped = <String, List<InitialStockRow>>{};
    for (final row in sorted) {
      final dt = row.createdAt?.toLocal();
      final y = dt?.year ?? 0;
      final m = dt?.month ?? 0;
      final key = '$y-$m';
      grouped.putIfAbsent(key, () => <InitialStockRow>[]);
      grouped[key]!.add(row);
    }

    final keys = grouped.keys.toList()
      ..sort((a, b) {
        final ap = a.split('-');
        final bp = b.split('-');
        final ay = int.tryParse(ap.first) ?? 0;
        final am = int.tryParse(ap.last) ?? 0;
        final by = int.tryParse(bp.first) ?? 0;
        final bm = int.tryParse(bp.last) ?? 0;
        if (ay != by) return by.compareTo(ay);
        return bm.compareTo(am);
      });

    return keys.map((key) {
      final p = key.split('-');
      return _InitialStockMonthYearGroup(
        year: int.tryParse(p.first) ?? 0,
        month: int.tryParse(p.last) ?? 0,
        rows: grouped[key]!,
      );
    }).toList();
  }

  String _monthYearLabel(int month, int year) {
    if (month == 0 || year == 0) return 'Tanpa tanggal';
    return DateFormat('MMMM yyyy', 'id_ID').format(DateTime(year, month));
  }

  String? _apiDate(DateTime? dt) {
    if (dt == null) return null;
    return DateFormat('yyyy-MM-dd').format(dt.toLocal());
  }

  String? _selectedStoreName(StoreProvider sp) {
    final id = (_filters.storeLocationId ?? '').trim();
    if (id.isEmpty) return null;
    for (final s in sp.stores) {
      if (s.idStoreLocation.trim() == id) {
        final name = s.name.trim();
        return name.isEmpty ? null : name;
      }
    }
    return null;
  }

  Future<int> _fetchPage({required int page, required bool append}) async {
    final q = _searchC.text.trim();
    final fromApi = _apiDate(_filters.dateFrom);
    final toApi = _apiDate(_filters.dateTo);

    return context.read<StockProvider>().fetchInitialStocks(
      context,
      page: page,
      rowPerPage: _pageSize,
      append: append,
      search: q.isEmpty ? null : q,
      storeLocationId: (_filters.storeLocationId ?? '').trim().isEmpty
          ? null
          : _filters.storeLocationId!.trim(),
      dateFrom: fromApi,
      dateTo: toApi,
    );
  }

  bool _resolveHasMore(StockProvider prov, {required int fetchedCount}) {
    final meta = prov.pageInitialStocks;
    if (meta != null && meta.totalPages > 0) {
      return meta.currentPage < meta.totalPages;
    }
    return fetchedCount >= _pageSize;
  }

  Future<void> _reloadFirstPage() async {
    setState(() {
      _page = 1;
      _hasMore = true;
    });

    final fetched = await _fetchPage(page: 1, append: false);
    if (!mounted) return;
    final prov = context.read<StockProvider>();

    setState(() {
      _page = 1;
      _hasMore = _resolveHasMore(prov, fetchedCount: fetched);
    });
  }

  Future<void> _loadMore() async {
    final prov = context.read<StockProvider>();
    if (!_hasMore || prov.loadingInitialStocks) return;

    final next = _page + 1;
    final fetched = await _fetchPage(page: next, append: true);
    if (!mounted) return;
    final latestProv = context.read<StockProvider>();

    setState(() {
      _page = next;
      _hasMore = _resolveHasMore(latestProv, fetchedCount: fetched);
    });
  }

  void _onScroll() {
    if (!_booted || !_scrollC.hasClients) return;
    final max = _scrollC.position.maxScrollExtent;
    final pos = _scrollC.position.pixels;
    if (max <= 0) return;
    if (pos >= max * 0.72) {
      _loadMore();
    }
  }

  void _onSearchChanged(String _) {
    _searchDebounce?.cancel();
    _searchDebounce = Timer(const Duration(milliseconds: 420), () {
      if (!mounted) return;
      _reloadFirstPage();
    });
  }

  Future<void> _onSearchSubmitted(String _) async {
    _searchDebounce?.cancel();
    await _reloadFirstPage();
  }

  Future<void> _openAdvancedFilter() async {
    final result = await showModalBottomSheet<_InitialStockFilters>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => _InitialStockAdvancedFilterSheet(
        initial: _filters,
        formatDate: _fmtDate,
      ),
    );

    if (!mounted || result == null) return;
    setState(() => _filters = result);
    await _reloadFirstPage();
  }

  int get _stickyToken =>
      Object.hash(_filters.rebuildToken, _searchC.text.trim().isNotEmpty);

  @override
  Widget build(BuildContext context) {
    return Consumer2<StockProvider, StoreProvider>(
      builder: (context, prov, storeProv, _) {
        final items = prov.initialStocks;
        final isLoading = prov.loadingInitialStocks;
        final error = prov.initialStocksError;
        final selectedStoreName = _selectedStoreName(storeProv);
        final hasTopInfo =
            (selectedStoreName ?? '').trim().isNotEmpty ||
            _filters.dateFrom != null ||
            _filters.dateTo != null;
        final groups = _buildGroups(items);

        return RefreshIndicator(
          onRefresh: _reloadFirstPage,
          color: const Color(0xFF426FD4),
          child: CustomScrollView(
            controller: _scrollC,
            physics: const AlwaysScrollableScrollPhysics(),
            slivers: [
              SliverPersistentHeader(
                pinned: true,
                delegate: _StickyHeaderDelegate(
                  height: 79,
                  rebuildToken: _stickyToken,
                  builder: (context, overlaps) {
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
                          children: [
                            Padding(
                              padding: const EdgeInsets.fromLTRB(
                                16,
                                10,
                                16,
                                10,
                              ),
                              child: SizedBox(
                                height: 48,
                                child: Row(
                                  children: [
                                    Expanded(
                                      child: TextField(
                                        controller: _searchC,
                                        onChanged: _onSearchChanged,
                                        onSubmitted: _onSearchSubmitted,
                                        textInputAction: TextInputAction.search,
                                        decoration: InputDecoration(
                                          hintText: 'Search',
                                          isDense: true,
                                          filled: true,
                                          fillColor: const Color(0xFFF3F4F6),
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
                                            borderRadius: BorderRadius.circular(
                                              10,
                                            ),
                                          ),
                                          focusedBorder: OutlineInputBorder(
                                            borderSide: const BorderSide(
                                              color: Color(0xFFCBD5E1),
                                            ),
                                            borderRadius: BorderRadius.circular(
                                              10,
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 10),
                                    SizedBox(
                                      width: 42,
                                      height: 42,
                                      child: _AdvancedFilterIconButton(
                                        isActive: _filters.hasOptionalFilters,
                                        onPressed: _openAdvancedFilter,
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
              if (hasTopInfo)
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                    child: Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        if ((selectedStoreName ?? '').trim().isNotEmpty)
                          _TopPill(
                            icon: Icons.storefront_rounded,
                            text: selectedStoreName!,
                          ),
                        if (_filters.dateFrom != null)
                          _TopPill(
                            icon: Icons.event_rounded,
                            text: 'From: ${_fmtDate(_filters.dateFrom)}',
                          ),
                        if (_filters.dateTo != null)
                          _TopPill(
                            icon: Icons.event_available_rounded,
                            text: 'To: ${_fmtDate(_filters.dateTo)}',
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
                    child: _StockErrorBox(
                      message: error,
                      onRetry: _reloadFirstPage,
                    ),
                  ),
                )
              else if (items.isEmpty)
                const SliverPadding(
                  padding: EdgeInsets.fromLTRB(16, 12, 16, 24),
                  sliver: SliverToBoxAdapter(child: _StockEmptyBox()),
                )
              else
                ...groups.map(
                  (group) => SliverPadding(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                    sliver: SliverList(
                      delegate: SliverChildListDelegate.fixed([
                        _MonthYearSectionHeader(
                          text: _monthYearLabel(group.month, group.year),
                        ),
                        const SizedBox(height: 8),
                        ...List<Widget>.generate(group.rows.length, (i) {
                          final row = group.rows[i];
                          return Padding(
                            padding: EdgeInsets.only(
                              bottom: i < group.rows.length - 1 ? 12 : 14,
                            ),
                            child: _InitialStockHistoryCard(
                              title: row.number.trim().isEmpty
                                  ? '-'
                                  : row.number,
                              dateText: _fmtCardDate(row.createdAt),
                              storeName: row.storeLocation.name.trim().isEmpty
                                  ? '-'
                                  : row.storeLocation.name,
                              note: row.note.trim().isEmpty ? '-' : row.note,
                              onTap: () {
                                Navigator.pushNamed(
                                  context,
                                  '/stock/initial-stock/detail',
                                  arguments: {'id': row.id},
                                );
                              },
                            ),
                          );
                        }),
                      ]),
                    ),
                  ),
                ),
              if (isLoading && items.isNotEmpty)
                const SliverToBoxAdapter(
                  child: Padding(
                    padding: EdgeInsets.only(top: 8, bottom: 14),
                    child: Center(
                      child: SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                    ),
                  ),
                )
              else
                SliverToBoxAdapter(child: SizedBox(height: _hasMore ? 10 : 4)),
              const SliverToBoxAdapter(child: SizedBox(height: 24 + 72)),
            ],
          ),
        );
      },
    );
  }
}

class _InitialStockHistoryCard extends StatelessWidget {
  final String title;
  final String dateText;
  final String storeName;
  final String note;
  final VoidCallback onTap;

  const _InitialStockHistoryCard({
    required this.title,
    required this.dateText,
    required this.storeName,
    required this.note,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(22),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFFFFFFFF), Color(0xFFF6FAFF)],
          ),
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: const Color(0xFFD8E4FB)),
          boxShadow: const [
            BoxShadow(
              color: Color(0x14213A7A),
              blurRadius: 20,
              offset: Offset(0, 10),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFFE8F0FF),
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(color: const Color(0xFFD2DFFF)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: const [
                      Icon(
                        Icons.inventory_2_rounded,
                        size: 13,
                        color: Color(0xFF3E67CC),
                      ),
                      SizedBox(width: 5),
                      Text(
                        'Initial Stock',
                        style: TextStyle(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFF3E67CC),
                        ),
                      ),
                    ],
                  ),
                ),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8FAFD),
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(color: const Color(0xFFE1E7F2)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.schedule_rounded,
                        size: 12.5,
                        color: Color(0xFF627086),
                      ),
                      const SizedBox(width: 5),
                      Text(
                        dateText,
                        style: const TextStyle(
                          fontSize: 11.3,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF627086),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 18,
                height: 1.15,
                fontWeight: FontWeight.w900,
                color: Color(0xFF0F172A),
              ),
            ),
            const SizedBox(height: 10),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              decoration: BoxDecoration(
                color: const Color(0xFFEEF4FF),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFDCE7FA)),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.storefront_rounded,
                    size: 14,
                    color: Color(0xFF4F6D9E),
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      storeName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 12.5,
                        color: Color(0xFF3D4D6A),
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Container(
              width: double.infinity,
              margin: const EdgeInsets.only(top: 7),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              decoration: BoxDecoration(
                color: const Color(0xFFF9FAFC),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFE4E7EE)),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.sticky_note_2_outlined,
                    size: 14,
                    color: Color(0xFF798293),
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      note,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 12.3,
                        color: Color(0xFF4E5869),
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Container(
              width: double.infinity,
              margin: const EdgeInsets.only(top: 10),
              padding: const EdgeInsets.symmetric(vertical: 10),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Color(0xFF4C77DE), Color(0xFF3F68CF)],
                ),
                borderRadius: BorderRadius.circular(13),
              ),
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.visibility_rounded, size: 16, color: Colors.white),
                  SizedBox(width: 8),
                  Text(
                    'View Detail Initial Stock',
                    style: TextStyle(
                      fontSize: 13.2,
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
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

class _MonthYearSectionHeader extends StatelessWidget {
  final String text;

  const _MonthYearSectionHeader({required this.text});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: const Color(0xFFF3F4F6),
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: const Color(0xFFE5E7EB)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.calendar_month_rounded,
                size: 13,
                color: Color(0xFF6B7280),
              ),
              const SizedBox(width: 6),
              Text(
                text,
                style: const TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF6B7280),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 10),
        const Expanded(
          child: Divider(thickness: 1.1, height: 1, color: Color(0xFFD1D5DB)),
        ),
      ],
    );
  }
}

class _InitialStockMonthYearGroup {
  final int year;
  final int month;
  final List<InitialStockRow> rows;

  const _InitialStockMonthYearGroup({
    required this.year,
    required this.month,
    required this.rows,
  });
}

class _TopPill extends StatelessWidget {
  final IconData icon;
  final String text;
  const _TopPill({required this.icon, required this.text});

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
          Icon(icon, size: 14, color: const Color(0xFF6B7280)),
          const SizedBox(width: 6),
          Text(
            text,
            style: const TextStyle(
              fontSize: 11.5,
              fontWeight: FontWeight.w700,
              color: Color(0xFF374151),
            ),
          ),
        ],
      ),
    );
  }
}

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

class _AdvancedFilterIconButton extends StatelessWidget {
  const _AdvancedFilterIconButton({
    required this.isActive,
    required this.onPressed,
  });

  final bool isActive;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    const Color bg = Color(0xFFF3F4F6);
    const Color bd = Color(0xFFE5E7EB);
    const Color iconColor = Color(0xFF111827);
    const Color blue = Color(0xFF426FD4);

    final Color activeBorder = blue.withValues(alpha: 0.35);

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

class _InitialStockAdvancedFilterSheet extends StatefulWidget {
  final _InitialStockFilters initial;
  final String Function(DateTime?) formatDate;

  const _InitialStockAdvancedFilterSheet({
    required this.initial,
    required this.formatDate,
  });

  @override
  State<_InitialStockAdvancedFilterSheet> createState() =>
      _InitialStockAdvancedFilterSheetState();
}

class _InitialStockAdvancedFilterSheetState
    extends State<_InitialStockAdvancedFilterSheet> {
  String? _storeLocationId;
  DateTime? _dateFrom;
  DateTime? _dateTo;

  @override
  void initState() {
    super.initState();
    _storeLocationId = widget.initial.storeLocationId;
    _dateFrom = widget.initial.dateFrom;
    _dateTo = widget.initial.dateTo;
  }

  String _storeLabel() {
    if ((_storeLocationId ?? '').trim().isEmpty) return 'All stores';
    final stores = context.read<StoreProvider>().stores;
    for (final s in stores) {
      if (s.idStoreLocation.trim() == (_storeLocationId ?? '').trim()) {
        final name = s.name.trim();
        return name.isEmpty ? 'Store selected' : name;
      }
    }
    return 'Store selected';
  }

  Future<void> _pickStore() async {
    final picked = await showStorePickerSheet(
      context,
      selectedId: _storeLocationId,
      autoSelectWhenSingle: false,
    );

    if (!mounted) return;
    if (picked == null) return;
    final id = picked.id.trim();
    setState(() => _storeLocationId = id.isEmpty ? null : id);
  }

  Future<void> _pickDateFrom() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _dateFrom ?? now,
      firstDate: DateTime(2000, 1, 1),
      lastDate: DateTime(2100, 12, 31),
      helpText: 'Select date from',
    );
    if (picked == null) return;
    if (!mounted) return;
    final v = DateTime(picked.year, picked.month, picked.day);
    setState(() {
      _dateFrom = v;
      if (_dateTo != null && _dateTo!.isBefore(v)) {
        _dateTo = v;
      }
    });
  }

  Future<void> _pickDateTo() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _dateTo ?? _dateFrom ?? now,
      firstDate: DateTime(2000, 1, 1),
      lastDate: DateTime(2100, 12, 31),
      helpText: 'Select date to',
    );
    if (picked == null) return;
    if (!mounted) return;
    final v = DateTime(picked.year, picked.month, picked.day);
    setState(() {
      _dateTo = v;
      if (_dateFrom != null && _dateFrom!.isAfter(v)) {
        _dateFrom = v;
      }
    });
  }

  void _reset() {
    setState(() {
      _storeLocationId = null;
      _dateFrom = null;
      _dateTo = null;
    });
  }

  void _apply() {
    Navigator.pop(
      context,
      _InitialStockFilters(
        storeLocationId: (_storeLocationId ?? '').trim().isEmpty
            ? null
            : _storeLocationId!.trim(),
        dateFrom: _dateFrom,
        dateTo: _dateTo,
      ),
    );
  }

  void _applyLastDays(int days) {
    final now = DateTime.now();
    final end = DateTime(now.year, now.month, now.day);
    final start = end.subtract(Duration(days: days - 1));
    setState(() {
      _dateFrom = start;
      _dateTo = end;
    });
  }

  void _applyThisMonth() {
    final now = DateTime.now();
    setState(() {
      _dateFrom = DateTime(now.year, now.month, 1);
      _dateTo = DateTime(now.year, now.month, now.day);
    });
  }

  bool _isQuickLastDaysSelected(int days) {
    if (_dateFrom == null || _dateTo == null) return false;
    final now = DateTime.now();
    final end = DateTime(now.year, now.month, now.day);
    final start = end.subtract(Duration(days: days - 1));
    return _dateFrom == start && _dateTo == end;
  }

  bool _isThisMonthSelected() {
    if (_dateFrom == null || _dateTo == null) return false;
    final now = DateTime.now();
    return _dateFrom == DateTime(now.year, now.month, 1) &&
        _dateTo == DateTime(now.year, now.month, now.day);
  }

  @override
  Widget build(BuildContext context) {
    final hasAny =
        (_storeLocationId ?? '').trim().isNotEmpty ||
        _dateFrom != null ||
        _dateTo != null;

    return DraggableScrollableSheet(
      initialChildSize: 0.58,
      minChildSize: 0.42,
      maxChildSize: 0.7,
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
                        'Advanced Filter',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w900,
                          color: Color(0xFF111827),
                        ),
                      ),
                    ),
                    if (hasAny)
                      TextButton.icon(
                        onPressed: _reset,
                        icon: const Icon(Icons.restart_alt_rounded, size: 18),
                        label: const Text('Reset'),
                        style: TextButton.styleFrom(
                          foregroundColor: const Color(0xFF111827),
                        ),
                      ),
                  ],
                ),
              ),
              Expanded(
                child: ListView(
                  controller: controller,
                  padding: const EdgeInsets.fromLTRB(18, 8, 18, 96),
                  children: [
                    const Text(
                      'Store',
                      style: TextStyle(
                        fontSize: 12,
                        color: Color(0xFF6B7280),
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 8),
                    _FilterTile(
                      icon: Icons.store_mall_directory_rounded,
                      title: 'Store location',
                      value: _storeLabel(),
                      isPlaceholder: (_storeLocationId ?? '').trim().isEmpty,
                      onTap: _pickStore,
                      onClear: (_storeLocationId ?? '').trim().isEmpty
                          ? null
                          : () => setState(() => _storeLocationId = null),
                    ),
                    const SizedBox(height: 14),
                    const Text(
                      'Date',
                      style: TextStyle(
                        fontSize: 12,
                        color: Color(0xFF6B7280),
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: _DateRangeCard(
                            label: 'From',
                            value: _dateFrom == null
                                ? 'Pick a date'
                                : widget.formatDate(_dateFrom),
                            isPlaceholder: _dateFrom == null,
                            onTap: _pickDateFrom,
                            onClear: _dateFrom == null
                                ? null
                                : () => setState(() => _dateFrom = null),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: _DateRangeCard(
                            label: 'To',
                            value: _dateTo == null
                                ? 'Pick a date'
                                : widget.formatDate(_dateTo),
                            isPlaceholder: _dateTo == null,
                            onTap: _pickDateTo,
                            onClear: _dateTo == null
                                ? null
                                : () => setState(() => _dateTo = null),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 10,
                      runSpacing: 10,
                      children: [
                        _QuickChip(
                          text: 'Last 7 Days',
                          selected: _isQuickLastDaysSelected(7),
                          onTap: () => _applyLastDays(7),
                        ),
                        _QuickChip(
                          text: 'This Month',
                          selected: _isThisMonthSelected(),
                          onTap: _applyThisMonth,
                        ),
                      ],
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
                child: Row(
                  children: [
                    Expanded(
                      child: SizedBox(
                        height: 50,
                        child: OutlinedButton(
                          onPressed: () => Navigator.pop(context),
                          style: OutlinedButton.styleFrom(
                            side: const BorderSide(color: Color(0xFFD1D5DB)),
                            foregroundColor: const Color(0xFF111827),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                          ),
                          child: const Text(
                            'Cancel',
                            style: TextStyle(fontWeight: FontWeight.w800),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: SizedBox(
                        height: 50,
                        child: ElevatedButton(
                          onPressed: _apply,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF426FD4),
                            foregroundColor: Colors.white,
                            elevation: 0,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                          ),
                          child: const Text(
                            'Apply',
                            style: TextStyle(fontWeight: FontWeight.w900),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _DateRangeCard extends StatelessWidget {
  final String label;
  final String value;
  final bool isPlaceholder;
  final VoidCallback onTap;
  final VoidCallback? onClear;

  const _DateRangeCard({
    required this.label,
    required this.value,
    required this.isPlaceholder,
    required this.onTap,
    required this.onClear,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Ink(
          padding: const EdgeInsets.fromLTRB(12, 10, 10, 10),
          decoration: BoxDecoration(
            color: const Color(0xFFF9FAFB),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: const Color(0xFFE5E7EB)),
          ),
          child: Row(
            children: [
              const Icon(
                Icons.calendar_today_rounded,
                size: 16,
                color: Color(0xFF6B7280),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label,
                      style: const TextStyle(
                        fontSize: 12,
                        color: Color(0xFF6B7280),
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      value,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 13,
                        color: isPlaceholder
                            ? const Color(0xFF9CA3AF)
                            : const Color(0xFF111827),
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
              ),
              if (onClear != null)
                IconButton(
                  onPressed: onClear,
                  tooltip: 'Clear',
                  icon: const Icon(Icons.close_rounded, size: 16),
                  color: const Color(0xFF6B7280),
                  splashRadius: 18,
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _QuickChip extends StatelessWidget {
  final String text;
  final bool selected;
  final VoidCallback onTap;

  const _QuickChip({
    required this.text,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ActionChip(
      label: Text(text, style: const TextStyle(fontWeight: FontWeight.w800)),
      onPressed: onTap,
      backgroundColor: selected ? const Color(0xFFEAF0FF) : Colors.white,
      side: BorderSide(
        color: selected ? const Color(0xFF426FD4) : const Color(0xFFD1D5DB),
      ),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
      visualDensity: VisualDensity.compact,
      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
    );
  }
}

class _FilterTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String value;
  final bool isPlaceholder;
  final VoidCallback onTap;
  final VoidCallback? onClear;

  const _FilterTile({
    required this.icon,
    required this.title,
    required this.value,
    required this.isPlaceholder,
    required this.onTap,
    required this.onClear,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Ink(
          padding: const EdgeInsets.all(12),
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
                  borderRadius: BorderRadius.circular(11),
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
                        fontSize: 12,
                        color: Color(0xFF6B7280),
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      value,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 13,
                        color: isPlaceholder
                            ? const Color(0xFF9CA3AF)
                            : const Color(0xFF111827),
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
              ),
              if (onClear != null)
                IconButton(
                  onPressed: onClear,
                  tooltip: 'Clear',
                  icon: const Icon(Icons.close_rounded, size: 18),
                  color: const Color(0xFF6B7280),
                )
              else
                const Icon(
                  Icons.chevron_right_rounded,
                  color: Color(0xFF9CA3AF),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StockErrorBox extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;
  const _StockErrorBox({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
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
          const Text(
            'Failed to load stock',
            style: TextStyle(
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
              label: const Text('Retry'),
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

class _StockEmptyBox extends StatelessWidget {
  const _StockEmptyBox();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFF9FAFB),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Column(
        children: const [
          Icon(Icons.inventory_2_rounded, size: 32, color: Color(0xFF9CA3AF)),
          SizedBox(height: 8),
          Text(
            'No initial stock yet',
            style: TextStyle(
              fontWeight: FontWeight.w700,
              color: Color(0xFF111827),
            ),
          ),
          SizedBox(height: 6),
          Text(
            'Pull down to refresh or create the first initial stock document.',
            textAlign: TextAlign.center,
            style: TextStyle(color: Color(0xFF6B7280)),
          ),
        ],
      ),
    );
  }
}
