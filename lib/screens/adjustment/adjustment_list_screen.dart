import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import 'package:wa_blast/constants/app_colors.dart';
import 'package:wa_blast/providers/adjustment_provider.dart';
import 'package:wa_blast/screens/adjustment/adjustment_form_screen.dart';
import 'package:wa_blast/screens/adjustment/adjustment_detail_screen.dart';

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
    WidgetsBinding.instance.addPostFrameCallback((_) => _kick());
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
    final cur = pm?.currentPage;
    final total = pm?.totalPages;
    final isAtEnd = (cur != null && total != null) ? (cur >= total) : false;
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
      MaterialPageRoute(builder: (_) => const AdjustmentFormScreen()),
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

  void _openDetail(AdjustmentTransaction t) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => AdjustmentDetailScreen(t: t)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final prov = context.watch<AdjustmentProvider>();
    final items = prov.adjustments;

    final loading = prov.loadingAdjustments;
    final err = prov.adjustmentsError;

    final pm = prov.pageAdjustments;
    final cur = pm?.currentPage;
    final total = pm?.totalPages;
    final isAtEnd = (cur != null && total != null) ? (cur >= total) : true;

    final rows = _buildRows(items);

    return Scaffold(
      backgroundColor: const Color(0xFFF6F7FB),
      appBar: AppBar(
        backgroundColor: Colors.white,
        scrolledUnderElevation: 0,
        elevation: 0,
        title: Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment:
              CrossAxisAlignment.baseline, // ⬅️ ini pakai CrossAxisAlignment
          textBaseline:
              TextBaseline.alphabetic, // ⬅️ ini baru pakai TextBaseline
          children: const [
            Text(
              'Adjustment Stock',
              style: TextStyle(fontWeight: FontWeight.w800),
            ),
            SizedBox(width: 8),
            Text(
              '/list',
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
      ),
      body: RefreshIndicator(
        onRefresh: _refresh,
        child: (err != null && items.isEmpty && !loading)
            ? _ErrorState(message: err, onRetry: _refresh)
            : (items.isEmpty && loading)
            ? const _SkeletonList()
            : ListView.builder(
                controller: _scrollC,
                padding: const EdgeInsets.fromLTRB(16, 10, 16, 16),
                itemCount: rows.length + 1,
                itemBuilder: (context, i) {
                  if (i == rows.length) {
                    if ((loading && items.isNotEmpty) ||
                        (!loading && !isAtEnd && items.isNotEmpty)) {
                      return const Padding(
                        padding: EdgeInsets.symmetric(vertical: 14),
                        child: Center(child: CircularProgressIndicator()),
                      );
                    }
                    return const SizedBox(height: 12);
                  }

                  final r = rows[i];
                  if (r is _MonthHeaderRow) {
                    return _MonthHeader(title: r.title);
                  }

                  final t = (r as _ItemRow).t;

                  final dt = _fmtShortDate(t.orderAt);
                  final store = t.storeLocation.name;
                  final storeSub = _joinCityProv(
                    t.storeLocation.cityName,
                    t.storeLocation.provinceName,
                  );

                  final itemCount = t.items.length;
                  final netQty = t.items.fold<int>(0, (s, e) => s + e.netQty);

                  return _AdjustmentCardMinimal(
                    number: t.number,
                    dateText: dt,
                    storeName: store,
                    storeSub: storeSub,
                    itemCount: itemCount,
                    netQty: netQty,
                    note: t.note.trim(),
                    onTap: () => _openDetail(t),
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
          style: TextStyle(fontWeight: FontWeight.w900),
        ),
      ),
    );
  }

  // ===== GROUPING =====

  List<_Row> _buildRows(List<AdjustmentTransaction> items) {
    final now = DateTime.now();
    final currentYear = now.year;

    final out = <_Row>[];
    DateTime? lastBucket;

    for (final t in items) {
      final dt = _safeLocalDate(t.orderAt);
      final bucket = DateTime(dt.year, dt.month, 1);

      final changed =
          lastBucket == null ||
          bucket.year != lastBucket!.year ||
          bucket.month != lastBucket!.month;

      if (changed) {
        lastBucket = bucket;
        out.add(_MonthHeaderRow(_fmtMonthHeader(bucket, currentYear)));
      }
      out.add(_ItemRow(t));
    }
    return out;
  }

  static DateTime _safeLocalDate(int unixSeconds) {
    if (unixSeconds <= 0) return DateTime.now();
    return DateTime.fromMillisecondsSinceEpoch(
      unixSeconds * 1000,
      isUtc: false,
    );
  }

  static String _fmtMonthHeader(DateTime bucket, int currentYear) {
    final m = DateFormat('MMMM', 'en_US').format(bucket); // ⬅️ EN
    if (bucket.year == currentYear) return m;
    return '$m ${bucket.year}';
  }

  static String _fmtShortDate(int unixSeconds) {
    if (unixSeconds <= 0) return '-';
    try {
      final dt = DateTime.fromMillisecondsSinceEpoch(
        unixSeconds * 1000,
        isUtc: false,
      );
      return DateFormat('dd MMM • HH:mm', 'en_US').format(dt); // ⬅️ EN
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
}

// ===== ROW MODEL =====

sealed class _Row {}

class _MonthHeaderRow extends _Row {
  final String title;
  _MonthHeaderRow(this.title);
}

class _ItemRow extends _Row {
  final AdjustmentTransaction t;
  _ItemRow(this.t);
}

// ===== UI =====

class _MonthHeader extends StatelessWidget {
  final String title;
  const _MonthHeader({required this.title});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(2, 14, 2, 10),
      child: Row(
        children: [
          Text(
            title,
            style: const TextStyle(
              fontWeight: FontWeight.w900,
              fontSize: 14,
              color: Color(0xFF111827),
            ),
          ),
          const SizedBox(width: 10),
          const Expanded(child: Divider(height: 1, color: Color(0xFFE5E7EB))),
        ],
      ),
    );
  }
}

/// Card versi "tetap cantik seperti sebelumnya" tapi lebih minimalis:
/// - status dihilangkan
/// - info inti: number, date, store
/// - stats: Items & Net Qty dalam chip kecil
/// - ada accent strip halus berdasarkan netQty (plus hijau / minus merah / netral biru)
class _AdjustmentCardMinimal extends StatelessWidget {
  final String number;
  final String dateText;
  final String storeName;
  final String? storeSub;
  final int itemCount;
  final int netQty;
  final String note;
  final VoidCallback onTap;

  const _AdjustmentCardMinimal({
    required this.number,
    required this.dateText,
    required this.storeName,
    required this.storeSub,
    required this.itemCount,
    required this.netQty,
    required this.note,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final title = number.trim().isNotEmpty ? number.trim() : 'Adjustment';

    final netColor = netQty > 0
        ? const Color(0xFF16A34A)
        : (netQty < 0 ? const Color(0xFFDC2626) : const Color(0xFF1D4ED8));
    final netText = netQty >= 0 ? '+$netQty' : '$netQty';

    final accent = netColor.withOpacity(0.16);

    final hasStoreSub = (storeSub ?? '').trim().isNotEmpty;
    final hasNote = note.trim().isNotEmpty;

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
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Accent strip + icon (biar menarik tapi tetap minimal)
            Column(
              children: [
                Container(
                  width: 4,
                  height: 52,
                  decoration: BoxDecoration(
                    color: accent,
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
                const SizedBox(height: 10),
              ],
            ),
            const SizedBox(width: 12),

            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Title row + chips stats
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontWeight: FontWeight.w900,
                            fontSize: 15,
                            color: Color(0xFF111827),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      _ChipStat(
                        icon: Icons.list_alt_rounded,
                        text: '$itemCount',
                      ),
                      const SizedBox(width: 8),
                      _ChipStat(
                        icon: Icons.swap_vert_rounded,
                        text: netText,
                        textColor: netColor,
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),

                  // Date
                  Row(
                    children: [
                      const _TinyIcon(Icons.schedule_rounded),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          dateText,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Color(0xFF6B7280),
                            fontWeight: FontWeight.w700,
                            fontSize: 12,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),

                  // Store + chevron
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const _TinyIcon(Icons.store_mall_directory_outlined),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              storeName,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            if (hasStoreSub)
                              Text(
                                storeSub!.trim(),
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
                      const SizedBox(width: 8),
                      const Icon(
                        Icons.chevron_right_rounded,
                        color: Color(0xFF9CA3AF),
                      ),
                    ],
                  ),

                  // Note (tanpa box, 1 baris)
                  if (hasNote) ...[
                    const SizedBox(height: 8),
                    Text(
                      note.trim(),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Color(0xFF4B5563),
                        fontWeight: FontWeight.w600,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TinyIcon extends StatelessWidget {
  final IconData icon;
  const _TinyIcon(this.icon);

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 22,
      height: 22,
      decoration: BoxDecoration(
        color: const Color(0xFFF9FAFB),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Icon(icon, size: 14, color: const Color(0xFF6B7280)),
    );
  }
}

class _ChipStat extends StatelessWidget {
  final IconData icon;
  final String text;
  final Color? textColor;

  const _ChipStat({required this.icon, required this.text, this.textColor});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0xFFF9FAFB),
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
            style: TextStyle(
              fontWeight: FontWeight.w900,
              fontSize: 12,
              color: textColor ?? const Color(0xFF111827),
            ),
          ),
        ],
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
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 4,
                height: 52,
                decoration: BoxDecoration(
                  color: const Color(0xFFEFF6FF),
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(child: bar(w: 180, h: 14)),
                        const SizedBox(width: 10),
                        Container(
                          width: 56,
                          height: 26,
                          decoration: BoxDecoration(
                            color: const Color(0xFFF9FAFB),
                            borderRadius: BorderRadius.circular(999),
                            border: Border.all(color: const Color(0xFFE5E7EB)),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          width: 64,
                          height: 26,
                          decoration: BoxDecoration(
                            color: const Color(0xFFF9FAFB),
                            borderRadius: BorderRadius.circular(999),
                            border: Border.all(color: const Color(0xFFE5E7EB)),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    bar(w: 210),
                    const SizedBox(height: 10),
                    bar(w: 240),
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
