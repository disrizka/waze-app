// lib/screens/stock/stock_opname_list_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shimmer/shimmer.dart';
import 'package:intl/intl.dart';

import 'package:wa_blast/constants/app_colors.dart';
import 'package:wa_blast/providers/store_provider.dart';
import 'package:wa_blast/providers/stock_provider.dart';
import 'package:wa_blast/widgets/reusable_pickers.dart';

class StockOpnameListScreen extends StatefulWidget {
  const StockOpnameListScreen({super.key});

  @override
  State<StockOpnameListScreen> createState() => _StockOpnameListScreenState();
}

class _StockOpnameListScreenState extends State<StockOpnameListScreen> {
  String? _storeId;
  String? _storeName;

  static const _monthEn = <String>[
    'January',
    'February',
    'March',
    'April',
    'May',
    'June',
    'July',
    'August',
    'September',
    'October',
    'November',
    'December',
  ];

  DateTime? _parseCreatedAt(String raw) {
    final s = raw.trim();
    if (s.isEmpty) return null;

    // Common backend format from your example: "08-01-2026 11:16"
    try {
      return DateFormat('dd-MM-yyyy HH:mm').parseLoose(s);
    } catch (_) {}

    // Other common formats
    try {
      return DateFormat('yyyy-MM-dd HH:mm:ss').parseLoose(s);
    } catch (_) {}
    try {
      return DateFormat('yyyy-MM-dd HH:mm').parseLoose(s);
    } catch (_) {}

    // ISO fallback
    final isoTry = s.replaceAll(' ', 'T');
    final dt = DateTime.tryParse(isoTry);
    return dt;
  }

  String _monthNameLower(int month) {
    if (month < 1 || month > 12) return '';
    return _monthEn[month - 1];
  }

  String _formatCardDate(DateTime dt) {
    // "8 januari 11:16" (no year)
    final hhmm = DateFormat('HH:mm').format(dt);
    return '${dt.day} ${_monthNameLower(dt.month)} $hhmm';
  }

  String _formatGroupHeader(DateTime dt) {
    // Group header:
    // - current year => "januari"
    // - past year    => "januari 2025"
    final now = DateTime.now();
    final m = _monthNameLower(dt.month);
    if (dt.year == now.year) return m;
    return '$m ${dt.year}';
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      await _ensureDefaultStoreAndFetch();
    });
  }

  Future<void> _ensureDefaultStoreAndFetch() async {
    final sp = context.read<StoreProvider>();
    if (sp.stores.isEmpty) {
      setState(() {
        _storeId = null;
        _storeName = null;
      });
      return;
    }

    final first = sp.stores.first;
    final id = (first.idStoreLocation).toString().trim();
    final name = (first.name).toString().trim();
    if (id.isEmpty) return;

    setState(() {
      _storeId = id;
      _storeName = name.isNotEmpty ? name : 'Store';
    });

    await context.read<StockProvider>().fetchStockOpnames(
      context,
      idStoreLocation: id,
      page: 1,
      rowPerPage: 50,
      append: false,
    );
  }

  Future<void> _pickStore() async {
    final picked = await showStorePickerSheet(context, selectedId: _storeId);
    if (picked == null) return;

    final id = (picked.id ?? '').toString().trim();
    final name = (picked.label ?? '').toString().trim();
    if (id.isEmpty) return;

    setState(() {
      _storeId = id;
      _storeName = name.isNotEmpty ? name : 'Store';
    });

    await context.read<StockProvider>().fetchStockOpnames(
      context,
      idStoreLocation: id,
      page: 1,
      rowPerPage: 50,
      append: false,
    );
  }

  Future<void> _onRefresh() async {
    final id = (_storeId ?? '').trim();
    if (id.isEmpty) {
      await _ensureDefaultStoreAndFetch();
      return;
    }
    await context.read<StockProvider>().fetchStockOpnames(
      context,
      idStoreLocation: id,
      page: 1,
      rowPerPage: 50,
      append: false,
    );
  }

  @override
  Widget build(BuildContext context) {
    final sp = context.watch<StoreProvider>();

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        elevation: 0,
        scrolledUnderElevation: 0,
        backgroundColor: Colors.white,
        foregroundColor: const Color(0xFF111827),
        title: const Text(
          'Stock Opname',
          style: TextStyle(
            fontWeight: FontWeight.w800,
            color: Color(0xFF111827),
          ),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 16),
          child: Column(
            children: [
              _TopBar(
                storeName:
                    _storeName ??
                    (sp.stores.isNotEmpty ? sp.stores.first.name : null),
                onPickStore: _pickStore,
                onRetryDefault: _ensureDefaultStoreAndFetch,
                hasStore: (_storeId ?? '').isNotEmpty,
              ),
              const SizedBox(height: 10),
              Expanded(
                child: Consumer<StockProvider>(
                  builder: (context, prov, _) {
                    if (sp.stores.isEmpty) {
                      return _EmptyBox(
                        title: 'No store location',
                        message:
                            'Store location belum tersedia. Pastikan store sudah ter-load.',
                        actionText: 'Retry',
                        onAction: _ensureDefaultStoreAndFetch,
                      );
                    }

                    if ((_storeId ?? '').isEmpty) {
                      return _EmptyBox(
                        title: 'Select store',
                        message:
                            'Pilih store location untuk melihat stock opname.',
                        actionText: 'Choose store',
                        onAction: _pickStore,
                      );
                    }

                    if (prov.loadingStockOpnames) {
                      return _shimmerList();
                    }

                    final err = (prov.stockOpnamesError ?? '').trim();
                    if (err.isNotEmpty) {
                      return _EmptyBox(
                        title: 'Failed to load',
                        message: err,
                        actionText: 'Retry',
                        onAction: _onRefresh,
                      );
                    }

                    final list = prov.stockOpnames;
                    if (list.isEmpty) {
                      return RefreshIndicator(
                        onRefresh: _onRefresh,
                        child: ListView(
                          physics: const AlwaysScrollableScrollPhysics(),
                          children: const [
                            SizedBox(height: 90),
                            Center(
                              child: Text(
                                'No stock opname yet',
                                style: TextStyle(
                                  color: Color(0xFF6B7280),
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                          ],
                        ),
                      );
                    }

                    // Sort newest first (unknown dates last)
                    final sorted = [...list];
                    sorted.sort((a, b) {
                      final da = _parseCreatedAt(a.createdAt);
                      final db = _parseCreatedAt(b.createdAt);
                      if (da == null && db == null) return 0;
                      if (da == null) return 1;
                      if (db == null) return -1;
                      return db.compareTo(da);
                    });

                    // Build grouped rows (month grouping)
                    final rows = <_Row>[];
                    String? lastHeader;

                    for (final item in sorted) {
                      final dt = _parseCreatedAt(item.createdAt);
                      final header = dt == null
                          ? 'lainnya'
                          : _formatGroupHeader(dt);

                      if (header != lastHeader) {
                        rows.add(_Row.header(header));
                        lastHeader = header;
                      }

                      rows.add(_Row.item(item, dt));
                    }

                    return RefreshIndicator(
                      onRefresh: _onRefresh,
                      child: ListView.separated(
                        physics: const AlwaysScrollableScrollPhysics(),
                        padding: const EdgeInsets.fromLTRB(0, 2, 0, 8),
                        itemCount: rows.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 10),
                        itemBuilder: (_, i) {
                          final r = rows[i];
                          if (r.isHeader) {
                            return _MonthHeader(title: r.headerText!);
                          }
                          return _OpnameCard(
                            opname: r.opname!,
                            createdDt: r.createdDt,
                            dateLabel: r.createdDt == null
                                ? (r.opname!.createdAt.trim().isEmpty
                                      ? '-'
                                      : r.opname!.createdAt)
                                : _formatCardDate(r.createdDt!),
                          );
                        },
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
      bottomNavigationBar: SafeArea(
        minimum: const EdgeInsets.fromLTRB(12, 8, 12, 16),
        child: SizedBox(
          height: 48,
          width: double.infinity,
          child: ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.blueButton,
              foregroundColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            onPressed: () {
              Navigator.pushNamed(
                context,
                '/stock/opname/create',
                arguments: _storeId,
              );
            },
            child: const Text(
              'Create stock opname',
              style: TextStyle(fontWeight: FontWeight.w800),
            ),
          ),
        ),
      ),
    );
  }
}

class _Row {
  final bool isHeader;
  final String? headerText;

  final StockOpname? opname;
  final DateTime? createdDt;

  _Row.header(this.headerText)
    : isHeader = true,
      opname = null,
      createdDt = null;

  _Row.item(this.opname, this.createdDt) : isHeader = false, headerText = null;
}

class _MonthHeader extends StatelessWidget {
  final String title;
  const _MonthHeader({required this.title});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(2, 6, 2, 0),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
            decoration: BoxDecoration(
              color: const Color(0xFFF3F4F6),
              borderRadius: BorderRadius.circular(999),
              border: Border.all(color: const Color(0xFFE5E7EB)),
            ),
            child: Text(
              title,
              style: const TextStyle(
                fontWeight: FontWeight.w900,
                color: Color(0xFF111827),
              ),
            ),
          ),
          const SizedBox(width: 10),
          const Expanded(child: Divider(height: 1, color: Color(0xFFE5E7EB))),
        ],
      ),
    );
  }
}

class _TopBar extends StatelessWidget {
  final String? storeName;
  final VoidCallback onPickStore;
  final VoidCallback onRetryDefault;
  final bool hasStore;

  const _TopBar({
    required this.storeName,
    required this.onPickStore,
    required this.onRetryDefault,
    required this.hasStore,
  });

  @override
  Widget build(BuildContext context) {
    final title = (storeName ?? '').trim().isEmpty
        ? 'Select store'
        : storeName!;
    return Row(
      children: [
        Expanded(
          child: InkWell(
            onTap: onPickStore,
            borderRadius: BorderRadius.circular(12),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
              decoration: BoxDecoration(
                color: const Color(0xFFF3F4F6),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFE5E7EB)),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.storefront_rounded,
                    size: 18,
                    color: Color(0xFF4B5563),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF111827),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  const Icon(
                    Icons.expand_more_rounded,
                    color: Color(0xFF6B7280),
                  ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(width: 10),
        SizedBox(
          width: 44,
          height: 44,
          child: IconButton(
            tooltip: 'Reload',
            onPressed: onRetryDefault,
            style: IconButton.styleFrom(
              backgroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
                side: const BorderSide(color: Color(0xFFE5E7EB)),
              ),
            ),
            icon: const Icon(
              Icons.refresh_rounded,
              color: Color(0xFF111827),
              size: 20,
            ),
          ),
        ),
      ],
    );
  }
}

class _OpnameCard extends StatelessWidget {
  final StockOpname opname;
  final DateTime? createdDt;
  final String dateLabel;

  const _OpnameCard({
    required this.opname,
    required this.createdDt,
    required this.dateLabel,
  });

  String _prettyStatus(String s) {
    final t = s.trim();
    if (t.isEmpty) return '-';
    final cleaned = t.replaceAll('_', ' ');
    return cleaned[0].toUpperCase() + cleaned.substring(1);
  }

  String _shortId(String id) {
    final t = id.trim();
    if (t.isEmpty) return '-';
    if (t.length <= 10) return t;
    return '${t.substring(0, 6)}…${t.substring(t.length - 4)}';
  }

  @override
  Widget build(BuildContext context) {
    final status = _prettyStatus(opname.status);

    final items = opname.items;
    final itemsCount = items.length;

    // Product headline:
    String primaryProductName = '-';
    String? primarySkuCode;
    int extraCount = 0;

    if (items.isNotEmpty) {
      final first = items.first;
      final pname = (first.product.name).toString().trim();
      primaryProductName = pname.isEmpty ? '-' : pname;

      final code = (first.productSku.code).toString().trim();
      primarySkuCode = code.isEmpty ? null : code;

      extraCount = (items.length - 1).clamp(0, 999999);
    }

    // Totals
    int sumVariance = 0;
    int sumCounted = 0;
    int sumSystem = 0;
    for (final it in items) {
      sumVariance += it.variance;
      sumCounted += it.countedQty;
      sumSystem += it.systemQty;
    }

    // Status badge colors
    final st = opname.status.trim().toLowerCase();
    final Color badgeBg;
    final Color badgeFg;
    if (st == 'validated' || st == 'approved') {
      badgeBg = const Color(0xFFDCFCE7);
      badgeFg = const Color(0xFF166534);
    } else if (st == 'rejected') {
      badgeBg = const Color(0xFFFEE2E2);
      badgeFg = const Color(0xFF991B1B);
    } else {
      badgeBg = const Color(0xFFEFF6FF);
      badgeFg = const Color(0xFF1D4ED8);
    }

    return InkWell(
      onTap: () {
        // TODO: detail screen
      },
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFE5E7EB)),
          boxShadow: const [
            BoxShadow(
              color: Color(0x12000000),
              blurRadius: 18,
              offset: Offset(0, 10),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // HEADER: date label (no year) + status
            Row(
              children: [
                SizedBox(height: 10),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: badgeBg,
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(color: const Color(0xFFE5E7EB)),
                  ),
                  child: Text(
                    dateLabel,
                    style: TextStyle(
                      fontWeight: FontWeight.w900,
                      fontSize: 12,
                      color: badgeFg,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),

            // PRODUCT LINE
            _ProductLine(
              productName: primaryProductName,
              skuCode: primarySkuCode,
              extraCount: extraCount,
            ),

            const SizedBox(height: 10),

            // QUICK PILLS
            Row(
              children: [
                _TinyPill(
                  icon: Icons.format_list_bulleted_rounded,
                  text: '$itemsCount item',
                ),
                const SizedBox(width: 8),
                _CountChip(variance: sumVariance),
              ],
            ),

            const SizedBox(height: 10),

            // SUMMARY BOX
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
              decoration: BoxDecoration(
                color: const Color(0xFFF9FAFB),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFE5E7EB)),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: _KV(label: 'Counted', value: '$sumCounted'),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _KV(label: 'System', value: '$sumSystem'),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _KV(
                      label: 'Variance',
                      value: sumVariance >= 0
                          ? '+$sumVariance'
                          : '$sumVariance',
                      valueColor: sumVariance == 0
                          ? const Color(0xFF111827)
                          : (sumVariance > 0
                                ? const Color(0xFF166534)
                                : const Color(0xFF991B1B)),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 10),
          ],
        ),
      ),
    );
  }
}

class _ProductLine extends StatelessWidget {
  final String productName;
  final String? skuCode;
  final int extraCount;

  const _ProductLine({
    required this.productName,
    required this.skuCode,
    required this.extraCount,
  });

  @override
  Widget build(BuildContext context) {
    final showExtra = extraCount > 0;

    return Row(
      children: [
        Container(
          width: 34,
          height: 34,
          decoration: BoxDecoration(
            color: const Color(0xFFEFF6FF),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFFE5E7EB)),
          ),
          child: const Icon(
            Icons.inventory_2_rounded,
            color: Color(0xFF1D4ED8),
            size: 18,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      productName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontWeight: FontWeight.w900,
                        color: Color(0xFF111827),
                      ),
                    ),
                  ),
                  if (showExtra) ...[
                    const SizedBox(width: 8),
                    Container(
                      width: 24,
                      height: 24,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: const Color(0xFF111827),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(
                        '+$extraCount',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 11,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
              if ((skuCode ?? '').trim().isNotEmpty) ...[
                const SizedBox(height: 2),
                Text(
                  'SKU: $skuCode',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Color(0xFF6B7280),
                    fontWeight: FontWeight.w700,
                    fontSize: 12,
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

class _CountChip extends StatelessWidget {
  final int variance;
  const _CountChip({required this.variance});

  @override
  Widget build(BuildContext context) {
    final Color bg;
    final Color fg;
    final String text;

    if (variance == 0) {
      bg = const Color(0xFFF3F4F6);
      fg = const Color(0xFF111827);
      text = 'Variance 0';
    } else if (variance > 0) {
      bg = const Color(0xFFDCFCE7);
      fg = const Color(0xFF166534);
      text = 'Variance +$variance';
    } else {
      bg = const Color(0xFFFEE2E2);
      fg = const Color(0xFF991B1B);
      text = 'Variance $variance';
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.compare_arrows_rounded, size: 16, color: fg),
          const SizedBox(width: 6),
          Text(
            text,
            style: TextStyle(
              fontWeight: FontWeight.w900,
              fontSize: 12,
              color: fg,
            ),
          ),
        ],
      ),
    );
  }
}

class _TinyPill extends StatelessWidget {
  final IconData icon;
  final String text;
  const _TinyPill({required this.icon, required this.text});

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
          Icon(icon, size: 16, color: const Color(0xFF4B5563)),
          const SizedBox(width: 6),
          Text(
            text,
            style: const TextStyle(
              fontWeight: FontWeight.w900,
              fontSize: 12,
              color: Color(0xFF111827),
            ),
          ),
        ],
      ),
    );
  }
}

class _KV extends StatelessWidget {
  final String label;
  final String value;
  final Color? valueColor;
  const _KV({required this.label, required this.value, this.valueColor});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 12,
            color: Color(0xFF6B7280),
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 3),
        Text(
          value,
          style: TextStyle(
            fontSize: 14,
            color: valueColor ?? const Color(0xFF111827),
            fontWeight: FontWeight.w900,
          ),
        ),
      ],
    );
  }
}

class _EmptyBox extends StatelessWidget {
  final String title;
  final String message;
  final String actionText;
  final VoidCallback onAction;

  const _EmptyBox({
    required this.title,
    required this.message,
    required this.actionText,
    required this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 18),
        child: Container(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 14),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFFE5E7EB)),
            boxShadow: const [
              BoxShadow(
                color: Color(0x11000000),
                blurRadius: 18,
                offset: Offset(0, 10),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontWeight: FontWeight.w900,
                  color: Color(0xFF111827),
                  fontSize: 16,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                message,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Color(0xFF6B7280),
                  height: 1.35,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                height: 44,
                width: double.infinity,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.blueButton,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  onPressed: onAction,
                  child: Text(
                    actionText,
                    style: const TextStyle(fontWeight: FontWeight.w900),
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

Widget _shimmerList() {
  return ListView.separated(
    padding: const EdgeInsets.fromLTRB(0, 2, 0, 8),
    itemCount: 8,
    separatorBuilder: (_, __) => const SizedBox(height: 10),
    itemBuilder: (_, __) {
      return Shimmer.fromColors(
        baseColor: const Color(0xFFE5E7EB),
        highlightColor: const Color(0xFFF3F4F6),
        child: Container(
          height: 132,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFFE5E7EB)),
          ),
        ),
      );
    },
  );
}
