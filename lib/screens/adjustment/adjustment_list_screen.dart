import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import 'package:wa_blast/constants/app_colors.dart';
import 'package:wa_blast/providers/adjustment_provider.dart';
import 'package:wa_blast/screens/adjustment/adjustment_create_screen.dart';

class AdjustmentListScreen extends StatefulWidget {
  const AdjustmentListScreen({super.key});

  @override
  State<AdjustmentListScreen> createState() => _AdjustmentListScreenState();
}

class _AdjustmentListScreenState extends State<AdjustmentListScreen> {
  final ScrollController _scrollC = ScrollController();

  static const int _limit = 30;
  bool _booted = false;

  @override
  void initState() {
    super.initState();
    _scrollC.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollC.removeListener(_onScroll);
    _scrollC.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (!_scrollC.hasClients) return;
    final prov = context.read<AdjustmentProvider>();
    if (prov.loadingAdjustments) return;

    final pos = _scrollC.position;
    final threshold = pos.maxScrollExtent * 0.82;
    if (pos.pixels < threshold) return;

    final pm = prov.pageAdjustments;
    final int? cur = pm?.currentPage;
    final int? total = pm?.totalPages;

    final bool isAtEnd = (cur != null && total != null)
        ? (cur >= total)
        : false;
    if (isAtEnd) return;

    final nextPage = (cur ?? 1) + 1;
    prov.fetchAdjustments(context, page: nextPage, limit: _limit, append: true);
  }

  Future<void> _kick() async {
    if (_booted) return;
    _booted = true;
    await context.read<AdjustmentProvider>().fetchAdjustments(
      context,
      page: 1,
      limit: _limit,
      append: false,
    );
  }

  Future<void> _refresh() async {
    await context.read<AdjustmentProvider>().fetchAdjustments(
      context,
      page: 1,
      limit: _limit,
      append: false,
    );
  }

  Future<void> _goCreate() async {
    final ok = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => const AdjustmentCreateScreen()),
    );

    if (!mounted) return;

    if (ok == true) {
      await _refresh();
      if (_scrollC.hasClients) {
        _scrollC.animateTo(
          0,
          duration: const Duration(milliseconds: 260),
          curve: Curves.easeOut,
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    WidgetsBinding.instance.addPostFrameCallback((_) => _kick());

    final prov = context.watch<AdjustmentProvider>();
    final items = prov.adjustments;

    final bool loading = prov.loadingAdjustments;
    final String? err = prov.adjustmentsError;

    final pm = prov.pageAdjustments;
    final int? cur = pm?.currentPage;
    final int? total = pm?.totalPages;
    final bool isAtEnd = (cur != null && total != null) ? (cur >= total) : true;

    return Scaffold(
      backgroundColor: const Color(0xFFF6F7FB),
      appBar: AppBar(
        backgroundColor: Colors.white,
        scrolledUnderElevation: 0,
        elevation: 0,
        title: const Text(
          'Adjustment',
          style: TextStyle(fontWeight: FontWeight.w800),
        ),
        actions: [
          IconButton(
            tooltip: 'Create Adjustment',
            onPressed: _goCreate,
            icon: const Icon(Icons.add_circle_outline_rounded),
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _refresh,
        child: (err != null && items.isEmpty && !loading)
            ? _ErrorState(message: err, onRetry: _refresh)
            : (items.isEmpty && loading)
            ? const _SkeletonList()
            : ListView.builder(
                controller: _scrollC,
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
                itemCount: items.length + 1,
                itemBuilder: (context, i) {
                  if (i == items.length) {
                    if (loading && items.isNotEmpty) {
                      return const Padding(
                        padding: EdgeInsets.symmetric(vertical: 16),
                        child: Center(child: CircularProgressIndicator()),
                      );
                    }
                    if (!loading && !isAtEnd && items.isNotEmpty) {
                      return const Padding(
                        padding: EdgeInsets.symmetric(vertical: 16),
                        child: Center(child: CircularProgressIndicator()),
                      );
                    }
                    return const SizedBox(height: 12);
                  }

                  final t = items[i];
                  final dt = _fmtOrderAt(t.orderAt);
                  final store = t.storeLocation.name;
                  final city = t.storeLocation.cityName;
                  final provName = t.storeLocation.provinceName;

                  final int itemCount = t.items.length;
                  final int netQty = t.items.fold<int>(
                    0,
                    (s, e) => s + e.netQty,
                  );

                  final status = (t.status).trim();
                  final statusUi = _statusUi(status);

                  final note = (t.note).trim();

                  return _AdjustmentCard(
                    number: t.number,
                    dateText: dt,
                    storeName: store,
                    storeSub: _joinCityProv(city, provName),
                    statusText: status.isEmpty ? '-' : status,
                    statusBg: statusUi.bg,
                    statusFg: statusUi.fg,
                    itemCount: itemCount,
                    netQty: netQty,
                    note: note,
                    onTap: () {
                      _openQuickDetail(context, t);
                    },
                  );
                },
              ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _goCreate,
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        elevation: 0,
        icon: const Icon(Icons.add_rounded),
        label: const Text(
          'Create',
          style: TextStyle(fontWeight: FontWeight.w800),
        ),
      ),
    );
  }

  void _openQuickDetail(BuildContext context, AdjustmentTransaction t) {
    final money = NumberFormat.decimalPattern('id_ID');
    showModalBottomSheet(
      context: context,
      useSafeArea: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
      ),
      builder: (_) {
        final dt = _fmtOrderAt(t.orderAt);
        final store = t.storeLocation.name;

        return Padding(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 44,
                height: 4,
                decoration: BoxDecoration(
                  color: const Color(0xFFE5E7EB),
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      t.number.isNotEmpty ? t.number : 'Adjustment',
                      style: const TextStyle(
                        fontWeight: FontWeight.w900,
                        fontSize: 16,
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close_rounded),
                    tooltip: 'Close',
                  ),
                ],
              ),
              const SizedBox(height: 4),
              _kv('Date', dt),
              _kv('Store', store),
              _kv('Status', (t.status).trim().isEmpty ? '-' : t.status),
              if ((t.note).trim().isNotEmpty) _kv('Notes', t.note.trim()),
              const SizedBox(height: 10),
              Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'Items (${t.items.length})',
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
              ),
              const SizedBox(height: 8),
              Flexible(
                child: ListView.separated(
                  shrinkWrap: true,
                  itemCount: t.items.length,
                  separatorBuilder: (_, __) => const Divider(height: 1),
                  itemBuilder: (context, i) {
                    final it = t.items[i];
                    final pName = it.product?.name ?? '-';
                    final sku = it.productSku?.code ?? '-';
                    final qIn = it.qtyIn;
                    final qOut = it.qtyOut;

                    String qtyText;
                    if (qIn > 0 && qOut == 0) {
                      qtyText = '+$qIn';
                    } else if (qOut > 0 && qIn == 0) {
                      qtyText = '-$qOut';
                    } else {
                      qtyText =
                          '${qIn > 0 ? "+$qIn" : ""} ${qOut > 0 ? "-$qOut" : ""}'
                              .trim();
                    }

                    return ListTile(
                      dense: true,
                      contentPadding: EdgeInsets.zero,
                      title: Text(
                        pName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontWeight: FontWeight.w800),
                      ),
                      subtitle: Text(
                        sku,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(color: Color(0xFF6B7280)),
                      ),
                      trailing: Text(
                        qtyText,
                        style: TextStyle(
                          fontWeight: FontWeight.w900,
                          color: (it.netQty >= 0)
                              ? const Color(0xFF16A34A)
                              : const Color(0xFFDC2626),
                        ),
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'Amount: Rp ${money.format(t.amount)}',
                      style: const TextStyle(
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF111827),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
            ],
          ),
        );
      },
    );
  }

  static Widget _kv(String k, String v) {
    return Padding(
      padding: const EdgeInsets.only(top: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 92,
            child: Text(
              k,
              style: const TextStyle(
                color: Color(0xFF6B7280),
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(v, style: const TextStyle(fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
  }

  static String _fmtOrderAt(int unixSeconds) {
    if (unixSeconds <= 0) return '-';
    try {
      final dt = DateTime.fromMillisecondsSinceEpoch(
        unixSeconds * 1000,
        isUtc: false,
      );
      return DateFormat('dd MMM yyyy • HH:mm', 'id_ID').format(dt);
    } catch (_) {
      return '-';
    }
  }

  static String? _joinCityProv(String? city, String? prov) {
    final c = (city ?? '').trim();
    final p = (prov ?? '').trim();
    if (c.isEmpty && p.isEmpty) return null;
    if (c.isNotEmpty && p.isNotEmpty) return '$c, $p';
    return c.isNotEmpty ? c : p;
  }

  static _StatusUi _statusUi(String raw) {
    final s = raw.trim().toLowerCase();
    if (s.contains('adjusted') || s.contains('success') || s.contains('done')) {
      return const _StatusUi(bg: Color(0xFFDCFCE7), fg: Color(0xFF166534));
    }
    if (s.contains('pending') || s.contains('process')) {
      return const _StatusUi(bg: Color(0xFFFEF3C7), fg: Color(0xFF92400E));
    }
    if (s.contains('fail') || s.contains('reject') || s.contains('cancel')) {
      return const _StatusUi(bg: Color(0xFFFEE2E2), fg: Color(0xFF991B1B));
    }
    return const _StatusUi(bg: Color(0xFFEFF6FF), fg: Color(0xFF1D4ED8));
  }
}

class _StatusUi {
  final Color bg;
  final Color fg;
  const _StatusUi({required this.bg, required this.fg});
}

class _AdjustmentCard extends StatelessWidget {
  final String number;
  final String dateText;
  final String storeName;
  final String? storeSub;
  final String statusText;
  final Color statusBg;
  final Color statusFg;
  final int itemCount;
  final int netQty;
  final String note;
  final VoidCallback onTap;

  const _AdjustmentCard({
    required this.number,
    required this.dateText,
    required this.storeName,
    required this.storeSub,
    required this.statusText,
    required this.statusBg,
    required this.statusFg,
    required this.itemCount,
    required this.netQty,
    required this.note,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final netColor = netQty >= 0
        ? const Color(0xFF16A34A)
        : const Color(0xFFDC2626);

    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFE5E7EB)),
          boxShadow: const [
            BoxShadow(
              color: Color(0x0F000000),
              blurRadius: 16,
              offset: Offset(0, 6),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Top row: Number + Status
            Row(
              children: [
                Expanded(
                  child: Text(
                    number.isNotEmpty ? number : 'Adjustment',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontWeight: FontWeight.w900,
                      fontSize: 15,
                      color: Color(0xFF111827),
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: statusBg,
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(color: statusBg.withOpacity(.9)),
                  ),
                  child: Text(
                    statusText,
                    style: TextStyle(
                      fontWeight: FontWeight.w900,
                      fontSize: 11,
                      color: statusFg,
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 6),

            // Date
            Row(
              children: [
                const Icon(
                  Icons.schedule_rounded,
                  size: 16,
                  color: Color(0xFF6B7280),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    dateText,
                    style: const TextStyle(
                      color: Color(0xFF6B7280),
                      fontWeight: FontWeight.w600,
                      fontSize: 12,
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 10),

            // Store
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(
                  Icons.store_mall_directory_outlined,
                  size: 16,
                  color: Color(0xFF6B7280),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        storeName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontWeight: FontWeight.w800),
                      ),
                      if ((storeSub ?? '').trim().isNotEmpty)
                        Text(
                          storeSub!,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Color(0xFF6B7280),
                            fontWeight: FontWeight.w600,
                            fontSize: 12,
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(width: 10),
                const Icon(
                  Icons.chevron_right_rounded,
                  color: Color(0xFF9CA3AF),
                ),
              ],
            ),

            const SizedBox(height: 10),
            const Divider(height: 1, color: Color(0xFFE5E7EB)),
            const SizedBox(height: 10),

            Row(
              children: [
                _MiniStat(
                  icon: Icons.list_alt_rounded,
                  label: 'Items',
                  value: '$itemCount',
                ),
                const SizedBox(width: 12),
                _MiniStat(
                  icon: Icons.swap_vert_rounded,
                  label: 'Net Qty',
                  value: netQty >= 0 ? '+$netQty' : '$netQty',
                  valueColor: netColor,
                ),
              ],
            ),

            if (note.trim().isNotEmpty) ...[
              const SizedBox(height: 10),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: const Color(0xFFF9FAFB),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFE5E7EB)),
                ),
                child: Text(
                  note,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Color(0xFF4B5563),
                    fontWeight: FontWeight.w600,
                    fontSize: 12,
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

class _MiniStat extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color? valueColor;

  const _MiniStat({
    required this.icon,
    required this.label,
    required this.value,
    this.valueColor,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: const Color(0xFFF9FAFB),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFFE5E7EB)),
        ),
        child: Row(
          children: [
            Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0xFFE5E7EB)),
              ),
              child: Icon(icon, size: 18, color: const Color(0xFF6B7280)),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: const TextStyle(
                      color: Color(0xFF6B7280),
                      fontWeight: FontWeight.w700,
                      fontSize: 11,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    value,
                    style: TextStyle(
                      fontWeight: FontWeight.w900,
                      fontSize: 14,
                      color: valueColor ?? const Color(0xFF111827),
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

class _ErrorState extends StatelessWidget {
  final String message;
  final Future<void> Function() onRetry;

  const _ErrorState({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const SizedBox(height: 70),
        const Icon(Icons.wifi_off_rounded, size: 42, color: Color(0xFF9CA3AF)),
        const SizedBox(height: 12),
        const Text(
          'Gagal memuat adjustment',
          textAlign: TextAlign.center,
          style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16),
        ),
        const SizedBox(height: 6),
        Text(
          message,
          textAlign: TextAlign.center,
          style: const TextStyle(
            color: Color(0xFF6B7280),
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 16),
        Center(
          child: FilledButton.icon(
            onPressed: () => onRetry(),
            icon: const Icon(Icons.refresh_rounded),
            label: const Text(
              'Coba lagi',
              style: TextStyle(fontWeight: FontWeight.w800),
            ),
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _SkeletonList extends StatelessWidget {
  const _SkeletonList();

  @override
  Widget build(BuildContext context) {
    Widget bar({double w = 140, double h = 12}) => Container(
      width: w,
      height: h,
      decoration: BoxDecoration(
        color: const Color(0xFFE5E7EB),
        borderRadius: BorderRadius.circular(999),
      ),
    );

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
      itemCount: 6,
      itemBuilder: (_, __) {
        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFFE5E7EB)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(child: bar(w: 180, h: 14)),
                  const SizedBox(width: 10),
                  Container(
                    width: 84,
                    height: 26,
                    decoration: BoxDecoration(
                      color: const Color(0xFFEFF6FF),
                      borderRadius: BorderRadius.circular(999),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              bar(w: 200),
              const SizedBox(height: 10),
              bar(w: 220),
              const SizedBox(height: 12),
              const Divider(height: 1, color: Color(0xFFE5E7EB)),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: Container(
                      height: 54,
                      decoration: BoxDecoration(
                        color: const Color(0xFFF9FAFB),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: const Color(0xFFE5E7EB)),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Container(
                      height: 54,
                      decoration: BoxDecoration(
                        color: const Color(0xFFF9FAFB),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: const Color(0xFFE5E7EB)),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }
}
