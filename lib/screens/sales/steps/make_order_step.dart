import 'dart:async';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:flutter/services.dart';
import 'package:wa_blast/models/product_model.dart';
import 'package:wa_blast/providers/product_provider.dart' as catalog;
import 'package:wa_blast/providers/product_provider.dart';
import 'package:wa_blast/providers/sales_provider.dart';
import 'package:wa_blast/widgets/show_fancy_bar.dart';

import '../../../constants/app_colors.dart';
import '../../../constants/design_system.dart';
import '../../../widgets/stepper_header.dart';
import '../../../widgets/reusable_pickers.dart';

import 'package:infinite_scroll_pagination/infinite_scroll_pagination.dart';

// ===============================
// Minimal UI helpers (theme tokens)
// ===============================

// NOTE: jika CheckOrderStep dipisah file, import di sini, contoh:
// import 'check_order_step.dart'; // berisi class CheckOrderStep & CheckOrderStepState

// Expose helper agar bisa dipanggil dari AppBar di wrapper
// Expose helper agar bisa dipanggil dari AppBar di wrapper
Future<bool?> openAddProductSheet(BuildContext context) async {
  final parentSp = context.read<SalesProvider>();

  // 3) Init paging + pasang filter store ke ProductProvider

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
// MAKE ORDER STEP (minimal look)
// ===============================

class MakeOrderStep extends StatefulWidget {
  final bool withHeader;
  const MakeOrderStep({super.key, this.withHeader = true});

  @override
  State<MakeOrderStep> createState() => _MakeOrderStepState();
}

class _MakeOrderStepState extends State<MakeOrderStep> {
  final _discountC = TextEditingController();

  String? _customerId;
  String? _customerName;

  Future<void> _pickStore() async {
    final picked = await showStorePickerSheet(
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

    setState(() {}); // hanya untuk repaint UI
  }

  @override
  void initState() {
    super.initState();
    final prov = context.read<SalesProvider>();
    _discountC.text = (prov.discount ?? 0).toString();

    // ⬇️ NEW: prefill customer dari provider
    _customerId = prov.customerId;
    _customerName = prov.customerName ?? '';

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      context.read<SalesProvider>().ensureReferenceInitialized(notify: true);
    });
  }

  @override
  void dispose() {
    _discountC.dispose();
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

  // ⬇️ NEW
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
                      Icon(
                        Icons.store_mall_directory_outlined,
                        size: 18,
                        color: UI.sub,
                      ),
                      SizedBox(width: 8),
                      Text('Store Location', style: UI.tsSub),
                      SizedBox(width: 8),
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
                    valueText: storeName, // ← dari provider
                    emptyHint: 'Select store…',
                    onTap: _pickStore,
                  ),
                ),

                // ============ CUSTOMER (REQUIRED) ============
                const SizedBox(height: 12),
                _Section(
                  titleWidget: Row(
                    children: [
                      const Icon(Icons.person_outline, size: 18, color: UI.sub),
                      const SizedBox(width: 8),
                      const Text('Customer', style: UI.tsSub),
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
                    label: 'Choose customer',
                    valueText: _customerName,
                    emptyHint: 'Select customer…',
                    onTap: _pickCustomer,
                  ),
                ),
              ],
            ),
          ),

          // // Totals bar: disable jika belum pilih store atau cart kosong
          // StickyTotalsBar(
          //   subtotal: sub,
          //   serviceFeeLabel: '',
          //   serviceFee: 0,
          //   adjustment: adjustment,
          //   total: grand,
          //   enabled: !storeNotSelected && cartLen > 0,
          //   onNext: (!storeNotSelected && cartLen > 0)
          //       ? () {
          //           context.read<SalesProvider>().setOrderMeta(
          //             discount: adjustment,
          //           );
          //           context.read<SalesProvider>().goTo(1);
          //         }
          //       : null,
          // ),

          // CTA minimal (opsional)
          SafeArea(
            minimum: const EdgeInsets.fromLTRB(16, 8, 16, 16),
            child: SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: (!storeNotSelected)
                    ? () {
                        if (_customerId == null || _customerId!.isEmpty) {
                          showFancySnackBar(
                            context,
                            message: 'Please select customer',
                            icon: Icons.person_outline,
                          );
                          return;
                        }
                        final d = int.tryParse(_discountC.text.trim()) ?? 0;
                        context.read<SalesProvider>().setOrderMeta(discount: d);
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
// ====== Order Summary — Compact List (auto height, scroll only if > 5) ======
Widget _orderSummaryList(SalesProvider prov, context) {
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

  final list = ListView.separated(
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

  // batasi tinggi sesuai device: 5 baris (mobile) / 10 baris (tablet)
  final double maxHeight = (_rowExtent * maxVisible) + (1.0 * (maxVisible - 1));

  return ConstrainedBox(
    constraints: BoxConstraints(maxHeight: maxHeight),
    child: Scrollbar(
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
                // Tidak perlu hapus diskon lokal: provider sudah bereskan saat remove
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
    final money = NumberFormat.decimalPattern('id_ID'); // ⬅️ untuk format Rp
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
  final String
  serviceFeeLabel; // ← dipertahankan demi kompat, TIDAK ditampilkan
  final int serviceFee; // ← dipertahankan demi kompat, TIDAK ditampilkan
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
            // ⬇️ Subtotal & Service Fee dihilangkan dari tampilan
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

class _ChipBadge extends StatelessWidget {
  final IconData icon;
  final String label;
  const _ChipBadge({required this.icon, required this.label, Key? key})
    : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.greyBackground,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: AppColors.divider),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: AppColors.textSecondary),
          const SizedBox(width: 6),
          Text(
            label,
            style: const TextStyle(
              fontWeight: FontWeight.w600,
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}

class _RowKV extends StatelessWidget {
  final String label;
  final int value;
  final bool bold;
  const _RowKV({required this.label, required this.value, this.bold = false});

  @override
  Widget build(BuildContext context) {
    final style = bold
        ? DS.tsTitle.copyWith(fontWeight: FontWeight.w700)
        : DS.tsTitle;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: style),
          Text(formatRp(value), style: style),
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

class _QtyPill extends StatelessWidget {
  final int qty;
  final VoidCallback onMinus;
  final VoidCallback onPlus;
  const _QtyPill({
    required this.qty,
    required this.onMinus,
    required this.onPlus,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 36,
      decoration: BoxDecoration(
        border: Border.all(color: AppColors.divider),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            visualDensity: VisualDensity.compact,
            onPressed: onMinus,
            icon: const Icon(Icons.remove),
          ),
          Text('$qty', style: const TextStyle(fontWeight: FontWeight.w700)),
          IconButton(
            visualDensity: VisualDensity.compact,
            onPressed: onPlus,
            icon: const Icon(Icons.add),
          ),
        ],
      ),
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
  void didUpdateWidget(covariant _QtyEditor2 old) {
    super.didUpdateWidget(old);
    if (old.qty != widget.qty) _c.text = widget.qty.toString();
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
// DATA GROUPING UNTUK GRID PRODUCT
// ===============================
class _SalesProductGroup {
  final Product product; // simpan full Product
  final String productId;
  final String productName;
  final String? thumbUrl;
  final List<ProductSku> skus; // ProductSku
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

// ===============================
// ADD PRODUCT BOTTOM SHEET (minimal tweaks compatible)
// ===============================

class AddProductSheet extends StatefulWidget {
  const AddProductSheet({super.key});

  @override
  State<AddProductSheet> createState() => AddProductSheetState();
}

class AddProductSheetState extends State<AddProductSheet> {
  final _searchC = TextEditingController();

  ProductProvider? _catalogProv; // cache ref provider (non-listen)
  Timer? _debounce;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _catalogProv ??= Provider.of<ProductProvider>(context, listen: false);
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;

      _catalogProv ??= Provider.of<ProductProvider>(context, listen: false);
      final salesProv = Provider.of<SalesProvider>(context, listen: false);
      final String? storeId = salesProv.storeLocationId;

      // Init + set filter store
      _catalogProv?.initInfinitePaging(context);
      if (storeId != null && storeId.isNotEmpty) {
        // prefer method khusus store:
        // _catalogProv?.setInfiniteStore(context, storeId);
        _catalogProv?.setStoreLocationForPaging?.call(context, storeId);
      }
      await _catalogProv?.refreshInfinite(context);

      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchC.dispose();
    _catalogProv?.disposeInfinitePaging();
    super.dispose();
  }

  void _debouncedSearch(String raw) {
    final q = raw.trim();

    // Kosong → langsung trigger search="" supaya tidak nyantol di huruf terakhir
    if (q.isEmpty) {
      _debounce?.cancel();
      _catalogProv?.setInfiniteSearch(context, '');
      return;
    }

    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 250), () {
      _catalogProv?.setInfiniteSearch(context, q);
    });
  }

  void _doSearch() {
    final q = _searchC.text.trim();
    _catalogProv?.setInfiniteSearch(context, q);
  }

  Future<void> _refreshPaging() async {
    await _catalogProv?.refreshInfinite(context);
  }

  _SalesProductGroup _toGroup(Product p) {
    int minPriceOf(Product p) {
      if (p.productSkus.isNotEmpty) {
        final prices = p.productSkus.map((s) => s.price).toList()..sort();
        return prices.first;
      }
      if (p.productPrices.isNotEmpty) {
        final prices = p.productPrices.map((x) => x.price).toList()..sort();
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

  @override
  Widget build(BuildContext context) {
    final salesProv = context.watch<SalesProvider>();
    final productProv = context.watch<ProductProvider>();
    final controller = productProv.pagingController;

    if (controller == null) {
      return const SafeArea(
        minimum: EdgeInsets.fromLTRB(16, 12, 16, 16),
        child: SizedBox(
          height: 240,
          child: Center(child: CircularProgressIndicator()),
        ),
      );
    }

    final state = controller.value;
    next() {
      final pm = productProv.pageProducts;
      final cur = pm?.currentPage;
      final tot = pm?.totalPages;

      // ⛔️ stop kalau sudah halaman terakhir
      if (cur != null && tot != null && cur >= tot) {
        debugPrint('[NEXT] blocked by meta cur=$cur tot=$tot');
        return;
      } else {
        controller.fetchNextPage();
      }
    }

    // Pakai data provider, bukan state.itemList
    final firstPageEmptyAndDone = productProv.isFirstPageDoneEmpty;
    debugPrint(firstPageEmptyAndDone.toString());
    final reachedEnd = productProv.reachedEnd;

    final pm = productProv.pageProducts;
    final isAtEnd = (pm?.currentPage != null && pm?.totalPages != null)
        ? (pm!.currentPage! >= pm.totalPages!)
        : productProv.reachedEnd; // fallback

    final selectedItems = salesProv.cartItems.length;
    final selectedQty = salesProv.cartItems.fold<int>(0, (s, it) => s + it.qty);

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
                onSubmitted: (_) => _doSearch(),
                onChanged: (t) {
                  setState(() {}); // update ikon clear
                  _debouncedSearch(t);
                },
                decoration: InputDecoration(
                  hintText: 'Search product / SKU',
                  prefixIcon: const Icon(Icons.search_rounded),
                  suffixIcon: (_searchC.text.trim().isEmpty)
                      ? null
                      : IconButton(
                          onPressed: () {
                            _searchC.clear();
                            _doSearch(); // langsung search=""
                            setState(() {});
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

            // GRID (pagination menggunakan state & fetchNextPage)
            Expanded(
              child: firstPageEmptyAndDone
                  ? const Center(
                      child: Padding(
                        padding: EdgeInsets.all(24),
                        child: Text('No products found'),
                      ),
                    )
                  : PagedGridView<int, Product>(
                      state: state,
                      fetchNextPage: next,
                      padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
                      gridDelegate:
                          const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 2,
                            crossAxisSpacing: 12,
                            mainAxisSpacing: 12,
                            childAspectRatio: 0.62,
                          ),
                      builderDelegate: PagedChildBuilderDelegate<Product>(
                        itemBuilder: (_, p, __) {
                          final g = _toGroup(p);
                          final qtyOfProduct = salesProv.cartItems
                              .where((it) => it.sku.productId == g.productId)
                              .fold<int>(0, (s, it) => s + it.qty);

                          return _SalesProductCard(
                            group: g,
                            selectedQty: qtyOfProduct,
                            onChoose: () async {
                              final changed = await showModalBottomSheet<bool>(
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
                                    ChangeNotifierProvider<SalesProvider>.value(
                                      value: salesProv,
                                      child: _SalesVariantAttributeSheet(
                                        group: g,
                                      ),
                                    ),
                              );
                              if (mounted && changed == true) setState(() {});
                            },
                          );
                        },
                        firstPageProgressIndicatorBuilder: (_) => const Center(
                          child: Padding(
                            padding: EdgeInsets.all(24),
                            child: CircularProgressIndicator(),
                          ),
                        ),
                        newPageProgressIndicatorBuilder: (_) =>
                            const SizedBox.shrink(),
                        firstPageErrorIndicatorBuilder: (_) =>
                            _ErrorRetry(onRetry: _refreshPaging),
                        newPageErrorIndicatorBuilder: (_) =>
                            _ErrorRetry(onRetry: next),
                        // tetap boleh, tapi kita juga pasang footer manual di bawah
                        noMoreItemsIndicatorBuilder: (_) =>
                            const SizedBox.shrink(),
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
}

class _ErrorRetry extends StatelessWidget {
  final VoidCallback onRetry;
  const _ErrorRetry({required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.error_outline, color: Colors.redAccent),
          const SizedBox(height: 8),
          const Text('Something went wrong'),
          const SizedBox(height: 8),
          OutlinedButton(onPressed: onRetry, child: const Text('Retry')),
        ],
      ),
    );
  }
}

// ===============================
// VARIANT SHEETS
// ===============================
class _SalesVariantAttributeSheet extends StatefulWidget {
  final _SalesProductGroup group; // kumpulan SKU utk 1 Product
  const _SalesVariantAttributeSheet({required this.group});

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

    // preselect kalau atribut hanya punya 1 nilai
    final attrsMap = _extractAttributes(_p.productSkus);
    for (final e in attrsMap.entries) {
      if (e.value.length == 1) _selected[e.key] = e.value.first;
    }
  }

  @override
  Widget build(BuildContext context) {
    final prov = context.watch<SalesProvider>();
    final attrsMap = _extractAttributes(_p.productSkus);

    // cari SKU yang cocok dengan pilihan
    ProductSku? matched;
    for (final s in _p.productSkus) {
      if (_isSkuMatch(s, _selected, requiredCount: attrsMap.length)) {
        matched = s;
        break;
      }
    }

    final price = matched?.price ?? _p.basePrice ?? 0;
    final money = NumberFormat.decimalPattern('id_ID');

    return Container(
      color: Colors.white,
      child: SafeArea(
        minimum: const EdgeInsets.fromLTRB(16, 12, 16, 0),
        child: Column(
          children: [
            _SheetHeader(title: 'Choose Variants', caption: _p.name),
            const SizedBox(height: 4),

            // HERO
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
                          'Rp ${money.format(price)}',
                          style: const TextStyle(
                            fontWeight: FontWeight.w800,
                            fontSize: 16,
                          ),
                        ),
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
                        onPressed:
                            (_selected.length == attrsMap.length &&
                                matched != null)
                            ? () {
                                final inStock =
                                    !_p.isHide; // kebalikan dari isHide
                                final posSku = PosSku(
                                  skuId: matched!.idProductSku,
                                  skuCode: matched.code,
                                  price: matched.price,
                                  productId: _p.idProduct,
                                  productName: _p.name,
                                  imageUrl: _p.primaryImageUrl ?? '',
                                  inStock: inStock,
                                );

                                for (var i = 0; i < _qty; i++) {
                                  prov.add(posSku);
                                }
                                Navigator.pop<bool>(context, true);
                              }
                            : null,
                        style: FilledButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                        ),
                        child: Text(
                          (_selected.length == attrsMap.length &&
                                  matched != null)
                              ? 'Add to cart — Rp ${money.format(price)}'
                              : 'Pilih semua varian',
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

  // ==== helpers utk ProductSku ====
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
// (Opsional) EXACT PURCHASE-STYLE VARIANT SHEET
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

    // auto-pilih attr yg hanya punya 1 opsi
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

            // attributes
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

            // qty + CTA
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
              .toList(growable: false);

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

class _SalesProductCard extends StatelessWidget {
  final _SalesProductGroup group;
  final int selectedQty;
  final VoidCallback onChoose;

  const _SalesProductCard({
    required this.group,
    required this.selectedQty,
    required this.onChoose,
  });

  @override
  Widget build(BuildContext context) {
    Widget image() {
      final url = group.thumbUrl;
      final fallback = Container(
        decoration: BoxDecoration(
          color: AppColors.greyBackground,
          borderRadius: BorderRadius.circular(12),
        ),
        child: const Center(
          child: Icon(Icons.image, color: AppColors.disabledFg),
        ),
      );
      return ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: (url != null && url.isNotEmpty)
            ? Image.network(
                url,
                height: 110,
                width: double.infinity,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) =>
                    SizedBox(height: 110, child: fallback),
              )
            : SizedBox(height: 110, child: fallback),
      );
    }

    return Container(
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
        border: Border.all(color: AppColors.divider),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Stack(
              children: [
                image(),
                if (selectedQty > 0)
                  Positioned(
                    top: 8,
                    right: 8,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(999),
                        boxShadow: const [
                          BoxShadow(color: Color(0x1A000000), blurRadius: 10),
                        ],
                      ),
                      child: Text(
                        '$selectedQty',
                        style: const TextStyle(fontWeight: FontWeight.w800),
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              group.productName,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontWeight: FontWeight.w800,
                color: AppColors.primaryText,
              ),
            ),
            const SizedBox(height: 6),
            Text('from ${formatRp(group.minPrice)}', style: DS.tsPrice),
            const Spacer(),
            SizedBox(
              height: 40,
              width: double.infinity,
              child: FilledButton(
                onPressed: onChoose,
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: Text('Choose'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ===== Sticky header untuk sheets (MINIMAL) =====
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
              color: UI.line,
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
                    Text(title, style: UI.tsH6),
                    if (caption != null) ...[
                      const SizedBox(height: 4),
                      Text(caption!, style: UI.tsSub),
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
        ],
      ),
    );
  }
}
