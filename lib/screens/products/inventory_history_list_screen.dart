import 'package:dotted_border/dotted_border.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:wa_blast/providers/product_provider.dart';

class InventoryHistoryListScreen extends StatefulWidget {
  const InventoryHistoryListScreen({super.key});

  @override
  State<InventoryHistoryListScreen> createState() =>
      _InventoryHistoryListScreenState();
}

enum _TypeFilter { all, purchase, sale }

class _InventoryHistoryListScreenState
    extends State<InventoryHistoryListScreen> {
  _TypeFilter _type = _TypeFilter.all;
  DateTimeRange? _range;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      context.read<ProductProvider>().fetchInventoryHistory(context);
    });
  }

  Future<void> _refreshInventory() async {
    await Future<void>.delayed(Duration.zero);
    if (!mounted) return;
    await context.read<ProductProvider>().refresh(
      context,
      inventoryHistory: true,
      products: false,
      brands: false,
      categories: false,
    );
  }

  // ---------- DATE HELPERS ----------
  DateTime _todayStart() {
    final now = DateTime.now();
    return DateTime(now.year, now.month, now.day);
  }

  DateTimeRange _quickToday() {
    final s = _todayStart();
    return DateTimeRange(
      start: s,
      end: s.add(const Duration(hours: 23, minutes: 59, seconds: 59)),
    );
  }

  DateTimeRange _quickLastNDays(int n) {
    final end = _todayStart().add(
      const Duration(hours: 23, minutes: 59, seconds: 59),
    );
    final start = end.subtract(Duration(days: n - 1));
    return DateTimeRange(
      start: DateTime(start.year, start.month, start.day),
      end: end,
    );
  }

  String _rangeLabel(DateTimeRange? r) {
    final f = DateFormat('d MMM yyyy');
    if (r == null) return 'Date';
    final s = f.format(r.start);
    final e = f.format(r.end);
    return s == e ? s : '$s — $e';
  }

  Future<void> _pickDateRange() async {
    final now = DateTime.now();
    final firstDate = DateTime(now.year - 3, 1, 1);
    final lastDate = DateTime(now.year + 1, 12, 31);

    final picked = await showDateRangePicker(
      context: context,
      firstDate: firstDate,
      lastDate: lastDate,
      initialDateRange: _range ?? _quickToday(),
      helpText: 'Pick date range',
      builder: (context, child) {
        // aksen warna primer
        final cs = Theme.of(context).colorScheme;
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: cs.copyWith(
              primary: const Color(0xFF426FD4),
              onPrimary: Colors.white,
              surface: Colors.white,
              onSurface: const Color(0xFF111827),
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      setState(() {
        _range = DateTimeRange(
          start: DateTime(
            picked.start.year,
            picked.start.month,
            picked.start.day,
          ),
          end: DateTime(
            picked.end.year,
            picked.end.month,
            picked.end.day,
            23,
            59,
            59,
          ),
        );
      });
      _refreshInventory();
    }
  }

  void _applyQuickRange(DateTimeRange r) {
    setState(() => _range = r);
    _refreshInventory();
  }

  void _clearDateRange() {
    setState(() => _range = null);
    _refreshInventory();
  }

  // ---------- CHIP UI ----------
  Widget _typeChip({
    required String label,
    required _TypeFilter me,
    required Color selectedBg,
    required Color selectedFg,
    required Color unselectedBg,
    required Color unselectedFg,
    required Color border,
  }) {
    final selected = _type == me;
    return ChoiceChip(
      label: Text(label, overflow: TextOverflow.ellipsis),
      selected: selected,
      onSelected: (_) {
        if (_type != me) {
          setState(() => _type = me);
          _refreshInventory();
        }
      },
      side: BorderSide(color: selected ? selectedBg : border),
      selectedColor: selectedBg,
      backgroundColor: unselectedBg,
      labelStyle: TextStyle(
        fontWeight: FontWeight.w700,
        color: selected ? selectedFg : unselectedFg,
      ),
      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
      visualDensity: VisualDensity.compact,
      pressElevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
    );
  }

  Widget _quickRangeChip(String label, VoidCallback onTap) {
    return ActionChip(
      label: Text(label, style: const TextStyle(fontWeight: FontWeight.w700)),
      onPressed: onTap,
      backgroundColor: const Color(0xFFF3F4F6),
      side: const BorderSide(color: Color(0xFFE5E7EB)),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
      visualDensity: VisualDensity.compact,
    );
  }

  @override
  Widget build(BuildContext context) {
    final rangeText = _rangeLabel(_range);

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Inventory History',
          style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18),
        ),
        centerTitle: false,
        scrolledUnderElevation: 0,
      ),
      body: Column(
        children: [
          // ====== FILTER BAR (Horizontal scrollable, anti overflow) ======
          Container(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 10),
            decoration: const BoxDecoration(
              color: Colors.white,
              border: Border(bottom: BorderSide(color: Color(0xFFE5E7EB))),
            ),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  // Type chips
                  _typeChip(
                    label: 'All',
                    me: _TypeFilter.all,
                    selectedBg: const Color(0xFFE0E7FF), // indigo-100
                    selectedFg: const Color(0xFF1E3A8A), // indigo-900
                    unselectedBg: const Color(0xFFF8FAFC),
                    unselectedFg: const Color(0xFF111827),
                    border: const Color(0xFFE5E7EB),
                  ),
                  const SizedBox(width: 8),
                  _typeChip(
                    label: 'Purchase',
                    me: _TypeFilter.purchase,
                    selectedBg: const Color(0xFFDDEAFE), // blue-100
                    selectedFg: const Color(0xFF1D4ED8), // blue-700
                    unselectedBg: const Color(0xFFF8FAFC),
                    unselectedFg: const Color(0xFF111827),
                    border: const Color(0xFFE5E7EB),
                  ),
                  const SizedBox(width: 8),
                  _typeChip(
                    label: 'Sales',
                    me: _TypeFilter.sale,
                    selectedBg: const Color(0xFFFEE2E2), // rose-100
                    selectedFg: const Color(0xFFB91C1C), // red-700
                    unselectedBg: const Color(0xFFF8FAFC),
                    unselectedFg: const Color(0xFF111827),
                    border: const Color(0xFFE5E7EB),
                  ),
                  const SizedBox(width: 12),

                  // Quick ranges
                  _quickRangeChip(
                    'Today',
                    () => _applyQuickRange(_quickToday()),
                  ),
                  const SizedBox(width: 6),
                  _quickRangeChip(
                    '7D',
                    () => _applyQuickRange(_quickLastNDays(7)),
                  ),
                  const SizedBox(width: 6),
                  _quickRangeChip(
                    '30D',
                    () => _applyQuickRange(_quickLastNDays(30)),
                  ),
                  const SizedBox(width: 12),

                  // Date range button + clear
                  ConstrainedBox(
                    constraints: const BoxConstraints(minWidth: 120),
                    child: OutlinedButton.icon(
                      onPressed: _pickDateRange,
                      icon: const Icon(Icons.calendar_today_rounded, size: 18),
                      label: Text(
                        rangeText,
                        overflow: TextOverflow.ellipsis,
                        maxLines: 1,
                      ),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: const Color(0xFF111827),
                        side: const BorderSide(color: Color(0xFFE5E7EB)),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 10,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(999),
                        ),
                        textStyle: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                    ),
                  ),
                  if (_range != null) ...[
                    const SizedBox(width: 6),
                    IconButton(
                      tooltip: 'Clear date',
                      onPressed: _clearDateRange,
                      icon: const Icon(Icons.close_rounded, size: 18),
                      splashRadius: 18,
                    ),
                  ],
                ],
              ),
            ),
          ),

          const Expanded(child: _InventoryList()),
        ],
      ),
    );
  }
}

class _InventoryList extends StatelessWidget {
  const _InventoryList();

  @override
  Widget build(BuildContext context) {
    final fDateHeader = DateFormat('EEE, d MMM yyyy');
    final fTime = DateFormat('HH:mm');

    return Consumer<ProductProvider>(
      builder: (context, prov, _) {
        final items = prov.inventoryHistory;
        final isLoading = prov.loadingInventoryHistory;
        final error = prov.inventoryHistoryError;

        // ambil filter dari parent
        final state = context
            .findAncestorStateOfType<_InventoryHistoryListScreenState>()!;
        final _TypeFilter type = state._type;
        final DateTimeRange? range = state._range;

        // apply filters
        final filtered =
            items.where((it) {
              if (type == _TypeFilter.purchase && it.type != 'purchase')
                return false;
              if (type == _TypeFilter.sale && it.type != 'sale') return false;
              if (range != null) {
                final dt = it.createdAt as DateTime;
                if (dt.isBefore(range.start) || dt.isAfter(range.end))
                  return false;
              }
              return true;
            }).toList()..sort(
              (a, b) =>
                  (b.createdAt as DateTime).compareTo(a.createdAt as DateTime),
            );

        return RefreshIndicator(
          onRefresh: () => context.read<ProductProvider>().refresh(
            context,
            inventoryHistory: true,
            products: false,
            brands: false,
            categories: false,
          ),
          color: const Color(0xFF426FD4),
          child: Builder(
            builder: (context) {
              if (isLoading && items.isEmpty) {
                return ListView(
                  padding: const EdgeInsets.fromLTRB(16, 24, 16, 24),
                  children: const [Center(child: CircularProgressIndicator())],
                );
              }

              if (error != null && items.isEmpty) {
                return ListView(
                  padding: const EdgeInsets.fromLTRB(16, 24, 16, 24),
                  children: [
                    _ErrorBox(
                      message: error,
                      onRetry: () => context
                          .read<ProductProvider>()
                          .fetchInventoryHistory(context),
                    ),
                  ],
                );
              }

              if (filtered.isEmpty) {
                return ListView(
                  padding: const EdgeInsets.fromLTRB(16, 24, 16, 24),
                  children: const [_EmptyBox()],
                );
              }

              // grouping per tanggal (date-only)
              final Map<DateTime, List<dynamic>> grouped = {};
              for (final it in filtered) {
                final d = it.createdAt as DateTime;
                final key = DateTime(d.year, d.month, d.day);
                grouped.putIfAbsent(key, () => []).add(it);
              }

              final dates = grouped.keys.toList()
                ..sort((a, b) => b.compareTo(a));

              // total rows = sum(1 header tanggal + n item)
              final totalCount = dates.fold<int>(
                0,
                (acc, d) => acc + 1 + grouped[d]!.length,
              );

              return ListView.builder(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
                itemCount: totalCount,
                itemBuilder: (context, i) {
                  // iterasi tanggal demi tanggal
                  int cursor = 0;
                  for (final date in dates) {
                    final dayItems = grouped[date]!;
                    if (i == cursor) {
                      // subheader tanggal (bold)
                      return Padding(
                        padding: const EdgeInsets.only(top: 8, bottom: 8),
                        child: Text(
                          fDateHeader.format(date),
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                            color: Color(0xFF111827),
                          ),
                        ),
                      );
                    }
                    cursor += 1;

                    if (i < cursor + dayItems.length) {
                      final it = dayItems[i - cursor];

                      // chips kecil
                      Widget chip(String text, Color bg, Color fg) => Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: bg,
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Text(
                          text,
                          style: TextStyle(
                            color: fg,
                            fontWeight: FontWeight.w700,
                            fontSize: 11,
                          ),
                        ),
                      );

                      Color typeBg(String t) {
                        switch (t) {
                          case 'purchase':
                            return const Color(0xFFDDEAFE);
                          case 'adjustment':
                            return const Color(0xFFFFF7ED);
                          case 'sale':
                            return const Color(0xFFFEE2E2);
                          default:
                            return const Color(0xFFF3F4F6);
                        }
                      }

                      Color typeFg(String t) {
                        switch (t) {
                          case 'purchase':
                            return const Color(0xFF1D4ED8);
                          case 'adjustment':
                            return const Color(0xFF92400E);
                          case 'sale':
                            return const Color(0xFFB91C1C);
                          default:
                            return const Color(0xFF374151);
                        }
                      }

                      final attrs = it.productSku.attributes;
                      final skuAttrs = (attrs.isEmpty)
                          ? ''
                          : attrs
                                .map((a) => '${a.name}: ${a.value}')
                                .join(' · ');

                      final card = DottedBorder(
                        options: RoundedRectDottedBorderOptions(
                          color: const Color(0xFFD1D5DB),
                          dashPattern: const [6, 6],
                          strokeWidth: 1.4,
                          radius: const Radius.circular(12),
                          padding: const EdgeInsets.all(0),
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
                              // Header: icon + product + jam + chip
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
                                      Icons.inventory_2_rounded,
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
                                          it.product.name,
                                          style: const TextStyle(
                                            fontSize: 16,
                                            fontWeight: FontWeight.w700,
                                            color: Color(0xFF111827),
                                          ),
                                          maxLines: 2,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                        const SizedBox(height: 2),
                                        Row(
                                          children: [
                                            Text(
                                              DateFormat(
                                                'HH:mm',
                                              ).format(it.createdAt),
                                              style: const TextStyle(
                                                fontSize: 12,
                                                color: Color(0xFF6B7280),
                                              ),
                                            ),
                                            const SizedBox(width: 8),
                                            chip(
                                              it.type.isNotEmpty
                                                  ? it.type
                                                  : (it.referenceType.isNotEmpty
                                                        ? it.referenceType
                                                        : '—'),
                                              typeBg(it.type),
                                              typeFg(it.type),
                                            ),
                                            const SizedBox(width: 6),
                                            chip(
                                              it.source.isNotEmpty
                                                  ? it.source
                                                  : '—',
                                              const Color(0xFFF3F4F6),
                                              const Color(0xFF374151),
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),

                              const SizedBox(height: 14),

                              // Detail: SKU / Store / Qty
                              Row(
                                children: [
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        const Text(
                                          'SKU',
                                          style: TextStyle(
                                            fontSize: 12,
                                            color: Color(0xFF6B7280),
                                          ),
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          it.productSku.code,
                                          style: const TextStyle(
                                            fontWeight: FontWeight.w700,
                                            fontSize: 14,
                                          ),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                        if (skuAttrs.isNotEmpty) ...[
                                          const SizedBox(height: 2),
                                          Text(
                                            skuAttrs,
                                            maxLines: 2,
                                            overflow: TextOverflow.ellipsis,
                                            style: const TextStyle(
                                              fontSize: 12,
                                              color: Color(0xFF9CA3AF),
                                            ),
                                          ),
                                        ],
                                      ],
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        const Text(
                                          'Store',
                                          style: TextStyle(
                                            fontSize: 12,
                                            color: Color(0xFF6B7280),
                                          ),
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          it.storeLocation.name,
                                          style: const TextStyle(
                                            fontWeight: FontWeight.w700,
                                            fontSize: 14,
                                          ),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Column(
                                    crossAxisAlignment: CrossAxisAlignment.end,
                                    children: [
                                      const Text(
                                        'Qty',
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: Color(0xFF6B7280),
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        '${it.qty}',
                                        style: const TextStyle(
                                          fontSize: 18,
                                          fontWeight: FontWeight.w800,
                                          color: Color(0xFF111827),
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),

                              if (it.note.isNotEmpty) ...[
                                const SizedBox(height: 12),
                                const Divider(
                                  color: Color(0xFFE5E7EB),
                                  height: 20,
                                ),
                                Text(
                                  it.note,
                                  style: const TextStyle(
                                    color: Color(0xFF6B7280),
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                      );

                      return Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: card,
                      );
                    }

                    cursor += dayItems.length;
                  }

                  return const SizedBox.shrink();
                },
              );
            },
          ),
        );
      },
    );
  }
}

// ====== Reusable boxes ======

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
            'Failed to load inventory history',
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
          Icon(Icons.move_down_rounded, size: 32, color: Color(0xFF9CA3AF)),
          SizedBox(height: 8),
          Text(
            'No inventory history yet',
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
