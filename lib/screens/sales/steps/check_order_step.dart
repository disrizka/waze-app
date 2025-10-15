// =====================================================
// CHECK ORDER STEP (Order details only) + withHeader + Payment CTA
// =====================================================
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:wa_blast/constants/app_colors.dart';
import 'package:wa_blast/constants/design_system.dart' hide UI;
import 'package:wa_blast/providers/sales_provider.dart';
import 'package:wa_blast/screens/sales/steps/make_order_step.dart'
    show UI, StickyTotalsBar; // gunakan UI tokens & totals bar
import 'package:wa_blast/widgets/reusable_pickers.dart';
import 'package:wa_blast/widgets/stepper_header.dart';

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

  int _paymentMethod = 1;

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

    _customerId = prov.customerId;
    _customerName = prov.customerName ?? '';
  }

  @override
  void dispose() {
    _shippingC.dispose();
    _noteC.dispose();
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
      ScaffoldMessenger.of(ctx).showSnackBar(
        const SnackBar(content: Text('Please select store location')),
      );
      return false;
    }
    if (_customerId == null || _customerId!.isEmpty) {
      ScaffoldMessenger.of(
        ctx,
      ).showSnackBar(const SnackBar(content: Text('Please select customer')));
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

    final content = Form(
      key: _formKey,
      child: Column(
        children: [
          _CardSection(
            titleWidget: Row(
              children: [
                const Icon(
                  Icons.store_mall_directory_outlined,
                  size: 18,
                  color: UI.sub,
                ),
                const SizedBox(width: 8),
                Text('Store', style: UI.tsSub),
              ],
            ),
            child: PickerField(
              placeholder: 'Select store',
              value: _storeName,
              onTap: _pickStore,
            ),
          ),
          const SizedBox(height: 12),

          _CardSection(
            titleWidget: Row(
              children: [
                const Icon(Icons.person_outline, size: 18, color: UI.sub),
                const SizedBox(width: 8),
                Text('Customer', style: UI.tsSub),
              ],
            ),
            child: PickerField(
              placeholder: 'Select customer',
              value: _customerName,
              onTap: _pickCustomer,
            ),
          ),
          const SizedBox(height: 12),

          _CardSection(
            titleWidget: Row(
              children: [
                const Icon(
                  Icons.sticky_note_2_outlined,
                  size: 18,
                  color: UI.sub,
                ),
                const SizedBox(width: 8),
                Text('Notes', style: UI.tsSub),
              ],
            ),
            child: TextFormField(
              controller: _noteC,
              decoration: InputDecoration(
                hintText: 'Optional notes',
                isDense: true,
                border: UI.thinBorder(),
                focusedBorder: UI.thinBorder(AppColors.primary),
              ),
              maxLines: 2,
            ),
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
          // Sticky Totals bar (tanpa subtotal/service fee di UI)
          Builder(
            builder: (_) {
              final prov = context.watch<SalesProvider>();
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
