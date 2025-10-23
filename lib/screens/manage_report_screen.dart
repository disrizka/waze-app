import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:wa_blast/constants/app_colors.dart';

class ReportDashboardScreen extends StatefulWidget {
  const ReportDashboardScreen({super.key});

  @override
  State<ReportDashboardScreen> createState() => _ReportDashboardScreenState();
}

enum _QuickRange { week, month, year, none }

class _ReportDashboardScreenState extends State<ReportDashboardScreen> {
  late DateTimeRange _range;
  _QuickRange _quick = _QuickRange.month;

  final _money = NumberFormat.currency(
    locale: 'id_ID',
    symbol: 'Rp ',
    decimalDigits: 0,
  );
  final _num = NumberFormat.decimalPattern('id_ID');

  @override
  void initState() {
    super.initState();
    _applyQuick(_QuickRange.month);
  }

  void _applyQuick(_QuickRange q) {
    final now = DateTime.now();
    late DateTime start;
    switch (q) {
      case _QuickRange.week:
        start = now.subtract(const Duration(days: 7));
        break;
      case _QuickRange.month:
        start = DateTime(now.year, now.month - 1, now.day);
        break;
      case _QuickRange.year:
        start = DateTime(now.year - 1, now.month, now.day);
        break;
      case _QuickRange.none:
        start = now.subtract(const Duration(days: 30));
        break;
    }
    setState(() {
      _quick = q;
      _range = DateTimeRange(start: start, end: now);
    });
  }

  Future<void> _pickRange() async {
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020, 1, 1),
      lastDate: DateTime.now(),
      initialDateRange: _range,
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: ColorScheme.fromSeed(
              seedColor: AppColors.success,
              primary: AppColors.success,
              secondary: AppColors.success,
            ),
            textButtonTheme: TextButtonThemeData(
              style: TextButton.styleFrom(foregroundColor: AppColors.success),
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null) {
      setState(() {
        _quick = _QuickRange.none;
        _range = picked;
      });
    }
  }

  // ===== dummy data berdasar panjang range =====
  int get _days => _range.end.difference(_range.start).inDays.clamp(1, 9999);
  int get _sales => _days * 120;
  int get _revenue => _days * 1_350_000;
  int get _purchase => _days * 870_000;

  String _rangeLabel() {
    final d = DateFormat('dd MMM yyyy', 'id_ID');
    return '${d.format(_range.start)} — ${d.format(_range.end)}';
  }

  @override
  Widget build(BuildContext context) {
    final isWide = MediaQuery.of(context).size.width >= 760;

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
      ),
      body: SafeArea(
        top: false,
        child: ListView(
          padding: EdgeInsets.symmetric(
            horizontal: isWide ? 24 : 16,
            vertical: 16,
          ),
          children: [
            // ===== Filter Ringkas
            _FilterBar(
              label: _rangeLabel(),
              onPick: _pickRange,
              quick: _quick,
              onQuickTap: _applyQuick,
            ),
            const SizedBox(height: 14),

            // ===== KPI Card — lebih rapat dan berisi
            _KpiGrid(
              isWide: isWide,
              items: [
                _KpiData(
                  title: 'Revenue',
                  value: _money.format(_revenue),
                  deltaUp: true,
                ),
                _KpiData(
                  title: 'Sales',
                  value: _num.format(_sales),
                  deltaUp: true,
                ),
                _KpiData(
                  title: 'Purchase',
                  value: _money.format(_purchase),
                  deltaUp: false,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// =================== Widgets ===================

class _FilterBar extends StatelessWidget {
  final String label;
  final VoidCallback onPick;
  final _QuickRange quick;
  final void Function(_QuickRange) onQuickTap;

  const _FilterBar({
    required this.label,
    required this.onPick,
    required this.quick,
    required this.onQuickTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.divider),
      ),
      padding: const EdgeInsets.all(10),
      child: Row(
        children: [
          Expanded(
            child: _DateButton(label: label, onTap: onPick),
          ),
          const SizedBox(width: 8),
          _QuickChip(
            label: '1W',
            selected: quick == _QuickRange.week,
            onTap: () => onQuickTap(_QuickRange.week),
          ),
          const SizedBox(width: 6),
          _QuickChip(
            label: '1M',
            selected: quick == _QuickRange.month,
            onTap: () => onQuickTap(_QuickRange.month),
          ),
          const SizedBox(width: 6),
          _QuickChip(
            label: '1Y',
            selected: quick == _QuickRange.year,
            onTap: () => onQuickTap(_QuickRange.year),
          ),
        ],
      ),
    );
  }
}

class _DateButton extends StatelessWidget {
  final String label;
  final VoidCallback onTap;

  const _DateButton({required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.white,
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Container(
          height: 40,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            border: Border.all(color: AppColors.border),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Row(
            children: [
              Icon(
                Icons.date_range,
                size: 18,
                color: AppColors.success.withOpacity(.95),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.w700,
                    fontSize: 13,
                  ),
                ),
              ),
              const SizedBox(width: 4),
              const Icon(
                Icons.keyboard_arrow_down_rounded,
                size: 18,
                color: AppColors.disabledFg,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _QuickChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _QuickChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ChoiceChip(
      label: Text(label),
      selected: selected,
      onSelected: (_) => onTap(),
      selectedColor: AppColors.success.withOpacity(.15),
      backgroundColor: AppColors.greyBackground,
      labelStyle: TextStyle(
        color: selected ? AppColors.textPrimary : AppColors.textSecondary,
        fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
      ),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      side: BorderSide(color: selected ? AppColors.success : AppColors.border),
      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
      visualDensity: VisualDensity.compact,
    );
  }
}

// =================== KPI ===================

@immutable
class _KpiData {
  final String title;
  final String value;
  final bool deltaUp;

  const _KpiData({
    required this.title,
    required this.value,
    required this.deltaUp,
  });
}

class _KpiGrid extends StatelessWidget {
  final bool isWide;
  final List<_KpiData> items;

  const _KpiGrid({required this.isWide, required this.items});

  @override
  Widget build(BuildContext context) {
    // childAspectRatio disetel agar kartu lebih rapat/pendek
    final cross = isWide ? 3 : 1;
    final aspect = isWide ? 2.1 : 1.9;

    return GridView.builder(
      itemCount: items.length,
      physics: const NeverScrollableScrollPhysics(),
      shrinkWrap: true,
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: cross,
        mainAxisSpacing: 10,
        crossAxisSpacing: 10,
        childAspectRatio: aspect,
      ),
      itemBuilder: (_, i) => _KpiCard(data: items[i]),
    );
  }
}

class _KpiCard extends StatelessWidget {
  final _KpiData data;
  const _KpiCard({required this.data});

  @override
  Widget build(BuildContext context) {
    final deltaColor = data.deltaUp ? AppColors.success : AppColors.danger;
    final deltaIcon = data.deltaUp
        ? Icons.arrow_upward_rounded
        : Icons.arrow_downward_rounded;

    return Card(
      color: AppColors.white,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: const BorderSide(color: AppColors.divider),
      ),
      child: Padding(
        // padding kecil supaya kartu terlihat compact
        padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
        child: Row(
          children: [
            // Icon Target (aksen hijau)
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: AppColors.success.withOpacity(.12),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(
                Icons.track_changes,
                color: AppColors.success,
                size: 20,
              ),
            ),
            const SizedBox(width: 12),
            // Teks
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // judul kecil
                  Text(
                    data.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 12.5,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 4),
                  // angka hijau tebal
                  AnimatedSwitcher(
                    duration: const Duration(milliseconds: 200),
                    child: Text(
                      data.value,
                      key: ValueKey(data.value),
                      style: const TextStyle(
                        color: AppColors.success,
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                        letterSpacing: .2,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 10),
          ],
        ),
      ),
    );
  }
}
