// lib/screens/stock/stock_opname_list_screen.dart
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:shimmer/shimmer.dart';

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

  bool _adjustMode = false;
  final Set<String> _selectedOpnameIds = <String>{};

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

    try {
      return DateFormat('dd-MM-yyyy HH:mm').parseLoose(s);
    } catch (_) {}

    try {
      return DateFormat('yyyy-MM-dd HH:mm:ss').parseLoose(s);
    } catch (_) {}
    try {
      return DateFormat('yyyy-MM-dd HH:mm').parseLoose(s);
    } catch (_) {}

    final isoTry = s.replaceAll(' ', 'T');
    return DateTime.tryParse(isoTry);
  }

  String _monthNameLower(int month) {
    if (month < 1 || month > 12) return '';
    return _monthEn[month - 1];
  }

  String _formatCardDate(DateTime dt) {
    final hhmm = DateFormat('HH:mm').format(dt);
    return '${dt.day} ${_monthNameLower(dt.month)} $hhmm';
  }

  String _formatGroupHeader(DateTime dt) {
    final now = DateTime.now();
    final m = _monthNameLower(dt.month);
    if (dt.year == now.year) return m;
    return '$m ${dt.year}';
  }

  void _exitAdjustMode() {
    setState(() {
      _adjustMode = false;
      _selectedOpnameIds.clear();
    });
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
  }

  void _showSnack(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(
            message,
            style: const TextStyle(fontWeight: FontWeight.w800),
          ),
        ),
      );
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      await _ensureDefaultStoreSelected();
      await _fetchAllOrSelected(page: 1, append: false);
    });
  }

  Future<void> _fetchAllOrSelected({int? page, bool append = false}) async {
    final id = (_storeId ?? '').trim();
    await context.read<StockProvider>().fetchStockOpnames(
      context,
      idStoreLocation: id,
      page: page ?? 1,
      rowPerPage: 50,
      append: append,
    );
  }

  Future<void> _ensureDefaultStoreSelected() async {
    if ((_storeId ?? '').trim().isNotEmpty) return;

    var stores = context.read<StoreProvider>().stores;

    var tries = 0;
    while (stores.isEmpty && tries < 20) {
      await Future.delayed(const Duration(milliseconds: 120));
      if (!mounted) return;
      stores = context.read<StoreProvider>().stores;
      tries++;
    }

    if (stores.isEmpty) return;

    final first = stores.first;

    final id = (first.idStoreLocation ?? '').toString().trim();
    final name = (first.name ?? '').toString().trim();
    if (id.isEmpty) return;

    setState(() {
      _storeId = id;
      _storeName = name.isNotEmpty ? name : 'Store';
    });
  }

  Future<void> _pickStore() async {
    if (_adjustMode) return;

    final sp = context.read<StoreProvider>();
    if (sp.stores.isEmpty) return;

    final picked = await showStorePickerSheet(context, selectedId: _storeId);
    if (picked == null) return;

    final id = (picked.id ?? '').toString().trim();
    final name = (picked.label ?? '').toString().trim();
    if (id.isEmpty) return;

    setState(() {
      _storeId = id;
      _storeName = name.isNotEmpty ? name : 'Store';
    });

    await _fetchAllOrSelected(page: 1, append: false);
  }

  Future<void> _onRefresh() async {
    if (_adjustMode) _exitAdjustMode();
    await _fetchAllOrSelected(page: 1, append: false);
  }

  bool _isUnadjusted(StockOpname o) {
    final s = o.status.trim().toLowerCase();
    return s == 'not_adjusted' || s.contains('unadjusted');
  }

  List<String> _selectableIds(StockProvider prov) {
    final ids = <String>[];
    for (final o in prov.stockOpnames) {
      if (!_isUnadjusted(o)) continue;
      final id = o.idStockOpname.toString().trim();
      if (id.isNotEmpty) ids.add(id);
    }
    return ids;
  }

  void _toggleSelectAll(StockProvider prov) {
    if (prov.loadingStockOpnames) return;
    final ids = _selectableIds(prov);
    if (ids.isEmpty) {
      _showSnack('No "Unadjusted" records available to select.');
      return;
    }

    final allSelected = ids.every(_selectedOpnameIds.contains);

    setState(() {
      if (allSelected) {
        _selectedOpnameIds.clear();
      } else {
        _selectedOpnameIds
          ..clear()
          ..addAll(ids);
      }
    });
  }

  Future<void> _onAppBarAction() async {
    final prov = context.read<StockProvider>();

    if (prov.adjustingStockOpnames) return;

    if (!_adjustMode) {
      final sid = (_storeId ?? '').trim();
      if (sid.isEmpty) {
        _showSnack('Please select a store location first.');
        return;
      }

      setState(() {
        _adjustMode = true;
        _selectedOpnameIds.clear();
      });
      return;
    }

    if (_selectedOpnameIds.isEmpty) {
      _exitAdjustMode();
      return;
    }

    await _showAdjustmentBottomSheet();
  }

  String _appBarActionLabel() {
    if (!_adjustMode) return 'Adjust Stock';
    if (_selectedOpnameIds.isNotEmpty) return 'Adjust Stock';
    return 'Cancel';
  }

  Future<void> _showAdjustmentBottomSheet() async {
    final sid = (_storeId ?? '').trim();
    if (sid.isEmpty) {
      _showSnack('Please select a store location first.');
      return;
    }

    final selectedIds = _selectedOpnameIds.toList();
    if (selectedIds.isEmpty) return;

    await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      useSafeArea: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
      ),
      builder: (_) => _AdjustmentSheet(
        selectedCount: selectedIds.length,
        onSubmit: (note) async {
          final prov = context.read<StockProvider>();

          final res = await prov.stockOpnameBulkAdjustment(
            context: context,
            idStoreLocation: sid,
            stockOpnameIds: selectedIds,
            note: note,
            refreshListAfter: true,
          );

          if (!mounted) return false;

          if (res == null) {
            final err =
                (prov.stockOpnameAdjustmentError ?? prov.lastError ?? '')
                    .trim();
            _showSnack(err.isEmpty ? 'Failed to submit adjustment.' : err);
            return false;
          }

          final msg = (res.message.trim().isEmpty)
              ? 'Adjustment finished.'
              : res.message.trim();

          _exitAdjustMode();

          _showSnack(
            '$msg (Success: ${res.successCount}, Skipped: ${res.skipCount})',
          );
          return true;
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final stores = context.watch<StoreProvider>().stores;
    final stockProv = context.watch<StockProvider>();

    final storeLabel = ((_storeName ?? '').trim().isEmpty)
        ? 'Store'
        : _storeName!.trim();

    final actionLabel = _appBarActionLabel();
    final isCancel = _adjustMode && _selectedOpnameIds.isEmpty;

    final selectableIds = _adjustMode
        ? _selectableIds(stockProv)
        : const <String>[];
    final allSelected =
        _adjustMode &&
        selectableIds.isNotEmpty &&
        selectableIds.every(_selectedOpnameIds.contains);

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        scrolledUnderElevation: 0,
        elevation: 0,
        foregroundColor: const Color(0xFF111827),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded),
          onPressed: () {
            if (_adjustMode) {
              _exitAdjustMode();
              return;
            }
            Navigator.pop(context);
          },
        ),
        title: const Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.baseline,
          textBaseline: TextBaseline.alphabetic,
          children: [
            Text(
              'Stock Opname',
              style: TextStyle(
                fontWeight: FontWeight.w800,
                color: Color(0xFF111827),
              ),
            ),
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
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12, top: 8, bottom: 8),
            child: _BlueActionButton(
              label: actionLabel,
              loading: stockProv.adjustingStockOpnames,
              isOutline: isCancel,
              onPressed: stockProv.adjustingStockOpnames
                  ? null
                  : _onAppBarAction,
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 16),
          child: Column(
            children: [
              _TopBar(
                title: storeLabel,
                subtitle: 'Tap to change store location',
                enabled: stores.isNotEmpty && !_adjustMode,
                onPickStore: _pickStore,
              ),
              const SizedBox(height: 10),

              if (_adjustMode)
                _SelectionToolbar(
                  selectedCount: _selectedOpnameIds.length,
                  selectableCount: selectableIds.length,
                  allSelected: allSelected,
                  onToggleSelectAll: selectableIds.isEmpty
                      ? null
                      : () => _toggleSelectAll(stockProv),
                  onClear: _selectedOpnameIds.isEmpty
                      ? null
                      : () => setState(() => _selectedOpnameIds.clear()),
                ),

              if (_adjustMode) const SizedBox(height: 10),

              Expanded(
                child: Consumer<StockProvider>(
                  builder: (context, prov, _) {
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
                        color: AppColors.blueButton,
                        onRefresh: _onRefresh,
                        child: ListView(
                          physics: const AlwaysScrollableScrollPhysics(),
                          children: const [
                            SizedBox(height: 90),
                            Center(
                              child: Text(
                                'No stock opname history yet',
                                style: TextStyle(
                                  color: Color(0xFF6B7280),
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ),
                          ],
                        ),
                      );
                    }

                    // Sort newest first
                    final sorted = [...list];
                    sorted.sort((a, b) {
                      final da = _parseCreatedAt(a.createdAt);
                      final db = _parseCreatedAt(b.createdAt);
                      if (da == null && db == null) return 0;
                      if (da == null) return 1;
                      if (db == null) return -1;
                      return db.compareTo(da);
                    });

                    // Group by month
                    final rows = <_Row>[];
                    String? lastHeader;

                    for (final item in sorted) {
                      final dt = _parseCreatedAt(item.createdAt);
                      final header = dt == null
                          ? 'others'
                          : _formatGroupHeader(dt);

                      if (header != lastHeader) {
                        rows.add(_Row.header(header));
                        lastHeader = header;
                      }

                      rows.add(_Row.item(item, dt));
                    }

                    return RefreshIndicator(
                      color: AppColors.blueButton,
                      onRefresh: _onRefresh,
                      child: ListView.separated(
                        physics: const AlwaysScrollableScrollPhysics(),
                        padding: const EdgeInsets.fromLTRB(0, 2, 0, 8),
                        itemCount: rows.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 8),
                        itemBuilder: (_, i) {
                          final r = rows[i];
                          if (r.isHeader) {
                            return _MonthHeader(title: r.headerText!);
                          }

                          final opname = r.opname!;
                          final dt = r.createdDt;
                          final dateLabel = dt == null
                              ? (opname.createdAt.trim().isEmpty
                                    ? '-'
                                    : opname.createdAt)
                              : _formatCardDate(dt);

                          final canSelect = _isUnadjusted(opname);
                          final selected = _selectedOpnameIds.contains(
                            opname.idStockOpname,
                          );

                          Null toggle() {
                            if (!_adjustMode) return;
                            if (!canSelect) return;
                            setState(() {
                              final id = opname.idStockOpname;
                              if (_selectedOpnameIds.contains(id)) {
                                _selectedOpnameIds.remove(id);
                              } else {
                                _selectedOpnameIds.add(id);
                              }
                            });
                          }

                          if (!_adjustMode) {
                            return _OpnameCard(
                              opname: opname,
                              dateLabel: dateLabel,
                              adjustMode: false,
                              selectable: canSelect,
                              selected: false,
                              onToggleSelected: () {},
                            );
                          }

                          // Adjust mode
                          return Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Padding(
                                padding: const EdgeInsets.only(top: 8),
                                child: SizedBox(
                                  width: 22,
                                  height: 22,
                                  child: Checkbox(
                                    value: selected,
                                    onChanged: canSelect
                                        ? (_) => toggle()
                                        : null,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    activeColor: AppColors.blueButton,
                                    visualDensity: VisualDensity.compact,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: _OpnameCard(
                                  opname: opname,
                                  dateLabel: dateLabel,
                                  adjustMode: true,
                                  selectable: canSelect,
                                  selected: selected,
                                  onToggleSelected: toggle,
                                ),
                              ),
                            ],
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
    );
  }
}

// =======================
// Bottom sheet
// =======================
class _AdjustmentSheet extends StatefulWidget {
  final int selectedCount;
  final Future<bool> Function(String note) onSubmit;

  const _AdjustmentSheet({required this.selectedCount, required this.onSubmit});

  @override
  State<_AdjustmentSheet> createState() => _AdjustmentSheetState();
}

class _AdjustmentSheetState extends State<_AdjustmentSheet> {
  final TextEditingController _noteC = TextEditingController();
  bool _submitting = false;

  @override
  void dispose() {
    _noteC.dispose();
    super.dispose();
  }

  Future<bool> _showConfirmDialog() async {
    final res = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) {
        return Dialog(
          insetPadding: const EdgeInsets.symmetric(horizontal: 18),
          backgroundColor: Colors.transparent,
          elevation: 0,
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: const Color(0xFFE5E7EB)),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x24000000),
                  blurRadius: 26,
                  offset: Offset(0, 16),
                ),
              ],
            ),
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 14),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 42,
                      height: 42,
                      decoration: BoxDecoration(
                        color: const Color(0xFFFFF7ED),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: const Color(0xFFFED7AA)),
                      ),
                      child: const Icon(
                        Icons.warning_rounded,
                        color: Color(0xFF9A3412),
                      ),
                    ),
                    const SizedBox(width: 12),
                    const Expanded(
                      child: Text(
                        'Confirm Adjustment',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w900,
                          color: Color(0xFF111827),
                        ),
                      ),
                    ),
                    IconButton(
                      tooltip: 'Close',
                      onPressed: () => Navigator.of(context).pop(false),
                      icon: const Icon(
                        Icons.close_rounded,
                        color: Color(0xFF6B7280),
                      ),
                      visualDensity: const VisualDensity(
                        horizontal: -2,
                        vertical: -2,
                      ),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(
                        minWidth: 36,
                        minHeight: 36,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Text(
                  'You are about to adjust ${widget.selectedCount} stock opname record(s) to the system stock.',
                  style: const TextStyle(
                    color: Color(0xFF374151),
                    fontWeight: FontWeight.w800,
                    height: 1.35,
                  ),
                ),
                const SizedBox(height: 10),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 10,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFF7ED),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFFFED7AA)),
                  ),
                  child: const Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(
                        Icons.info_outline_rounded,
                        size: 18,
                        color: Color(0xFF9A3412),
                      ),
                      SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'This action may create stock adjustment transactions and cannot be undone.',
                          style: TextStyle(
                            color: Color(0xFF9A3412),
                            fontWeight: FontWeight.w800,
                            height: 1.35,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    Expanded(
                      child: SizedBox(
                        height: 44,
                        child: OutlinedButton(
                          onPressed: () => Navigator.of(context).pop(false),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: const Color(0xFF111827),
                            side: const BorderSide(color: Color(0xFFE5E7EB)),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: const Text(
                            'Cancel',
                            style: TextStyle(fontWeight: FontWeight.w900),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: SizedBox(
                        height: 44,
                        child: ElevatedButton(
                          onPressed: () => Navigator.of(context).pop(true),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.blueButton,
                            foregroundColor: Colors.white,
                            elevation: 0,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: const Text(
                            'Submit',
                            style: TextStyle(fontWeight: FontWeight.w900),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );

    return res == true;
  }

  Future<void> _submitFlow() async {
    if (_submitting) return;

    FocusScope.of(context).unfocus();

    final confirmed = await _showConfirmDialog();
    if (!confirmed) return;

    setState(() => _submitting = true);

    final ok = await widget.onSubmit(_noteC.text.trim());
    if (!mounted) return;

    setState(() => _submitting = false);

    if (ok) {
      Navigator.of(context).pop(true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return Padding(
      padding: EdgeInsets.only(
        left: 16,
        right: 16,
        top: 8,
        bottom: bottomInset > 0 ? bottomInset : 16,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 36,
              height: 4,
              margin: const EdgeInsets.only(bottom: 12),
              decoration: BoxDecoration(
                color: const Color(0xFFE5E7EB),
                borderRadius: BorderRadius.circular(99),
              ),
            ),
          ),
          Row(
            children: [
              const Expanded(
                child: Text(
                  'Adjust Stock',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                    color: Color(0xFF111827),
                  ),
                ),
              ),
              IconButton(
                tooltip: 'Close',
                onPressed: _submitting
                    ? null
                    : () => Navigator.of(context).pop(),
                icon: const Icon(Icons.close_rounded),
              ),
            ],
          ),
          Text(
            'Selected stock opname: ${widget.selectedCount}',
            style: const TextStyle(
              color: Color(0xFF6B7280),
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 14),
          const Text(
            'Adjustment note (optional)',
            style: TextStyle(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _noteC,
            textInputAction: TextInputAction.done,
            enabled: !_submitting,
            decoration: const InputDecoration(
              hintText: 'E.g. January adjustment',
              filled: true,
              fillColor: Color(0xFFF3F4F6),
              contentPadding: EdgeInsets.symmetric(
                horizontal: 14,
                vertical: 14,
              ),
              border: OutlineInputBorder(
                borderSide: BorderSide.none,
                borderRadius: BorderRadius.all(Radius.circular(12)),
              ),
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            height: 48,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.blueButton,
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                minimumSize: const Size.fromHeight(48),
              ),
              onPressed: _submitting ? null : _submitFlow,
              child: _submitting
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.5,
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                      ),
                    )
                  : const Text(
                      'Submit Adjustment Stock',
                      style: TextStyle(fontWeight: FontWeight.w900),
                    ),
            ),
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}

// =======================
// Rows & UI
// =======================
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
  final String title;
  final String subtitle;
  final bool enabled;
  final VoidCallback onPickStore;

  const _TopBar({
    required this.title,
    required this.subtitle,
    required this.enabled,
    required this.onPickStore,
  });

  @override
  Widget build(BuildContext context) {
    final disabled = !enabled;

    return InkWell(
      onTap: enabled ? onPickStore : null,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        decoration: BoxDecoration(
          color: const Color(0xFFF3F4F6),
          borderRadius: BorderRadius.circular(14),
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
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontWeight: FontWeight.w900,
                      color: Color(0xFF111827),
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    disabled ? 'Store selection is locked' : subtitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 12,
                      color: Color(0xFF6B7280),
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Icon(
              enabled ? Icons.expand_more_rounded : Icons.lock_rounded,
              color: const Color(0xFF6B7280),
            ),
          ],
        ),
      ),
    );
  }
}

class _SelectionToolbar extends StatelessWidget {
  final int selectedCount;
  final int selectableCount;
  final bool allSelected;
  final VoidCallback? onToggleSelectAll;
  final VoidCallback? onClear;

  const _SelectionToolbar({
    required this.selectedCount,
    required this.selectableCount,
    required this.allSelected,
    required this.onToggleSelectAll,
    required this.onClear,
  });

  @override
  Widget build(BuildContext context) {
    final disabled = selectableCount <= 0;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFFF9FAFB),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Row(
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: const Color(0xFFEFF6FF),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFDBEAFE)),
            ),
            child: const Icon(
              Icons.checklist_rounded,
              color: Color(0xFF1D4ED8),
              size: 18,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Selection mode',
                  style: TextStyle(
                    fontWeight: FontWeight.w900,
                    color: Color(0xFF111827),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  disabled
                      ? 'No selectable records (only "Unadjusted" can be selected)'
                      : 'Selected $selectedCount of $selectableCount',
                  style: const TextStyle(
                    fontSize: 12,
                    color: Color(0xFF6B7280),
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          if (onClear != null)
            _MiniTextButton(label: 'Clear', onPressed: onClear!),
          const SizedBox(width: 8),
          _MiniTextButton(
            label: allSelected ? 'Selected all' : 'Select all',
            onPressed: onToggleSelectAll,
          ),
        ],
      ),
    );
  }
}

class _MiniTextButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;

  const _MiniTextButton({required this.label, required this.onPressed});

  @override
  Widget build(BuildContext context) {
    final enabled = onPressed != null;

    return InkWell(
      onTap: onPressed,
      borderRadius: BorderRadius.circular(999),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: enabled ? const Color(0xFFEFF6FF) : const Color(0xFFF3F4F6),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(
            color: enabled ? const Color(0xFFDBEAFE) : const Color(0xFFE5E7EB),
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w900,
            color: enabled ? const Color(0xFF1D4ED8) : const Color(0xFF9CA3AF),
          ),
        ),
      ),
    );
  }
}

class _BlueActionButton extends StatelessWidget {
  final String label;
  final bool loading;
  final bool isOutline;
  final VoidCallback? onPressed;

  const _BlueActionButton({
    required this.label,
    required this.loading,
    required this.isOutline,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    final textStyle = const TextStyle(
      fontWeight: FontWeight.w900,
      fontSize: 12,
      height: 1,
    );

    final child = loading
        ? const SizedBox(
            width: 14,
            height: 14,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
            ),
          )
        : Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: textStyle,
          );

    final basePadding = const EdgeInsets.symmetric(horizontal: 10, vertical: 6);
    final radius = BorderRadius.circular(999);

    if (isOutline) {
      return ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 30),
        child: OutlinedButton(
          onPressed: onPressed,
          style: OutlinedButton.styleFrom(
            foregroundColor: AppColors.blueButton,
            side: BorderSide(color: AppColors.blueButton, width: 1.2),
            shape: RoundedRectangleBorder(borderRadius: radius),
            padding: basePadding,
            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            visualDensity: const VisualDensity(horizontal: -2, vertical: -2),
          ),
          child: loading
              ? const SizedBox(
                  width: 14,
                  height: 14,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : child,
        ),
      );
    }

    return ConstrainedBox(
      constraints: const BoxConstraints(minHeight: 30),
      child: ElevatedButton(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.blueButton,
          foregroundColor: Colors.white,
          elevation: 0,
          shape: RoundedRectangleBorder(borderRadius: radius),
          padding: basePadding,
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          visualDensity: const VisualDensity(horizontal: -2, vertical: -2),
        ),
        child: child,
      ),
    );
  }
}

// =======================
// ✅ Compact Card (more items per screen)
// - Remove branch/store name from card
// - Product + SKU grouped in one block
// - Reduced spacing/padding to fit 4–5 cards per screen
// =======================
class _OpnameCard extends StatelessWidget {
  final StockOpname opname;
  final String dateLabel;

  final bool adjustMode;
  final bool selectable;
  final bool selected;
  final VoidCallback onToggleSelected;

  const _OpnameCard({
    required this.opname,
    required this.dateLabel,
    required this.adjustMode,
    required this.selectable,
    required this.selected,
    required this.onToggleSelected,
  });

  String _prettyEnum(String s) {
    final t = s.trim();
    if (t.isEmpty) return '-';
    final parts = t.replaceAll('_', ' ').split(' ').where((e) => e.isNotEmpty);
    final titled = parts
        .map(
          (w) => w.length <= 1
              ? w.toUpperCase()
              : '${w[0].toUpperCase()}${w.substring(1).toLowerCase()}',
        )
        .join(' ');
    return titled.isEmpty ? '-' : titled;
  }

  @override
  Widget build(BuildContext context) {
    final productName = opname.product.name.toString().trim().isEmpty
        ? '-'
        : opname.product.name.toString().trim();

    final skuCode = opname.productSku.code.toString().trim().isEmpty
        ? '-'
        : opname.productSku.code.toString().trim();

    final statusText = _prettyEnum(opname.status);

    final variance = opname.variance;
    final counted = opname.countedQty;
    final system = opname.systemQty;

    final stLower = opname.status.trim().toLowerCase();

    Color badgeBg = const Color(0xFFF3F4F6);
    Color badgeFg = const Color(0xFF111827);
    if (stLower.contains('not_adjusted')) {
      badgeBg = const Color(0xFFFFFBEB);
      badgeFg = const Color(0xFF92400E);
    } else if (stLower.contains('adjusted')) {
      badgeBg = const Color(0xFFEFF6FF);
      badgeFg = const Color(0xFF1D4ED8);
    } else if (stLower.contains('validated') || stLower.contains('approved')) {
      badgeBg = const Color(0xFFDCFCE7);
      badgeFg = const Color(0xFF166534);
    } else if (stLower.contains('rejected')) {
      badgeBg = const Color(0xFFFEE2E2);
      badgeFg = const Color(0xFF991B1B);
    }

    final disabled = adjustMode && !selectable;
    final bgColor = disabled ? const Color(0xFFE5E7EB) : Colors.white;
    final borderColor = disabled
        ? const Color(0xFFD1D5DB)
        : const Color(0xFFE5E7EB);

    final content = Opacity(
      opacity: disabled ? 0.55 : 1.0,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // top row (date + badge) - compact
          Row(
            children: [
              Expanded(
                child: Text(
                  dateLabel,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Color(0xFF6B7280),
                    fontWeight: FontWeight.w800,
                    fontSize: 11,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
                decoration: BoxDecoration(
                  color: badgeBg,
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(color: const Color(0xFFE5E7EB)),
                ),
                child: Text(
                  statusText,
                  style: TextStyle(
                    fontWeight: FontWeight.w900,
                    fontSize: 11,
                    color: badgeFg,
                    height: 1,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),

          // Product + SKU grouped
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Container(
                width: 30,
                height: 30,
                decoration: BoxDecoration(
                  color: const Color(0xFFF9FAFB),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: const Color(0xFFE5E7EB)),
                ),
                child: const Icon(
                  Icons.inventory_2_rounded,
                  color: Color(0xFF111827),
                  size: 16,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      productName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontWeight: FontWeight.w900,
                        color: Color(0xFF111827),
                        fontSize: 13,
                        height: 1.1,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Row(
                      children: [
                        const Icon(
                          Icons.qr_code_2_rounded,
                          size: 14,
                          color: Color(0xFF6B7280),
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            skuCode,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 11,
                              color: Color(0xFF6B7280),
                              fontWeight: FontWeight.w800,
                              height: 1,
                              fontFamily: 'monospace',
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 8),

          // compact metrics row
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            decoration: BoxDecoration(
              color: const Color(0xFFF9FAFB),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFE5E7EB)),
            ),
            child: Row(
              children: [
                Expanded(
                  child: _KVCompact(label: 'Counted', value: '$counted'),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _KVCompact(label: 'System', value: '$system'),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _KVCompact(
                    label: 'Variance',
                    value: variance >= 0 ? '+$variance' : '$variance',
                    valueColor: variance == 0
                        ? const Color(0xFF111827)
                        : (variance > 0
                              ? const Color(0xFF166534)
                              : const Color(0xFF991B1B)),
                  ),
                ),
              ],
            ),
          ),

          // note: keep but super compact (no big card)
          if (opname.note.trim().isNotEmpty) ...[
            const SizedBox(height: 6),
            Row(
              children: [
                const Icon(
                  Icons.sticky_note_2_rounded,
                  size: 14,
                  color: Color(0xFF6B7280),
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    opname.note.trim(),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Color(0xFF6B7280),
                      fontWeight: FontWeight.w800,
                      fontSize: 11,
                      height: 1,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );

    return InkWell(
      onTap: adjustMode ? (selectable ? onToggleSelected : null) : () {},
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.fromLTRB(10, 10, 10, 10),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: borderColor),
          boxShadow: const [
            BoxShadow(
              color: Color(0x0F000000),
              blurRadius: 14,
              offset: Offset(0, 8),
            ),
          ],
        ),
        child: content,
      ),
    );
  }
}

// compact KV used by compact card
class _KVCompact extends StatelessWidget {
  final String label;
  final String value;
  final Color? valueColor;

  const _KVCompact({required this.label, required this.value, this.valueColor});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 11,
            color: Color(0xFF6B7280),
            fontWeight: FontWeight.w800,
            height: 1,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(
            fontSize: 13,
            color: valueColor ?? const Color(0xFF111827),
            fontWeight: FontWeight.w900,
            height: 1,
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
    separatorBuilder: (_, __) => const SizedBox(height: 8),
    itemBuilder: (_, __) {
      return Shimmer.fromColors(
        baseColor: const Color(0xFFE5E7EB),
        highlightColor: const Color(0xFFF3F4F6),
        child: Container(
          height: 118, // ✅ lebih pendek biar muat 4–5 card
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: const Color(0xFFE5E7EB)),
          ),
        ),
      );
    },
  );
}
