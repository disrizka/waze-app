import 'package:dotted_border/dotted_border.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:wa_blast/providers/sales_provider.dart';

/// Sales Report with search + date range filters
class SalesReportScreen extends StatefulWidget {
  const SalesReportScreen({super.key});

  @override
  State<SalesReportScreen> createState() => _SalesReportScreenState();
}

class _SalesReportScreenState extends State<SalesReportScreen> {
  final _searchC = TextEditingController();
  DateTimeRange? _range; // active date range
  bool _showFilters = true; // keep filters visible by default

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      context.read<SalesProvider>().fetchSalesReports(context);
    });
  }

  @override
  void dispose() {
    _searchC.dispose();
    super.dispose();
  }

  // Helpers
  String _formatRangeShort(DateTimeRange r) {
    final f = DateFormat('dd MMM yyyy');
    return '${f.format(r.start)} — ${f.format(r.end)}';
  }

  Future<void> _pickRange() async {
    final now = DateTime.now();
    final firstDate = DateTime(now.year - 3);
    final lastDate = DateTime(now.year + 1, 12, 31);

    final res = await showDateRangePicker(
      context: context,
      initialDateRange:
          _range ??
          DateTimeRange(
            start: DateTime(now.year, now.month, now.day),
            end: DateTime(now.year, now.month, now.day),
          ),
      firstDate: firstDate,
      lastDate: lastDate,
      saveText: 'Apply',
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

    if (res != null) {
      setState(
        () => _range = DateTimeRange(
          start: DateTime(res.start.year, res.start.month, res.start.day),
          end: DateTime(res.end.year, res.end.month, res.end.day, 23, 59, 59),
        ),
      );
    }
  }

  void _clearFilters() {
    setState(() {
      _searchC.clear();
      _range = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    final fTime = DateFormat('dd MMM yyyy, HH:mm');
    final fMoney = NumberFormat.decimalPattern('id_ID');

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        scrolledUnderElevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded),
          onPressed: () => Navigator.of(
            context,
          ).popUntil((route) => route.settings.name == '/sales'),
        ),
        title: Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.baseline,
          textBaseline: TextBaseline.alphabetic,
          children: const [
            Text('Sales', style: TextStyle(fontWeight: FontWeight.w800)),
            SizedBox(width: 8),
            Text(
              '/history',
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
        // actions: [
        //   IconButton(
        //     tooltip: _showFilters ? 'Hide filters' : 'Show filters',
        //     onPressed: () => setState(() => _showFilters = !_showFilters),
        //     icon: Icon(_showFilters ? Icons.filter_alt_off : Icons.filter_alt),
        //   ),
        // ],
      ),
      body: Consumer<SalesProvider>(
        builder: (context, prov, _) {
          final items = prov.reports;
          final isLoading = prov.loadingReports;
          final error = prov.reportError;

          // Apply client-side filters
          final filtered = items.where((it) {
            // search
            final q = _searchC.text.trim().toLowerCase();
            final matchesQuery = q.isEmpty
                ? true
                : [
                    it.code,
                    it.reference,
                    it.status,
                  ].whereType<String>().any((s) => s.toLowerCase().contains(q));

            // date range (inclusive)
            final matchesRange = _range == null
                ? true
                : (it.time.isAfter(_range!.start) ||
                          it.time.isAtSameMomentAs(_range!.start)) &&
                      (it.time.isBefore(_range!.end) ||
                          it.time.isAtSameMomentAs(_range!.end));

            return matchesQuery && matchesRange;
          }).toList();

          return RefreshIndicator(
            onRefresh: () =>
                context.read<SalesProvider>().fetchSalesReports(context),
            color: const Color(0xFF426FD4),
            child: CustomScrollView(
              slivers: [
                // Filters (collapsible)
                SliverToBoxAdapter(
                  child: AnimatedCrossFade(
                    duration: const Duration(milliseconds: 300),
                    firstCurve: Curves.easeOutCubic,
                    secondCurve: Curves.easeInCubic,
                    crossFadeState: _showFilters
                        ? CrossFadeState.showFirst
                        : CrossFadeState.showSecond,
                    firstChild: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 10,
                      ),
                      child: _FiltersCard(
                        searchC: _searchC,
                        onSearchChanged: () => setState(() {}),
                        onPickRange: _pickRange,
                        range: _range, // kirim DateTimeRange? langsung
                        onClear: (_searchC.text.isNotEmpty || _range != null)
                            ? _clearFilters
                            : null,
                      ),
                    ),
                    secondChild: const SizedBox.shrink(),
                  ),
                ),

                // Empty / error / loading states
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
                      child: _ErrorBox(
                        message: error,
                        onRetry: () => context
                            .read<SalesProvider>()
                            .fetchSalesReports(context),
                      ),
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
                  // Header with count
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              'Results (${filtered.length})',
                              style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: Color(0xFF6B7280),
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

                  // List
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
                              // header
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
                              // amounts
                              Row(
                                children: [
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        const Text(
                                          'Total amount',
                                          style: TextStyle(
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
                                      const Text(
                                        'Quantity',
                                        style: TextStyle(
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
                  const SliverToBoxAdapter(child: SizedBox(height: 24)),
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
              onPressed: () => Navigator.pushNamed(context, '/sales/add'),
              icon: const Icon(Icons.add, size: 20),
              label: const Text(
                'Add Sales',
                style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
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

/// --- Formatter range pendek ---
/// - Same month/year:  "27 Oct — 31"
/// - Same year:        "27 Oct — 02 Nov"
/// - Different year:   "27 Oct 2025 — 02 Jan 2026"
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

class _FiltersCard extends StatelessWidget {
  final TextEditingController searchC;
  final VoidCallback onSearchChanged;
  final VoidCallback onPickRange;
  final DateTimeRange? range; // ganti dari String ke DateTimeRange?
  final VoidCallback? onClear;

  const _FiltersCard({
    required this.searchC,
    required this.onSearchChanged,
    required this.onPickRange,
    required this.range,
    this.onClear,
  });

  @override
  Widget build(BuildContext context) {
    const borderColor = Color(0xFFE5E7EB);
    const textMain = Color(0xFF111827);
    const textSub = Color(0xFF6B7280);

    final rangeLabel = range == null ? 'Any time' : formatRangeCompact(range!);

    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        height: 52,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: borderColor),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF0B1220).withOpacity(0.04),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final isTight = constraints.maxWidth < 360; // responsif sederhana
            return Row(
              children: [
                const Icon(Icons.search_rounded, size: 20, color: textSub),
                const SizedBox(width: 8),

                // search field
                Expanded(
                  child: TextField(
                    controller: searchC,
                    onChanged: (_) => onSearchChanged(),
                    textInputAction: TextInputAction.search,
                    textAlignVertical: TextAlignVertical.center,
                    style: const TextStyle(fontSize: 14, color: textMain),
                    maxLines: 1,
                    decoration: const InputDecoration(
                      hintText: 'Search code / reference / status',
                      hintStyle: TextStyle(
                        fontSize: 14,
                        color: Color(0xFF9CA3AF),
                      ),
                      isCollapsed: true,
                      filled: false,
                      border: InputBorder.none,
                      enabledBorder: InputBorder.none,
                      focusedBorder: InputBorder.none,
                      contentPadding: EdgeInsets.zero,
                    ),
                  ),
                ),

                if (searchC.text.isNotEmpty) ...[
                  const SizedBox(width: 8),
                  InkWell(
                    borderRadius: BorderRadius.circular(20),
                    onTap: () {
                      searchC.clear();
                      onSearchChanged();
                    },
                    child: const Padding(
                      padding: EdgeInsets.all(6),
                      child: Icon(
                        Icons.close_rounded,
                        size: 18,
                        color: Color(0xFF9CA3AF),
                      ),
                    ),
                  ),
                ],

                const SizedBox(width: 10),
                _VDivider(color: borderColor),
                const SizedBox(width: 10),

                // date (Flexible supaya tidak overflow)
                Flexible(
                  fit: FlexFit.loose,
                  child: InkWell(
                    borderRadius: BorderRadius.circular(10),
                    onTap: onPickRange,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 8,
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.date_range_rounded,
                            size: 18,
                            color: textMain,
                          ),
                          const SizedBox(width: 8),
                          Flexible(
                            child: Text(
                              rangeLabel,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              softWrap: false,
                              style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: textMain,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),

                if (onClear != null) ...[
                  const SizedBox(width: 8),
                  _VDivider(color: borderColor),
                  const SizedBox(width: 4),

                  // Reset: teks atau ikon saja bila sempit
                  if (!isTight)
                    TextButton(
                      onPressed: onClear,
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 8,
                        ),
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        minimumSize: Size.zero,
                        foregroundColor: const Color(0xFF2563EB),
                      ),
                      child: const Text(
                        'Reset',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    )
                  else
                    IconButton(
                      onPressed: onClear,
                      tooltip: 'Reset filters',
                      padding: const EdgeInsets.all(6),
                      constraints: const BoxConstraints(),
                      icon: const Icon(
                        Icons.restart_alt_rounded,
                        size: 18,
                        color: Color(0xFF2563EB),
                      ),
                    ),
                ],
              ],
            );
          },
        ),
      ),
    );
  }
}

class _VDivider extends StatelessWidget {
  final Color color;
  const _VDivider({required this.color});
  @override
  Widget build(BuildContext context) {
    return Container(width: 1, height: 24, color: color);
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
            'Failed to load sales',
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

class _EmptyBox extends StatelessWidget {
  const _EmptyBox();

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
          Icon(Icons.receipt_long_rounded, size: 32, color: Color(0xFF9CA3AF)),
          SizedBox(height: 8),
          Text(
            'No sales yet',
            style: TextStyle(
              fontWeight: FontWeight.w700,
              color: Color(0xFF111827),
            ),
          ),
          SizedBox(height: 6),
          Text(
            'Pull down to refresh.',
            textAlign: TextAlign.center,
            style: TextStyle(color: Color(0xFF6B7280)),
          ),
        ],
      ),
    );
  }
}
