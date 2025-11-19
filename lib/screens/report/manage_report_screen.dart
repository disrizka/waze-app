import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import 'package:wa_blast/providers/report_provider.dart';

class ManageReportScreen extends StatefulWidget {
  const ManageReportScreen({super.key});

  @override
  State<ManageReportScreen> createState() => _ManageReportScreenState();
}

class _ManageReportScreenState extends State<ManageReportScreen> {
  ReportSummary? _salesSummary;
  ReportSummary? _purchaseSummary;
  bool _loadingSummary = false;

  late final DateTime _startOfMonth;
  late final DateTime _endOfMonth;

  @override
  void initState() {
    super.initState();

    final now = DateTime.now();
    _startOfMonth = DateTime(now.year, now.month, 1);
    _endOfMonth = DateTime(now.year, now.month + 1, 0);

    // fetch setelah frame pertama supaya context aman
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadMonthlySummaries();
    });
  }

  Future<void> _loadMonthlySummaries() async {
    setState(() => _loadingSummary = true);
    try {
      final report = ReportProviderV2.of(context, listen: false);

      // 1) Sales per month (pakai fungsi provider)
      await report.fetchByPeriod(
        context,
        domain: ReportDomain.sales,
        period: ReportPeriod.month,
        startDate: _startOfMonth,
        endDate: _endOfMonth,
      );
      final sales = report.summary;

      // 2) Purchase per month (pakai fungsi provider)
      await report.fetchByPeriod(
        context,
        domain: ReportDomain.purchase,
        period: ReportPeriod.month,
        startDate: _startOfMonth,
        endDate: _endOfMonth,
      );
      final purchase = report.summary;

      if (!mounted) return;

      setState(() {
        _salesSummary = sales;
        _purchaseSummary = purchase;
      });
    } catch (e) {
      if (!mounted) return;
      // optional: bisa pakai snackbar kalau mau
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Gagal memuat ringkasan report: $e')),
      );
    } finally {
      if (!mounted) return;
      setState(() => _loadingSummary = false);
    }
  }

  String get _monthLabel {
    final formatter = DateFormat('MMMM yyyy', 'id_ID');
    return formatter.format(_startOfMonth);
  }

  String _formatRevenue(ReportSummary? summary) {
    if (summary == null) return '-';
    final formatted = summary.totalRevenueFormatted;
    if (formatted != null && formatted.trim().isNotEmpty) {
      return formatted;
    }
    final value = summary.totalRevenue ?? 0;
    final f = NumberFormat.currency(
      locale: 'id_ID',
      symbol: 'Rp ',
      decimalDigits: 0,
    );
    return f.format(value);
  }

  String _formatCount(int? v) {
    if (v == null) return '-';
    return NumberFormat.decimalPattern('id_ID').format(v);
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded),
          onPressed: () => Navigator.of(
            context,
          ).popUntil((route) => route.settings.name == '/home'),
        ),
        title: const Text('Report'),
        centerTitle: false,
        elevation: 0,
      ),
      body: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 8),
              // ==== DASHBOARD SUMMARY ====
              _MonthlyReportDashboard(
                monthLabel: _monthLabel,
                loading: _loadingSummary,
                salesRevenueText: _formatRevenue(_salesSummary),
                salesTxText: _formatCount(
                  _salesSummary?.totalTransactions ?? 0,
                ),
                salesQtyText: _formatCount(_salesSummary?.totalQty ?? 0),
                purchaseRevenueText: _formatRevenue(_purchaseSummary),
                purchaseTxText: _formatCount(
                  _purchaseSummary?.totalTransactions ?? 0,
                ),
                purchaseQtyText: _formatCount(_purchaseSummary?.totalQty ?? 0),
                onRetry: _loadMonthlySummaries,
              ),
              const SizedBox(height: 24),
              // ==== LIST MENU ====
              Text(
                'List Menu',
                style: textTheme.bodyMedium?.copyWith(
                  color: Colors.black.withOpacity(0.6),
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 8),
              _MenuTile(
                icon: Icons.query_stats_rounded,
                title: 'Report Sales',
                onTap: () => Navigator.pushNamed(context, '/report/sales'),
              ),
              const SizedBox(height: 8),
              _MenuTile(
                icon: Icons.people_alt_rounded,
                title: 'Report Purchase',
                onTap: () => Navigator.pushNamed(context, '/report/purchase'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// ===============================
/// DASHBOARD WIDGET
/// ===============================
class _MonthlyReportDashboard extends StatelessWidget {
  const _MonthlyReportDashboard({
    required this.monthLabel,
    required this.loading,
    required this.salesRevenueText,
    required this.salesTxText,
    required this.salesQtyText,
    required this.purchaseRevenueText,
    required this.purchaseTxText,
    required this.purchaseQtyText,
    required this.onRetry,
  });

  final String monthLabel;
  final bool loading;

  final String salesRevenueText;
  final String salesTxText;
  final String salesQtyText;

  final String purchaseRevenueText;
  final String purchaseTxText;
  final String purchaseQtyText;

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFF5F7FF),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE1E6FF)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Report Summary',
                      style: textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                        color: const Color(0xFF111827),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      monthLabel,
                      style: textTheme.bodySmall?.copyWith(
                        color: const Color(0xFF6B7280),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (loading)
            const Center(
              child: Padding(
                padding: EdgeInsets.symmetric(vertical: 12),
                child: SizedBox(
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(strokeWidth: 2.2),
                ),
              ),
            )
          else
            Row(
              children: [
                // Sales
                Expanded(
                  child: _MiniMetricCard(
                    icon: Icons.trending_up_rounded,
                    iconBg: const Color(0xFFE9F0FF),
                    title: 'Sales Revenue',
                    value: salesRevenueText,
                    sub1Label: 'Transaksi',
                    sub1Value: salesTxText,
                    sub2Label: 'Qty',
                    sub2Value: salesQtyText,
                  ),
                ),
                const SizedBox(width: 8),
                // Purchase
                Expanded(
                  child: _MiniMetricCard(
                    icon: Icons.shopping_bag_rounded,
                    iconBg: const Color(0xFFEFF6FF),
                    title: 'Purchase',
                    value: purchaseRevenueText,
                    sub1Label: 'Transaksi',
                    sub1Value: purchaseTxText,
                    sub2Label: 'Qty',
                    sub2Value: purchaseQtyText,
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }
}

class _MiniMetricCard extends StatelessWidget {
  const _MiniMetricCard({
    required this.icon,
    required this.iconBg,
    required this.title,
    required this.value,
    required this.sub1Label,
    required this.sub1Value,
    required this.sub2Label,
    required this.sub2Value,
  });

  final IconData icon;
  final Color iconBg;
  final String title;
  final String value;
  final String sub1Label;
  final String sub1Value;
  final String sub2Label;
  final String sub2Value;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE5E7EB)),
        boxShadow: const [
          BoxShadow(
            blurRadius: 10,
            offset: Offset(0, 4),
            color: Color(0x1A111827),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: iconBg,
                ),
                child: Icon(icon, size: 18, color: const Color(0xFF4C6EF5)),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: textTheme.bodySmall?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: const Color(0xFF4B5563),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w700,
              color: const Color(0xFF111827),
            ),
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              Expanded(
                child: _SubMetric(label: sub1Label, value: sub1Value),
              ),
              const SizedBox(width: 4),
              Expanded(
                child: _SubMetric(label: sub2Label, value: sub2Value),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _SubMetric extends StatelessWidget {
  const _SubMetric({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: textTheme.bodySmall?.copyWith(
            color: const Color(0xFF9CA3AF),
            fontSize: 11,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          value,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: textTheme.bodySmall?.copyWith(
            fontWeight: FontWeight.w600,
            color: const Color(0xFF374151),
          ),
        ),
      ],
    );
  }
}

/// ===============================
/// MENU TILE
/// ===============================
class _MenuTile extends StatelessWidget {
  const _MenuTile({required this.icon, required this.title, this.onTap});

  final IconData icon;
  final String title;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8.0),
          child: Row(
            children: [
              _BlueIcon(icon: icon),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  title,
                  style: Theme.of(
                    context,
                  ).textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.w600),
                ),
              ),
              const Icon(Icons.chevron_right_rounded, size: 20),
            ],
          ),
        ),
      ),
    );
  }
}

class _BlueIcon extends StatelessWidget {
  const _BlueIcon({required this.icon});
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 36,
      height: 36,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: const Color(0xFFE9F0FF),
        border: Border.all(color: const Color(0xFFD6E3FF)),
      ),
      child: Center(
        child: Icon(icon, size: 20, color: const Color(0xFF4C6EF5)),
      ),
    );
  }
}
