import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:wa_blast/providers/report_provider.dart';

class PurchaseReportScreen extends StatelessWidget {
  static const routeName = '/report/purchase';
  const PurchaseReportScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const _ReportScreenBase(
      domain: ReportDomain.purchase,
      title: 'Purchase Report',
      customerLikeLabel: 'Supplier',
    );
  }
}

class _ReportScreenBase extends StatefulWidget {
  final ReportDomain domain;
  final String title;
  final String customerLikeLabel;
  const _ReportScreenBase({
    super.key,
    required this.domain,
    required this.title,
    required this.customerLikeLabel,
  });

  @override
  State<_ReportScreenBase> createState() => _ReportScreenBaseState();
}

class _ReportScreenBaseState extends State<_ReportScreenBase> {
  late ReportTarget _target;
  late ReportPeriod _period;
  bool _useCustomRange = false;
  DateTime? _startDate;
  DateTime? _endDate;

  String _sortKey = 'revenue';
  bool _sortDesc = true;

  /// Shimmer/UI loading saat transisi ke period
  bool _uiLoading = false;

  final _currency = NumberFormat.currency(
    locale: 'id_ID',
    symbol: 'Rp ',
    decimalDigits: 0,
  );

  @override
  void initState() {
    super.initState();
    _target = ReportTarget.customer; // di purchase: slot "supplier"
    _period = ReportPeriod.week;
    WidgetsBinding.instance.addPostFrameCallback((_) => _fetch());
  }

  Future<void> _pickDateRange() async {
    final now = DateTime.now();
    final initialStart = _startDate ?? DateTime(now.year, now.month, 1);
    final initialEnd = _endDate ?? now;

    final r = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020, 1, 1),
      lastDate: DateTime(now.year + 2, 12, 31),
      initialDateRange: DateTimeRange(start: initialStart, end: initialEnd),
      helpText: 'Pilih Rentang Tanggal',
      saveText: 'Pakai Rentang',
      builder: (ctx, child) => Theme(
        data: Theme.of(ctx).copyWith(
          colorScheme: const ColorScheme.light(
            primary: Color(0xFF1D4ED8),
            onPrimary: Colors.white,
            surface: Colors.white,
            onSurface: Color(0xFF0F172A),
          ),
        ),
        child: child!,
      ),
    );

    if (r != null) {
      setState(() {
        _startDate = DateTime(r.start.year, r.start.month, r.start.day);
        _endDate = DateTime(r.end.year, r.end.month, r.end.day);
        _target = ReportTarget.period;
        _useCustomRange = true;
        _uiLoading = true; // shimmer tampil
      });
      await _fetch();
    }
  }

  Future<void> _fetch() async {
    final p = context.read<ReportProviderV2>();
    try {
      if (_target == ReportTarget.period || _useCustomRange) {
        final sd = _startDate ?? DateTime(DateTime.now().year, 1, 1);
        final ed = _endDate ?? DateTime.now();
        await p.fetchByPeriod(
          context,
          domain: widget.domain,
          period: _period,
          startDate: sd,
          endDate: ed,
          force: true,
        );
      } else {
        await p.fetchPurchase(
          context,
          target: _target,
          period: _period,
          force: true,
        );
      }
    } finally {
      if (mounted) setState(() => _uiLoading = false);
    }
  }

  void _onChangeTarget(ReportTarget t) {
    setState(() {
      _target = t;
      // custom range hanya relevan kalau period
      _useCustomRange = (t == ReportTarget.period) && _useCustomRange;
      _uiLoading = (t == ReportTarget.period); // shimmer saat pindah ke period
    });
    _fetch();
  }

  void _onChangePeriod(ReportPeriod v) {
    setState(() {
      _period = v;
      _uiLoading = (_target == ReportTarget.period);
    });
    _fetch();
  }

  void _onToggleCustomRange(bool v) {
    setState(() {
      _useCustomRange = (_target == ReportTarget.period) && v;
      _uiLoading = (_target == ReportTarget.period) && v;
    });
    _fetch();
  }

  void _applySort(List<dynamic> items) {
    int cmpNum(num a, num b) => a == b ? 0 : (a < b ? -1 : 1);
    int cmpStr(String a, String b) =>
        a.toLowerCase().compareTo(b.toLowerCase());
    int mult = _sortDesc ? -1 : 1;

    if (_target == ReportTarget.period) {
      final list = items.whereType<PeriodSeriesItem>().toList();
      list.sort((a, b) {
        switch (_sortKey) {
          case 'qty':
            return mult * cmpNum(a.totalQty, b.totalQty);
          case 'tx':
            return mult * cmpNum(a.totalTransactions, b.totalTransactions);
          case 'period':
            return mult * cmpStr(a.period, b.period);
          case 'revenue':
          default:
            return mult * cmpNum(a.totalRevenue, b.totalRevenue);
        }
      });
      items
        ..clear()
        ..addAll(list);
    } else {
      final list = items.whereType<EntityReportItem>().toList();
      list.sort((a, b) {
        switch (_sortKey) {
          case 'label':
            return mult * cmpStr(a.label, b.label);
          case 'qty':
            return mult * cmpNum(a.totalQty, b.totalQty);
          case 'tx':
            return mult * cmpNum(a.totalTransactions, b.totalTransactions);
          case 'revenue':
          default:
            return mult * cmpNum(a.totalRevenue, b.totalRevenue);
        }
      });
      items
        ..clear()
        ..addAll(list);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isPeriod = _target == ReportTarget.period;

    return Scaffold(
      backgroundColor: const Color(0xFFF1F5F9),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0.6,
        title: Text(
          widget.title,
          style: const TextStyle(
            color: Color(0xFF0F172A),
            fontWeight: FontWeight.w800,
          ),
        ),
        iconTheme: const IconThemeData(color: Color(0xFF0F172A)),
        actions: [
          IconButton(
            tooltip: 'Refresh',
            onPressed: _fetch,
            icon: const Icon(Icons.refresh, color: Color(0xFF0F172A)),
          ),
        ],
      ),
      body: Consumer<ReportProviderV2>(
        builder: (ctx, p, _) {
          final items = List<dynamic>.from(p.items);
          _applySort(items);
          final s = p.summary;
          final r = p.range;

          return RefreshIndicator(
            color: const Color(0xFF1D4ED8),
            onRefresh: _fetch,
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                _ReportFilterBar(
                  domain: widget.domain,
                  customerLikeLabel: widget.customerLikeLabel,
                  target: _target,
                  onTargetChanged: _onChangeTarget,
                  period: _period,
                  onPeriodChanged: _onChangePeriod,
                  showCustomControls: isPeriod,
                  useCustomRange: _useCustomRange,
                  onToggleCustomRange: _onToggleCustomRange,
                  startDate: _startDate,
                  endDate: _endDate,
                  onPickDateRange: _pickDateRange,
                ),
                const SizedBox(height: 12),

                // SHIMMER saat transisi ke Period
                if (_uiLoading) ...[
                  const _SummaryStripShimmer(),
                  const SizedBox(height: 16),
                  const _PieShimmer(),
                  const SizedBox(height: 24),
                  const _TableShimmer(),
                  const SizedBox(height: 32),
                ] else ...[
                  _SummaryStrip(
                    currency: _currency,
                    totalRevenue: s?.totalRevenue ?? 0,
                    totalRevenueFormatted:
                        s?.totalRevenueFormatted ??
                        _currency.format(s?.totalRevenue ?? 0),
                    totalQty: s?.totalQty ?? 0,
                    totalTx: s?.totalTransactions ?? 0,
                  ),
                  const SizedBox(height: 16),
                  if (r?.startDate != null && r?.endDate != null)
                    Row(
                      children: [
                        Chip(
                          backgroundColor: const Color(0xFFEFF6FF),
                          side: BorderSide.none,
                          labelStyle: const TextStyle(color: Color(0xFF1D4ED8)),
                          label: Text(
                            'Range: ${_fmtD(r!.startDate!)} — ${_fmtD(r.endDate!)}',
                          ),
                        ),
                      ],
                    ),
                  const SizedBox(height: 16),

                  // Pie + Top 5 (Dashboard feel)
                  _DistributionAndTop(
                    items: items,
                    target: _target,
                    currency: _currency,
                    customerLikeLabel: widget.customerLikeLabel,
                  ),

                  const SizedBox(height: 24),
                  _SortBar(
                    target: _target,
                    sortKey: _sortKey,
                    sortDesc: _sortDesc,
                    onChange: (k, desc) =>
                        setState(() => {_sortKey = k, _sortDesc = desc}),
                  ),
                  const SizedBox(height: 8),
                  _ReportDataTable(
                    items: items,
                    target: _target,
                    currency: _currency,
                    customerLikeLabel: widget.customerLikeLabel,
                  ),
                  const SizedBox(height: 32),
                ],
              ],
            ),
          );
        },
      ),
    );
  }

  String _fmtD(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
}

/// =============================
/// FILTER BAR
/// =============================

class _ReportFilterBar extends StatelessWidget {
  final ReportDomain domain;
  final String customerLikeLabel;
  final ReportTarget target;
  final ValueChanged<ReportTarget> onTargetChanged;

  final ReportPeriod period;
  final ValueChanged<ReportPeriod> onPeriodChanged;

  final bool showCustomControls;
  final bool useCustomRange;
  final ValueChanged<bool> onToggleCustomRange;
  final DateTime? startDate;
  final DateTime? endDate;
  final Future<void> Function() onPickDateRange;

  const _ReportFilterBar({
    super.key,
    required this.domain,
    required this.customerLikeLabel,
    required this.target,
    required this.onTargetChanged,
    required this.period,
    required this.onPeriodChanged,
    required this.showCustomControls,
    required this.useCustomRange,
    required this.onToggleCustomRange,
    required this.startDate,
    required this.endDate,
    required this.onPickDateRange,
  });

  @override
  Widget build(BuildContext context) {
    final targets = <ReportTarget>[
      ReportTarget.customer,
      ReportTarget.product,
      ReportTarget.category,
      ReportTarget.brand,
      ReportTarget.period,
    ];

    String labelFor(ReportTarget t) =>
        t == ReportTarget.customer ? customerLikeLabel : t.label;

    return Card(
      color: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      elevation: 0.5,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Row: Target & Granularity
            Row(
              children: [
                Expanded(
                  child: _Labeled(
                    label: 'Target',
                    child: _FancyDropdown<ReportTarget>(
                      value: target,
                      items: [
                        for (final e in targets)
                          DropdownMenuItem(value: e, child: Text(labelFor(e))),
                      ],
                      icon: Icons.flag_outlined,
                      onChanged: (v) => v != null ? onTargetChanged(v) : null,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _Labeled(
                    label: 'Granularity',
                    child: _FancyDropdown<ReportPeriod>(
                      value: period,
                      items: [
                        for (final e in ReportPeriod.values)
                          DropdownMenuItem(
                            value: e,
                            child: Text(e.query.toUpperCase()),
                          ),
                      ],
                      icon: Icons.schedule_outlined,
                      onChanged: (v) => v != null ? onPeriodChanged(v) : null,
                    ),
                  ),
                ),
              ],
            ),

            // Row 2: Custom Date Range (opsional)
            if (showCustomControls) ...[
              const SizedBox(height: 12),
              Wrap(
                spacing: 12,
                runSpacing: 8,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  _Labeled(
                    label: 'Custom Date Range',
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Switch.adaptive(
                          value: useCustomRange,
                          onChanged: (v) => onToggleCustomRange(v),
                          activeColor: const Color(0xFF1D4ED8),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          useCustomRange ? 'On' : 'Off',
                          style: const TextStyle(color: Color(0xFF334155)),
                        ),
                      ],
                    ),
                  ),
                  if (useCustomRange)
                    OutlinedButton.icon(
                      icon: const Icon(
                        Icons.event_outlined,
                        color: Color(0xFF1D4ED8),
                      ),
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: Color(0xFF1D4ED8)),
                        foregroundColor: const Color(0xFF1D4ED8),
                      ),
                      label: Text(
                        startDate == null || endDate == null
                            ? 'Pick date range'
                            : '${_fmt(startDate!)} — ${_fmt(endDate!)}',
                      ),
                      onPressed: onPickDateRange,
                    ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  String _fmt(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
}

class _FancyDropdown<T> extends StatelessWidget {
  final T value;
  final List<DropdownMenuItem<T>> items;
  final void Function(T?)? onChanged;
  final IconData icon;

  const _FancyDropdown({
    required this.value,
    required this.items,
    required this.onChanged,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return DropdownButtonFormField<T>(
      value: value,
      items: items,
      onChanged: onChanged,
      decoration: InputDecoration(
        isDense: true,
        filled: true,
        fillColor: const Color(0xFFF8FAFF),
        prefixIcon: Icon(icon, color: const Color(0xFF1D4ED8)),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 12,
          vertical: 10,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFF93C5FD)),
        ),
      ),
      icon: const Icon(Icons.expand_more, color: Color(0xFF334155)),
      borderRadius: BorderRadius.circular(12),
      dropdownColor: Colors.white,
    );
  }
}

class _Labeled extends StatelessWidget {
  final String label;
  final Widget child;
  const _Labeled({required this.label, required this.child});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: Theme.of(
            context,
          ).textTheme.labelMedium?.copyWith(color: const Color(0xFF64748B)),
        ),
        const SizedBox(height: 4),
        child,
      ],
    );
  }
}

/// =============================
/// SUMMARY STRIP
/// =============================

class _SummaryStrip extends StatelessWidget {
  final NumberFormat currency;
  final num totalRevenue;
  final String totalRevenueFormatted;
  final int totalQty;
  final int totalTx;

  const _SummaryStrip({
    required this.currency,
    required this.totalRevenue,
    required this.totalRevenueFormatted,
    required this.totalQty,
    required this.totalTx,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _SummaryCard.fullWidth(
          title: 'Total Purchase',
          value: totalRevenueFormatted,
          icon: Icons.paid_outlined,
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _SummaryCard(
                title: 'Total Qty',
                value: '$totalQty',
                icon: Icons.stacked_line_chart_outlined,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _SummaryCard(
                title: 'Total Transactions',
                value: '$totalTx',
                icon: Icons.receipt_long_outlined,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _SummaryCard extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;
  final bool expandToFullWidth;

  const _SummaryCard({
    required this.title,
    required this.value,
    required this.icon,
    this.expandToFullWidth = false,
  });

  const _SummaryCard.fullWidth({
    required this.title,
    required this.value,
    required this.icon,
  }) : expandToFullWidth = true;

  @override
  Widget build(BuildContext context) {
    final card = Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Row(
        children: [
          Container(
            decoration: BoxDecoration(
              color: const Color(0xFFEFF6FF),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFDBEAFE)),
            ),
            padding: const EdgeInsets.all(10),
            child: Icon(icon, color: const Color(0xFF1D4ED8)),
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
                    fontSize: 12,
                    color: Color(0xFF94A3B8),
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  value,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF0F172A),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );

    if (expandToFullWidth) {
      return SizedBox(width: double.infinity, child: card);
    }
    return card;
  }
}

/// =============================
/// AGGREGATION (Pie & Top 5)
/// =============================

class _Agg {
  final String key;
  final String displayName;
  final double value;

  const _Agg({
    required this.key,
    required this.displayName,
    required this.value,
  });

  _Agg copyWith({String? key, String? displayName, double? value}) => _Agg(
    key: key ?? this.key,
    displayName: displayName ?? this.displayName,
    value: value ?? this.value,
  );
}

Map<String, _Agg> _buildAggFrom(List<dynamic> items, ReportTarget target) {
  final isPeriod = target == ReportTarget.period;
  final map = <String, _Agg>{};

  for (final raw in items) {
    if (isPeriod) {
      if (raw is! PeriodSeriesItem) continue;
      final key = raw.period.trim();
      final value = (raw.totalRevenue ?? 0).toDouble();
      if (key.isEmpty || value == 0) continue;
      map.update(
        key,
        (a) => a.copyWith(value: a.value + value),
        ifAbsent: () => _Agg(key: key, displayName: key, value: value),
      );
    } else {
      if (raw is! EntityReportItem) continue;
      final label = (raw.label ?? '').trim();
      final sku = (raw.sku ?? '').trim();
      final key = sku.isNotEmpty ? sku : label; // group by SKU
      final value = (raw.totalRevenue ?? 0).toDouble();
      if (key.isEmpty || value == 0) continue;

      map.update(
        key,
        (a) => a.copyWith(
          value: a.value + value,
          displayName: a.displayName.isEmpty ? label : a.displayName,
        ),
        ifAbsent: () => _Agg(key: key, displayName: label, value: value),
      );
    }
  }
  return map;
}

class _DistributionAndTop extends StatelessWidget {
  final List<dynamic> items;
  final ReportTarget target;
  final NumberFormat currency;
  final String customerLikeLabel;

  const _DistributionAndTop({
    required this.items,
    required this.target,
    required this.currency,
    required this.customerLikeLabel,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isWide = constraints.maxWidth >= 900;

        if (isWide) {
          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                flex: 3,
                child: _ReportPieChart(
                  items: items,
                  target: target,
                  currency: currency,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                flex: 2,
                child: _TopFiveSection(
                  items: items,
                  target: target,
                  currency: currency,
                  customerLikeLabel: customerLikeLabel,
                ),
              ),
            ],
          );
        }

        return Column(
          children: [
            _ReportPieChart(items: items, target: target, currency: currency),
            const SizedBox(height: 16),
            _TopFiveSection(
              items: items,
              target: target,
              currency: currency,
              customerLikeLabel: customerLikeLabel,
            ),
          ],
        );
      },
    );
  }
}

class _ReportPieChart extends StatelessWidget {
  final List<dynamic> items;
  final ReportTarget target;
  final NumberFormat currency;

  const _ReportPieChart({
    required this.items,
    required this.target,
    required this.currency,
  });

  List<Color> get _paletteTop3 => const [
    Color(0xFF2563EB),
    Color(0xFF8B5CF6),
    Color(0xFF10B981),
  ];

  Color get _othersColor => const Color(0xFFE5E7EB);

  @override
  Widget build(BuildContext context) {
    final merged = _buildAggFrom(items, target);
    final entries = merged.values.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    final totalAll = entries.fold<double>(0, (p, e) => p + e.value);
    if (entries.isEmpty || totalAll <= 0) {
      return _Section(
        title: 'Purchase Distribution',
        child: SizedBox(
          height: 260,
          child: Center(
            child: Text(
              'No data to visualize',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ),
        ),
      );
    }

    final top = entries.take(3).toList();
    final othersSum = entries.skip(3).fold<double>(0, (p, e) => p + e.value);
    if (othersSum > 0) {
      top.add(_Agg(key: 'others', displayName: 'Others', value: othersSum));
    }

    final total = top.fold<double>(0, (p, e) => p + e.value);

    final sections = <PieChartSectionData>[];
    for (int i = 0; i < top.length; i++) {
      final e = top[i];
      final pct = total == 0 ? 0 : (e.value / total) * 100;

      final isOthers = e.key == 'others';
      final color = isOthers
          ? _othersColor
          : _paletteTop3[i % _paletteTop3.length];

      final showLabel = pct >= 3.0;
      final whiteText = !isOthers && pct >= 10.0;

      sections.add(
        PieChartSectionData(
          color: color,
          value: e.value,
          title: showLabel ? '${pct.toStringAsFixed(1)}%' : '',
          radius: 92,
          showTitle: showLabel,
          titleStyle: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w800,
            color: whiteText ? Colors.white : const Color(0xFF0F172A),
          ),
        ),
      );
    }

    Widget legend() => Wrap(
      spacing: 10,
      runSpacing: 8,
      children: [
        for (int i = 0; i < top.length; i++)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFF),
              borderRadius: BorderRadius.circular(999),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 10,
                  height: 10,
                  decoration: BoxDecoration(
                    color: top[i].key == 'others'
                        ? _othersColor
                        : _paletteTop3[i % _paletteTop3.length],
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  '${top[i].displayName} • ${currency.format(top[i].value)}',
                  style: const TextStyle(
                    fontSize: 12,
                    color: Color(0xFF0F172A),
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
      ],
    );

    return _Section(
      title: 'Purchase Distribution',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            height: 260,
            child: PieChart(
              PieChartData(
                sections: sections,
                sectionsSpace: 0,
                centerSpaceRadius: 48,
                centerSpaceColor: Colors.white,
                startDegreeOffset: -90,
              ),
            ),
          ),
          const SizedBox(height: 12),
          legend(),
        ],
      ),
    );
  }
}

/// TOP 5

class _TopFiveSection extends StatelessWidget {
  final List<dynamic> items;
  final ReportTarget target;
  final NumberFormat currency;
  final String customerLikeLabel;

  const _TopFiveSection({
    required this.items,
    required this.target,
    required this.currency,
    required this.customerLikeLabel,
  });

  String _title() {
    switch (target) {
      case ReportTarget.customer:
        return 'Top 5 $customerLikeLabel';
      case ReportTarget.product:
        return 'Top 5 Products';
      case ReportTarget.category:
        return 'Top 5 Categories';
      case ReportTarget.brand:
        return 'Top 5 Brands';
      case ReportTarget.period:
        return 'Top 5 Periods';
    }
  }

  @override
  Widget build(BuildContext context) {
    final agg = _buildAggFrom(items, target);
    final all = agg.values.toList()..sort((a, b) => b.value.compareTo(a.value));

    if (all.isEmpty) {
      return _Section(
        title: _title(),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 16),
          child: Center(
            child: Text(
              'Belum ada data',
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(color: const Color(0xFF9CA3AF)),
            ),
          ),
        ),
      );
    }

    final top = all.take(5).toList();
    final total = all.fold<double>(0, (p, e) => p + e.value);

    return _Section(
      title: _title(),
      child: Column(
        children: [
          for (int i = 0; i < top.length; i++)
            Padding(
              padding: EdgeInsets.only(top: i == 0 ? 0 : 8),
              child: _TopFiveRow(
                rank: i + 1,
                name: top[i].displayName,
                valueText: currency.format(top[i].value),
                percentage: total == 0 ? 0 : (top[i].value / total * 100.0),
              ),
            ),
        ],
      ),
    );
  }
}

class _TopFiveRow extends StatelessWidget {
  final int rank;
  final String name;
  final String valueText;
  final double percentage;

  const _TopFiveRow({
    required this.rank,
    required this.name,
    required this.valueText,
    required this.percentage,
  });

  @override
  Widget build(BuildContext context) {
    final isTop1 = rank == 1;
    final badgeColor = isTop1
        ? const Color(0xFF1D4ED8)
        : const Color(0xFFE5E7EB);
    final badgeTextColor = isTop1 ? Colors.white : const Color(0xFF111827);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFFF9FAFB),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 14,
            backgroundColor: badgeColor,
            child: Text(
              '$rank',
              style: TextStyle(
                color: badgeTextColor,
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name.isEmpty ? 'Unnamed' : name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF111827),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '${percentage.toStringAsFixed(1)}% of purchase',
                  style: const TextStyle(
                    fontSize: 11,
                    color: Color(0xFF6B7280),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Text(
            valueText,
            textAlign: TextAlign.right,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: Color(0xFF111827),
            ),
          ),
        ],
      ),
    );
  }
}

/// =============================
/// SECTION + TABLE + SORT
/// =============================

class _Section extends StatelessWidget {
  final String title;
  final Widget child;
  const _Section({required this.title, required this.child});

  @override
  Widget build(BuildContext context) {
    return Card(
      color: Colors.white,
      elevation: 0.5,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              title,
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 8),
            child,
          ],
        ),
      ),
    );
  }
}

class _ReportDataTable extends StatelessWidget {
  final List<dynamic> items;
  final ReportTarget target;
  final NumberFormat currency;
  final String customerLikeLabel;

  const _ReportDataTable({
    required this.items,
    required this.target,
    required this.currency,
    required this.customerLikeLabel,
  });

  String _sectionTitle() {
    switch (target) {
      case ReportTarget.customer:
        return 'Details by $customerLikeLabel';
      case ReportTarget.product:
        return 'Details by Product';
      case ReportTarget.category:
        return 'Details by Category';
      case ReportTarget.brand:
        return 'Details by Brand';
      case ReportTarget.period:
        return 'Details by Period';
    }
  }

  @override
  Widget build(BuildContext context) {
    return _Section(
      title: _sectionTitle(),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: target == ReportTarget.period
            ? _buildPeriodTable(context)
            : _buildEntityTable(context),
      ),
    );
  }

  Widget _buildEntityTable(BuildContext context) {
    final list = items.whereType<EntityReportItem>().toList();
    return DataTable(
      columnSpacing: 24,
      headingTextStyle: const TextStyle(
        fontWeight: FontWeight.w800,
        color: Color(0xFF0F172A),
      ),
      headingRowColor: MaterialStateProperty.resolveWith(
        (states) => const Color(0xFFF9FAFB),
      ),
      dataRowColor: MaterialStateProperty.resolveWith((states) => Colors.white),
      columns: [
        DataColumn(
          label: Text(customerLikeLabel == 'Supplier' ? 'Supplier' : 'Name'),
        ),
        const DataColumn(label: Text('Qty')),
        const DataColumn(label: Text('Revenue')),
        const DataColumn(label: Text('Avg/Tx')),
      ],
      rows: [
        for (final it in list)
          DataRow(
            cells: [
              DataCell(
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      it.label,
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                    if ((it.sku ?? '').isNotEmpty)
                      Text(
                        'SKU: ${it.sku}',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    if ((it.phone ?? '').isNotEmpty)
                      Text(
                        'Phone: ${it.phone}',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                  ],
                ),
              ),
              DataCell(Text('${it.totalQty}')),
              DataCell(
                Text(it.revenueFormatted ?? currency.format(it.totalRevenue)),
              ),
              DataCell(
                Text(
                  it.avgTransactionFormatted ??
                      (it.avgTransaction == null
                          ? '-'
                          : currency.format(it.avgTransaction)),
                ),
              ),
            ],
          ),
      ],
    );
  }

  Widget _buildPeriodTable(BuildContext context) {
    final list = items.whereType<PeriodSeriesItem>().toList();
    return DataTable(
      columnSpacing: 24,
      headingTextStyle: const TextStyle(
        fontWeight: FontWeight.w800,
        color: Color(0xFF0F172A),
      ),
      headingRowColor: MaterialStateProperty.resolveWith(
        (states) => const Color(0xFFF9FAFB),
      ),
      dataRowColor: MaterialStateProperty.resolveWith((states) => Colors.white),
      columns: const [
        DataColumn(label: Text('Period')),
        DataColumn(label: Text('Transactions')),
        DataColumn(label: Text('Qty')),
        DataColumn(label: Text('Revenue')),
      ],
      rows: [
        for (final it in list)
          DataRow(
            cells: [
              DataCell(Text(it.period)),
              DataCell(Text('${it.totalTransactions}')),
              DataCell(Text('${it.totalQty}')),
              DataCell(
                Text(it.revenueFormatted ?? currency.format(it.totalRevenue)),
              ),
            ],
          ),
      ],
    );
  }
}

class _SortBar extends StatelessWidget {
  final ReportTarget target;
  final String sortKey;
  final bool sortDesc;
  final void Function(String key, bool desc) onChange;

  const _SortBar({
    required this.target,
    required this.sortKey,
    required this.sortDesc,
    required this.onChange,
  });

  @override
  Widget build(BuildContext context) {
    final keys = target == ReportTarget.period
        ? <String, String>{
            'period': 'Period',
            'tx': 'Transactions',
            'qty': 'Qty',
            'revenue': 'Revenue',
          }
        : <String, String>{
            'label': 'Name',
            'tx': 'Transactions',
            'qty': 'Qty',
            'revenue': 'Revenue',
          };

    return Row(
      children: [
        const Text('Sort:', style: TextStyle(color: Color(0xFF334155))),
        const SizedBox(width: 8),
        Expanded(
          child: _FancyDropdown<String>(
            value: sortKey,
            items: keys.entries
                .map(
                  (e) => DropdownMenuItem<String>(
                    value: e.key,
                    child: Text(e.value),
                  ),
                )
                .toList(),
            onChanged: (v) => v != null ? onChange(v, sortDesc) : null,
            icon: Icons.sort_outlined,
          ),
        ),
        const SizedBox(width: 8),
        IconButton(
          tooltip: sortDesc ? 'Descending' : 'Ascending',
          onPressed: () => onChange(sortKey, !sortDesc),
          icon: Icon(sortDesc ? Icons.south : Icons.north),
        ),
      ],
    );
  }
}

/// =============================
/// SHIMMER
/// =============================

class _Shimmer extends StatefulWidget {
  final Widget child;
  const _Shimmer({required this.child});

  @override
  State<_Shimmer> createState() => _ShimmerState();
}

class _ShimmerState extends State<_Shimmer>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1400),
  )..repeat();

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
        final v = _c.value;
        final begin = Alignment(-1.0 + 2.0 * v, 0.0);
        final end = Alignment(1.0 + 2.0 * v, 0.0);

        return ShaderMask(
          shaderCallback: (rect) {
            return LinearGradient(
              begin: begin,
              end: end,
              colors: const [
                Color(0xFFEFF1F5),
                Color(0xFFF7F8FA),
                Color(0xFFEFF1F5),
              ],
              stops: const [0.1, 0.5, 0.9],
            ).createShader(rect);
          },
          blendMode: BlendMode.srcATop,
          child: widget.child,
        );
      },
    );
  }
}

class _ShimmerBox extends StatelessWidget {
  final double height;
  final double? width;
  final double radius;
  const _ShimmerBox({required this.height, this.width, this.radius = 12});

  @override
  Widget build(BuildContext context) {
    return _Shimmer(
      child: Container(
        height: height,
        width: width,
        decoration: BoxDecoration(
          color: const Color(0xFFE5E7EB),
          borderRadius: BorderRadius.circular(radius),
        ),
      ),
    );
  }
}

class _SummaryStripShimmer extends StatelessWidget {
  const _SummaryStripShimmer({super.key});
  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // revenue full width
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFFE2E8F0)),
          ),
          child: const _ShimmerBox(height: 28, width: double.infinity),
        ),
        const SizedBox(height: 12),
        Row(
          children: const [
            Expanded(child: _CardSkeleton()),
            SizedBox(width: 12),
            Expanded(child: _CardSkeleton()),
          ],
        ),
      ],
    );
  }
}

class _CardSkeleton extends StatelessWidget {
  const _CardSkeleton({super.key});
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: const [
          _ShimmerBox(height: 12, width: 90),
          SizedBox(height: 10),
          _ShimmerBox(height: 22, width: 140),
        ],
      ),
    );
  }
}

class _PieShimmer extends StatelessWidget {
  const _PieShimmer({super.key});
  @override
  Widget build(BuildContext context) {
    return _Section(
      title: 'Purchase Distribution',
      child: Column(
        children: [
          const SizedBox(height: 8),
          Center(
            child: _Shimmer(
              child: Container(
                width: 220,
                height: 220,
                decoration: const BoxDecoration(
                  color: Color(0xFFE5E7EB),
                  shape: BoxShape.circle,
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 10,
            runSpacing: 8,
            children: const [
              _ShimmerBox(height: 20, width: 160, radius: 999),
              _ShimmerBox(height: 20, width: 140, radius: 999),
              _ShimmerBox(height: 20, width: 120, radius: 999),
            ],
          ),
        ],
      ),
    );
  }
}

class _TableShimmer extends StatelessWidget {
  const _TableShimmer({super.key});
  @override
  Widget build(BuildContext context) {
    return _Section(
      title: 'Details',
      child: Column(
        children: List.generate(
          6,
          (i) => Padding(
            padding: EdgeInsets.only(top: i == 0 ? 0 : 8),
            child: Row(
              children: const [
                Expanded(child: _ShimmerBox(height: 18, radius: 6)),
                SizedBox(width: 12),
                _ShimmerBox(height: 18, width: 60, radius: 6),
                SizedBox(width: 12),
                _ShimmerBox(height: 18, width: 100, radius: 6),
                SizedBox(width: 12),
                _ShimmerBox(height: 18, width: 100, radius: 6),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
