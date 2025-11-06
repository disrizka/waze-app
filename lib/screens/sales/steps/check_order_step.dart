// =====================================================
// CHECK ORDER STEP (Order details only) + withHeader + Payment CTA
// =====================================================
import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; // ← for digitsOnly
import 'package:intl/intl.dart'; // ← for NumberFormat
import 'package:provider/provider.dart';
import 'package:wa_blast/constants/app_colors.dart';
import 'package:wa_blast/constants/design_system.dart';
import 'package:wa_blast/providers/sales_provider.dart';
import 'package:wa_blast/screens/sales/steps/make_order_step.dart'
    show UI; // gunakan UI tokens
import 'package:wa_blast/widgets/reusable_pickers.dart';
import 'package:wa_blast/widgets/show_fancy_snack_bar.dart';
import 'package:wa_blast/widgets/stepper_header.dart';
import 'package:wa_blast/widgets/sticky_totals_bar.dart';

class CheckOrderStep extends StatefulWidget {
  final bool withHeader;
  const CheckOrderStep({super.key, this.withHeader = true});

  @override
  CheckOrderStepState createState() => CheckOrderStepState();
}

class CheckOrderStepState extends State<CheckOrderStep> {
  final _formKey = GlobalKey<FormState>();

  String? _storeId;
  String _storeName = '';

  String? _customerId;
  String _customerName = '';

  final _shippingC = TextEditingController(); // reserved (optional)
  final _noteC = TextEditingController();

  final _orderDiscountC = TextEditingController(); // NEW

  int _paymentMethod = 1;

  // Controller untuk scroll vertikal DataTable (order table)
  final ScrollController _tableVScrollCtrl = ScrollController();

  static const _methods = <_PaymentOption>[
    _PaymentOption(1, 'Cash', Icons.payments_outlined, 'Pay with cash'),
    _PaymentOption(2, 'Debit', Icons.credit_card, 'Use a debit card'),
    _PaymentOption(3, 'QRIS/VA', Icons.qr_code, 'QRIS, e-wallet, or VA'),
  ];

  @override
  void initState() {
    super.initState();
    final prov = context.read<SalesProvider>();
    // Prefill dari provider
    _storeId = prov.storeLocationId;
    _storeName = prov.storeLocationName ?? '';
    _shippingC.text = (prov.shippingFee ?? 0).toString();
    _noteC.text = prov.note ?? '';
    _paymentMethod = prov.paymentMethod ?? 1;
    _orderDiscountC.text = (prov.discount ?? 0).toString();

    _customerId = prov.customerId;
    _customerName = prov.customerName ?? '';
  }

  @override
  void dispose() {
    _shippingC.dispose();
    _noteC.dispose();
    _orderDiscountC.dispose();
    _tableVScrollCtrl.dispose();
    super.dispose();
  }

  // ---------- PICKERS ----------
  Future<void> _pickPaymentMethod() async {
    final selected = await showModalBottomSheet<int>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (_) =>
          _PaymentMethodSheet(current: _paymentMethod, options: _methods),
    );
    if (selected != null && mounted) {
      setState(() => _paymentMethod = selected);
    }
  }

  Future<void> _pickStore() async {
    final picked = await showStorePickerSheet(context, selectedId: _storeId);
    if (picked != null && mounted) {
      setState(() {
        _storeId = picked.id;
        _storeName = picked.label;
      });
    }
  }

  Future<void> _pickCustomer() async {
    final picked = await showCustomerPickerSheet(
      context,
      selectedId: _customerId,
    );
    if (picked != null && mounted) {
      setState(() {
        _customerId = picked.id;
        _customerName = picked.label;
      });
    }
  }

  String _paymentLabel(int v) => _methods
      .firstWhere((e) => e.value == v, orElse: () => _methods.first)
      .label;

  /// Dipanggil dari parent / CTA sebelum lanjut ke Payment
  bool validateAndPersist(BuildContext ctx) {
    if (_storeId == null || _storeId!.isEmpty) {
      showFancySnackBar(
        ctx,
        message: 'Please select store location',
        icon: Icons.store_mall_directory_outlined,
        actionLabel: 'Select',
        onAction: () {
          // arahkan user ke picker lokasi store, kalau ada
        },
      );
      return false;
    }
    if (_formKey.currentState?.validate() != true) return false;

    final shipping = int.tryParse(_shippingC.text.trim()) ?? 0;

    ctx.read<SalesProvider>().setOrderMeta(
      storeLocationId: _storeId,
      storeLocationName: _storeName,
      shippingFee: shipping,
      note: _noteC.text.trim(),
      paymentMethod: _paymentMethod,
      customerId: _customerId,
      customerName: _customerName,
    );
    return true;
  }

  @override
  Widget build(BuildContext context) {
    // untuk men-disable tombol payment bila cart kosong
    final cartLen = context.select<SalesProvider, int>((p) => p.cartLen);
    final prov = context.watch<SalesProvider>();

    final content = Form(
      key: _formKey,
      child: Column(
        children: [
          const SizedBox(height: 12),

          // ====== ORDER SUMMARY (LIST kompak, sama persis MakeOrderStep) ======
          _CardSection(
            titleWidget: Row(
              children: const [
                Icon(Icons.receipt_long_outlined, size: 18, color: UI.sub),
                SizedBox(width: 8),
                Text('Order summary', style: UI.tsSub),
              ],
            ),
            child: _OrderSummaryList(prov: prov), // ← pakai widget stateful
          ),
          const SizedBox(height: 12),
        ],
      ),
    );

    return Container(
      color: UI.bg,
      child: Column(
        children: [
          if (widget.withHeader) const StepperHeader(activeIndex: 1),

          // body scrollable
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: content,
            ),
          ),

          // Sticky Totals bar (subtotal, fee, discount hijau)
          Builder(
            builder: (_) {
              final adjustment = prov.discount ?? 0;

              // subtotal efektif = Σ (price - perItemDisc) * qty  (clamp ≥ 0)
              final subtotal = prov.cartItems.fold<int>(0, (sum, it) {
                final d = prov.perItemDiscountOf(it.sku.skuId);
                final unitAfter = (it.sku.price - d);
                final safeUnit = unitAfter < 0 ? 0 : unitAfter;
                return sum + safeUnit * it.qty;
              });

              // service fee ditiadakan
              const serviceFee = 0;

              // total akhir = subtotal - adjustment (clamp ≥ 0)
              final total = subtotal - adjustment;
              final grand = total < 0 ? 0 : total;

              return StickyTotalsBar(
                subtotal: subtotal, // tidak ditampilkan di komponen
                serviceFeeLabel: '', // diset kosong (tidak ditampilkan)
                serviceFee: serviceFee, // 0
                adjustment: adjustment,
                total: grand,
                onNext: null, // tidak dipakai di step ini
                enabled: prov.cartLen > 0,
              );
            },
          ),

          // CTA Payment
          SafeArea(
            minimum: const EdgeInsets.fromLTRB(16, 8, 16, 16),
            child: SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: cartLen == 0
                    ? null
                    : () {
                        final ok = validateAndPersist(context);
                        if (!ok) return;
                        context.read<SalesProvider>().goTo(2); // ➜ step payment
                      },
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
                child: const Text('Payment'),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ====== Compact DataTable builder (show-only selection) ======
  Widget _orderTable(int cartLen, SalesProvider prov) {
    if (cartLen == 0) {
      return Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: UI.bg,
          borderRadius: BorderRadius.circular(10),
        ),
        child: const Row(
          children: [
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
                    fontWeight: itemDisc > 0
                        ? FontWeight.w800
                        : FontWeight.w700,
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
                  // diskon per item akan dirapikan oleh provider saat remove
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
                    controller:
                        _tableVScrollCtrl, // ← pakai controller yang sama
                    thumbVisibility: true,
                    thickness: 6,
                    radius: const Radius.circular(999),
                    child: SingleChildScrollView(
                      controller: _tableVScrollCtrl, // ← sama
                      child: table,
                    ),
                  ),
                ),
              )
            : table,
      ),
    );
  }
}

// ---- MINIMAL SELECT TILE ----
class _SelectTile extends StatelessWidget {
  final String valueText;
  final String? subtitleText;
  final Widget? leading;
  final VoidCallback onTap;

  const _SelectTile({
    required this.valueText,
    this.subtitleText,
    this.leading,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Ink(
      decoration: BoxDecoration(
        border: Border.all(color: UI.line),
        borderRadius: BorderRadius.circular(10),
      ),
      child: ListTile(
        onTap: onTap,
        leading: leading,
        title: Text(
          valueText,
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        subtitle: (subtitleText?.isNotEmpty ?? false)
            ? Text(subtitleText!, style: UI.tsSub)
            : null,
        trailing: const Icon(Icons.expand_more, color: UI.sub),
        dense: true,
        visualDensity: VisualDensity.compact,
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
      ),
    );
  }
}

// ===== Order Summary — Compact List (auto height, scroll only if > 4/9) =====
class _OrderSummaryList extends StatefulWidget {
  final SalesProvider prov;
  const _OrderSummaryList({Key? key, required this.prov}) : super(key: key);

  @override
  State<_OrderSummaryList> createState() => _OrderSummaryListState();
}

class _OrderSummaryListState extends State<_OrderSummaryList> {
  final ScrollController _listCtrl = ScrollController();

  @override
  void dispose() {
    _listCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final prov = widget.prov;

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
      controller: needScroll
          ? _listCtrl
          : null, // ← pasang controller saat scroll
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

        // hitung line total (harga efek per item × qty)
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
            lineTotal: lineTotal,
            onMinus: () => prov.removeOne(sku),
            onPlus: () => prov.add(sku),
          ),
        );
      },
    );

    if (!needScroll) return list;

    // batasi tinggi sesuai device: 4 baris (mobile) / 9 baris (tablet)
    final double maxHeight =
        (_rowExtent * maxVisible) + (1.0 * (maxVisible - 1));

    return ConstrainedBox(
      constraints: BoxConstraints(maxHeight: maxHeight),
      child: Scrollbar(
        controller: _listCtrl, // ← pakai controller yang sama
        thumbVisibility: true,
        radius: const Radius.circular(999),
        child: list,
      ),
    );
  }
}

class _OrderItemTile extends StatelessWidget {
  final String imageUrl;
  final String productName;
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
                // TOTAL per SKU (line total)
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

// ---- PAYMENT METHOD SHEET (MINIMAL) ----
class _PaymentMethodSheet extends StatelessWidget {
  final int current;
  final List<_PaymentOption> options;
  const _PaymentMethodSheet({required this.current, required this.options});

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      minimum: const EdgeInsets.fromLTRB(16, 16, 16, 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 44,
            height: 4,
            decoration: BoxDecoration(
              color: UI.line,
              borderRadius: BorderRadius.circular(999),
            ),
          ),
          const SizedBox(height: 12),
          const Text(
            'Choose payment method',
            style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
          ),
          const SizedBox(height: 8),
          ...options.map((m) {
            final selected = m.value == current;
            return Container(
              margin: const EdgeInsets.only(bottom: 8),
              decoration: BoxDecoration(
                color: Colors.white,
                border: Border.all(
                  color: selected ? AppColors.primary : UI.line,
                ),
                borderRadius: BorderRadius.circular(12),
              ),
              child: ListTile(
                onTap: () => Navigator.pop<int>(context, m.value),
                leading: Icon(
                  m.icon,
                  color: selected ? AppColors.primary : UI.text,
                ),
                title: Text(
                  m.label,
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    color: selected ? AppColors.primary : UI.text,
                  ),
                ),
                subtitle: Text(m.desc, style: UI.tsSub),
                trailing: Icon(
                  selected
                      ? Icons.radio_button_checked
                      : Icons.radio_button_off,
                  color: selected ? AppColors.primary : UI.sub,
                ),
                dense: true,
              ),
            );
          }),
        ],
      ),
    );
  }
}

class _PaymentOption {
  final int value;
  final String label;
  final IconData icon;
  final String desc;
  const _PaymentOption(this.value, this.label, this.icon, this.desc);
}

// ---- LOCAL MINIMAL SECTION CARD ----
class _CardSection extends StatelessWidget {
  final String? title;
  final Widget? titleWidget;
  final Widget child;

  const _CardSection({this.title, this.titleWidget, required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: UI.line),
        borderRadius: BorderRadius.circular(12),
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
              child: Text(title!, style: UI.tsSub),
            ),
          child,
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

class _RequiredTag extends StatelessWidget {
  const _RequiredTag();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.only(left: 6),
      child: Text(
        '(required)',
        style: TextStyle(
          fontSize: 11, // kecil
          fontWeight: FontWeight.w700,
          color: UI.sub, // merah
        ),
      ),
    );
  }
}
