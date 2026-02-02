import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import 'package:wa_blast/constants/app_colors.dart';
import 'package:wa_blast/providers/adjustment_provider.dart';
import 'package:wa_blast/screens/adjustment/adjustment_form_screen.dart';

class AdjustmentDetailScreen extends StatefulWidget {
  final AdjustmentTransaction t;
  const AdjustmentDetailScreen({super.key, required this.t});

  @override
  State<AdjustmentDetailScreen> createState() => _AdjustmentDetailScreenState();
}

class _AdjustmentDetailScreenState extends State<AdjustmentDetailScreen> {
  late AdjustmentTransaction _txn;
  bool _refreshing = false;

  @override
  void initState() {
    super.initState();
    _txn = widget.t;
  }

  Future<void> _refreshDetail({bool showSnack = false}) async {
    if (_refreshing) return;
    setState(() => _refreshing = true);

    try {
      final res = await context
          .read<AdjustmentProvider>()
          .fetchAdjustmentDetail(context, _txn.idTransaction);

      // ✅ mengikuti pola di form kamu: res?.transaction
      final latest = res?.transaction;

      if (!mounted) return;

      if (latest != null) {
        setState(() => _txn = latest);
        if (showSnack) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(const SnackBar(content: Text('Refreshed')));
        }
      } else {
        if (showSnack) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(const SnackBar(content: Text('Gagal refresh detail')));
        }
      }
    } finally {
      if (mounted) setState(() => _refreshing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = _txn; // ✅ gunakan data terbaru

    final money = NumberFormat.decimalPattern('id_ID');

    final number = t.number.trim().isNotEmpty ? t.number.trim() : 'ADJ-';
    final dtText = _fmtFullDate(t.orderAt);

    final store = t.storeLocation.name;
    final storeSub = _joinCityProv(
      t.storeLocation.cityName,
      t.storeLocation.provinceName,
    );

    final note = t.note.trim();

    final itemCount = t.items.length;
    final netQty = t.items.fold<int>(0, (s, e) => s + e.netQty);

    final netColor = netQty > 0
        ? const Color(0xFF16A34A)
        : (netQty < 0 ? const Color(0xFFDC2626) : const Color(0xFF2563EB));
    final netText = netQty >= 0 ? '+$netQty' : '$netQty';

    final ap = context.watch<AdjustmentProvider>();
    final busy = ap.deletingAdjustment || ap.editingAdjustment;

    Future<void> onDelete() async {
      final ok = await showDialog<bool>(
        context: context,
        barrierDismissible: true,
        builder: (ctx) {
          return Dialog(
            backgroundColor: Colors.transparent,
            insetPadding: const EdgeInsets.symmetric(
              horizontal: 18,
              vertical: 24,
            ),
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(22),
                border: Border.all(color: const Color(0xFFDBEAFE)),
                boxShadow: const [
                  BoxShadow(
                    color: Color(0x20000000),
                    blurRadius: 24,
                    offset: Offset(0, 16),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.fromLTRB(16, 14, 12, 14),
                    decoration: const BoxDecoration(
                      color: Color(0xFFEFF6FF),
                      borderRadius: BorderRadius.vertical(
                        top: Radius.circular(22),
                      ),
                      border: Border(
                        bottom: BorderSide(color: Color(0xFFDBEAFE)),
                      ),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 42,
                          height: 42,
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(color: const Color(0xFFDBEAFE)),
                          ),
                          child: const Icon(
                            Icons.delete_outline_rounded,
                            color: Color(0xFF1D4ED8),
                          ),
                        ),
                        const SizedBox(width: 12),
                        const Expanded(
                          child: Text(
                            'Delete adjustment?',
                            style: TextStyle(
                              fontWeight: FontWeight.w900,
                              fontSize: 16,
                              color: Color(0xFF0F172A),
                            ),
                          ),
                        ),
                        IconButton(
                          tooltip: 'Close',
                          onPressed: () => Navigator.pop(ctx, false),
                          icon: const Icon(
                            Icons.close_rounded,
                            color: Color(0xFF64748B),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'You are about to permanently delete adjustment:',
                          style: TextStyle(
                            color: Color(0xFF334155),
                            fontWeight: FontWeight.w800,
                            height: 1.25,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 12,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF8FAFF),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: const Color(0xFFDBEAFE)),
                          ),
                          child: Row(
                            children: [
                              const Icon(
                                Icons.receipt_long_rounded,
                                size: 18,
                                color: Color(0xFF2563EB),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  number,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w900,
                                    color: Color(0xFF0F172A),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 12),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: const Color(0xFFEFF6FF),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: const Color(0xFFDBEAFE)),
                          ),
                          child: const Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Icon(
                                Icons.info_outline_rounded,
                                color: Color(0xFF1D4ED8),
                                size: 18,
                              ),
                              SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  'If this adjustment has already been processed, the server may reject the deletion.',
                                  style: TextStyle(
                                    color: Color(0xFF1E3A8A),
                                    fontWeight: FontWeight.w800,
                                    height: 1.25,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                    child: Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            style: OutlinedButton.styleFrom(
                              foregroundColor: const Color(0xFF1D4ED8),
                              side: const BorderSide(color: Color(0xFF93C5FD)),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16),
                              ),
                              padding: const EdgeInsets.symmetric(vertical: 14),
                            ),
                            onPressed: () => Navigator.pop(ctx, false),
                            child: const Text(
                              'Cancel',
                              style: TextStyle(fontWeight: FontWeight.w900),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: FilledButton(
                            style: FilledButton.styleFrom(
                              backgroundColor: const Color(0xFFDC2626),
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16),
                              ),
                              padding: const EdgeInsets.symmetric(vertical: 14),
                            ),
                            onPressed: () => Navigator.pop(ctx, true),
                            child: const Text(
                              'Delete',
                              style: TextStyle(fontWeight: FontWeight.w900),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      );

      if (ok != true) return;

      final success = await context.read<AdjustmentProvider>().deleteAdjustment(
        context: context,
        idTransaction: t.idTransaction,
        removeFromListOnSuccess: true,
      );

      if (!context.mounted) return;

      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Adjustment deleted successfully')),
        );
        Navigator.pop(context, true);
      } else {
        final msg =
            context.read<AdjustmentProvider>().deleteAdjustmentError ??
            context.read<AdjustmentProvider>().lastError ??
            'Failed to delete adjustment';
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(msg)));
      }
    }

    Future<void> onEdit() async {
      final res = await Navigator.push<bool>(
        context,
        MaterialPageRoute(
          builder: (_) => AdjustmentFormScreen(
            initialTransaction: t,
            lockStoreOnEdit: true,
          ),
        ),
      );

      if (!context.mounted) return;

      // ✅ balik dari edit => langsung refresh detail
      if (res == true) {
        await _refreshDetail(showSnack: false);

        if (!context.mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Adjustment berhasil diubah')),
        );
      }
    }

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: Color(0xFF0F172A)),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          if (_refreshing)
            const Padding(
              padding: EdgeInsets.only(right: 8),
              child: Center(
                child: SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              ),
            ),
          IconButton(
            tooltip: 'Copy number',
            onPressed: () async {
              await Clipboard.setData(ClipboardData(text: number));
              if (!context.mounted) return;
              ScaffoldMessenger.of(
                context,
              ).showSnackBar(const SnackBar(content: Text('Copied')));
            },
            icon: const Icon(Icons.copy_rounded, color: Color(0xFF0F172A)),
          ),
          const SizedBox(width: 4),
        ],
      ),

      // ✅ Pull-to-refresh
      body: RefreshIndicator(
        color: AppColors.primary,
        onRefresh: () => _refreshDetail(showSnack: true),
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 90),
          children: [
            const SizedBox(height: 10),
            Center(
              child: Text(
                number,
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontWeight: FontWeight.w900,
                  fontSize: 28,
                  letterSpacing: 0.2,
                  color: Color(0xFF0F172A),
                ),
              ),
            ),
            const SizedBox(height: 12),
            _BlueCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _InfoRow(
                    icon: Icons.schedule_rounded,
                    label: 'Date & Time',
                    value: dtText,
                  ),
                  const SizedBox(height: 12),
                  _InfoRow(
                    icon: Icons.store_mall_directory_outlined,
                    label: 'Store',
                    value: store,
                    subValue: (storeSub ?? '').trim().isEmpty ? null : storeSub,
                  ),
                  if (note.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    _NoteBox(note: note),
                  ],
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: _StatBox(
                          icon: Icons.list_alt_rounded,
                          label: 'Items',
                          value: '$itemCount',
                          valueColor: const Color(0xFF0F172A),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _StatBox(
                          icon: Icons.swap_vert_rounded,
                          label: 'Net Qty',
                          value: netText,
                          valueColor: netColor,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                const Text(
                  'Items',
                  style: TextStyle(
                    fontWeight: FontWeight.w900,
                    fontSize: 16,
                    color: Color(0xFF0F172A),
                  ),
                ),
                const SizedBox(width: 10),
                _CountBadge(count: itemCount),
              ],
            ),
            const SizedBox(height: 10),
            if (t.items.isEmpty)
              const _EmptyItems()
            else
              ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: t.items.length,
                separatorBuilder: (_, __) => const SizedBox(height: 10),
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

                  final qtyColor = (it.netQty >= 0)
                      ? const Color(0xFF16A34A)
                      : const Color(0xFFDC2626);

                  return _ItemCard(
                    name: pName,
                    sku: sku,
                    qtyText: qtyText,
                    qtyColor: qtyColor,
                  );
                },
              ),
          ],
        ),
      ),

      bottomNavigationBar: SafeArea(
        top: false,
        child: Container(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 14),
          decoration: const BoxDecoration(
            color: Colors.white,
            border: Border(top: BorderSide(color: Color(0xFFE5E7EB))),
          ),
          child: SizedBox(
            height: 52,
            child: Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFFDC2626),
                      side: const BorderSide(color: Color(0xFFDC2626)),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    onPressed: busy ? null : onDelete,
                    icon: ap.deletingAdjustment
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.delete_rounded),
                    label: const Text(
                      'Delete',
                      style: TextStyle(
                        fontWeight: FontWeight.w900,
                        fontSize: 16,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: FilledButton.icon(
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    onPressed: busy ? null : onEdit,
                    icon: ap.editingAdjustment
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.edit_rounded),
                    label: const Text(
                      'Edit',
                      style: TextStyle(
                        fontWeight: FontWeight.w900,
                        fontSize: 16,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  static String _fmtFullDate(int unixSeconds) {
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
}

// ====== WIDGETS BAWAH INI TETAP SAMA (tidak aku ubah) ======

class _BlueCard extends StatelessWidget {
  final Widget child;
  final EdgeInsets padding;

  const _BlueCard({
    required this.child,
    this.padding = const EdgeInsets.all(14),
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFDBEAFE)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0C000000),
            blurRadius: 18,
            offset: Offset(0, 10),
          ),
        ],
      ),
      child: child,
    );
  }
}

/// ✅ Versi baru: `subValue` akan sejajar di bawah `value` (kolom kanan)
class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final String? subValue;

  const _InfoRow({
    required this.icon,
    required this.label,
    required this.value,
    this.subValue,
  });

  @override
  Widget build(BuildContext context) {
    final sub = (subValue ?? '').trim();
    final hasSub = sub.isNotEmpty;

    return Row(
      crossAxisAlignment: hasSub
          ? CrossAxisAlignment.start
          : CrossAxisAlignment.center,
      children: [
        Container(
          width: 30,
          height: 30,
          decoration: BoxDecoration(
            color: const Color(0xFFEFF6FF),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFFDBEAFE)),
          ),
          child: Icon(icon, size: 18, color: const Color(0xFF1D4ED8)),
        ),
        const SizedBox(width: 10),

        // label (kiri)
        Expanded(
          child: Padding(
            padding: EdgeInsets.only(top: hasSub ? 4 : 0),
            child: Text(
              label,
              style: const TextStyle(
                color: Color(0xFF64748B),
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
        ),
        const SizedBox(width: 12),

        // value + subValue (kanan) -> subValue sejajar di bawah value
        Flexible(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                value,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.right,
                style: const TextStyle(
                  fontWeight: FontWeight.w900,
                  color: Color(0xFF0F172A),
                ),
              ),
              if (hasSub) ...[
                const SizedBox(height: 6),
                Text(
                  sub,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.right,
                  style: const TextStyle(
                    color: Color(0xFF64748B),
                    fontWeight: FontWeight.w700,
                    height: 1.2,
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class _NoteBox extends StatelessWidget {
  final String note;
  const _NoteBox({required this.note});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFF),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFDBEAFE)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.notes_rounded, color: Color(0xFF2563EB), size: 18),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              note,
              style: const TextStyle(
                color: Color(0xFF334155),
                fontWeight: FontWeight.w700,
                height: 1.25,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _StatBox extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color valueColor;

  const _StatBox({
    required this.icon,
    required this.label,
    required this.value,
    required this.valueColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFF),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFDBEAFE)),
      ),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFDBEAFE)),
            ),
            child: Icon(icon, size: 18, color: const Color(0xFF1D4ED8)),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    color: Color(0xFF64748B),
                    fontWeight: FontWeight.w900,
                    fontSize: 12,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: TextStyle(
                    fontWeight: FontWeight.w900,
                    fontSize: 16,
                    color: valueColor,
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

class _CountBadge extends StatelessWidget {
  final int count;
  const _CountBadge({required this.count});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      decoration: BoxDecoration(
        color: const Color(0xFFEFF6FF),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: const Color(0xFFDBEAFE)),
      ),
      child: Text(
        '$count',
        style: const TextStyle(
          fontWeight: FontWeight.w900,
          color: Color(0xFF1D4ED8),
        ),
      ),
    );
  }
}

class _ItemCard extends StatelessWidget {
  final String name;
  final String sku;
  final String qtyText;
  final Color qtyColor;

  const _ItemCard({
    required this.name,
    required this.sku,
    required this.qtyText,
    required this.qtyColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFDBEAFE)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0C000000),
            blurRadius: 18,
            offset: Offset(0, 10),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontWeight: FontWeight.w900,
                    fontSize: 16,
                    color: Color(0xFF0F172A),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  sku,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Color(0xFF64748B),
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: qtyColor.withOpacity(0.10),
              borderRadius: BorderRadius.circular(999),
              border: Border.all(color: qtyColor.withOpacity(0.18)),
            ),
            child: Text(
              qtyText,
              style: TextStyle(
                fontWeight: FontWeight.w900,
                fontSize: 16,
                color: qtyColor,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptyItems extends StatelessWidget {
  const _EmptyItems();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFF),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFDBEAFE)),
      ),
      child: const Row(
        children: [
          Icon(Icons.inbox_rounded, color: Color(0xFF1D4ED8)),
          SizedBox(width: 10),
          Expanded(
            child: Text(
              'Tidak ada item pada adjustment ini.',
              style: TextStyle(
                fontWeight: FontWeight.w800,
                color: Color(0xFF334155),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
