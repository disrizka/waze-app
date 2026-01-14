import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:wa_blast/models/product_model.dart';
import 'package:wa_blast/providers/product_provider.dart';
import 'package:wa_blast/providers/sales_provider.dart';
import 'package:wa_blast/providers/store_provider.dart' as st;

import '../../../constants/app_colors.dart';
import '../../../constants/design_system.dart';
import '../../../widgets/stepper_header.dart';
import '../../../widgets/reusable_pickers.dart';

// ===============================
// Minimal UI helpers (theme tokens)
// ===============================

Future<bool?> openAddProductSheet(BuildContext context) async {
  final parentSp = context.read<SalesProvider>();

  return showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: Colors.white,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
    ),
    builder: (_) => ChangeNotifierProvider<SalesProvider>.value(
      value: parentSp,
      child: const AddProductSheet(),
    ),
  );
}

// ===============================
// MAKE ORDER STEP (customer OPTIONAL)
// ===============================

class MakeOrderStep extends StatefulWidget {
  final bool withHeader;
  const MakeOrderStep({super.key, this.withHeader = true});

  @override
  State<MakeOrderStep> createState() => _MakeOrderStepState();
}

class _MakeOrderStepState extends State<MakeOrderStep> {
  final _discountC = TextEditingController();
  final _notesC = TextEditingController();

  String? _customerId;
  String? _customerName;

  Future<void> _autoSelectSingleStoreIfNeeded() async {
    final sales = context.read<SalesProvider>();
    final alreadySelected = (sales.storeLocationId ?? '').isNotEmpty;
    if (alreadySelected) return;

    final sp = context.read<st.StoreProvider>();
    // Pastikan stores sudah tersedia
    if (sp.stores.isEmpty && !sp.loadingList) {
      await sp.fetchStoreLocations(context);
    }

    if (!mounted) return;

    // Kalau cuma 1 store → set otomatis
    if (sp.stores.length == 1) {
      final s = sp.stores.first;

      // Set ke SalesProvider
      sales.setOrderMeta(
        storeLocationId: s.idStoreLocation,
        storeLocationName: s.name,
      );

      // Sinkronkan ProductProvider (paging/filternya)
      await context.read<ProductProvider>().setInfiniteStoreAndRefresh(
        context,
        s.idStoreLocation,
      );

      if (mounted) setState(() {});
    }
  }

  Future<void> _pickStore() async {
    final picked = await showStorePickerSheet(
      autoSelectWhenSingle: true,
      context,
      selectedId: context.read<SalesProvider>().storeLocationId,
    );
    if (picked == null || !mounted) return;

    context.read<SalesProvider>().setOrderMeta(
      storeLocationId: picked.id,
      storeLocationName: picked.label,
    );

    // sinkronkan filter product paging
    final prodProv = context.read<ProductProvider>();
    await prodProv.setInfiniteStoreAndRefresh(context, picked.id);

    setState(() {}); // repaint UI
  }

  @override
  void initState() {
    super.initState();
    final prov = context.read<SalesProvider>();
    _discountC.text = (prov.discount ?? 0).toString();
    _notesC.text = prov.note ?? '';

    _customerId = prov.customerId;
    _customerName = prov.customerName ?? '';

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      context.read<SalesProvider>()
        ..ensureReferenceInitialized(notify: true)
        ..normalizeCart();

      // 🔽 AUTO SELECT STORE kalau cuma ada 1
      await _autoSelectSingleStoreIfNeeded();
    });
  }

  @override
  void dispose() {
    _discountC.dispose();
    _notesC.dispose();
    super.dispose();
  }

  /// Subtotal setelah diskon per item (tanpa alokasi order discount)
  int _subtotalPerItemOnly(SalesProvider prov) {
    var sum = 0;
    for (final it in prov.cartItems) {
      final sku = it.sku;
      final perItemDisc = prov.perItemDiscountOf(sku.skuId);
      final unitAfterItem = (sku.price - perItemDisc).clamp(0, 1 << 31) as int;
      sum += unitAfterItem * it.qty;
    }
    return sum;
  }

  // Service fee ditiadakan → selalu 0
  int _serviceFeeOn(int base) => 0;

  // total akhir = subtotal (per-item only) + fee(=0) - adjustment
  (int subtotal, int fee, int total) _totals(
    SalesProvider prov,
    int adjustment,
  ) {
    final sub = _subtotalPerItemOnly(prov);
    final fee = 0; // dihapus
    final grand = (sub + fee - adjustment).clamp(0, 1 << 31) as int;
    return (sub, fee, grand);
  }

  Future<void> _pickCustomer() async {
    final picked = await showCustomerPickerSheet(
      context,
      selectedId: _customerId,
    );
    if (picked == null || !mounted) return;

    setState(() {
      _customerId = picked.id;
      _customerName = picked.label;
    });

    // persist ke SalesProvider
    context.read<SalesProvider>().setOrderMeta(
      customerId: picked.id,
      customerName: picked.label,
    );
  }

  void _clearCustomer() {
    setState(() {
      _customerId = null;
      _customerName = '';
    });
    context.read<SalesProvider>().setOrderMeta(
      customerId: null,
      customerName: null,
    );
  }

  Future<void> _editReferenceDialog() async {
    final prov = context.read<SalesProvider>();

    final newRef = await showDialog<String>(
      context: context,
      builder: (_) => _EditReferenceDialog(
        initial: prov.currentReference ?? prov.generateDefaultReference(),
      ),
    );

    if (!mounted || newRef == null) return;
    final v = newRef.trim();
    if (v.isEmpty) return;

    prov.setOrderMeta(reference: v);
  }

  @override
  Widget build(BuildContext context) {
    final cartLen = context.select<SalesProvider, int>((p) => p.cartLen);
    final prov = context.watch<SalesProvider>();
    final storeId = prov.storeLocationId;
    final storeName = prov.storeLocationName;

    final adjustment = int.tryParse(_discountC.text.trim()) ?? 0;
    final (sub, fee, grand) = _totals(prov, adjustment);

    final bool storeNotSelected = (storeId == null || storeId!.isEmpty);

    return Container(
      color: UI.bg,
      child: Column(
        children: [
          if (widget.withHeader) const StepperHeader(activeIndex: 1),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                // ============ STORE SELECTOR (REQUIRED) ============
                _Section(
                  titleWidget: Row(
                    children: [
                      const Icon(
                        Icons.store_mall_directory_outlined,
                        size: 18,
                        color: UI.sub,
                      ),
                      const SizedBox(width: 8),
                      const Text('Store Location', style: UI.tsSub),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.background,
                          borderRadius: BorderRadius.circular(999),
                          border: Border.all(color: AppColors.blueAccent),
                        ),
                        child: const Text(
                          'Required',
                          style: TextStyle(
                            color: AppColors.blue,
                            fontWeight: FontWeight.w700,
                            fontSize: 11,
                          ),
                        ),
                      ),
                    ],
                  ),
                  child: SelectFieldTile(
                    label: 'Choose a store',
                    valueText: storeName, // dari provider
                    emptyHint: 'Select store…',
                    onTap: _pickStore,
                  ),
                ),

                // ============ CUSTOMER (OPTIONAL) ============
                const SizedBox(height: 12),
                _Section(
                  titleWidget: Row(
                    children: [
                      const Icon(Icons.person_outline, size: 18, color: UI.sub),
                      const SizedBox(width: 8),
                      const Text('Customer', style: UI.tsSub),
                      const SizedBox(width: 8),
                      const Spacer(),
                      if ((_customerId ?? '').isNotEmpty)
                        TextButton.icon(
                          onPressed: _clearCustomer,
                          style: TextButton.styleFrom(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 6,
                            ),
                            minimumSize: Size.zero,
                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                            foregroundColor: AppColors.textSecondary,
                          ),
                          icon: const Icon(Icons.backspace_outlined, size: 16),
                          label: const Text(
                            'Clear',
                            style: TextStyle(fontWeight: FontWeight.w700),
                          ),
                        ),
                    ],
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: SelectFieldTile(
                          label: 'Choose customer',
                          valueText: _customerName?.isNotEmpty == true
                              ? _customerName
                              : null,
                          emptyHint: 'Select customer...',
                          onTap: _pickCustomer,
                        ),
                      ),
                    ],
                  ),
                ),

                // ============ NOTES (OPTIONAL) ============
                const SizedBox(height: 12),
                _Section(
                  titleWidget: Row(
                    children: const [
                      Icon(Icons.note_alt_outlined, size: 18, color: UI.sub),
                      SizedBox(width: 8),
                      Text('Notes', style: UI.tsSub),
                    ],
                  ),
                  child: TextFormField(
                    controller: _notesC,
                    decoration: InputDecoration(
                      hintText: 'Optional notes for this order...',
                      isDense: true,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: const BorderSide(color: UI.line),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: const BorderSide(color: AppColors.primary),
                      ),
                    ),
                    maxLines: 2,
                    onChanged: (t) => context
                        .read<SalesProvider>()
                        .setOrderMeta(note: t.trim()),
                  ),
                ),
              ],
            ),
          ),

          // CTA minimal
          SafeArea(
            minimum: const EdgeInsets.fromLTRB(16, 8, 16, 16),
            child: SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: (!storeNotSelected)
                    ? () {
                        final d = int.tryParse(_discountC.text.trim()) ?? 0;
                        // kirim discount, customer, dan notes
                        context.read<SalesProvider>().setOrderMeta(
                          discount: d,
                          note: _notesC.text.trim(),
                          customerId: (_customerId?.isNotEmpty == true)
                              ? _customerId
                              : null,
                          customerName: (_customerId?.isNotEmpty == true)
                              ? _customerName
                              : null,
                        );
                        context.read<SalesProvider>().goTo(1);
                      }
                    : null,
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  textStyle: const TextStyle(fontWeight: FontWeight.w700),
                ),
                child: const Text('Check Order'),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ====== Order Summary — Compact List (auto height, scroll only if > 5) ======
Widget _orderSummaryList(SalesProvider prov, BuildContext context) {
  if (prov.cartLen == 0) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: UI.bg,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: const [
          Icon(Icons.inventory_2_outlined, color: UI.sub),
          SizedBox(width: 10),
          Expanded(
            child: Text(
              'Belum ada item. Tambahkan produk dari katalog.',
              style: UI.tsSub,
            ),
          ),
        ],
      ),
    );
  }

  const double _rowExtent = 86.0; // tinggi 1 baris
  final bool isTablet = MediaQuery.of(context).size.shortestSide >= 600;
  final int maxVisible = isTablet ? 9 : 4;

  final bool needScroll = prov.cartLen > maxVisible;
  final controller = ScrollController();

  final list = ListView.separated(
    controller: needScroll ? controller : null,
    padding: EdgeInsets.zero,
    itemCount: prov.cartItems.length,
    shrinkWrap: !needScroll,
    physics: needScroll
        ? const AlwaysScrollableScrollPhysics()
        : const NeverScrollableScrollPhysics(),
    separatorBuilder: (_, __) => const Divider(height: 1, color: UI.line),
    itemBuilder: (context, i) {
      final it = prov.cartItems[i];
      final sku = it.sku;

      // ⬇️ Tambahan: hitung line total (harga efek per item × qty)
      final itemDisc = prov.perItemDiscountOf(sku.skuId);
      final unitAfterItem = (sku.price - itemDisc).clamp(0, 1 << 31) as int;
      final lineTotal = unitAfterItem * it.qty;

      return SizedBox(
        height: _rowExtent,
        child: _OrderItemTile(
          imageUrl: sku.imageUrl,
          productName: sku.productName,
          skuCode: sku.skuCode,
          qty: it.qty,
          lineTotal: lineTotal, // ⬅️ kirim ke tile
          onMinus: () => prov.removeOne(sku),
          onPlus: () => prov.add(sku),
        ),
      );
    },
  );

  if (!needScroll) return list;
  final double maxHeight = (_rowExtent * maxVisible) + (1.0 * (maxVisible - 1));

  return ConstrainedBox(
    constraints: BoxConstraints(maxHeight: maxHeight),
    child: Scrollbar(
      controller: controller,
      thumbVisibility: true,
      radius: const Radius.circular(999),
      child: list,
    ),
  );
}

// ====== Compact DataTable builder (minimal look) ======
Widget _orderTable(int cartLen, SalesProvider prov) {
  if (cartLen == 0) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: UI.bg,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: const [
          Icon(Icons.inventory_2_outlined, color: UI.sub),
          SizedBox(width: 10),
          Expanded(
            child: Text(
              'Belum ada item. Tambahkan produk dari katalog.',
              style: UI.tsSub,
            ),
          ),
        ],
      ),
    );
  }

  const minTableWidth = 900.0;
  const _rowHeight = 52.0;
  const _headHeight = 40.0;
  const _visibleRows = 7;

  final needsVerticalScroll = prov.cartItems.length > _visibleRows;
  final tableViewportHeight = _headHeight + (_rowHeight * _visibleRows) + 12;

  const _wQty = 108.0;
  const _wDisc = 132.0;
  const _wUnit = 112.0;
  const _wLineTotal = 136.0;

  Widget _hRight(String t, double w) => SizedBox(
    width: w,
    child: Align(alignment: Alignment.centerRight, child: Text(t)),
  );
  Widget _cRight(Widget child, double w) => SizedBox(
    width: w,
    child: Align(alignment: Alignment.centerRight, child: child),
  );

  final table = DataTable(
    horizontalMargin: 10,
    columnSpacing: 14,
    headingRowHeight: _headHeight,
    dataRowMinHeight: 48,
    dataRowMaxHeight: 56,
    dividerThickness: .6,
    headingTextStyle: UI.tsSub.copyWith(fontSize: 11),
    columns: [
      const DataColumn(label: Text('Product')),
      const DataColumn(label: Text('SKU')),
      DataColumn(label: _hRight('Qty', _wQty)),
      DataColumn(label: _hRight('Disc/Item', _wDisc)),
      DataColumn(label: _hRight('Unit (Base)', _wUnit)),
      DataColumn(label: _hRight('Unit (Effective)', _wUnit)),
      DataColumn(label: _hRight('Line Total', _wLineTotal)),
      const DataColumn(label: Text('')),
    ],
    rows: prov.cartItems.map((it) {
      final sku = it.sku;
      final skuId = sku.skuId;

      // ambil disc dari provider
      final itemDisc = prov.perItemDiscountOf(skuId);
      final unitAfterItem = (sku.price - itemDisc).clamp(0, 1 << 31) as int;
      final lineTotal = unitAfterItem * it.qty;
      final money = NumberFormat.decimalPattern('id_ID');

      Widget thumb() {
        final fallback = Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: UI.bg,
            borderRadius: BorderRadius.circular(8),
          ),
          child: const Icon(Icons.image, color: UI.sub, size: 18),
        );
        return ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: (sku.imageUrl.isNotEmpty)
              ? Image.network(
                  sku.imageUrl,
                  width: 36,
                  height: 36,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => fallback,
                )
              : fallback,
        );
      }

      return DataRow(
        cells: [
          // Product
          DataCell(
            Row(
              children: [
                thumb(),
                const SizedBox(width: 10),
                Flexible(
                  child: Text(
                    sku.productName,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                ),
              ],
            ),
          ),

          // SKU
          DataCell(
            Text(
              sku.skuCode,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: UI.tsSub,
            ),
          ),

          // Qty
          DataCell(
            _cRight(
              _QtyEditor2(
                qty: it.qty,
                onMinus: () => prov.removeOne(sku),
                onPlus: () => prov.add(sku),
                onTyped: (v) {
                  final cur = it.qty;
                  if (v <= 0) {
                    for (var i = 0; i < cur; i++) prov.removeOne(sku);
                  } else if (v > cur) {
                    for (var i = 0; i < (v - cur); i++) prov.add(sku);
                  } else if (v < cur) {
                    for (var i = 0; i < (cur - v); i++) prov.removeOne(sku);
                  }
                },
              ),
              _wQty,
            ),
          ),

          // Disc/Item
          DataCell(
            _cRight(
              SizedBox(
                width: _wDisc,
                child: TextFormField(
                  initialValue: itemDisc.toString(),
                  textAlign: TextAlign.right,
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  decoration: InputDecoration(
                    isDense: true,
                    border: UI.thinBorder(),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 8,
                    ),
                    prefixText: 'Rp ',
                  ),
                  onChanged: (v) => prov.setPerItemDiscount(
                    skuId: skuId,
                    discountPerItem: int.tryParse(v) ?? 0,
                  ),
                ),
              ),
              _wDisc,
            ),
          ),

          // Unit (Base)
          DataCell(_cRight(Text(money.format(sku.price)), _wUnit)),

          // Unit (Effective)
          DataCell(
            _cRight(
              Text(
                money.format(unitAfterItem),
                style: TextStyle(
                  fontWeight: itemDisc > 0 ? FontWeight.w800 : FontWeight.w700,
                ),
              ),
              _wUnit,
            ),
          ),

          // Line Total
          DataCell(
            _cRight(
              Text(
                money.format(lineTotal),
                style: const TextStyle(fontWeight: FontWeight.w800),
              ),
              _wLineTotal,
            ),
          ),

          // Remove
          DataCell(
            IconButton(
              tooltip: 'Remove',
              icon: const Icon(Icons.delete_outline, color: UI.sub),
              onPressed: () {
                for (var i = 0; i < it.qty; i++) {
                  prov.removeOne(sku);
                }
                // Provider membersihkan diskon terkait SKU ketika remove
              },
            ),
          ),
        ],
      );
    }).toList(),
  );

  return SingleChildScrollView(
    scrollDirection: Axis.horizontal,
    child: ConstrainedBox(
      constraints: const BoxConstraints(minWidth: minTableWidth),
      child: needsVerticalScroll
          ? ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: SizedBox(
                height: tableViewportHeight,
                child: Scrollbar(
                  thumbVisibility: true,
                  thickness: 6,
                  radius: const Radius.circular(999),
                  child: SingleChildScrollView(child: table),
                ),
              ),
            )
          : table,
    ),
  );
}

// ======= UI HELPERS =======

class _Section extends StatelessWidget {
  final String? title;
  final Widget? titleWidget;
  final Widget child;

  const _Section({this.title, this.titleWidget, required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: UI.card,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: UI.line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (titleWidget != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: titleWidget!,
            )
          else if (title != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Text(title!, style: UI.tsBody.copyWith(color: UI.sub)),
            ),
          child,
        ],
      ),
    );
  }
}

class _OrderItemTile extends StatelessWidget {
  final String imageUrl;
  final String productName;
  final String skuCode;
  final int qty;
  final int lineTotal; // ⬅️ NEW
  final VoidCallback onMinus;
  final VoidCallback onPlus;

  const _OrderItemTile({
    Key? key,
    required this.imageUrl,
    required this.productName,
    required this.skuCode,
    required this.qty,
    required this.lineTotal, // ⬅️ NEW
    required this.onMinus,
    required this.onPlus,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final money = NumberFormat.decimalPattern('id_ID'); // format Rp
    return SizedBox(
      height: 86, // sinkron dengan _rowExtent
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          _thumb(imageUrl),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Nama produk
                Text(
                  productName,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 4),
                // SKU Code
                Text(
                  skuCode,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: UI.tsSub,
                ),
                const SizedBox(height: 4),
                // ⬇️ TOTAL per SKU (line total)
                Text(
                  'Rp ${money.format(lineTotal)}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontWeight: FontWeight.w800,
                    color: AppColors.success,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          _qtyPill(qty, onMinus, onPlus),
        ],
      ),
    );
  }

  Widget _thumb(String url) {
    final fallback = Container(
      width: 64,
      height: 64,
      decoration: BoxDecoration(
        color: UI.bg,
        borderRadius: BorderRadius.circular(12),
      ),
      child: const Icon(Icons.image, color: UI.sub),
    );
    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: (url.isNotEmpty)
          ? Image.network(
              url,
              width: 64,
              height: 64,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => fallback,
            )
          : fallback,
    );
  }

  Widget _qtyPill(int qty, VoidCallback onMinus, VoidCallback onPlus) {
    return Container(
      height: 36,
      decoration: BoxDecoration(
        border: Border.all(color: UI.line),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _iconBtn(Icons.remove_rounded, onMinus),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10),
            child: Text(
              '$qty',
              style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
            ),
          ),
          _iconBtn(Icons.add_rounded, onPlus),
        ],
      ),
    );
  }

  Widget _iconBtn(IconData icon, VoidCallback onTap) => SizedBox(
    width: 36,
    height: 36,
    child: IconButton(
      onPressed: onTap,
      icon: Icon(icon),
      padding: EdgeInsets.zero,
      constraints: const BoxConstraints.tightFor(width: 36, height: 36),
      splashRadius: 18,
    ),
  );
}

class StickyTotalsBar extends StatelessWidget {
  final int subtotal; // ← dipertahankan demi kompat, TIDAK ditampilkan
  final String serviceFeeLabel; // ← dipertahankan demi kompat
  final int serviceFee; // ← dipertahankan demi kompat
  final int adjustment;
  final int total;
  final bool enabled;
  final VoidCallback? onNext;

  const StickyTotalsBar({
    required this.subtotal,
    required this.serviceFeeLabel,
    required this.serviceFee,
    required this.adjustment,
    required this.total,
    this.enabled = true,
    this.onNext,
    Key? key,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final money = NumberFormat.decimalPattern('id_ID');
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: UI.line)),
      ),
      child: SafeArea(
        top: false,
        minimum: const EdgeInsets.fromLTRB(16, 8, 16, 12),
        child: Column(
          children: [
            if (adjustment > 0) ...[
              _kv(
                'Discount',
                '- Rp ${money.format(adjustment)}',
                color: UI.ok,
                bold: true,
              ),
              const SizedBox(height: 6),
              const Divider(height: 1, color: UI.line),
              const SizedBox(height: 8),
            ],

            // Total kiri, angka kanan
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Total', style: UI.tsH6),
                Text(
                  'Rp ${money.format(total)}',
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _kv(String k, String v, {Color? color, bool bold = false}) {
    final style = TextStyle(
      fontWeight: bold ? FontWeight.w700 : FontWeight.w600,
      color: color ?? UI.text,
      fontSize: 13,
    );
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(k, style: style),
          Text(v, style: style),
        ],
      ),
    );
  }
}

class _EditReferenceDialog extends StatefulWidget {
  final String initial;
  const _EditReferenceDialog({required this.initial});

  @override
  State<_EditReferenceDialog> createState() => _EditReferenceDialogState();
}

class _EditReferenceDialogState extends State<_EditReferenceDialog> {
  late final TextEditingController _c;

  @override
  void initState() {
    super.initState();
    _c = TextEditingController(text: widget.initial);
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Edit Reference Number'),
      content: TextField(
        controller: _c,
        autofocus: true,
        decoration: const InputDecoration(
          hintText: 'REF-123456',
          border: OutlineInputBorder(),
          isDense: true,
        ),
        textInputAction: TextInputAction.done,
        onSubmitted: (v) => Navigator.pop(context, v),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: () => Navigator.pop(context, _c.text),
          child: const Text('Save'),
        ),
      ],
    );
  }
}

// ===== Compact Qty Editor used in DataTable =====
class _QtyEditor2 extends StatefulWidget {
  final int qty;
  final VoidCallback onMinus;
  final VoidCallback onPlus;
  final void Function(int value) onTyped;

  const _QtyEditor2({
    required this.qty,
    required this.onMinus,
    required this.onPlus,
    required this.onTyped,
    Key? key,
  }) : super(key: key);

  @override
  State<_QtyEditor2> createState() => _QtyEditor2State();
}

class _QtyEditor2State extends State<_QtyEditor2> {
  late final TextEditingController _c;

  @override
  void initState() {
    super.initState();
    _c = TextEditingController(text: widget.qty.toString());
  }

  @override
  void didUpdateWidget(covariant _QtyEditor2 oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.qty != widget.qty) _c.text = widget.qty.toString();
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 108),
      child: DecoratedBox(
        decoration: BoxDecoration(
          border: Border.all(color: UI.line),
          borderRadius: BorderRadius.circular(10),
        ),
        child: SizedBox(
          height: 30,
          child: Row(
            children: [
              _miniBtn(Icons.remove_rounded, widget.onMinus),
              SizedBox(
                width: 40,
                child: TextField(
                  controller: _c,
                  textAlign: TextAlign.center,
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                  ),
                  decoration: const InputDecoration(
                    border: InputBorder.none,
                    isDense: true,
                    contentPadding: EdgeInsets.symmetric(vertical: 4),
                  ),
                  onChanged: (t) => widget.onTyped(int.tryParse(t) ?? 0),
                  onSubmitted: (t) => widget.onTyped(int.tryParse(t) ?? 0),
                ),
              ),
              _miniBtn(Icons.add_rounded, widget.onPlus),
            ],
          ),
        ),
      ),
    );
  }

  Widget _miniBtn(IconData icon, VoidCallback onTap) {
    return SizedBox(
      width: 30,
      height: 30,
      child: IconButton(
        onPressed: onTap,
        icon: Icon(icon, size: 18),
        padding: EdgeInsets.zero,
        constraints: const BoxConstraints.tightFor(width: 30, height: 30),
        splashRadius: 16,
      ),
    );
  }
}

// ===============================
// ADD PRODUCT BOTTOM SHEET
// ===============================

class AddProductSheet extends StatefulWidget {
  const AddProductSheet({super.key});

  @override
  State<AddProductSheet> createState() => AddProductSheetState();
}

class AddProductSheetState extends State<AddProductSheet> {
  final _searchC = TextEditingController();
  final _gridScrollC = ScrollController();
  Timer? _debounce;
  bool _loadMoreArmed = false;
  bool _kicked = false;

  // ===== Stock rule (business setting) =====
  bool _canSellOutOfStock = false;

  // ===== Plan rule (FREE plan: hide stock info + ignore stock restrictions) =====
  bool _isFreePlan = false;

  ProductProvider? _pp;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _pp ??= Provider.of<ProductProvider>(context, listen: false);
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _kickOnOpen());
    _loadOutOfStockFlag();
    _loadPlanFlag();
  }

  Future<void> _loadPlanFlag() async {
    try {
      final prefs = await SharedPreferences.getInstance();

      bool isPremium = false;

      // 1) coba key yang paling umum
      final direct = prefs.getBool('activeBizIsPremium');
      if (direct != null) {
        isPremium = direct == true;
      } else {
        final alt1 = prefs.getBool('isPremiumUser');
        if (alt1 != null) isPremium = alt1 == true;
      }

      // 2) fallback: parse business_full (list business)
      if (!isPremium) {
        final activeBizId = (prefs.getString('activeBizId') ?? '').trim();
        final rawFull = (prefs.getString('business_full') ?? '').trim();

        if (activeBizId.isNotEmpty && rawFull.isNotEmpty) {
          try {
            final list = (jsonDecode(rawFull) as List);
            Map<String, dynamic>? found;

            for (final e in list) {
              if (e is Map<String, dynamic>) {
                final id = (e['idBusiness'] ?? '').toString();
                if (id == activeBizId) {
                  found = e;
                  break;
                }
              }
            }

            bool truthy(dynamic v) {
              if (v == null) return false;
              if (v is bool) return v;
              final s = v.toString().trim().toLowerCase();
              return s == '1' || s == 'true' || s == 'yes' || s == 'premium';
            }

            if (found != null) {
              final p1 = found['isPremium'];
              final p2 = found['premium'];
              final p3 = found['is_premium'];
              final p4 = found['premiumStatus'];

              final exp1 = found['premiumExpiresAt'];
              final exp2 = found['premium_expires_at'];

              isPremium =
                  truthy(p1) ||
                  truthy(p2) ||
                  truthy(p3) ||
                  truthy(p4) ||
                  ((exp1 != null && exp1.toString().trim().isNotEmpty) ||
                      (exp2 != null && exp2.toString().trim().isNotEmpty));
            }
          } catch (_) {}
        }
      }

      if (!mounted) return;
      setState(() {
        _isFreePlan = !isPremium;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _isFreePlan = false; // fallback aman
      });
    }
  }

  Future<void> _loadOutOfStockFlag() async {
    try {
      final prefs = await SharedPreferences.getInstance();

      bool flag = prefs.getBool('activeBizCanSellOutOfStock') ?? false;

      if (!flag) {
        final activeBizId = prefs.getString('activeBizId');
        final rawFull = prefs.getString('business_full');
        if (activeBizId != null &&
            activeBizId.isNotEmpty &&
            rawFull != null &&
            rawFull.isNotEmpty) {
          try {
            final list = (jsonDecode(rawFull) as List);
            final Map<String, dynamic>? found = list
                .cast<Map<String, dynamic>?>()
                .firstWhere(
                  (e) => (e?['idBusiness'] ?? '').toString() == activeBizId,
                  orElse: () => null,
                );

            if (found != null) {
              flag =
                  (found['canBeSoldOutOfStock'] ??
                      found['canSellOutOfStock'] ??
                      false) ==
                  true;
            }
          } catch (_) {}
        }
      }

      if (!mounted) return;
      setState(() {
        _canSellOutOfStock = flag;
      });
    } catch (_) {}
  }

  Future<void> _kickOnOpen() async {
    if (_kicked || !mounted) return;
    _kicked = true;

    final prov = context.read<ProductProvider>();

    prov.initInfinitePaging(context, initialSearch: '');

    try {
      await prov
          .ensureDefaultStoreLocation(context)
          .timeout(const Duration(seconds: 6));
    } catch (_) {}

    await prov.refreshInfinite(context);

    prov.pagingController?.fetchNextPage();

    Future.delayed(const Duration(milliseconds: 300), () {
      if (!mounted) return;
      if (prov.products.isEmpty) {
        prov.pagingController?.fetchNextPage();
      }
    });

    if (mounted) setState(() {});
  }

  Future<void> _manualRetry() async {
    final prov = context.read<ProductProvider>();
    prov.initInfinitePaging(context, initialSearch: _searchC.text.trim());
    try {
      await prov
          .ensureDefaultStoreLocation(context)
          .timeout(const Duration(seconds: 6));
    } catch (_) {}
    await prov.refreshInfinite(context);
    prov.pagingController?.fetchNextPage();
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchC.dispose();
    _gridScrollC.dispose();
    super.dispose();
  }

  String _composeSearch(String raw) {
    final q = raw.trim();
    if (q.isEmpty) return '';
    return 'q:$q'; // samakan dengan ProductScreen
  }

  void _debouncedSearch(String raw) {
    final q = raw.trim();
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 250), () async {
      await _pp?.setInfiniteSearch(context, q);
      await _pp?.refreshInfinite(context);

      // ✅ penting: kalau list kosong, scroll gak bakal memicu loadMore
      _pp?.pagingController?.fetchNextPage();

      if (_gridScrollC.hasClients) _gridScrollC.jumpTo(0);
    });
  }

  void _armLoadMore() {
    if (_loadMoreArmed) return;
    _loadMoreArmed = true;
    Future.delayed(const Duration(milliseconds: 200), () {
      _loadMoreArmed = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final salesProv = context.watch<SalesProvider>();
    final prov = context.watch<ProductProvider>();
    final controller = prov.pagingController;

    if (controller == null) {
      return SafeArea(
        minimum: const EdgeInsets.fromLTRB(16, 12, 16, 16),
        child: SizedBox(
          height: 240,
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const CircularProgressIndicator(),
                const SizedBox(height: 10),
                TextButton.icon(
                  onPressed: _manualRetry,
                  icon: const Icon(Icons.refresh),
                  label: const Text('Retry'),
                ),
              ],
            ),
          ),
        ),
      );
    }

    final all = prov.products;
    final visible = all;

    final pm = prov.pageProducts;
    final bool isAtEnd = (pm?.currentPage != null && pm?.totalPages != null)
        ? (pm!.currentPage! >= pm.totalPages!)
        : prov.reachedEnd;

    final selectedItems = salesProv.cartItems.length;
    final selectedQty = salesProv.cartItems.fold<int>(0, (s, it) => s + it.qty);

    // ✅ FREE plan: no stock UI & no restriction
    final bool showStockUI = !_isFreePlan; // premium -> true
    final bool effectiveAllowOutOfStock = _isFreePlan
        ? true
        : _canSellOutOfStock;

    return SafeArea(
      minimum: const EdgeInsets.fromLTRB(16, 12, 16, 16),
      child: SizedBox(
        height: MediaQuery.of(context).size.height * 0.9,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const _SheetHeader(title: 'Select Products'),

            // SEARCH
            Material(
              elevation: 1,
              color: Colors.white,
              borderRadius: BorderRadius.circular(10),
              child: TextField(
                controller: _searchC,
                textInputAction: TextInputAction.search,
                onSubmitted: (_) async {
                  final q = _searchC.text.trim();
                  await _pp?.setInfiniteSearch(context, q);
                  await _pp?.refreshInfinite(context);

                  // ✅ trigger fetch page pertama setelah reset
                  context
                      .read<ProductProvider>()
                      .pagingController
                      ?.fetchNextPage();
                },

                onChanged: (t) {
                  setState(() {});
                  _debouncedSearch(t);
                },
                decoration: InputDecoration(
                  hintText: 'Search product / SKU',
                  prefixIcon: const Icon(Icons.search_rounded),
                  suffixIcon: (_searchC.text.trim().isEmpty)
                      ? null
                      : IconButton(
                          onPressed: () async {
                            _searchC.clear();
                            await _pp?.setInfiniteSearch(context, '');
                            await _pp?.refreshInfinite(context);
                            _pp?.pagingController?.fetchNextPage(); // ✅
                            if (mounted) setState(() {});
                          },

                          icon: const Icon(Icons.close_rounded),
                        ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: const BorderSide(color: AppColors.divider),
                  ),
                  isDense: true,
                ),
              ),
            ),
            const SizedBox(height: 8),

            // GRID
            Expanded(
              child: (visible.isEmpty)
                  ? RefreshIndicator(
                      onRefresh: _manualRetry,
                      child: ListView(
                        children: const [
                          SizedBox(height: 80),
                          Center(child: Text('No products found')),
                          SizedBox(height: 400),
                        ],
                      ),
                    )
                  : NotificationListener<ScrollNotification>(
                      onNotification: (n) {
                        if (n is ScrollUpdateNotification) {
                          final max = _gridScrollC.position.maxScrollExtent;
                          final cur = _gridScrollC.position.pixels;
                          if (!isAtEnd && max > 0 && cur / max > 0.80) {
                            if (!_loadMoreArmed) {
                              _armLoadMore();
                              controller.fetchNextPage();
                            }
                          }
                        }
                        return false;
                      },
                      child: GridView.builder(
                        controller: _gridScrollC,
                        padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
                        gridDelegate:
                            const SliverGridDelegateWithFixedCrossAxisCount(
                              crossAxisCount: 2,
                              crossAxisSpacing: 12,
                              mainAxisSpacing: 12,
                              childAspectRatio: 0.62,
                            ),
                        itemCount: visible.length + (isAtEnd ? 0 : 1),
                        itemBuilder: (_, i) {
                          if (i >= visible.length) {
                            return const Center(
                              child: Padding(
                                padding: EdgeInsets.all(8),
                                child: CircularProgressIndicator(),
                              ),
                            );
                          }
                          final p = visible[i];
                          final g = _toGroup(p);
                          final selectedForProduct = salesProv.cartItems
                              .where((it) => it.sku.productId == g.productId)
                              .fold<int>(0, (s, it) => s + it.qty);

                          // premium: stock enabled; free: ignore stock
                          final bool isOut = showStockUI
                              ? (p.totalStockQty <= 0)
                              : false;

                          // block hanya untuk premium yang tidak boleh oversell
                          final bool hardBlock =
                              isOut && showStockUI && !effectiveAllowOutOfStock;

                          final double cardOpacity = hardBlock
                              ? 0.6
                              : 1.0; // abu-abu jika blocked

                          return Stack(
                            children: [
                              AbsorbPointer(
                                absorbing: hardBlock,
                                child: Opacity(
                                  opacity: cardOpacity,
                                  child: _SalesProductCard(
                                    group: g,
                                    selectedQty: selectedForProduct,
                                    allowOutOfStock: effectiveAllowOutOfStock,
                                    showStockUI: showStockUI,
                                    onChoose: () {
                                      showModalBottomSheet<bool>(
                                        context: context,
                                        isScrollControlled: true,
                                        useSafeArea: true,
                                        backgroundColor: Colors.white,
                                        shape: const RoundedRectangleBorder(
                                          borderRadius: BorderRadius.vertical(
                                            top: Radius.circular(16),
                                          ),
                                        ),
                                        builder: (_) =>
                                            ChangeNotifierProvider<
                                              SalesProvider
                                            >.value(
                                              value: salesProv,
                                              child: _SalesVariantAttributeSheet(
                                                group: g,
                                                allowOutOfStock:
                                                    effectiveAllowOutOfStock,
                                                showStockUI: showStockUI,
                                              ),
                                            ),
                                      ).then((changed) {
                                        if (mounted && changed == true) {
                                          setState(() {});
                                        }
                                      });
                                    },
                                  ),
                                ),
                              ),
                            ],
                          );
                        },
                      ),
                    ),
            ),

            // FOOTER
            SafeArea(
              top: false,
              minimum: const EdgeInsets.only(top: 8),
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(12, 10, 12, 6),
                    child: Text(
                      (selectedItems > 0)
                          ? '$selectedItems SKU • $selectedQty qty'
                          : 'Pilih produk lalu tentukan variannya',
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        color: AppColors.textSecondary,
                        fontSize: 12,
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                    child: SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: FilledButton.icon(
                        onPressed: () => Navigator.pop<bool>(context, true),
                        icon: const Icon(Icons.check_rounded, size: 24),
                        label: const Text('Use selected'),
                        style: FilledButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          foregroundColor: Colors.white,
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                          textStyle: const TextStyle(
                            fontWeight: FontWeight.w800,
                            fontSize: 17,
                            letterSpacing: .2,
                          ),
                        ),
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
  }

  _SalesProductGroup _toGroup(Product p) {
    int minPriceOf(Product p) {
      if (p.productPrices.isNotEmpty) {
        final prices = p.productPrices.map((x) => x.price).toList()..sort();
        return prices.first;
      }
      if (p.productSkus.isNotEmpty) {
        final prices = p.productSkus.map((s) => s.price).toList()..sort();
        return prices.first;
      }
      return p.basePrice ?? 0;
    }

    return _SalesProductGroup(
      product: p,
      productId: p.idProduct,
      productName: p.name,
      thumbUrl: p.primaryImageUrl,
      skus: p.productSkus,
      minPrice: minPriceOf(p),
    );
  }
}

class _SheetHeader extends StatelessWidget {
  final String title;
  final String? caption;
  const _SheetHeader({required this.title, this.caption});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Column(
        children: [
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: const Color(0xFFE5E7EB),
              borderRadius: BorderRadius.circular(999),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 16,
                        color: Colors.black87,
                      ),
                    ),
                    if (caption != null) ...[
                      const SizedBox(height: 4),
                      Text(
                        caption!,
                        style: const TextStyle(
                          fontSize: 12,
                          color: Colors.black54,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              IconButton(
                onPressed: () => Navigator.pop(context),
                icon: const Icon(Icons.close_rounded, color: Colors.black54),
                tooltip: 'Close',
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _CountBadge extends StatelessWidget {
  final int count;
  const _CountBadge({required this.count, Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    if (count <= 0) return const SizedBox.shrink();
    return Semantics(
      label: 'Selected $count',
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
        decoration: BoxDecoration(
          color: const Color(0xFF4069E6),
          borderRadius: BorderRadius.circular(999),
          boxShadow: const [
            BoxShadow(
              color: Color(0x33000000),
              blurRadius: 6,
              offset: Offset(0, 2),
            ),
          ],
          border: Border.all(color: Colors.white, width: 1),
        ),
        child: Text(
          '$count',
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w900,
            fontSize: 12,
            height: 1.0,
          ),
        ),
      ),
    );
  }
}

class _SalesProductGroup {
  final Product product;
  final String productId;
  final String productName;
  final String? thumbUrl;
  final List<ProductSku> skus;
  final int minPrice;

  _SalesProductGroup({
    required this.product,
    required this.productId,
    required this.productName,
    required this.skus,
    required this.minPrice,
    this.thumbUrl,
  });
}

class _SalesProductCard extends StatelessWidget {
  final _SalesProductGroup group;
  final int selectedQty;
  final VoidCallback onChoose;
  final bool allowOutOfStock;
  final bool showStockUI; // premium: true, free: false

  const _SalesProductCard({
    Key? key,
    required this.group,
    required this.selectedQty,
    required this.onChoose,
    this.allowOutOfStock = false,
    this.showStockUI = true,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final p = group.product;
    final name = group.productName;
    final minPrice = group.minPrice;
    final thumb = group.thumbUrl;

    final bool isOut = showStockUI ? (p.totalStockQty <= 0) : false;
    final bool disabled = isOut && showStockUI && !allowOutOfStock;

    final Color stockColor = (showStockUI && isOut)
        ? Colors.red
        : const Color(0xFF475569);

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ---- GAMBAR PRODUK ----
          AspectRatio(
            aspectRatio: 1,
            child: Stack(
              fit: StackFit.expand,
              children: [
                ClipRRect(
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(14),
                  ),
                  child: thumb != null && thumb.isNotEmpty
                      ? Image.network(
                          thumb,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => const Center(
                            child: Icon(Icons.image_not_supported),
                          ),
                        )
                      : Container(
                          color: Colors.grey[200],
                          child: const Center(
                            child: Icon(Icons.image_outlined, size: 30),
                          ),
                        ),
                ),

                // === BADGE JUMLAH TERPILIH ===
                Positioned(
                  top: 8,
                  right: 8,
                  child: _CountBadge(count: selectedQty),
                ),

                // ✅ PREMIUM: tampilkan overlay Empty Stock
                if (showStockUI && isOut)
                  Container(
                    color: Colors.white.withOpacity(0.5),
                    alignment: Alignment.center,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      margin: const EdgeInsets.symmetric(horizontal: 8),
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.65),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: const Text(
                        'Empty Stock',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),

          // ---- INFORMASI PRODUK ----
          Expanded(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(10, 6, 10, 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF0F172A),
                      fontSize: 14,
                      height: 1.2,
                    ),
                  ),
                  const SizedBox(height: 4),

                  Text(
                    'from Rp ${_formatCurrency(minPrice)}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Color(0xFF475569),
                      fontWeight: FontWeight.w500,
                      fontSize: 12,
                      height: 1.2,
                    ),
                  ),

                  // ✅ PREMIUM: tampilkan info stok (angka)
                  if (showStockUI) ...[
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        const Icon(
                          Icons.inventory_2_outlined,
                          size: 14,
                          color: Color(0xFF64748B),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          'Stock: ${p.totalStockQty}',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: stockColor,
                          ),
                        ),
                      ],
                    ),
                  ],

                  const Spacer(),

                  SizedBox(
                    width: double.infinity,
                    height: 36,
                    child: ElevatedButton(
                      onPressed: disabled ? null : onChoose,
                      style: ElevatedButton.styleFrom(
                        elevation: 0,
                        backgroundColor: disabled
                            ? Colors.grey[300]
                            : const Color(0xFF4069E6),
                        foregroundColor: disabled
                            ? Colors.grey[600]
                            : Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      child: Text(
                        disabled ? 'Unavailable' : 'Choose',
                        style: const TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 13,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _formatCurrency(int value) {
    String s = value.toString();
    if (s.length <= 3) return s;
    final buffer = StringBuffer();
    int count = 0;
    for (int i = s.length - 1; i >= 0; i--) {
      buffer.write(s[i]);
      count++;
      if (count == 3 && i != 0) {
        buffer.write('.');
        count = 0;
      }
    }
    return buffer.toString().split('').reversed.join();
  }
}

class _SalesVariantAttributeSheet extends StatefulWidget {
  final _SalesProductGroup group;
  final bool allowOutOfStock;
  final bool showStockUI; // premium: true, free: false

  const _SalesVariantAttributeSheet({
    required this.group,
    this.allowOutOfStock = false,
    this.showStockUI = true,
  });

  @override
  State<_SalesVariantAttributeSheet> createState() =>
      _SalesVariantAttributeSheetState();
}

class _SalesVariantAttributeSheetState
    extends State<_SalesVariantAttributeSheet> {
  final Map<String, String> _selected = {}; // name -> value
  int _qty = 1;

  late final Product _p;

  @override
  void initState() {
    super.initState();
    _p = widget.group.product;

    final attrsMap = _extractAttributes(_p.productSkus);
    for (final e in attrsMap.entries) {
      if (e.value.length == 1) _selected[e.key] = e.value.first;
    }
  }

  int _qtyInCartOfSku(SalesProvider prov, String skuId) {
    return prov.cartItems
        .where((it) => it.sku.skuId == skuId)
        .fold<int>(0, (s, it) => s + it.qty);
  }

  int _computeUnitPriceWithWholesale(int basePrice, int qty) {
    if (qty <= 0) return basePrice;

    final List<ProductPrice> tiers = List<ProductPrice>.from(_p.productPrices);
    if (tiers.isEmpty) return basePrice;

    tiers.sort((a, b) => a.minQty.compareTo(b.minQty));

    int result = basePrice;
    for (final t in tiers) {
      if (qty >= t.minQty) {
        result = t.price;
      } else {
        break;
      }
    }
    return result;
  }

  @override
  Widget build(BuildContext context) {
    final prov = context.watch<SalesProvider>();
    final attrsMap = _extractAttributes(_p.productSkus);

    ProductSku? matched;
    for (final s in _p.productSkus) {
      if (_isSkuMatch(s, _selected, requiredCount: attrsMap.length)) {
        matched = s;
        break;
      }
    }

    final money = NumberFormat.decimalPattern('id_ID');

    // FREE plan: stok tidak dipakai sama sekali
    final bool stockEnabled = widget.showStockUI;
    final bool allowOversell = stockEnabled ? widget.allowOutOfStock : true;

    final int stockRaw = matched?.stockQty ?? _p.totalStockQty;
    final int alreadyInCart = (matched == null)
        ? 0
        : _qtyInCartOfSku(prov, matched.idProductSku);
    final int leftRaw = stockRaw - alreadyInCart;

    if (stockEnabled && !allowOversell) {
      final int maxLeft = leftRaw.clamp(0, 1 << 31);
      if (_qty > maxLeft && maxLeft >= 0) {
        _qty = maxLeft;
      }
    }

    final int basePrice = matched?.price ?? _p.basePrice ?? 0;
    final int unitPrice = _computeUnitPriceWithWholesale(basePrice, _qty);
    final int lineTotal = unitPrice * _qty;

    final int displayStock = leftRaw;
    final bool nonPositive = displayStock <= 0;
    final Color stockColor = (stockEnabled && allowOversell && nonPositive)
        ? Colors.red
        : AppColors.textSecondary;

    final bool ctaDisabled = stockEnabled
        ? (allowOversell
              ? (matched == null || _qty <= 0)
              : (matched == null || leftRaw <= 0 || _qty <= 0))
        : (matched == null || _qty <= 0);

    final List<ProductPrice> wholesaleTiers = List<ProductPrice>.from(
      _p.productPrices,
    )..sort((a, b) => a.minQty.compareTo(b.minQty));

    return Container(
      color: Colors.white,
      child: SafeArea(
        minimum: const EdgeInsets.fromLTRB(16, 12, 16, 0),
        child: Column(
          children: [
            const _SheetHeader(title: 'Choose Variants'),
            const SizedBox(height: 4),

            // HERO + Info (Premium: show stock; Free: no stock)
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.divider),
                boxShadow: const [
                  BoxShadow(
                    color: Color(0x0F000000),
                    blurRadius: 16,
                    offset: Offset(0, 6),
                  ),
                ],
              ),
              child: Row(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child:
                        (_p.primaryImageUrl != null &&
                            _p.primaryImageUrl!.isNotEmpty)
                        ? Image.network(
                            _p.primaryImageUrl!,
                            width: 72,
                            height: 72,
                            fit: BoxFit.cover,
                          )
                        : Container(
                            width: 72,
                            height: 72,
                            color: AppColors.greyBackground,
                            child: const Icon(
                              Icons.image,
                              color: AppColors.disabledFg,
                            ),
                          ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _p.name,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontWeight: FontWeight.w800),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'Rp ${money.format(unitPrice)} / pcs',
                          style: const TextStyle(
                            fontWeight: FontWeight.w800,
                            fontSize: 16,
                          ),
                        ),
                        if (wholesaleTiers.isNotEmpty) ...[
                          const SizedBox(height: 2),
                          Text(
                            'Harga normal: Rp ${money.format(basePrice)}',
                            style: const TextStyle(
                              fontSize: 11,
                              color: AppColors.textSecondary,
                            ),
                          ),
                          const SizedBox(height: 4),
                          const Text(
                            'Harga grosir:',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: AppColors.textSecondary,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Wrap(
                            spacing: 6,
                            runSpacing: 2,
                            children: wholesaleTiers.map((t) {
                              return Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 3,
                                ),
                                decoration: BoxDecoration(
                                  color: AppColors.background,
                                  borderRadius: BorderRadius.circular(999),
                                  border: Border.all(color: AppColors.divider),
                                ),
                                child: Text(
                                  '≥ ${t.minQty} : Rp ${money.format(t.price)}',
                                  style: const TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              );
                            }).toList(),
                          ),
                        ],
                        if (matched != null) ...[
                          const SizedBox(height: 4),
                          Text(
                            matched.code,
                            style: const TextStyle(
                              color: AppColors.textSecondary,
                              fontSize: 12,
                            ),
                          ),
                        ],

                        // ✅ PREMIUM: tampilkan info stok persis seperti konteks sebelumnya
                        if (stockEnabled) ...[
                          const SizedBox(height: 6),
                          Row(
                            children: [
                              const Icon(
                                Icons.inventory_2_outlined,
                                size: 16,
                                color: AppColors.textSecondary,
                              ),
                              const SizedBox(width: 6),
                              Text(
                                'Stock: $displayStock'
                                '${alreadyInCart > 0 ? "  •  In cart: $alreadyInCart" : ""}',
                                style: TextStyle(
                                  color: stockColor,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 12),

            // ATRIBUT
            Expanded(
              child: ListView(
                children: attrsMap.entries.map((e) {
                  final attrName = e.key;
                  final values = e.value.toList()..sort();
                  final selectedVal = _selected[attrName];

                  return Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: AppColors.divider),
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
                          Text(
                            attrName,
                            style: const TextStyle(fontWeight: FontWeight.w800),
                          ),
                          const SizedBox(height: 10),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: values.map((val) {
                              final isSel = selectedVal == val;
                              final enabled = _isValueEnabled(
                                attrName,
                                val,
                                _selected,
                                _p.productSkus,
                              );
                              return ChoiceChip(
                                label: Text(val),
                                selected: isSel,
                                onSelected: enabled
                                    ? (_) => setState(
                                        () => _selected[attrName] = val,
                                      )
                                    : null,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(999),
                                ),
                                selectedColor: AppColors.primary.withOpacity(
                                  .12,
                                ),
                                labelStyle: TextStyle(
                                  fontWeight: isSel
                                      ? FontWeight.w700
                                      : FontWeight.w500,
                                  color: !enabled
                                      ? AppColors.disabledFg
                                      : (isSel
                                            ? AppColors.primary
                                            : AppColors.textPrimary),
                                ),
                              );
                            }).toList(),
                          ),
                        ],
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),

            // QTY + CTA
            Container(
              decoration: const BoxDecoration(
                color: Colors.white,
                border: Border(top: BorderSide(color: AppColors.divider)),
                boxShadow: [
                  BoxShadow(
                    color: Color(0x14000000),
                    blurRadius: 12,
                    offset: Offset(0, -2),
                  ),
                ],
              ),
              child: SafeArea(
                top: false,
                minimum: const EdgeInsets.fromLTRB(16, 10, 16, 12),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Quantity',
                          style: TextStyle(fontWeight: FontWeight.w700),
                        ),
                        Container(
                          height: 36,
                          decoration: BoxDecoration(
                            border: Border.all(color: AppColors.divider),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Row(
                            children: [
                              IconButton(
                                visualDensity: VisualDensity.compact,
                                onPressed: _qty > 1
                                    ? () => setState(() => _qty--)
                                    : null,
                                icon: const Icon(Icons.remove_rounded),
                              ),
                              Text(
                                '$_qty',
                                style: const TextStyle(
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                              IconButton(
                                visualDensity: VisualDensity.compact,
                                onPressed: stockEnabled
                                    ? (allowOversell
                                          ? () => setState(() => _qty++)
                                          : (leftRaw > 0 && _qty < leftRaw)
                                          ? () => setState(() => _qty++)
                                          : null)
                                    : () => setState(() => _qty++),
                                icon: const Icon(Icons.add_rounded),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton(
                        onPressed: ctaDisabled
                            ? null
                            : () {
                                final int toAdd = stockEnabled
                                    ? (widget.allowOutOfStock
                                          ? _qty.clamp(0, 1 << 31)
                                          : _qty.clamp(
                                              0,
                                              leftRaw.clamp(0, 1 << 31),
                                            ))
                                    : _qty.clamp(0, 1 << 31);

                                final posSku = PosSku(
                                  skuId: matched!.idProductSku,
                                  skuCode: matched.code,
                                  price: unitPrice,
                                  productId: _p.idProduct,
                                  productName: _p.name,
                                  imageUrl: _p.primaryImageUrl ?? '',
                                  inStock: !_p.isHide,
                                );

                                prov.addQuantity(posSku, toAdd);
                                prov.normalizeCart();

                                Navigator.pop<bool>(context, true);
                              },
                        style: FilledButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                        ),
                        child: Text(
                          (matched == null)
                              ? 'Pilih semua varian'
                              : (stockEnabled &&
                                    !widget.allowOutOfStock &&
                                    leftRaw <= 0)
                              ? 'Stok habis'
                              : 'Add to cart — Rp ${money.format(lineTotal)}',
                          style: const TextStyle(fontWeight: FontWeight.w700),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Map<String, Set<String>> _extractAttributes(List<ProductSku> skus) {
    final result = <String, Set<String>>{};
    for (final sku in skus) {
      for (final a in sku.attributes) {
        (result[a.name] ??= <String>{}).add(a.value);
      }
    }
    return result;
  }

  bool _isSkuMatch(
    ProductSku sku,
    Map<String, String> sel, {
    required int requiredCount,
  }) {
    for (final entry in sel.entries) {
      final ok = sku.attributes.any(
        (a) =>
            a.name.toLowerCase() == entry.key.toLowerCase() &&
            a.value == entry.value,
      );
      if (!ok) return false;
    }
    return sel.length == requiredCount;
  }

  bool _isValueEnabled(
    String attr,
    String val,
    Map<String, String> currentSel,
    List<ProductSku> allSkus,
  ) {
    final trial = Map<String, String>.from(currentSel)..[attr] = val;
    return allSkus.any((sku) {
      for (final e in trial.entries) {
        final ok = sku.attributes.any(
          (a) =>
              a.name.toLowerCase() == e.key.toLowerCase() && a.value == e.value,
        );
        if (!ok) return false;
      }
      return true;
    });
  }
}

// ===============================
// (Opsional) EXACT PURCHASE-STYLE VARIANT SHEET (tidak diubah)
// ===============================
class _SalesPicked {
  final String skuId;
  final int qty;
  const _SalesPicked({required this.skuId, required this.qty});
}

class _SProduct {
  final String idProduct;
  final String name;
  final String? primaryImageUrl;
  final int? basePrice;
  final List<_SSku> productSkus;
  _SProduct({
    required this.idProduct,
    required this.name,
    required this.productSkus,
    this.primaryImageUrl,
    this.basePrice,
  });
}

class _SSku {
  final String idProductSku;
  final String code;
  final int price;
  final List<_SAttr> attributes;
  final bool inStock;
  final String imageUrl;
  _SSku({
    required this.idProductSku,
    required this.code,
    required this.price,
    required this.attributes,
    required this.inStock,
    required this.imageUrl,
  });
}

class _SAttr {
  final String name;
  final String value;
  const _SAttr(this.name, this.value);
}

class _SalesVariantExactSheet extends StatefulWidget {
  final _SalesProductGroup group;
  const _SalesVariantExactSheet({required this.group});

  @override
  State<_SalesVariantExactSheet> createState() =>
      _SalesVariantExactSheetState();
}

class _SalesVariantExactSheetState extends State<_SalesVariantExactSheet> {
  final Map<String, String> _selectedAttrs = {};
  int _qty = 1;
  late final _SProduct product;

  @override
  void initState() {
    super.initState();
    product = _adaptGroup(widget.group);

    final attrsList = _extractAttributes(product.productSkus);
    for (final e in attrsList.entries) {
      if (e.value.length == 1) {
        _selectedAttrs[e.key] = e.value.first;
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final attrsList = _extractAttributes(product.productSkus);

    _SSku? matchedSku;
    for (final s in product.productSkus) {
      if (_isSkuMatch(s, _selectedAttrs, requiredCount: attrsList.length)) {
        matchedSku = s;
        break;
      }
    }

    final price = matchedSku?.price ?? product.basePrice ?? 0;
    final money = NumberFormat.decimalPattern('id_ID');

    return Container(
      color: UI.bg,
      child: SafeArea(
        minimum: const EdgeInsets.fromLTRB(16, 12, 16, 0),
        child: Column(
          children: [
            _PSheetHeader(title: 'Choose Variants', caption: product.name),
            const SizedBox(height: 4),
            _PSection(
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child:
                        (product.primaryImageUrl != null &&
                            product.primaryImageUrl!.isNotEmpty)
                        ? Image.network(
                            product.primaryImageUrl!,
                            width: 72,
                            height: 72,
                            fit: BoxFit.cover,
                          )
                        : Container(
                            width: 72,
                            height: 72,
                            color: const Color(0xFFF3F4F6),
                            child: const Icon(
                              Icons.image,
                              color: Color(0xFFA3A3A3),
                            ),
                          ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          product.name,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontWeight: FontWeight.w800),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'Rp ${money.format(price)}',
                          style: const TextStyle(
                            fontWeight: FontWeight.w800,
                            fontSize: 16,
                          ),
                        ),
                        if (matchedSku != null) ...[
                          const SizedBox(height: 4),
                          Text(
                            matchedSku.code,
                            style: const TextStyle(color: UI.sub, fontSize: 12),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Expanded(
              child: ListView(
                children: attrsList.entries.map((e) {
                  final attr = e.key;
                  final values = e.value.toList()..sort();
                  final selected = _selectedAttrs[attr];

                  return Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: _PSection(
                      title: attr,
                      child: Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: values.map((val) {
                          final isSel = selected == val;
                          return ChoiceChip(
                            label: Text(val),
                            selected: isSel,
                            onSelected: (_) =>
                                setState(() => _selectedAttrs[attr] = val),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(999),
                            ),
                            selectedColor: UI.blue.withOpacity(.12),
                            labelStyle: TextStyle(
                              fontWeight: isSel
                                  ? FontWeight.w700
                                  : FontWeight.w500,
                              color: isSel ? UI.blue : UI.text,
                            ),
                          );
                        }).toList(),
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
            Container(
              decoration: const BoxDecoration(
                color: Colors.white,
                border: Border(top: BorderSide(color: UI.line)),
                boxShadow: [
                  BoxShadow(
                    color: Color(0x14000000),
                    blurRadius: 12,
                    offset: Offset(0, -2),
                  ),
                ],
              ),
              child: SafeArea(
                top: false,
                minimum: const EdgeInsets.fromLTRB(16, 10, 16, 12),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          "Quantity",
                          style: TextStyle(fontWeight: FontWeight.w700),
                        ),
                        Container(
                          height: 36,
                          decoration: BoxDecoration(
                            border: Border.all(color: UI.line),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Row(
                            children: [
                              IconButton(
                                visualDensity: VisualDensity.compact,
                                onPressed: _qty > 1
                                    ? () => setState(() => _qty--)
                                    : null,
                                icon: const Icon(Icons.remove_rounded),
                              ),
                              Text(
                                "$_qty",
                                style: const TextStyle(
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                              IconButton(
                                visualDensity: VisualDensity.compact,
                                onPressed: () => setState(() => _qty++),
                                icon: const Icon(Icons.add_rounded),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton(
                        onPressed: (matchedSku == null)
                            ? null
                            : () {
                                Navigator.pop<_SalesPicked>(
                                  context,
                                  _SalesPicked(
                                    skuId: matchedSku!.idProductSku,
                                    qty: _qty,
                                  ),
                                );
                              },
                        style: FilledButton.styleFrom(
                          backgroundColor: UI.blue,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                        ),
                        child: Text(
                          (matchedSku == null)
                              ? "Pilih semua varian"
                              : "Add to cart — Rp ${money.format(price)}",
                          style: const TextStyle(fontWeight: FontWeight.w700),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Map<String, Set<String>> _extractAttributes(List<_SSku> skus) {
    final result = <String, Set<String>>{};
    for (final s in skus) {
      for (final a in s.attributes) {
        (result[a.name] ??= <String>{}).add(a.value);
      }
    }
    return result;
  }

  bool _isSkuMatch(
    _SSku sku,
    Map<String, String> sel, {
    required int requiredCount,
  }) {
    for (final entry in sel.entries) {
      final ok = sku.attributes.any(
        (a) =>
            a.name.toLowerCase() == entry.key.toLowerCase() &&
            a.value == entry.value,
      );
      if (!ok) return false;
    }
    return sel.length == requiredCount;
  }

  _SProduct _adaptGroup(_SalesProductGroup g) {
    final String? thumb = (g.thumbUrl?.isNotEmpty == true)
        ? g.thumbUrl
        : g.product.primaryImageUrl;

    final int? basePrice = g.skus.isEmpty
        ? null
        : g.skus.map((e) => e.price).reduce((a, b) => a < b ? a : b);

    final bool inStock = !g.product.isHide;

    final List<_SSku> skus = g.skus
        .map((s) {
          final attrs = s.attributes
              .map((a) => _SAttr(a.name, a.value))
              .toList();
          return _SSku(
            idProductSku: s.idProductSku,
            code: s.code,
            price: s.price,
            attributes: attrs.isNotEmpty
                ? attrs
                : <_SAttr>[_SAttr('Variant', s.code)],
            inStock: inStock,
            imageUrl: thumb ?? '',
          );
        })
        .toList(growable: false);

    return _SProduct(
      idProduct: g.productId,
      name: g.productName,
      primaryImageUrl: thumb,
      basePrice: basePrice,
      productSkus: skus,
    );
  }
}

class _PSheetHeader extends StatelessWidget {
  final String title;
  final String? caption;
  const _PSheetHeader({required this.title, this.caption});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        const SizedBox(height: 6),
        Container(
          width: 44,
          height: 4,
          decoration: BoxDecoration(
            color: UI.line,
            borderRadius: BorderRadius.circular(999),
          ),
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 16,
                      color: UI.text,
                    ),
                  ),
                  if (caption != null) ...[
                    const SizedBox(height: 4),
                    Text(
                      caption!,
                      style: const TextStyle(fontSize: 12, color: UI.sub),
                    ),
                  ],
                ],
              ),
            ),
            IconButton(
              onPressed: () => Navigator.pop(context),
              icon: const Icon(Icons.close_rounded, color: UI.sub),
              tooltip: 'Close',
            ),
          ],
        ),
        const SizedBox(height: 4),
      ],
    );
  }
}

/// Gambar network yang aman:
class SafeNetImage extends StatelessWidget {
  final String? url;
  final double? width;
  final double? height;
  final BoxFit fit;
  final BorderRadius? borderRadius;
  final Widget? crashIcon;

  const SafeNetImage({
    super.key,
    required this.url,
    this.width,
    this.height,
    this.fit = BoxFit.cover,
    this.borderRadius,
    this.crashIcon,
  });

  @override
  Widget build(BuildContext context) {
    final Widget fallback = Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: const Color(0xFFF3F4F6),
        borderRadius: borderRadius ?? BorderRadius.circular(12),
      ),
      child: const Center(
        child: Icon(Icons.broken_image_rounded, color: Color(0xFFA3A3A3)),
      ),
    );

    if (url == null || url!.isEmpty) return fallback;

    Widget img = Image.network(
      url!,
      width: width,
      height: height,
      fit: fit,
      loadingBuilder: (context, child, progress) {
        if (progress == null) return child;
        return SizedBox(width: width, height: height);
      },
      errorBuilder: (_, __, ___) => crashIcon ?? fallback,
    );

    if (borderRadius != null) {
      img = ClipRRect(borderRadius: borderRadius!, child: img);
    }
    return img;
  }
}

class _PSection extends StatelessWidget {
  final String? title;
  final Widget? titleWidget;
  final Widget child;
  final EdgeInsets padding;
  const _PSection({
    this.title,
    required this.child,
    this.padding = const EdgeInsets.all(14),
    this.titleWidget,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0F000000),
            blurRadius: 16,
            offset: Offset(0, 6),
          ),
        ],
        border: Border.all(color: UI.line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (titleWidget != null)
            titleWidget!
          else if (title != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Text(
                title!,
                style: const TextStyle(
                  fontWeight: FontWeight.w800,
                  color: UI.text,
                ),
              ),
            ),
          child,
        ],
      ),
    );
  }
}

class _LabeledField extends StatelessWidget {
  final String label;
  final Widget child;
  const _LabeledField({required this.label, required this.child});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: DS.tsPrice),
        const SizedBox(height: 6),
        child,
      ],
    );
  }
}
