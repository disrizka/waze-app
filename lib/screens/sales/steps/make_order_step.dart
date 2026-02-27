import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:wa_blast/models/product_models/product_model.dart';
import 'package:wa_blast/providers/product_provider.dart';
import 'package:wa_blast/providers/sales_provider.dart';
import 'package:wa_blast/providers/store_provider.dart' as st;

import '../../../constants/app_colors.dart';
import '../../../constants/design_system.dart';
import '../../../widgets/product_picker_sheet.dart';
import '../../../widgets/product_variant_picker_sheet.dart';
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
    if (sp.stores.isEmpty && !sp.loadingList) {
      await sp.fetchStoreLocations(context);
    }

    if (!mounted) return;

    if (sp.stores.length == 1) {
      final s = sp.stores.first;

      sales.setOrderMeta(
        storeLocationId: s.idStoreLocation,
        storeLocationName: s.name,
      );

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

    final prodProv = context.read<ProductProvider>();
    await prodProv.setInfiniteStoreAndRefresh(context, picked.id);

    setState(() {});
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

      await _autoSelectSingleStoreIfNeeded();
    });
  }

  @override
  void dispose() {
    _discountC.dispose();
    _notesC.dispose();
    super.dispose();
  }

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

  int _serviceFeeOn(int base) => 0;

  (int subtotal, int fee, int total) _totals(
    SalesProvider prov,
    int adjustment,
  ) {
    final sub = _subtotalPerItemOnly(prov);
    final fee = 0;
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
                    valueText: storeName,
                    emptyHint: 'Select store…',
                    onTap: _pickStore,
                  ),
                ),
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
          SafeArea(
            minimum: const EdgeInsets.fromLTRB(16, 8, 16, 16),
            child: SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: (!storeNotSelected)
                    ? () {
                        final d = int.tryParse(_discountC.text.trim()) ?? 0;
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

  const double _rowExtent = 86.0;
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

      final itemDisc = prov.perItemDiscountOf(sku.skuId);
      final unitAfterItem = (sku.price - itemDisc).clamp(0, 1 << 31) as int;
      final lineTotal = unitAfterItem * it.qty;

      return SizedBox(
        height: _rowExtent,
        child: _OrderItemTile(
          imageUrl: sku.imageUrl,
          productName: sku.productName,
          // ✅ tampilkan UUID (diisi dari AddProductSheet saat add to cart)
          skuCode: sku.skuCode,
          qty: it.qty,
          lineTotal: lineTotal,
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

  /// ✅ sekarang dipakai untuk menampilkan UUID SKU (bukan code lama)
  final String skuCode;

  final int qty;
  final int lineTotal;
  final VoidCallback onMinus;
  final VoidCallback onPlus;

  const _OrderItemTile({
    Key? key,
    required this.imageUrl,
    required this.productName,
    required this.skuCode,
    required this.qty,
    required this.lineTotal,
    required this.onMinus,
    required this.onPlus,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final money = NumberFormat.decimalPattern('id_ID');
    return SizedBox(
      height: 86,
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
                Text(
                  productName,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 4),
                // ✅ tampil UUID
                Text(
                  skuCode,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: UI.tsSub,
                ),
                const SizedBox(height: 4),
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
    return SafeNetImage(
      url: url,
      width: 64,
      height: 64,
      borderRadius: BorderRadius.circular(12),
      crashIcon: const Center(child: Icon(Icons.image, color: UI.sub)),
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
  final int subtotal;
  final String serviceFeeLabel;
  final int serviceFee;
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
// ADD PRODUCT BOTTOM SHEET (with Brand/Category filter)
// - No clear buttons on grid
// - Reset all only exists in advanced sheet
// ===============================

@immutable
class _CatalogFilters {
  final String? brandId;
  final String? categoryId;

  const _CatalogFilters({this.brandId, this.categoryId});

  bool get hasAny =>
      (brandId != null && brandId!.isNotEmpty) ||
      (categoryId != null && categoryId!.isNotEmpty);

  String toSearchString({required String rawQuery}) {
    final tokens = <String>[];
    final q = rawQuery.trim();
    if (q.isNotEmpty) tokens.add('q:$q');
    if ((brandId ?? '').isNotEmpty) tokens.add('brand:$brandId');
    if ((categoryId ?? '').isNotEmpty) tokens.add('cat:$categoryId');
    return tokens.join(' ');
  }
}

class _PickerOption {
  final String id;
  final String label;
  const _PickerOption({required this.id, required this.label});
}

Future<String?> _showSimpleListPicker({
  required BuildContext context,
  required String title,
  required List<_PickerOption> options,
  String? selectedId,
}) async {
  final searchC = TextEditingController();
  List<_PickerOption> filtered = List.of(options);

  return showModalBottomSheet<String>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.white,
    useSafeArea: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
    ),
    builder: (ctx) {
      return DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.86,
        minChildSize: 0.55,
        maxChildSize: 0.95,
        builder: (_, sheetCtrl) {
          return StatefulBuilder(
            builder: (context, setState) {
              void doFilter(String q) {
                final low = q.trim().toLowerCase();
                setState(() {
                  filtered = options
                      .where((o) => o.label.toLowerCase().contains(low))
                      .toList();
                });
              }

              return Column(
                children: [
                  const SizedBox(height: 8),
                  Container(
                    width: 44,
                    height: 4,
                    decoration: BoxDecoration(
                      color: const Color(0xFFE5E7EB),
                      borderRadius: BorderRadius.circular(999),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 18),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            title,
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w800,
                              color: Color(0xFF111827),
                            ),
                          ),
                        ),
                        IconButton(
                          onPressed: () => Navigator.pop(ctx),
                          icon: const Icon(Icons.close_rounded),
                          splashRadius: 20,
                        ),
                      ],
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(18, 0, 18, 10),
                    child: TextField(
                      controller: searchC,
                      onChanged: doFilter,
                      decoration: InputDecoration(
                        hintText: 'Search…',
                        isDense: true,
                        filled: true,
                        fillColor: const Color(0xFFF3F4F6),
                        prefixIcon: const Icon(Icons.search, size: 20),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 10,
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderSide: const BorderSide(
                            color: Color(0xFFE5E7EB),
                          ),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderSide: const BorderSide(
                            color: Color(0xFFCBD5E1),
                          ),
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ),
                  const Divider(height: 1, color: Color(0xFFE5E7EB)),
                  Expanded(
                    child: ListView.separated(
                      controller: sheetCtrl,
                      padding: const EdgeInsets.fromLTRB(8, 8, 8, 16),
                      itemCount: filtered.length,
                      separatorBuilder: (_, __) =>
                          const Divider(height: 1, color: Color(0xFFF3F4F6)),
                      itemBuilder: (_, i) {
                        final o = filtered[i];
                        final isSel = o.id == selectedId;
                        return ListTile(
                          onTap: () => Navigator.pop(ctx, o.id),
                          leading: Radio<String>(
                            value: o.id,
                            groupValue: selectedId,
                            onChanged: (_) => Navigator.pop(ctx, o.id),
                          ),
                          title: Text(
                            o.label,
                            style: const TextStyle(
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF111827),
                            ),
                          ),
                          trailing: isSel
                              ? const Icon(
                                  Icons.check_circle,
                                  color: AppColors.primary,
                                )
                              : null,
                        );
                      },
                    ),
                  ),
                ],
              );
            },
          );
        },
      );
    },
  );
}

Future<String?> _pickBrandId(BuildContext context, {String? selectedId}) async {
  final prov = context.read<ProductProvider>();
  if (prov.brands.isEmpty) {
    await prov.fetchProductBrands(context);
  }
  final opts = prov.brands
      .map((b) => _PickerOption(id: b.idProductBrand, label: b.name))
      .toList();
  if (!context.mounted) return selectedId;
  return _showSimpleListPicker(
    context: context,
    title: 'Brand',
    options: opts,
    selectedId: selectedId,
  );
}

Future<String?> _pickCategoryId(
  BuildContext context, {
  String? selectedId,
}) async {
  final prov = context.read<ProductProvider>();
  if (prov.categories.isEmpty) {
    await prov.fetchProductCategories(context);
  }
  final opts = prov.categories
      .map((c) => _PickerOption(id: c.idProductCategory, label: c.name))
      .toList();
  if (!context.mounted) return selectedId;
  return _showSimpleListPicker(
    context: context,
    title: 'Category',
    options: opts,
    selectedId: selectedId,
  );
}

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

  // filters
  _CatalogFilters _filters = const _CatalogFilters();

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

      final direct = prefs.getBool('activeBizIsPremium');
      if (direct != null) {
        isPremium = direct == true;
      } else {
        final alt1 = prefs.getBool('isPremiumUser');
        if (alt1 != null) isPremium = alt1 == true;
      }

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
        _isFreePlan = false;
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

  String _composeSearch() {
    final q = _searchC.text.trim();
    return _filters.toSearchString(rawQuery: q);
  }

  Future<void> _applySearchAndRefresh({bool jumpTop = true}) async {
    final composed = _composeSearch();
    await _pp?.setInfiniteSearch(context, composed);
    await _pp?.refreshInfinite(context);

    // trigger page fetch (important for empty list)
    _pp?.pagingController?.fetchNextPage();

    if (jumpTop && _gridScrollC.hasClients) _gridScrollC.jumpTo(0);
    if (mounted) setState(() {});
  }

  Future<void> _kickOnOpen() async {
    if (_kicked || !mounted) return;
    _kicked = true;

    final prov = context.read<ProductProvider>();

    // init paging without filters first (filters apply via _applySearchAndRefresh)
    prov.initInfinitePaging(context, initialSearch: '');

    try {
      await prov
          .ensureDefaultStoreLocation(context)
          .timeout(const Duration(seconds: 6));
    } catch (_) {}

    await _applySearchAndRefresh(jumpTop: false);

    // extra kick
    prov.pagingController?.fetchNextPage();
    Future.delayed(const Duration(milliseconds: 300), () {
      if (!mounted) return;
      if (prov.products.isEmpty) {
        prov.pagingController?.fetchNextPage();
      }
    });
  }

  Future<void> _manualRetry() async {
    final prov = context.read<ProductProvider>();
    prov.initInfinitePaging(context, initialSearch: _composeSearch());
    try {
      await prov
          .ensureDefaultStoreLocation(context)
          .timeout(const Duration(seconds: 6));
    } catch (_) {}
    await _applySearchAndRefresh(jumpTop: false);
    prov.pagingController?.fetchNextPage();
    if (mounted) setState(() {});
  }

  void _debouncedSearch(String _) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 250), () async {
      await _applySearchAndRefresh(jumpTop: true);
    });
  }

  Future<void> _openAdvancedFilter(ProductProvider prov) async {
    if (prov.brands.isEmpty) await prov.fetchProductBrands(context);
    if (prov.categories.isEmpty) await prov.fetchProductCategories(context);
    if (!mounted) return;

    final result = await showModalBottomSheet<_CatalogFilters>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => _AddProductAdvancedFilterSheet(initial: _filters),
    );

    if (!mounted) return;
    if (result != null) {
      setState(() => _filters = result);
      await _applySearchAndRefresh(jumpTop: true);
    }
  }

  void _armLoadMore() {
    if (_loadMoreArmed) return;
    _loadMoreArmed = true;
    Future.delayed(const Duration(milliseconds: 200), () {
      _loadMoreArmed = false;
    });
  }

  String? _brandName(ProductProvider prov, String? id) {
    if (id == null || id.isEmpty) return null;
    final i = prov.brands.indexWhere((b) => b.idProductBrand == id);
    return i == -1 ? null : prov.brands[i].name;
  }

  String? _categoryName(ProductProvider prov, String? id) {
    if (id == null || id.isEmpty) return null;
    final i = prov.categories.indexWhere((c) => c.idProductCategory == id);
    return i == -1 ? null : prov.categories[i].name;
  }

  int _qtyInCartOfSkuUuid(SalesProvider prov, String skuUuid) {
    return prov.qtyBySkuUuid(skuUuid);
  }

  int _remainingStock(Product p, SalesProvider prov, ProductSku? matched) {
    final int stockRaw = matched?.stockQty ?? p.totalStockQty;
    final int alreadyInCart = (matched == null)
        ? 0
        : _qtyInCartOfSkuUuid(prov, matched.uuid);
    return stockRaw - alreadyInCart;
  }

  int _computeUnitPriceWithWholesale(Product p, int basePrice, int qty) {
    if (qty <= 0) return basePrice;
    final List<ProductPrice> tiers = List<ProductPrice>.from(p.productPrices);
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

  Future<void> _openVariantSheetAndApply({
    required SalesProvider salesProv,
    required _SalesProductGroup group,
    required bool showStockUI,
    required bool allowOutOfStock,
  }) async {
    final money = NumberFormat.decimalPattern('id_ID');
    final p = group.product;

    final picked = await showModalBottomSheet<VariantPickerSelection>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (_) => ProductVariantPickerSheet(
        product: p,
        title: 'Choose Variants',
        showPriceInfo: true,
        showStockInfo: showStockUI,
        showSkuCode: true,
        showWholesaleInfo: true,
        enforceValidOption: true,
        showUnitSuffix: true,
        primaryColor: AppColors.primary,
        dividerColor: AppColors.divider,
        secondaryTextColor: AppColors.textSecondary,
        safeAreaMinimum: const EdgeInsets.fromLTRB(16, 12, 16, 0),
        moneyFormatter: money,
        unitPriceResolver: (matched, qty) {
          final basePrice = matched?.price ?? p.basePrice ?? 0;
          return _computeUnitPriceWithWholesale(p, basePrice, qty);
        },
        canIncreaseQty: (matched, qty) {
          if (!showStockUI) return true;
          if (allowOutOfStock) return true;
          final leftRaw = _remainingStock(p, salesProv, matched);
          return leftRaw > 0 && qty < leftRaw;
        },
        isConfirmEnabled: (matched, qty) {
          if (matched == null || qty <= 0) return false;
          if (!showStockUI) return true;
          if (allowOutOfStock) return true;
          return _remainingStock(p, salesProv, matched) > 0;
        },
        confirmLabelResolver: (matched, qty, unitPrice) {
          if (matched == null) return 'Pilih semua varian';
          final leftRaw = _remainingStock(p, salesProv, matched);
          if (showStockUI && !allowOutOfStock && leftRaw <= 0) {
            return 'Stok habis';
          }
          return 'Add to cart — Rp ${money.format(unitPrice * qty)}';
        },
        stockTextResolver: (matched, qty, unitPrice) {
          if (!showStockUI) return '';
          final stockRaw = matched?.stockQty ?? p.totalStockQty;
          final alreadyInCart = (matched == null)
              ? 0
              : _qtyInCartOfSkuUuid(salesProv, matched.uuid);
          final leftRaw = stockRaw - alreadyInCart;
          return 'Stock: $leftRaw'
              '${alreadyInCart > 0 ? "  •  In cart: $alreadyInCart" : ""}';
        },
        stockColorResolver: (matched, qty) {
          if (!showStockUI) return AppColors.textSecondary;
          final leftRaw = _remainingStock(p, salesProv, matched);
          final nonPositive = leftRaw <= 0;
          return (allowOutOfStock && nonPositive)
              ? Colors.red
              : AppColors.textSecondary;
        },
      ),
    );

    if (!mounted || picked == null) return;

    final int leftRaw = _remainingStock(p, salesProv, picked.sku);
    final int toAdd = showStockUI
        ? (allowOutOfStock
              ? picked.qty.clamp(0, 1 << 31)
              : picked.qty.clamp(0, leftRaw.clamp(0, 1 << 31)))
        : picked.qty.clamp(0, 1 << 31);

    if (toAdd <= 0) return;

    final posSku = PosSku(
      skuId: picked.sku.idProductSku,
      skuUuid: picked.sku.uuid,
      skuCode: picked.sku.code,
      price: picked.unitPrice,
      productId: p.idProduct,
      productName: p.name,
      imageUrl: p.primaryImageUrl ?? '',
      inStock: !p.isHide,
    );

    salesProv.addQuantity(posSku, toAdd);
    salesProv.normalizeCart();

    if (mounted) {
      Navigator.pop<bool>(context, true);
    }
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchC.dispose();
    _gridScrollC.dispose();
    super.dispose();
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

    // FREE plan: no stock UI & no restriction
    final bool showStockUI = !_isFreePlan;
    final bool effectiveAllowOutOfStock = _isFreePlan
        ? true
        : _canSellOutOfStock;

    // minimal filter summary text (no reset button here)
    final bName = _brandName(prov, _filters.brandId);
    final cName = _categoryName(prov, _filters.categoryId);
    final String filterSummary = _filters.hasAny
        ? [
            if ((bName ?? '').isNotEmpty) 'Brand: $bName',
            if ((cName ?? '').isNotEmpty) 'Category: $cName',
          ].join(' • ')
        : '';

    return ProductPickerSheet(
      title: 'Select Products',
      searchController: _searchC,
      searchHintText: 'Search product / SKU',
      onSearchSubmitted: (_) async {
        await _applySearchAndRefresh(jumpTop: true);
      },
      onSearchChanged: (t) {
        setState(() {});
        _debouncedSearch(t);
      },
      onClearSearch: () async {
        _searchC.clear();
        await _applySearchAndRefresh(jumpTop: true);
      },
      onFilterPressed: () async => _openAdvancedFilter(prov),
      filterSummary: filterSummary,
      body: (visible.isEmpty)
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
              child: ListView.builder(
                controller: _gridScrollC,
                padding: const EdgeInsets.fromLTRB(0, 8, 0, 12),
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
                  final selectedForProduct = g.skus.isNotEmpty
                      ? g.skus.fold<int>(
                          0,
                          (sum, sku) => sum + salesProv.qtyBySkuUuid(sku.uuid),
                        )
                      : salesProv.cartItems
                            .where((it) => it.sku.productId == g.productId)
                            .fold<int>(0, (s, it) => s + it.qty);

                  final bool isOut = showStockUI
                      ? (p.totalStockQty <= 0)
                      : false;
                  final bool hardBlock =
                      isOut && showStockUI && !effectiveAllowOutOfStock;
                  final double cardOpacity = hardBlock ? 0.6 : 1.0;

                  return Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: AbsorbPointer(
                      absorbing: hardBlock,
                      child: Opacity(
                        opacity: cardOpacity,
                        child: ProductPickerListCard(
                          title: g.productName,
                          priceText: 'from Rp ${formatThousands(g.minPrice)}',
                          stockText: showStockUI
                              ? 'Stock: ${p.totalStockQty}'
                              : null,
                          stockColor: (showStockUI && isOut)
                              ? Colors.red
                              : const Color(0xFF475569),
                          imageUrl: g.thumbUrl,
                          selectedQty: selectedForProduct,
                          disabled: hardBlock,
                          showOutOfStockOverlay: showStockUI && isOut,
                          primaryColor: AppColors.primary,
                          onChoose: () => _openVariantSheetAndApply(
                            salesProv: salesProv,
                            group: g,
                            showStockUI: showStockUI,
                            allowOutOfStock: effectiveAllowOutOfStock,
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
      footerText: (selectedItems > 0)
          ? '$selectedItems SKU • $selectedQty qty'
          : 'Pilih produk lalu tentukan variannya',
      onUseSelected: () async => Navigator.pop<bool>(context, true),
      useSelectedLabel: 'Use selected',
      primaryColor: AppColors.primary,
      minimumSafeArea: const EdgeInsets.fromLTRB(16, 12, 16, 16),
      heightFactor: 0.9,
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

// ===============================
// Advanced Filter Sheet (Brand & Category)
// Reset all hanya di sini
// ===============================

class _AddProductAdvancedFilterSheet extends StatefulWidget {
  final _CatalogFilters initial;
  const _AddProductAdvancedFilterSheet({required this.initial});

  @override
  State<_AddProductAdvancedFilterSheet> createState() =>
      _AddProductAdvancedFilterSheetState();
}

class _AddProductAdvancedFilterSheetState
    extends State<_AddProductAdvancedFilterSheet> {
  String? _brandId;
  String? _categoryId;

  @override
  void initState() {
    super.initState();
    _brandId = widget.initial.brandId;
    _categoryId = widget.initial.categoryId;
  }

  String? _brandName(ProductProvider prov, String? id) {
    if (id == null || id.isEmpty) return null;
    final i = prov.brands.indexWhere((b) => b.idProductBrand == id);
    return i == -1 ? null : prov.brands[i].name;
  }

  String? _categoryName(ProductProvider prov, String? id) {
    if (id == null || id.isEmpty) return null;
    final i = prov.categories.indexWhere((c) => c.idProductCategory == id);
    return i == -1 ? null : prov.categories[i].name;
  }

  Future<void> _pickBrand(BuildContext context) async {
    final picked = await _pickBrandId(context, selectedId: _brandId);
    if (!mounted) return;
    setState(() => _brandId = picked);
  }

  Future<void> _pickCategory(BuildContext context) async {
    final picked = await _pickCategoryId(context, selectedId: _categoryId);
    if (!mounted) return;
    setState(() => _categoryId = picked);
  }

  void _resetAll() {
    setState(() {
      _brandId = null;
      _categoryId = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    final prov = context.watch<ProductProvider>();

    return DraggableScrollableSheet(
      initialChildSize: 0.72,
      minChildSize: 0.5,
      maxChildSize: 0.92,
      expand: false,
      builder: (context, controller) {
        return Column(
          children: [
            const SizedBox(height: 8),
            Container(
              width: 44,
              height: 4,
              decoration: BoxDecoration(
                color: const Color(0xFFE5E7EB),
                borderRadius: BorderRadius.circular(999),
              ),
            ),
            const SizedBox(height: 10),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 18),
              child: Row(
                children: [
                  const Expanded(
                    child: Text(
                      'Filter',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF111827),
                      ),
                    ),
                  ),
                  TextButton(
                    onPressed: _resetAll,
                    style: TextButton.styleFrom(
                      foregroundColor: AppColors.textSecondary,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 8,
                      ),
                      minimumSize: Size.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                    child: const Text(
                      'Reset all',
                      style: TextStyle(fontWeight: FontWeight.w800),
                    ),
                  ),
                  const SizedBox(width: 6),
                  SizedBox(
                    height: 36,
                    child: ElevatedButton(
                      onPressed: () {
                        Navigator.pop(
                          context,
                          _CatalogFilters(
                            brandId: _brandId,
                            categoryId: _categoryId,
                          ),
                        );
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                        elevation: 0,
                        padding: const EdgeInsets.symmetric(horizontal: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: const Text(
                        'Apply',
                        style: TextStyle(fontWeight: FontWeight.w800),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            Expanded(
              child: ListView(
                controller: controller,
                padding: const EdgeInsets.fromLTRB(18, 8, 18, 18),
                children: [
                  SelectFieldTile(
                    label: 'Brand',
                    valueText: _brandName(prov, _brandId),
                    emptyHint: 'All brands',
                    onTap: () => _pickBrand(context),
                  ),
                  const SizedBox(height: 14),
                  SelectFieldTile(
                    label: 'Category',
                    valueText: _categoryName(prov, _categoryId),
                    emptyHint: 'All categories',
                    onTap: () => _pickCategory(context),
                  ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }
}

// ===============================
// Product grid header + badges
// ===============================

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
