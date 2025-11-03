// lib/screens/report_dashboard_screen.dart
// Report dashboard terintegrasi ReportProvider untuk Sales (pemasukan) & Purchase (pengeluaran).
// - 2 Tab: Sales, Purchase
// - Period chips: 1 Hari / 1 Bulan / 1 Tahun
// - Summary: Total Qty + Total Sales/Spending (purchase tampil negatif)
// - Top 3 by Qty (donut) + legend
// - Top 3 by Sales/Purchase (donut) + legend
// - Insights (ASP, SKU count, avg qty/SKU, Top3 share qty & revenue)
// - Unit Price Ranking (Top 5 tertinggi & terendah)
// - Top 10 table (toggle sort revenue/qty)

import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

// ==== sesuaikan path ini dengan proyekmu
import 'package:wa_blast/constants/app_colors.dart';
import 'package:wa_blast/providers/report_provider.dart';
// ======================================

// ==== Extension helper untuk menghitung unit price per SKU ====
// Pastikan field yang dipakai sesuai dengan SalesReportItem di provider-mu:
// - productSku : String
// - productName: String
// - totalQty   : int
// - totalRevenue: num
extension SalesReportItemX on SalesReportItem {
  double get unitPrice {
    final qty = (totalQty is int) ? totalQty : int.tryParse('$totalQty') ?? 0;
    final rev = (totalRevenue is num)
        ? totalRevenue
        : num.tryParse('$totalRevenue') ?? 0;
    if (qty == 0) return 0.0;
    // Kembalikan nilai positif; tanda minus akan ditangani format UI untuk Purchase.
    return (rev / qty).toDouble();
  }
}

class ReportDashboardScreen extends StatefulWidget {
  const ReportDashboardScreen({super.key});

  @override
  State<ReportDashboardScreen> createState() => _ReportDashboardScreenState();
}

class _ReportDashboardScreenState extends State<ReportDashboardScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabc;

  @override
  void initState() {
    super.initState();
    _tabc = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabc.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => ReportProvider(),
      child: Builder(
        builder: (context) {
          final prov = context.read<ReportProvider>();
          return Scaffold(
            backgroundColor: AppColors.white,
            appBar: AppBar(
              elevation: 0,
              backgroundColor: AppColors.white,
              centerTitle: false,
              titleSpacing: 16,
              title: const Text(
                'Report',
                style: TextStyle(
                  color: AppColors.textPrimary,
                  fontWeight: FontWeight.w800,
                  fontSize: 20,
                  letterSpacing: .2,
                ),
              ),
              bottom: TabBar(
                controller: _tabc,
                labelColor: AppColors.textPrimary,
                unselectedLabelColor: AppColors.textSecondary,
                indicatorColor: AppColors.success,
                onTap: (i) async {
                  final kind = i == 0 ? ReportKind.sales : ReportKind.purchase;
                  prov.setKind(kind);
                  if (prov.itemsOf(kind).isEmpty && !prov.isLoadingOf(kind)) {
                    await prov.fetch(context, kind: kind);
                    final err = prov.consumeLastError(forKind: kind);
                    if (err != null && context.mounted) {
                      ScaffoldMessenger.of(
                        context,
                      ).showSnackBar(SnackBar(content: Text(err)));
                    }
                  }
                },
                tabs: const [
                  Tab(text: 'Sales'),
                  Tab(text: 'Purchase'),
                ],
              ),
            ),
            body: TabBarView(
              controller: _tabc,
              children: const [
                _ReportTab(kind: ReportKind.sales),
                _ReportTab(kind: ReportKind.purchase),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _ReportTab extends StatefulWidget {
  final ReportKind kind;
  const _ReportTab({required this.kind});

  @override
  State<_ReportTab> createState() => _ReportTabState();
}

class _ReportTabState extends State<_ReportTab> {
  final _money = NumberFormat.currency(
    locale: 'id_ID',
    symbol: 'Rp ',
    decimalDigits: 0,
  );
  final _num = NumberFormat.decimalPattern('id_ID');
  final _searchC = TextEditingController();

  bool _topByMoney = true; // toggle sort Top 10

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final prov = context.read<ReportProvider>();
      prov.setKind(widget.kind, notify: false);
      if (prov.itemsOf(widget.kind).isEmpty) {
        await prov.fetch(context, kind: widget.kind);
        final err = prov.consumeLastError(forKind: widget.kind);
        if (err != null && context.mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text(err)));
        }
      }
    });
  }

  @override
  void dispose() {
    _searchC.dispose();
    super.dispose();
  }

  Future<void> _onRefresh() async {
    await context.read<ReportProvider>().fetch(context, kind: widget.kind);
    final err = context.read<ReportProvider>().consumeLastError(
      forKind: widget.kind,
    );
    if (err != null && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(err)));
    }
  }

  @override
  Widget build(BuildContext context) {
    final prov = context.watch<ReportProvider>();
    final isWide = MediaQuery.of(context).size.width >= 760;

    final isLoading = prov.isLoadingOf(widget.kind);
    final period = prov.periodOf(widget.kind);
    final range = prov.rangeOf(widget.kind);
    final summary = prov.summaryOf(widget.kind);

    final isSales = widget.kind == ReportKind.sales;
    final moneyWord = isSales ? 'Sales' : 'Purchase';
    final moneyWordLong = isSales ? 'Total Sales' : 'Total Spending';
    final accent = isSales
        ? AppColors.success
        : const Color(0xFFF04438); // merah untuk spending

    final filtered = prov.filteredByQuery(_searchC.text, forKind: widget.kind);

    // === Top 3 by qty
    final itemsByQty = [...filtered]
      ..sort((a, b) => b.totalQty.compareTo(a.totalQty));
    final top3Qty = itemsByQty.take(3).toList();
    final totalQtyTop3 = top3Qty.fold<int>(0, (a, e) => a + e.totalQty);
    final totalQtyAll = filtered.fold<int>(0, (a, e) => a + e.totalQty);
    final othersQty = math.max(0, totalQtyAll - totalQtyTop3);

    // === Top 3 by money
    final itemsByMoney = [...filtered]
      ..sort((a, b) => b.totalRevenue.compareTo(a.totalRevenue));
    final top3Money = itemsByMoney.take(3).toList();
    final totalMoneyTop3 = top3Money.fold<num>(0, (a, e) => a + e.totalRevenue);
    final totalMoneyAll = filtered.fold<num>(0, (a, e) => a + e.totalRevenue);
    final othersMoney = math.max(
      0,
      (totalMoneyAll - totalMoneyTop3).toDouble(),
    );

    // === Top 10 table items
    final itemsForTable = [...filtered]
      ..sort(
        (a, b) => _topByMoney
            ? b.totalRevenue.compareTo(a.totalRevenue)
            : b.totalQty.compareTo(a.totalQty),
      );
    final top10 = itemsForTable.take(10).toList();

    // === INSIGHTS (pakai helper di bawah)
    final insights = _ReportInsights.compute(
      items: filtered,
      summaryQty: summary?.totalQty ?? 0,
      summaryRevenue: summary?.totalRevenue ?? 0,
    );

    String rangeLabel() {
      if (range?.startDate == null || range?.endDate == null)
        return period.label;
      final d = DateFormat('dd MMM yyyy', 'id_ID');
      return '${d.format(range!.startDate!)} — ${d.format(range!.endDate!)}';
    }

    String moneyDisplay(num v, {String? preformatted}) {
      // Sales: normal; Purchase: tampil sebagai pengeluaran "− Rp x"
      if (preformatted != null && preformatted.isNotEmpty) {
        return isSales ? preformatted : '− $preformatted';
      }
      final f = _money.format(v);
      return isSales ? f : '− $f';
    }

    return RefreshIndicator(
      onRefresh: _onRefresh,
      child: ListView(
        padding: EdgeInsets.symmetric(
          horizontal: isWide ? 24 : 16,
          vertical: 16,
        ),
        children: [
          _PeriodChips(
            current: period,
            accent: accent,
            onTap: (p) async {
              prov.setKind(widget.kind);
              prov.setPeriod(p, forKind: widget.kind);
              await prov.fetch(context, kind: widget.kind);
              final err = prov.consumeLastError(forKind: widget.kind);
              if (err != null && context.mounted) {
                ScaffoldMessenger.of(
                  context,
                ).showSnackBar(SnackBar(content: Text(err)));
              }
            },
          ),
          const SizedBox(height: 8),

          Row(
            children: [
              Icon(Icons.date_range, size: 18, color: accent),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  rangeLabel(),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: AppColors.textSecondary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          if (summary != null)
            _SummaryStrip(
              money: _money,
              numf: _num,
              totalQty: summary.totalQty,
              totalMoney: summary.totalRevenue,
              totalMoneyLabel: summary.totalRevenueFormatted,
              moneyTitle: moneyWordLong,
              isSales: isSales,
              accent: accent,
            ),

          const SizedBox(height: 12),

          _SearchBox(
            controller: _searchC,
            onChanged: (_) => setState(() {}),
            hint: 'Cari SKU / Nama produk…',
          ),

          const SizedBox(height: 14),

          // ==== Top 3 by Qty — PIE ATAS, LEGEND BAWAH
          _Top3WithPieQty(
            isLoading: isLoading,
            top3: top3Qty,
            othersQty: othersQty,
            numf: _num,
            accent: accent,
          ),

          const SizedBox(height: 14),

          // ==== Top 3 by Sales/Purchase — PIE ATAS, LEGEND BAWAH
          _Top3WithPieMoney(
            isLoading: isLoading,
            title: 'Top 3 SKU (by $moneyWord)',
            top3: top3Money,
            othersMoney: othersMoney.toDouble(),
            money: _money,
            isSales: isSales,
            accent: accent,
          ),

          // const SizedBox(height: 14),

          // // ==== Insights
          // _CardShell(
          //   title: 'Insights',
          //   action: const SizedBox(),
          //   child: Column(
          //     children: [
          //       _InsightRow(
          //         icon: Icons.attach_money_rounded,
          //         label: 'ASP (Average Selling Price)',
          //         value: _money.format(insights.asp),
          //         accent: accent,
          //       ),
          //       const SizedBox(height: 8),
          //       _InsightRow(
          //         icon: Icons.inventory_2_rounded,
          //         label: 'Jumlah SKU',
          //         value: _num.format(insights.skuCount),
          //         accent: accent,
          //       ),
          //       const SizedBox(height: 8),
          //       _InsightRow(
          //         icon: Icons.format_list_numbered_rounded,
          //         label: 'Rata-rata Qty / SKU',
          //         value: _num.format(insights.avgQtyPerSku),
          //         accent: accent,
          //       ),
          //       const SizedBox(height: 8),
          //       _InsightRow(
          //         icon: Icons.pie_chart_rounded,
          //         label: 'Top 3 Revenue Share',
          //         value: '${_num.format(insights.top3RevenueShare)}%',
          //         accent: accent,
          //       ),
          //       const SizedBox(height: 8),
          //       _InsightRow(
          //         icon: Icons.donut_large_rounded,
          //         label: 'Top 3 Qty Share',
          //         value: '${_num.format(insights.top3QtyShare)}%',
          //         accent: accent,
          //       ),
          //     ],
          //   ),
          // ),
          const SizedBox(height: 14),

          // ==== Unit Price Ranking (Top 5 tertinggi & terendah)
          _CardShell(
            title: 'Unit Price Ranking',
            action: const SizedBox(),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text(
                  'Top 5 Unit Price Tertinggi',
                  style: TextStyle(
                    color: AppColors.textSecondary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 8),
                _SimpleList(
                  rows: [
                    for (final e in insights.top5UnitPriceHigh)
                      _SimpleRow(
                        title: '${e.productName} (${e.productSku})',
                        right: moneyDisplay(e.unitPrice),
                      ),
                  ],
                ),
                const SizedBox(height: 12),
                const Text(
                  'Top 5 Unit Price Terendah',
                  style: TextStyle(
                    color: AppColors.textSecondary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 8),
                _SimpleList(
                  rows: [
                    for (final e in insights.top5UnitPriceLow)
                      _SimpleRow(
                        title: '${e.productName} (${e.productSku})',
                        right: moneyDisplay(e.unitPrice),
                      ),
                  ],
                ),
              ],
            ),
          ),

          const SizedBox(height: 14),

          // ==== Top 10 Table
          _Top10Table(
            isLoading: isLoading,
            items: top10,
            moneyFormatter: (e) =>
                moneyDisplay(e.totalRevenue, preformatted: e.revenueFormatted),
            numf: _num,
            topByMoney: _topByMoney,
            moneyWord: moneyWord,
            onToggleSort: () => setState(() => _topByMoney = !_topByMoney),
            isSales: isSales,
            accent: accent,
          ),
        ],
      ),
    );
  }
}

/// =================== FUNGSI PENGOLAHAN DATA ===================

class _ReportInsights {
  final double asp;
  final int skuCount;
  final double avgQtyPerSku;
  final double top3RevenueShare;
  final double top3QtyShare;
  final List<SalesReportItem> top5UnitPriceHigh;
  final List<SalesReportItem> top5UnitPriceLow;

  _ReportInsights({
    required this.asp,
    required this.skuCount,
    required this.avgQtyPerSku,
    required this.top3RevenueShare,
    required this.top3QtyShare,
    required this.top5UnitPriceHigh,
    required this.top5UnitPriceLow,
  });

  static _ReportInsights compute({
    required List<SalesReportItem> items,
    required int summaryQty,
    required num summaryRevenue,
  }) {
    // ASP
    final asp = summaryQty == 0 ? 0 : (summaryRevenue / summaryQty).toDouble();

    // SKU count & avg qty/SKU
    final skuCount = items.length;
    final totalQtyAll = items.fold<int>(0, (a, e) => a + e.totalQty);
    final avgQtyPerSku = skuCount == 0 ? 0 : totalQtyAll / skuCount;

    // Top3 shares
    final byMoney = [...items]
      ..sort((a, b) => b.totalRevenue.compareTo(a.totalRevenue));
    final top3Money = byMoney.take(3).toList();
    final totalMoneyTop3 = top3Money.fold<num>(0, (a, e) => a + e.totalRevenue);
    final totalMoneyAll = items.fold<num>(0, (a, e) => a + e.totalRevenue);
    final top3RevenueShare = totalMoneyAll == 0
        ? 0
        : (totalMoneyTop3 / totalMoneyAll) * 100.0;

    final byQty = [...items]..sort((a, b) => b.totalQty.compareTo(a.totalQty));
    final top3Qty = byQty.take(3).toList();
    final totalQtyTop3 = top3Qty.fold<int>(0, (a, e) => a + e.totalQty);
    final top3QtyShare = totalQtyAll == 0
        ? 0
        : (totalQtyTop3 / totalQtyAll) * 100.0;

    // Unit price ranking
    final withUnit = [...items]..removeWhere((e) => e.totalQty == 0);
    withUnit.sort((a, b) => (b.unitPrice).compareTo(a.unitPrice));
    final high = withUnit.take(5).toList();
    final low = (withUnit.length <= 5)
        ? withUnit.reversed.toList()
        : withUnit.sublist(withUnit.length - 5);

    return _ReportInsights(
      asp: asp.toDouble(),
      skuCount: skuCount,
      avgQtyPerSku: avgQtyPerSku.toDouble(),
      top3RevenueShare: top3RevenueShare.toDouble(),
      top3QtyShare: top3QtyShare.toDouble(),
      top5UnitPriceHigh: high,
      top5UnitPriceLow: low,
    );
  }
}

/// =================== Widgets ===================

class _PeriodChips extends StatelessWidget {
  final SalesPeriod current;
  final void Function(SalesPeriod) onTap;
  final Color accent;

  const _PeriodChips({
    required this.current,
    required this.onTap,
    required this.accent,
  });

  @override
  Widget build(BuildContext context) {
    Widget chip(String label, SalesPeriod p) => ChoiceChip(
      label: Text(label),
      selected: current == p,
      onSelected: (_) => onTap(p),
      selectedColor: accent.withOpacity(.15),
      backgroundColor: AppColors.greyBackground,
      labelStyle: TextStyle(
        color: current == p ? AppColors.textPrimary : AppColors.textSecondary,
        fontWeight: current == p ? FontWeight.w700 : FontWeight.w500,
      ),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      side: BorderSide(color: current == p ? accent : AppColors.border),
      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
      visualDensity: VisualDensity.compact,
    );

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        chip('1 Hari', SalesPeriod.daily),
        chip('1 Bulan', SalesPeriod.month),
        chip('1 Tahun', SalesPeriod.year),
      ],
    );
  }
}

class _SummaryStrip extends StatelessWidget {
  final NumberFormat money;
  final NumberFormat numf;
  final int totalQty;
  final num totalMoney;
  final String? totalMoneyLabel;
  final String moneyTitle; // "Total Sales" / "Total Spending"
  final bool isSales;
  final Color accent;

  const _SummaryStrip({
    required this.money,
    required this.numf,
    required this.totalQty,
    required this.totalMoney,
    required this.totalMoneyLabel,
    required this.moneyTitle,
    required this.isSales,
    required this.accent,
  });

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    final isWide = width >= 520;
    final String moneyText = (totalMoneyLabel?.isNotEmpty ?? false)
        ? (isSales ? totalMoneyLabel! : '− ${totalMoneyLabel!}')
        : (isSales
              ? money.format(totalMoney)
              : '− ${money.format(totalMoney)}');

    final kpis = <Widget>[
      _KPIBlock(
        icon: Icons.inventory_2_rounded,
        title: 'Total Qty',
        value: numf.format(totalQty),
        accent: accent,
        valueColor: AppColors.textPrimary,
      ),
      _KPIBlock(
        icon: isSales ? Icons.trending_up_rounded : Icons.trending_down_rounded,
        title: moneyTitle,
        value: moneyText,
        accent: accent,
        valueColor: isSales
            ? AppColors.textPrimary
            : const Color(0xFFB42318), // merah gelap utk spending
      ),
    ];

    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.divider),
      ),
      child: isWide
          ? Row(
              children: [
                Expanded(child: kpis[0]),
                const SizedBox(width: 10),
                Expanded(child: kpis[1]),
              ],
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [kpis[0], const SizedBox(height: 10), kpis[1]],
            ),
    );
  }
}

class _KPIBlock extends StatelessWidget {
  final IconData icon;
  final String title;
  final String value;
  final Color accent;
  final Color valueColor;

  const _KPIBlock({
    required this.icon,
    required this.title,
    required this.value,
    required this.accent,
    required this.valueColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 10),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.divider),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: accent.withOpacity(.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: accent, size: 18),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: valueColor,
                    fontSize: 15.5,
                    fontWeight: FontWeight.w800,
                    letterSpacing: .2,
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

class _SearchBox extends StatelessWidget {
  final TextEditingController controller;
  final ValueChanged<String> onChanged;
  final String hint;

  const _SearchBox({
    required this.controller,
    required this.onChanged,
    required this.hint,
  });

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      onChanged: onChanged,
      decoration: InputDecoration(
        hintText: hint,
        prefixIcon: const Icon(Icons.search, size: 20),
        contentPadding: const EdgeInsets.symmetric(
          vertical: 10,
          horizontal: 12,
        ),
        border: OutlineInputBorder(
          borderSide: const BorderSide(color: AppColors.border),
          borderRadius: BorderRadius.circular(10),
        ),
        enabledBorder: OutlineInputBorder(
          borderSide: const BorderSide(color: AppColors.border),
          borderRadius: BorderRadius.circular(10),
        ),
      ),
    );
  }
}

/// =================== Top 3 by Qty + Pie (stacked) ===================

class _Top3WithPieQty extends StatelessWidget {
  final bool isLoading;
  final List<SalesReportItem> top3;
  final int othersQty;
  final NumberFormat numf;
  final Color accent;

  const _Top3WithPieQty({
    required this.isLoading,
    required this.top3,
    required this.othersQty,
    required this.numf,
    required this.accent,
  });

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return const _CardShell(
        title: 'Top 3 SKU (by Qty)',
        action: SizedBox(),
        child: _SkeletonTop3(),
      );
    }

    final segments = <_PieSegment>[
      for (int i = 0; i < top3.length; i++)
        _PieSegment(value: top3[i].totalQty.toDouble(), colorIndex: i),
      if (othersQty > 0)
        _PieSegment(value: othersQty.toDouble(), colorIndex: 3),
      if (top3.isEmpty && othersQty == 0)
        const _PieSegment(value: 1, colorIndex: 3),
    ];

    return _CardShell(
      title: 'Top 3 SKU (by Qty)',
      action: const SizedBox(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Center(
            child: SizedBox(
              width: 168,
              height: 168,
              child: _PieChart(segments: segments),
            ),
          ),
          const SizedBox(height: 10),
          _LegendList(
            children: [
              for (int i = 0; i < top3.length; i++)
                _LegendRow(
                  colorIndex: i,
                  title: '${top3[i].productName} (${top3[i].productSku})',
                  value: '${numf.format(top3[i].totalQty)} pcs',
                ),
              if (othersQty > 0)
                _LegendRow(
                  colorIndex: 3,
                  title: 'Others',
                  value: '${numf.format(othersQty)} pcs',
                ),
            ],
          ),
        ],
      ),
    );
  }
}

/// =================== Top 3 by Sales/Purchase + Pie (stacked) ===================

class _Top3WithPieMoney extends StatelessWidget {
  final bool isLoading;
  final String title;
  final List<SalesReportItem> top3;
  final double othersMoney;
  final NumberFormat money;
  final bool isSales;
  final Color accent;

  const _Top3WithPieMoney({
    required this.isLoading,
    required this.title,
    required this.top3,
    required this.othersMoney,
    required this.money,
    required this.isSales,
    required this.accent,
  });

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return _CardShell(
        title: title,
        action: const SizedBox(),
        child: const _SkeletonTop3(),
      );
    }

    final segments = <_PieSegment>[
      for (int i = 0; i < top3.length; i++)
        _PieSegment(
          value: top3[i].totalRevenue.abs().toDouble(),
          colorIndex: i,
        ),
      if (othersMoney > 0) _PieSegment(value: othersMoney.abs(), colorIndex: 3),
      if (top3.isEmpty && othersMoney <= 0)
        const _PieSegment(value: 1, colorIndex: 3),
    ];

    String fmt(num v) => isSales ? money.format(v) : '− ${money.format(v)}';

    return _CardShell(
      title: title,
      action: const SizedBox(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Center(
            child: SizedBox(
              width: 168,
              height: 168,
              child: _PieChart(segments: segments),
            ),
          ),
          const SizedBox(height: 10),
          _LegendList(
            children: [
              for (int i = 0; i < top3.length; i++)
                _MoneyLegendRow(
                  colorIndex: i,
                  title: '${top3[i].productName} (${top3[i].productSku})',
                  value: fmt(top3[i].totalRevenue),
                ),
              if (othersMoney > 0)
                _MoneyLegendRow(
                  colorIndex: 3,
                  title: 'Others',
                  value: fmt(othersMoney),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _LegendList extends StatelessWidget {
  final List<Widget> children;
  const _LegendList({required this.children});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        for (final c in children)
          Padding(padding: const EdgeInsets.only(bottom: 8), child: c),
      ],
    );
  }
}

class _SkeletonTop3 extends StatelessWidget {
  const _SkeletonTop3();

  @override
  Widget build(BuildContext context) {
    Widget bar({double w = double.infinity}) => Container(
      height: 14,
      width: w,
      decoration: BoxDecoration(
        color: const Color(0xFFF3F4F6),
        borderRadius: BorderRadius.circular(6),
      ),
    );
    return Column(
      children: [
        Container(
          width: 168,
          height: 168,
          decoration: const BoxDecoration(
            color: Color(0xFFF3F4F6),
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(height: 10),
        bar(),
        const SizedBox(height: 8),
        bar(),
        const SizedBox(height: 8),
        bar(),
        const SizedBox(height: 8),
        bar(w: 120),
      ],
    );
  }
}

class _LegendRow extends StatelessWidget {
  final int colorIndex;
  final String title;
  final String value;
  const _LegendRow({
    required this.colorIndex,
    required this.title,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    final color = _pieColor(colorIndex);
    return Row(
      children: [
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: AppColors.textPrimary,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        const SizedBox(width: 8),
        Text(value, style: const TextStyle(color: AppColors.textSecondary)),
      ],
    );
  }
}

class _MoneyLegendRow extends StatelessWidget {
  final int colorIndex;
  final String title;
  final String value;
  const _MoneyLegendRow({
    required this.colorIndex,
    required this.title,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    final color = _pieColor(colorIndex);
    return Row(
      children: [
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: AppColors.textPrimary,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        const SizedBox(width: 8),
        Text(value, style: const TextStyle(color: AppColors.textSecondary)),
      ],
    );
  }
}

/// =================== Top 10 Table ===================

class _Top10Table extends StatelessWidget {
  final bool isLoading;
  final List<SalesReportItem> items;
  final String Function(SalesReportItem) moneyFormatter;
  final NumberFormat numf;
  final bool topByMoney;
  final String moneyWord;
  final VoidCallback onToggleSort;
  final bool isSales;
  final Color accent;

  const _Top10Table({
    required this.isLoading,
    required this.items,
    required this.moneyFormatter,
    required this.numf,
    required this.topByMoney,
    required this.moneyWord,
    required this.onToggleSort,
    required this.isSales,
    required this.accent,
  });

  @override
  Widget build(BuildContext context) {
    return _CardShell(
      title: 'Top 10 ${topByMoney ? "by $moneyWord" : "by Qty"}',
      action: TextButton.icon(
        onPressed: onToggleSort,
        icon: const Icon(Icons.swap_vert, size: 16),
        label: Text(topByMoney ? 'Sort by Qty' : 'Sort by $moneyWord'),
      ),
      child: isLoading
          ? const _SkeletonList()
          : (items.isEmpty
                ? const _EmptyState()
                : _ReportList(
                    items: items,
                    moneyTextOf: moneyFormatter,
                    numf: numf,
                    moneyWord: moneyWord,
                    isSales: isSales,
                    accent: accent,
                  )),
    );
  }
}

class _ReportList extends StatelessWidget {
  final List<SalesReportItem> items;
  final String Function(SalesReportItem) moneyTextOf;
  final NumberFormat numf;
  final String moneyWord;
  final bool isSales;
  final Color accent;

  const _ReportList({
    required this.items,
    required this.moneyTextOf,
    required this.numf,
    required this.moneyWord,
    required this.isSales,
    required this.accent,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.divider),
      ),
      child: ListView.separated(
        itemCount: items.length + 1,
        physics: const NeverScrollableScrollPhysics(),
        shrinkWrap: true,
        separatorBuilder: (_, __) =>
            const Divider(height: 1, color: AppColors.divider),
        itemBuilder: (_, i) {
          if (i == 0) return _HeaderRow(moneyWord: moneyWord);
          final e = items[i - 1];
          return _DataRowTile(
            sku: e.productSku,
            name: e.productName,
            qty: numf.format(e.totalQty),
            moneyText: moneyTextOf(e),
            isSales: isSales,
            accent: accent,
          );
        },
      ),
    );
  }
}

class _HeaderRow extends StatelessWidget {
  final String moneyWord;
  const _HeaderRow({required this.moneyWord});

  @override
  Widget build(BuildContext context) {
    Text _th(String s, {TextAlign align = TextAlign.left}) => Text(
      s,
      textAlign: align,
      style: const TextStyle(
        color: AppColors.textSecondary,
        fontWeight: FontWeight.w700,
        fontSize: 12,
      ),
    );

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
      child: Row(
        children: [
          Expanded(flex: 26, child: _th('SKU')),
          Expanded(flex: 40, child: _th('Nama Produk')),
          Expanded(flex: 14, child: _th('Qty', align: TextAlign.center)),
          Expanded(flex: 20, child: _th(moneyWord, align: TextAlign.right)),
        ],
      ),
    );
  }
}

class _DataRowTile extends StatelessWidget {
  final String sku;
  final String name;
  final String qty;
  final String moneyText;
  final bool isSales;
  final Color accent;

  const _DataRowTile({
    required this.sku,
    required this.name,
    required this.qty,
    required this.moneyText,
    required this.isSales,
    required this.accent,
  });

  @override
  Widget build(BuildContext context) {
    Widget _cellText(
      String s, {
      FontWeight w = FontWeight.w600,
      TextAlign align = TextAlign.left,
      Color c = AppColors.textPrimary,
      int? maxLines = 1,
      TextOverflow overflow = TextOverflow.ellipsis,
      bool softWrap = false,
    }) {
      return Text(
        s,
        maxLines: maxLines,
        softWrap: softWrap,
        overflow: overflow,
        textAlign: align,
        style: TextStyle(color: c, fontSize: 13, fontWeight: w),
      );
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
      child: Row(
        children: [
          // SKU: full wrap
          Expanded(
            flex: 26,
            child: _cellText(
              sku,
              w: FontWeight.w700,
              maxLines: 3,
              overflow: TextOverflow.visible,
              softWrap: true,
            ),
          ),
          // Nama produk: ellipsis
          Expanded(
            flex: 40,
            child: _cellText(
              name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          // Qty: center
          Expanded(
            flex: 14,
            child: Align(
              alignment: Alignment.center,
              child: _cellText(qty, align: TextAlign.center),
            ),
          ),
          // Amount: right, merah untuk spending
          Expanded(
            flex: 20,
            child: _cellText(
              moneyText,
              align: TextAlign.right,
              c: isSales ? AppColors.textPrimary : const Color(0xFFB42318),
            ),
          ),
        ],
      ),
    );
  }
}

class _SkeletonList extends StatelessWidget {
  const _SkeletonList();

  @override
  Widget build(BuildContext context) {
    Widget bar({double h = 14, double w = double.infinity}) => Container(
      height: h,
      width: w,
      decoration: BoxDecoration(
        color: const Color(0xFFF3F4F6),
        borderRadius: BorderRadius.circular(6),
      ),
    );

    return Column(
      children: List.generate(
        6,
        (i) => Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Row(
            children: [
              Expanded(flex: 26, child: bar()),
              const SizedBox(width: 10),
              Expanded(flex: 40, child: bar()),
              const SizedBox(width: 10),
              Expanded(flex: 14, child: bar(w: 40)),
              const SizedBox(width: 10),
              Expanded(flex: 20, child: bar(w: 80)),
            ],
          ),
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 36),
      alignment: Alignment.center,
      child: Column(
        children: const [
          Icon(Icons.inbox_outlined, size: 32, color: AppColors.disabledFg),
          SizedBox(height: 8),
          Text(
            'Tidak ada data',
            style: TextStyle(
              color: AppColors.textSecondary,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _CardShell extends StatelessWidget {
  final String title;
  final Widget child;
  final Widget action;

  const _CardShell({
    required this.title,
    required this.child,
    required this.action,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.divider),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Flexible(
                child: Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.w800,
                    fontSize: 15.5,
                  ),
                ),
              ),
              const Spacer(),
              action,
            ],
          ),
          const SizedBox(height: 8),
          child,
        ],
      ),
    );
  }
}

class _SimpleList extends StatelessWidget {
  final List<_SimpleRow> rows;
  const _SimpleList({required this.rows});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        for (final r in rows)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    r.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: AppColors.textPrimary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  r.right,
                  style: const TextStyle(color: AppColors.textSecondary),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

class _SimpleRow {
  final String title;
  final String right;
  const _SimpleRow({required this.title, required this.right});
}

class _InsightRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color accent;

  const _InsightRow({
    super.key,
    required this.icon,
    required this.label,
    required this.value,
    required this.accent,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        // Icon badge
        Container(
          width: 34,
          height: 34,
          decoration: BoxDecoration(
            color: accent.withOpacity(.12),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, size: 18, color: accent),
        ),
        const SizedBox(width: 10),
        // Label
        Expanded(
          child: Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: AppColors.textSecondary,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        const SizedBox(width: 8),
        // Value (right aligned)
        Text(
          value,
          textAlign: TextAlign.right,
          style: const TextStyle(
            color: AppColors.textPrimary,
            fontWeight: FontWeight.w800,
          ),
        ),
      ],
    );
  }
}

/// =================== Pie Chart (Custom Painter) ===================

class _PieSegment {
  final double value;
  final int colorIndex;
  const _PieSegment({required this.value, required this.colorIndex});
}

class _PieChart extends StatelessWidget {
  final List<_PieSegment> segments;
  const _PieChart({required this.segments});

  @override
  Widget build(BuildContext context) {
    return CustomPaint(painter: _PieChartPainter(segments));
  }
}

class _PieChartPainter extends CustomPainter {
  final List<_PieSegment> segments;
  _PieChartPainter(this.segments);

  @override
  void paint(Canvas canvas, Size size) {
    final total = segments.fold<double>(0.0, (a, e) => a + e.value);
    final rect = Offset.zero & size;
    final center = rect.center;
    final radius = math.min(size.width, size.height) / 2;

    final paint = Paint()..style = PaintingStyle.fill;

    double startRadian = -math.pi / 2;
    for (final s in segments) {
      final sweep = total <= 0 ? 0 : (s.value / total) * 2 * math.pi;
      paint.color = _pieColor(s.colorIndex);
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        startRadian,
        sweep.toDouble(),
        true,
        paint,
      );
      startRadian += sweep;
    }

    // Donut hole
    final hole = Paint()
      ..style = PaintingStyle.fill
      ..color = Colors.white;
    canvas.drawCircle(center, radius * 0.55, hole);

    // Ring outline
    final ring = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1
      ..color = const Color(0xFFE5E7EB);
    canvas.drawCircle(center, radius, ring);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

Color _pieColor(int i) {
  const colors = [
    Color(0xFF60A5FA), // blue
    Color(0xFF34D399), // green
    Color(0xFFFBBF24), // amber
    Color(0xFFE5E7EB), // grey (others)
  ];
  return colors[i.clamp(0, colors.length - 1)];
}
