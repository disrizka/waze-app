// ===============================
// Add Purchase PAGE (3-step)
// ===============================
import 'dart:ui';

import 'package:animations/animations.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:wa_blast/constants/design_system.dart';
import 'package:wa_blast/models/product_models/product_model.dart';
import 'package:wa_blast/providers/product_provider.dart';
import 'package:wa_blast/providers/purchase_provider.dart';
import 'package:wa_blast/widgets/stepper_header.dart';
import 'package:wa_blast/widgets/reusable_pickers.dart';

class _PurchaseRow {
  final String productId;
  final String skuId;
  final String productName;
  final String skuLabel; // nama SKU / kode
  final String? imageUrl;
  final int defaultPrice; // harga unit dari SKU (default)
  int customPrice; // harga unit input user
  int qty;
  int discountPerItem; // diskon per item (IDR)

  int get unitBasePrice => customPrice;
  int get unitPriceAfterDisc =>
      (unitBasePrice - discountPerItem).clamp(0, 1 << 31).toInt();

  int get lineTotal => unitPriceAfterDisc * qty;

  _PurchaseRow({
    required this.productId,
    required this.skuId,
    required this.productName,
    required this.skuLabel,
    required this.defaultPrice,
    int? customPrice,
    this.imageUrl,
    this.qty = 1,
  }) : customPrice = customPrice ?? 0,
       discountPerItem = 0;
}

class AddPurchasePage extends StatefulWidget {
  const AddPurchasePage({super.key});

  @override
  State<AddPurchasePage> createState() => _AddPurchasePageState();
}

class _AddPurchasePageState extends State<AddPurchasePage> {
  final _formKey = GlobalKey<FormState>();
  bool _submitting = false;
  int _lastStep = 0;

  /// 0 = Details, 1 = Items, 2 = Review
  int _currentStep = 0;

  // meta fields
  final _numberC = TextEditingController(); // optional
  final _referenceC = TextEditingController(text: '');
  final _noteC = TextEditingController();
  final _discountOrderC = TextEditingController(text: '0');
  final _shippingFeeC = TextEditingController(text: '0');

  int get _orderDiscount => int.tryParse(_discountOrderC.text.trim()) ?? 0;
  int get _shippingFee => int.tryParse(_shippingFeeC.text.trim()) ?? 0;

  String? _storeId;
  String _storeName = '';

  // Supplier
  String? _supplierId;
  String _supplierName = '';

  // items
  final Map<String, _PurchaseRow> _rows = {}; // key: skuId

  // ===== Responsive helpers =====
  bool get _isTablet {
    final shortest = MediaQuery.of(context).size.shortestSide;
    return shortest >= 600;
  }

  double get _maxContentWidth => _isTablet ? 960 : double.infinity;
  EdgeInsets get _contentPadding => _isTablet
      ? const EdgeInsets.fromLTRB(24, 12, 24, 16)
      : const EdgeInsets.fromLTRB(16, 12, 16, 16);

  @override
  void initState() {
    super.initState();
    if (_referenceC.text.trim().isEmpty) {
      _referenceC.text = _generateDefaultReference();
    }
  }

  @override
  void dispose() {
    _numberC.dispose();
    _referenceC.dispose();
    _noteC.dispose();
    _discountOrderC.dispose();
    _shippingFeeC.dispose();
    super.dispose();
  }

  String _generateDefaultReference() {
    final seed = DateTime.now().millisecondsSinceEpoch;
    final six = 100000 + (seed % 900000);
    return 'REF-$six';
  }

  void _showSnack(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  void _goToStep(int step) {
    setState(() {
      _currentStep = step.clamp(0, 2);
    });
  }

  Future<void> _handleBack() async {
    if (_currentStep > 0) {
      _goToStep(_currentStep - 1);
      return;
    }
    if (!mounted) return;
    final nav = Navigator.of(context);
    if (nav.canPop()) {
      nav.pop();
      return;
    }
    nav.pushReplacementNamed('/purchase/list');
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

  Future<void> _pickSupplier() async {
    final picked = await showSupplierPickerSheet(
      context,
      selectedId: _supplierId,
    );
    if (picked != null && mounted) {
      setState(() {
        _supplierId = picked.id;
        _supplierName = picked.label;
      });
    }
  }

  Future<void> _openSkuPicker() async {
    final picked = await showModalBottomSheet<List<_PurchaseRow>>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (_) => ChangeNotifierProvider.value(
        value: context.read<ProductProvider>(),
        child: _CenteredConstrainedSheet(
          maxWidth: _isTablet ? 720 : double.infinity,
          child: _ProductGridPicker(initial: _rows),
        ),
      ),
    );

    if (picked == null || !mounted) return;

    setState(() {
      final pickedIds = picked.map((e) => e.skuId).toSet();
      _rows.removeWhere((skuId, _) => !pickedIds.contains(skuId));
      for (final r in picked) {
        _rows[r.skuId] = r;
      }
    });
  }

  int get _subtotalItems {
    var sum = 0;
    for (final r in _rows.values) {
      sum += r.lineTotal;
    }
    return sum;
  }

  bool get _hasZeroPriceItems => _rows.values.any((r) => r.unitBasePrice <= 0);

  int get _grandTotal {
    final t = _subtotalItems - _orderDiscount + _shippingFee;
    return t < 0 ? 0 : t;
  }

  Map<String, dynamic> _buildPayload() {
    return {
      "number": _numberC.text.trim(), // optional
      "store_location_id": _storeId,
      "supplier_id": _supplierId,
      "note": _noteC.text.trim(),
      "reference": _referenceC.text.trim(),
      "discount": _orderDiscount,
      "shipping_fee": _shippingFee,
      "items": _rows.values
          .where((r) => r.qty > 0)
          .map(
            (r) => {
              "product_id": r.productId,
              "product_sku_id": r.skuId,
              "qty": r.qty,
              "discount": r.discountPerItem,
              "price": r.unitPriceAfterDisc,
            },
          )
          .toList(),
    };
  }

  Future<void> _submit() async {
    if (_rows.isEmpty) {
      _showSnack('Add at least 1 SKU');
      return;
    }
    if (_storeId == null || _storeId!.isEmpty) {
      _showSnack('Please select a store first');
      return;
    }
    if (_supplierId == null || _supplierId!.isEmpty) {
      _showSnack('Please select a supplier first');
      return;
    }
    if (_hasZeroPriceItems) {
      _showSnack('Set all SKU prices above Rp 0 before continuing');
      return;
    }
    if (_formKey.currentState?.validate() != true) return;

    final payload = _buildPayload();

    setState(() => _submitting = true);
    final ok = await context.read<PurchaseProvider>().storePurchase(
      context,
      payload,
    );
    if (!mounted) return;
    setState(() => _submitting = false);

    if (ok) {
      _showCreatedDialog();
    } else {
      final err =
          context.read<PurchaseProvider>().consumeLastError() ?? 'Failed';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(err), backgroundColor: const Color(0xFFDC2626)),
      );
    }
  }

  // ====== STEP FLOW HANDLERS ======

  void _nextFromDetails() {
    if (_storeId == null || _storeId!.isEmpty) {
      _showSnack('Please select a store first');
      return;
    }
    if (_supplierId == null || _supplierId!.isEmpty) {
      _showSnack('Please select a supplier first');
      return;
    }
    _goToStep(1);
  }

  void _nextFromItems() {
    if (_rows.isEmpty) {
      _showSnack('Add at least 1 SKU');
      return;
    }
    if (_hasZeroPriceItems) {
      _showSnack('Set all SKU prices above Rp 0 before continuing');
      return;
    }
    _goToStep(2);
  }

  // ====== UI BUILD ======

  @override
  Widget build(BuildContext context) {
    final hasStore = (_storeId ?? '').isNotEmpty;
    final hasSupplier = (_supplierId ?? '').isNotEmpty;
    final hasItems = _rows.isNotEmpty;
    final hasZeroPrices = _hasZeroPriceItems;
    final canSubmit =
        hasItems && hasStore && hasSupplier && !hasZeroPrices && !_submitting;
    final reverse = _currentStep < _lastStep;
    _lastStep = _currentStep;

    return PopScope(
      canPop: _currentStep == 0,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        _handleBack();
      },
      child: Scaffold(
        backgroundColor: Colors.white,
        appBar: AppBar(
          backgroundColor: Colors.white,
          surfaceTintColor: Colors.transparent,
          elevation: 0,
          scrolledUnderElevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back, color: Colors.black87),
            onPressed: _handleBack,
          ),
          title: Row(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: const [
              Text(
                'Purchase',
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  color: Colors.black,
                ),
              ),
              SizedBox(width: 8),
              Text(
                '/create',
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
            if (_currentStep == 1)
              Padding(
                padding: const EdgeInsets.only(right: 12),
                child: FilledButton.icon(
                  onPressed: _submitting ? null : _openSkuPicker,
                  icon: const Icon(Icons.add_shopping_cart_outlined, size: 16),
                  label: const Text(
                    'Add Items',
                    style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
                  ),
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFF426FD4),
                    foregroundColor: Colors.white,
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    minimumSize: const Size(0, 34),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                ),
              ),
          ],
        ),
        body: SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: BoxConstraints(maxWidth: _maxContentWidth),
              child: Column(
                children: [
                  if (_currentStep == 0 && (!hasStore || !hasSupplier))
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 10,
                      ),
                      margin: const EdgeInsets.only(bottom: 6),
                      color: const Color(0xFFFFF7E6),
                      child: const Row(
                        children: [
                          Icon(
                            Icons.info_outline,
                            size: 18,
                            color: Color(0xFFB45309),
                          ),
                          SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Please select store and supplier before adding products.',
                              style: TextStyle(
                                color: Color(0xFF8A4B08),
                                fontSize: 12.5,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ),
                    )
                  else if (_currentStep == 1 && hasZeroPrices)
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 10,
                      ),
                      margin: const EdgeInsets.only(bottom: 6),
                      color: const Color(0xFFFFF7E6),
                      child: const Row(
                        children: [
                          Icon(
                            Icons.info_outline,
                            size: 18,
                            color: Color(0xFFB45309),
                          ),
                          SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'All SKU prices must be above Rp 0 to continue.',
                              style: TextStyle(
                                color: Color(0xFF8A4B08),
                                fontSize: 12.5,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  StepperHeader(activeIndex: _currentStep),
                  Expanded(
                    child: Form(
                      key: _formKey,
                      child: PageTransitionSwitcher(
                        reverse: reverse,
                        duration: const Duration(milliseconds: 300),
                        transitionBuilder:
                            (child, animation, secondaryAnimation) {
                              return SharedAxisTransition(
                                animation: animation,
                                secondaryAnimation: secondaryAnimation,
                                transitionType:
                                    SharedAxisTransitionType.horizontal,
                                child: child,
                              );
                            },
                        child: ListView(
                          key: ValueKey('purchase-step-$_currentStep'),
                          padding: _contentPadding,
                          children: [_buildStepContent()],
                        ),
                      ),
                    ),
                  ),
                  if (_currentStep == 0)
                    _StepNavBar(
                      secondaryLabel: 'Cancel',
                      primaryLabel: 'Next',
                      primaryEnabled: hasStore && hasSupplier && !_submitting,
                      onSecondary: _handleBack,
                      onPrimary: _nextFromDetails,
                    )
                  else if (_currentStep == 1)
                    _StepNavBar(
                      secondaryLabel: 'Back',
                      primaryLabel: 'Next',
                      primaryEnabled:
                          hasItems && !hasZeroPrices && !_submitting,
                      totalAmount: _subtotalItems,
                      onSecondary: () => _goToStep(0),
                      onPrimary: _nextFromItems,
                    )
                  else
                    _StickyFooterBar(
                      enabled: canSubmit,
                      onSubmit: _submit,
                      onCancel: () => _goToStep(1),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildStepContent() {
    switch (_currentStep) {
      case 0:
        return _buildDetailsStep();
      case 1:
        return _buildItemsStep();
      case 2:
      default:
        return _buildReviewStep();
    }
  }

  // STEP 1: Purchase details (+ notes)
  Widget _buildDetailsStep() {
    return _Section(
      title: 'Purchase details',
      child: Column(
        children: [
          const SizedBox(height: 12),
          _LabeledField(
            label: 'Store',
            isRequired: true,
            child: PickerField(
              placeholder: 'Choose store',
              value: _storeName,
              onTap: _pickStore,
            ),
          ),
          const SizedBox(height: 12),
          _LabeledField(
            label: 'Supplier',
            isRequired: true,
            child: PickerField(
              placeholder: 'Choose supplier',
              value: _supplierName,
              onTap: _pickSupplier,
            ),
          ),
          const SizedBox(height: 12),
          _LabeledField(
            label: 'Notes',
            child: TextFormField(
              controller: _noteC,
              maxLines: 2,
              decoration: UI.input('Optional notes for this purchase...'),
            ),
          ),
          const SizedBox(height: 12),
          // _LabeledField(
          //   label: 'Reference (optional)',
          //   child: TextFormField(
          //     controller: _referenceC,
          //     decoration: UI.input('Auto-generated if empty'),
          //   ),
          // ),
          // const SizedBox(height: 12),
          // _LabeledField(
          //   label: 'Custom number (optional)',
          //   child: TextFormField(
          //     controller: _numberC,
          //     decoration: UI.input('Leave empty to auto-number'),
          //   ),
          // ),
        ],
      ),
    );
  }

  // STEP 2: Items
  Widget _buildItemsStep() {
    return _Section(
      titleWidget: Row(
        children: const [
          Icon(Icons.receipt_long_outlined, size: 18, color: UI.sub),
          SizedBox(width: 8),
          Text('Order summary', style: UI.tsSub),
        ],
      ),
      child: (_rows.isEmpty)
          ? _emptyItemsHint()
          : _ItemsDataTable(
              rows: _rows.values.toList(),
              onPriceChanged: (skuId, value) => setState(() {
                _rows[skuId]!.customPrice = value.clamp(0, 1 << 31);
              }),
              onRemove: (skuId) => setState(() => _rows.remove(skuId)),
              onQtyChanged: (skuId, nextQty) => setState(() {
                if (nextQty <= 0) {
                  _rows.remove(skuId);
                } else {
                  final row = _rows[skuId];
                  if (row != null) {
                    _rows[skuId] = row..qty = nextQty;
                  }
                }
              }),
            ),
    );
  }

  // STEP 3: Payment (discount confirmation)
  Widget _buildReviewStep() {
    return Column(
      children: [
        _Section(
          title: 'Details',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Store & supplier information.',
                style: TextStyle(color: UI.sub, fontSize: 13),
              ),
              const SizedBox(height: 10),
              _summaryRow('Store', _storeName.isEmpty ? '—' : _storeName),
              const SizedBox(height: 4),
              _summaryRow(
                'Supplier',
                _supplierName.isEmpty ? '—' : _supplierName,
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        _Section(
          title: 'Discount',
          child: Column(
            children: [
              _LabeledField(
                label: 'Order discount (IDR)',
                child: TextFormField(
                  controller: _discountOrderC,
                  textAlign: TextAlign.left,
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  decoration: UI.input('0').copyWith(prefixText: 'Rp '),
                  onChanged: (_) => setState(() {}),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        _buildPaymentSummaryCard(),
      ],
    );
  }

  Widget _buildPaymentSummaryCard() {
    final money = NumberFormat.decimalPattern('id_ID');
    return _Section(
      title: 'Payment Summary',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Review subtotal, discount, and total.',
            style: TextStyle(color: UI.sub, fontSize: 13),
          ),
          const SizedBox(height: 14),
          _summaryRow('Subtotal', 'Rp ${money.format(_subtotalItems)}'),
          if (_orderDiscount > 0) ...[
            const SizedBox(height: 4),
            _summaryRow('Discount', '- Rp ${money.format(_orderDiscount)}'),
          ],
          const Divider(height: 18, color: UI.line),
          _summaryRowStrong('Total', 'Rp ${money.format(_grandTotal)}'),
        ],
      ),
    );
  }

  Widget _summaryRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(color: UI.sub, fontSize: 12)),
          const SizedBox(width: 12),
          Flexible(
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: const TextStyle(
                color: UI.text,
                fontWeight: FontWeight.w600,
                fontSize: 12,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _summaryRowStrong(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: const TextStyle(
              color: UI.text,
              fontSize: 14,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(width: 12),
          Flexible(
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: const TextStyle(
                color: UI.text,
                fontWeight: FontWeight.w900,
                fontSize: 17,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _emptyItemsHint() => Container(
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      color: const Color(0xFFF3F4F6),
      borderRadius: BorderRadius.circular(12),
    ),
    child: Row(
      children: const [
        Icon(Icons.inventory_2_outlined, color: Color(0xFFA3A3A3)),
        SizedBox(width: 10),
        Expanded(
          child: Text(
            'Belum ada SKU. Tambahkan dari katalog.',
            style: TextStyle(color: UI.sub),
          ),
        ),
      ],
    ),
  );

  Future<void> _showCreatedDialog() async {
    await showGeneralDialog(
      context: context,
      barrierDismissible: false,
      barrierLabel: 'Purchase Created',
      barrierColor: Colors.black.withOpacity(0.2),
      transitionDuration: const Duration(milliseconds: 180),
      pageBuilder: (context, animation, secondaryAnimation) {
        final isTablet = MediaQuery.of(context).size.shortestSide >= 600;
        final dialogMaxW = isTablet
            ? 520.0
            : MediaQuery.of(context).size.width * 0.86;

        return BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 6, sigmaY: 6),
          child: Center(
            child: Material(
              color: Colors.transparent,
              child: Container(
                width: dialogMaxW,
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 14),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: const [
                    BoxShadow(
                      color: Color(0x1A000000),
                      blurRadius: 16,
                      offset: Offset(0, 6),
                    ),
                  ],
                  border: Border.all(color: UI.line),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 56,
                      height: 56,
                      decoration: BoxDecoration(
                        color: const Color(0xFF10B981).withOpacity(.12),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.check_rounded,
                        size: 28,
                        color: Color(0xFF059669),
                      ),
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      'Purchase Created',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 18,
                        color: UI.text,
                      ),
                    ),
                    const SizedBox(height: 6),
                    const Text(
                      'Pesanan berhasil dibuat.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: UI.sub),
                    ),
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      height: 44,
                      child: FilledButton(
                        style: FilledButton.styleFrom(
                          backgroundColor: const Color(0xFF426FD4),
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        onPressed: () {
                          _closeAfterCreated();
                        },
                        child: const Text(
                          'Close',
                          style: TextStyle(fontWeight: FontWeight.w700),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
      transitionBuilder: (context, animation, secondaryAnimation, child) {
        final fade = CurvedAnimation(parent: animation, curve: Curves.easeOut);
        final scale = CurvedAnimation(
          parent: animation,
          curve: Curves.easeOutBack,
        );

        return FadeTransition(
          opacity: fade,
          child: ScaleTransition(
            scale: Tween<double>(begin: .98, end: 1.0).animate(scale),
            child: child,
          ),
        );
      },
    );
  }

  Future<void> _closeAfterCreated() async {
    if (!mounted) return;

    // 1) Tutup dialog sukses
    Navigator.of(context).pop();

    // 2) Refresh list purchase supaya data terbaru terlihat
    try {
      await context.read<PurchaseProvider>().fetchPurchases(context);
    } catch (_) {}

    // 3) Reset root ke /home, lalu buka purchase list
    if (!mounted) return;
    Navigator.of(context).pushNamedAndRemoveUntil('/home', (route) => false);
    if (!mounted) return;
    Navigator.of(context).pushNamed('/purchase/list');
  }
}

/// Footer navigasi untuk step 1 & 2 (Cancel/Back + Next)
class _StepNavBar extends StatelessWidget {
  final String secondaryLabel;
  final String primaryLabel;
  final bool primaryEnabled;
  final VoidCallback onSecondary;
  final VoidCallback onPrimary;
  final int? totalAmount;

  const _StepNavBar({
    required this.secondaryLabel,
    required this.primaryLabel,
    required this.primaryEnabled,
    required this.onSecondary,
    required this.onPrimary,
    this.totalAmount,
  });

  @override
  Widget build(BuildContext context) {
    final money = NumberFormat.decimalPattern('id_ID');
    return Container(
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
          mainAxisSize: MainAxisSize.min,
          children: [
            if (totalAmount != null) ...[
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Total',
                    style: TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 17,
                      color: UI.text,
                    ),
                  ),
                  Text(
                    'Rp ${money.format(totalAmount)}',
                    style: const TextStyle(
                      fontWeight: FontWeight.w900,
                      fontSize: 18,
                      color: UI.text,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
            ],
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: onSecondary,
                    style: OutlinedButton.styleFrom(
                      foregroundColor: UI.sub,
                      side: const BorderSide(color: UI.line),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                    child: Text(secondaryLabel),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: FilledButton(
                    onPressed: primaryEnabled ? onPrimary : null,
                    style: FilledButton.styleFrom(
                      backgroundColor: UI.blue,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                    child: Text(
                      primaryLabel,
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// Pembungkus untuk mem-center + batasi lebar sheet di iPad
class _CenteredConstrainedSheet extends StatelessWidget {
  final double maxWidth;
  final Widget child;
  const _CenteredConstrainedSheet({
    required this.maxWidth,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    final isTablet = MediaQuery.of(context).size.shortestSide >= 600;
    final sheet = Material(
      color: Colors.white,
      borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
      child: child,
    );

    if (!isTablet) return sheet;

    return SafeArea(
      child: Align(
        alignment: Alignment.bottomCenter,
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: maxWidth),
          child: DecoratedBox(
            decoration: const BoxDecoration(
              borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
              boxShadow: [
                BoxShadow(
                  color: Color(0x26000000),
                  blurRadius: 24,
                  offset: Offset(0, -6),
                ),
              ],
            ),
            child: sheet,
          ),
        ),
      ),
    );
  }
}

class _ProductGridPicker extends StatefulWidget {
  const _ProductGridPicker({required this.initial});
  final Map<String, _PurchaseRow> initial; // skuId -> row

  @override
  State<_ProductGridPicker> createState() => _ProductGridPickerState();
}

class _ProductGridPickerState extends State<_ProductGridPicker> {
  final _searchC = TextEditingController();
  String _q = '';
  late Map<String, _PurchaseRow> _temp;

  bool get _isTablet => MediaQuery.of(context).size.shortestSide >= 600;

  @override
  void initState() {
    super.initState();
    _temp = Map<String, _PurchaseRow>.from(widget.initial);
    _searchC.addListener(() {
      final t = _searchC.text.trim();
      if (t != _q) setState(() => _q = t);
    });

    // load produk pertama kali (ubah nama fn sesuai providermu)
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final pp = context.read<ProductProvider>();
      if (!pp.loadingProducts && (pp.products.isEmpty)) {
        await pp.loadProducts(context);
        if (mounted) setState(() {});
      }
    });
  }

  @override
  void dispose() {
    _searchC.dispose();
    super.dispose();
  }

  // Ambil URL gambar utama dari Product.primaryImageUrl (sudah ada di model)
  String? _thumb(Product p) => p.primaryImageUrl;

  Future<void> _pickVariant(Product p) async {
    // QUICK-ADD: jika tidak ada atribut varian sama sekali
    if (_hasNoVariantAttrs(p)) {
      final s = _defaultSku(p);
      if (s == null) return;

      setState(() {
        final key = s.idProductSku;
        final cur = _temp[key];
        if (cur == null) {
          _temp[key] = _PurchaseRow(
            productId: p.idProduct,
            skuId: s.idProductSku,
            productName: p.name,
            skuLabel: s.code,
            imageUrl: p.primaryImageUrl,
            defaultPrice: s.price,
            qty: 1,
          );
        } else {
          _temp[key] = cur..qty = cur.qty + 1;
        }
      });

      return;
    }

    // NORMAL: ada atribut varian → buka sheet
    final row = await showProductVariantSheet(context, p);
    if (!mounted || row == null) return;
    setState(() {
      final cur = _temp[row.skuId];
      if (cur == null) {
        _temp[row.skuId] = row;
      } else {
        _temp[row.skuId] = cur..qty = cur.qty + row.qty;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final prov = context.watch<ProductProvider>();

    final list = () {
      // Selalu copy dulu supaya mutable
      List<Product> base = List<Product>.from(prov.products);

      if (_q.isNotEmpty) {
        final q = _q.toLowerCase();
        base = base.where((p) {
          final inName = p.name.toLowerCase().contains(q);
          final inSku = p.productSkus.any(
            (s) => s.code.toLowerCase().contains(q),
          );
          return inName || inSku;
        }).toList();
      }

      base.sort((a, b) => a.name.compareTo(b.name));
      return base;
    }();

    final hasAnyNoVariant = list.any(
      (p) => p.productSkus.every((s) => s.attributes.isEmpty),
    );

    final selectedCount = _temp.length;
    final selectedQty = _temp.values.fold<int>(0, (s, r) => s + r.qty);

    Widget body() {
      if (prov.loadingProducts && prov.products.isEmpty) {
        return const Expanded(
          child: Center(child: CircularProgressIndicator()),
        );
      }
      if (prov.productError != null) {
        return Expanded(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.error_outline,
                  color: Color(0xFFDC2626),
                  size: 32,
                ),
                const SizedBox(height: 8),
                const Text(
                  'Failed to load products',
                  style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
                ),
                const SizedBox(height: 6),
                Text(
                  prov.productError!,
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Color(0xFF6B7280)),
                ),
                const SizedBox(height: 12),
                OutlinedButton(
                  onPressed: () => prov.loadProducts(context),
                  child: const Text('Retry'),
                ),
              ],
            ),
          ),
        );
      }
      if (list.isEmpty) {
        return const Expanded(child: Center(child: Text('No products found')));
      }

      final cols = _isTablet
          ? (MediaQuery.of(context).size.width >= 1024 ? 4 : 3)
          : 2;
      final cardAR = _isTablet
          ? (MediaQuery.of(context).size.width >= 1024 ? 0.72 : 0.68)
          : 0.62;

      return Expanded(
        child: GridView.builder(
          padding: _isTablet
              ? const EdgeInsets.fromLTRB(16, 8, 16, 16)
              : const EdgeInsets.fromLTRB(12, 8, 12, 12),

          // 🔧 iPad: 3 kolom fix + mainAxisExtent untuk cegah overflow
          gridDelegate: _isTablet
              ? const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 3,
                  crossAxisSpacing: 16,
                  mainAxisSpacing: 16,
                  mainAxisExtent: 320, // tinggi sel tetap → tidak overflow
                )
              : const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  crossAxisSpacing: 12,
                  mainAxisSpacing: 12,
                  childAspectRatio: 0.62, // iPhone tetap sama
                ),

          itemCount: list.length,
          itemBuilder: (_, i) {
            final p = list[i];
            final qtyOfThisProduct = _temp.values
                .where((r) => r.productId == p.idProduct)
                .fold<int>(0, (s, r) => s + r.qty);

            return _ProductCardFromModel(
              product: p,
              onAdd: () => _pickVariant(p),
              selectedQty: qtyOfThisProduct,
              thumbUrl: _thumb(p),
            );
          },
        ),
      );
    }

    return SafeArea(
      minimum: _isTablet
          ? const EdgeInsets.fromLTRB(24, 12, 24, 16)
          : const EdgeInsets.fromLTRB(16, 12, 16, 16),
      child: Center(
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxWidth: _isTablet ? 900 : double.infinity,
          ),
          child: SizedBox(
            height:
                MediaQuery.of(context).size.height * (_isTablet ? 0.86 : 0.9),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const _SheetHeader(title: 'Select Products'),
                // Search
                Material(
                  elevation: 1,
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(10),
                  child: TextField(
                    controller: _searchC,
                    textInputAction: TextInputAction.search,
                    decoration: InputDecoration(
                      hintText: 'Search product / SKU',
                      prefixIcon: const Icon(Icons.search),
                      suffixIcon: (_searchC.text.trim().isEmpty)
                          ? null
                          : IconButton(
                              onPressed: _searchC.clear,
                              icon: const Icon(Icons.close),
                            ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
                      ),
                      isDense: true,
                    ),
                  ),
                ),
                const SizedBox(height: 8),

                // Body
                body(),

                // Footer
                SafeArea(
                  top: false,
                  minimum: const EdgeInsets.only(top: 8),
                  child: Column(
                    children: [
                      Padding(
                        padding: const EdgeInsets.fromLTRB(12, 10, 12, 6),
                        child: Text(
                          (selectedCount > 0)
                              ? '$selectedCount SKU • $selectedQty qty'
                              : 'Pilih produk, lalu tentukan variannya',
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF6B7280),
                            fontSize: 12,
                          ),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 6, 16, 12),
                        child: SizedBox(
                          width: double.infinity,
                          height: 50, // <<< lebih besar
                          child: FilledButton.icon(
                            onPressed: () =>
                                Navigator.pop(context, _temp.values.toList()),
                            icon: const Icon(Icons.check, size: 22),
                            label: const Text('Use selected'),
                            style: FilledButton.styleFrom(
                              elevation: 0,
                              backgroundColor: const Color(0xFF426FD4),
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14),
                              ),
                              textStyle: const TextStyle(
                                fontWeight: FontWeight.w800,
                                fontSize: 16,
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
        ),
      ),
    );
  }
}

class _ProductCardFromModel extends StatelessWidget {
  const _ProductCardFromModel({
    required this.product,
    required this.onAdd,
    required this.selectedQty,
    this.thumbUrl,
  });

  final Product product;
  final VoidCallback onAdd;
  final int selectedQty;
  final String? thumbUrl;

  @override
  Widget build(BuildContext context) {
    final isTablet = MediaQuery.of(context).size.shortestSide >= 600;

    Widget image() {
      final fallback = Container(
        decoration: BoxDecoration(
          color: const Color(0xFFF3F4F6),
          borderRadius: BorderRadius.circular(12),
        ),
        child: const Center(child: Icon(Icons.image, color: Color(0xFFA3A3A3))),
      );
      final h = isTablet ? 128.0 : 110.0; // 🔧 sedikit lebih pendek biar pas
      return ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: (thumbUrl != null && thumbUrl!.isNotEmpty)
            ? Image.network(
                thumbUrl!,
                height: h,
                width: double.infinity,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) =>
                    SizedBox(height: h, child: fallback),
              )
            : SizedBox(height: h, child: fallback),
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
        border: Border.all(color: UI.line),
      ),
      child: Padding(
        padding: EdgeInsets.all(isTablet ? 12 : 12), // keep compact
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
            const SizedBox(height: 8),
            SizedBox(
              height: 48,
              child: Text(
                product.name,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontWeight: FontWeight.w800,
                  color: UI.text,
                ),
              ),
            ),
            const SizedBox(height: 10),
            SizedBox(
              height: isTablet ? 42 : 40,
              width: double.infinity,
              child: FilledButton(
                onPressed: onAdd,
                style: FilledButton.styleFrom(
                  backgroundColor: UI.blue,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text(
                  'Add',
                  style: TextStyle(fontWeight: FontWeight.w700),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SkuRowForPurchase extends StatelessWidget {
  final PosSku sku;
  final bool selected;
  final int qty;
  final VoidCallback onChoose;
  final VoidCallback? onMinus;
  final VoidCallback? onPlus;

  const _SkuRowForPurchase({
    required this.sku,
    required this.selected,
    required this.qty,
    required this.onChoose,
    this.onMinus,
    this.onPlus,
  });

  @override
  Widget build(BuildContext context) {
    final image = ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: (sku.imageUrl.isNotEmpty == true)
          ? Image.network(
              sku.imageUrl,
              width: 60,
              height: 60,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => const _ImageFallback(),
            )
          : const _ImageFallback(),
    );

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        children: [
          image,
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  sku.productName,
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
                    color: Color(0xFF111827),
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Text(
                  sku.skuCode,
                  style: const TextStyle(
                    color: Color(0xFF6B7280),
                    fontSize: 12,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          selected
              ? _QtyPill(qty: qty, onMinus: onMinus!, onPlus: onPlus!)
              : ElevatedButton(
                  onPressed: onChoose,
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                    elevation: 0,
                  ),
                  child: const Text('Choose'),
                ),
        ],
      ),
    );
  }
}

class _ImageFallback extends StatelessWidget {
  const _ImageFallback();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 60,
      height: 60,
      color: const Color(0xFFF3F4F6),
      child: const Icon(
        Icons.image_not_supported_outlined,
        size: 22,
        color: Color(0xFFA3A3A3),
      ),
    );
  }
}

// ===== Sticky search header ala AddProductSheet =====
class _StickySearchHeaderDelegate extends SliverPersistentHeaderDelegate {
  final TextEditingController controller;
  final VoidCallback onClear;

  _StickySearchHeaderDelegate({
    required this.controller,
    required this.onClear,
  });

  @override
  double get minExtent => 56;
  @override
  double get maxExtent => 56;

  @override
  Widget build(
    BuildContext context,
    double shrinkOffset,
    bool overlapsContent,
  ) {
    return Material(
      elevation: overlapsContent ? 2 : 0,
      color: Colors.white,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
        child: TextField(
          controller: controller,
          textInputAction: TextInputAction.search,
          decoration: UI
              .input('Search by product name or SKU code')
              .copyWith(
                prefixIcon: const Icon(Icons.search_rounded),
                suffixIcon: (controller.text.trim().isEmpty)
                    ? null
                    : IconButton(
                        onPressed: onClear,
                        icon: const Icon(Icons.close_rounded),
                      ),
              ),
        ),
      ),
    );
  }

  @override
  bool shouldRebuild(covariant _StickySearchHeaderDelegate old) {
    return old.controller != controller || old.onClear != onClear;
  }
}

/// ----- Reuse small parts dari file (SheetHeader, Section, RowKV, QtyPill) -----
class _SheetHeader extends StatelessWidget {
  final String title;
  final String? caption;
  const _SheetHeader({required this.title, this.caption});

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

class _Section extends StatelessWidget {
  final String? title;
  final Widget? titleWidget;
  final Widget child;
  final EdgeInsets padding;
  const _Section({
    this.title,
    this.titleWidget,
    required this.child,
    this.padding = const EdgeInsets.all(14),
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
        border: Border.all(color: const Color(0xFFE5E7EB)),
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

class _ItemsDataTable extends StatefulWidget {
  const _ItemsDataTable({
    required this.rows,
    required this.onPriceChanged,
    required this.onRemove,
    required this.onQtyChanged,
  });

  final List<_PurchaseRow> rows;
  final void Function(String skuId, int value) onPriceChanged;
  final void Function(String skuId) onRemove;
  final void Function(String skuId, int nextQty) onQtyChanged;

  @override
  State<_ItemsDataTable> createState() => _ItemsDataTableState();
}

class _ItemsDataTableState extends State<_ItemsDataTable> {
  final ScrollController _listCtrl = ScrollController();

  @override
  void dispose() {
    _listCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    const double rowExtent = 128.0;
    final bool isTablet = MediaQuery.of(context).size.shortestSide >= 600;
    final int maxVisible = isTablet ? 7 : 4;
    final bool needScroll = widget.rows.length > maxVisible;

    final list = ListView.separated(
      controller: needScroll ? _listCtrl : null,
      padding: EdgeInsets.zero,
      itemCount: widget.rows.length,
      shrinkWrap: !needScroll,
      physics: needScroll
          ? const AlwaysScrollableScrollPhysics()
          : const NeverScrollableScrollPhysics(),
      separatorBuilder: (_, __) => const Divider(height: 1, color: UI.line),
      itemBuilder: (context, i) {
        final r = widget.rows[i];
        return SizedBox(
          height: rowExtent,
          child: _OrderSummaryEditableItem(
            row: r,
            onMinus: () => widget.onQtyChanged(r.skuId, r.qty - 1),
            onPlus: () => widget.onQtyChanged(r.skuId, r.qty + 1),
            onRemove: () => widget.onRemove(r.skuId),
            onPriceChanged: (v) => widget.onPriceChanged(r.skuId, v),
          ),
        );
      },
    );

    if (!needScroll) return list;

    final double maxHeight =
        (rowExtent * maxVisible) + (1.0 * (maxVisible - 1));

    return ConstrainedBox(
      constraints: BoxConstraints(maxHeight: maxHeight),
      child: Scrollbar(
        controller: _listCtrl,
        thumbVisibility: true,
        radius: const Radius.circular(999),
        child: list,
      ),
    );
  }
}

class _OrderSummaryEditableItem extends StatelessWidget {
  const _OrderSummaryEditableItem({
    required this.row,
    required this.onMinus,
    required this.onPlus,
    required this.onRemove,
    required this.onPriceChanged,
  });

  final _PurchaseRow row;
  final VoidCallback onMinus;
  final VoidCallback onPlus;
  final VoidCallback onRemove;
  final void Function(int value) onPriceChanged;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        _thumb(row.imageUrl),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                row.productName,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 2),
              Text(
                row.skuLabel,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: UI.tsSub,
              ),
              const SizedBox(height: 6),
              _InlinePriceEditor(
                value: row.unitBasePrice,
                onChanged: onPriceChanged,
              ),
            ],
          ),
        ),
        const SizedBox(width: 12),
        Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _QtyPill(qty: row.qty, onMinus: onMinus, onPlus: onPlus),
            const SizedBox(height: 4),
            IconButton(
              tooltip: 'Remove',
              visualDensity: VisualDensity.compact,
              icon: const Icon(Icons.delete_outline, color: UI.sub),
              onPressed: onRemove,
            ),
          ],
        ),
      ],
    );
  }

  Widget _thumb(String? url) {
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
      child: (url != null && url.isNotEmpty)
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
}

class _InlinePriceEditor extends StatefulWidget {
  const _InlinePriceEditor({required this.value, required this.onChanged});

  final int value;
  final void Function(int value) onChanged;

  @override
  State<_InlinePriceEditor> createState() => _InlinePriceEditorState();
}

class _InlinePriceEditorState extends State<_InlinePriceEditor> {
  late final TextEditingController _controller;
  late final FocusNode _focusNode;
  String? _programmaticText;
  int? _queuedValue;
  bool _emitScheduled = false;
  String? _pendingSyncText;
  bool _pendingSyncForce = false;
  bool _syncScheduled = false;

  String _normalizeDigits(String raw) {
    final digits = raw.replaceAll(RegExp(r'[^0-9]'), '');
    if (digits.isEmpty) return '';
    final trimmed = digits.replaceFirst(RegExp(r'^0+(?=\d)'), '');
    return trimmed.isEmpty ? '0' : trimmed;
  }

  void _setTextSilently(String text) {
    _programmaticText = text;
    _controller.value = TextEditingValue(
      text: text,
      selection: TextSelection.collapsed(offset: text.length),
    );
  }

  void _scheduleTextSync(String text, {bool force = false}) {
    _pendingSyncText = text;
    _pendingSyncForce = force;
    if (_syncScheduled) return;
    _syncScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _syncScheduled = false;
      final nextText = _pendingSyncText;
      final forceSync = _pendingSyncForce;
      _pendingSyncText = null;
      _pendingSyncForce = false;
      if (!mounted || nextText == null) return;
      if (!forceSync && _focusNode.hasFocus && _controller.text != nextText) {
        return;
      }
      if (_controller.text != nextText) {
        _setTextSilently(nextText);
      }
    });
  }

  void _queueEmit(int value) {
    _queuedValue = value;
    if (_emitScheduled) return;
    _emitScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _emitScheduled = false;
      final next = _queuedValue;
      _queuedValue = null;
      if (!mounted || next == null) return;
      if (next != widget.value) {
        widget.onChanged(next);
      }
    });
  }

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.value.toString());
    _focusNode = FocusNode();
  }

  @override
  void didUpdateWidget(covariant _InlinePriceEditor oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.value != widget.value && !_focusNode.hasFocus) {
      final next = widget.value.toString();
      if (_controller.text != next) {
        _scheduleTextSync(next);
      }
    }
  }

  @override
  void dispose() {
    _focusNode.dispose();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 150,
      height: 34,
      child: TextField(
        controller: _controller,
        focusNode: _focusNode,
        textAlign: TextAlign.right,
        keyboardType: TextInputType.number,
        inputFormatters: [FilteringTextInputFormatter.digitsOnly],
        onTap: () {
          if (_controller.text == '0') {
            _controller.selection = const TextSelection(
              baseOffset: 0,
              extentOffset: 1,
            );
          }
        },
        decoration: const InputDecoration(
          hintText: '0',
          isDense: true,
          border: OutlineInputBorder(),
          contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 7),
          prefixText: 'Rp ',
        ),
        onChanged: (v) {
          if (_programmaticText != null && v == _programmaticText) {
            _programmaticText = null;
            return;
          }

          final normalized = _normalizeDigits(v);
          if (normalized.isEmpty) {
            _queueEmit(0);
            _scheduleTextSync('0', force: true);
            return;
          }

          if (v != normalized) {
            _scheduleTextSync(normalized, force: true);
          }

          final next = int.tryParse(normalized) ?? 0;
          _queueEmit(next);
        },
      ),
    );
  }
}

Future<_PurchaseRow?> showProductVariantSheet(
  BuildContext context,
  Product product,
) {
  final isTablet = MediaQuery.of(context).size.shortestSide >= 600;
  return showModalBottomSheet<_PurchaseRow>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: Colors.transparent, // center on tablet
    builder: (_) => _CenteredConstrainedSheet(
      maxWidth: isTablet ? 640 : double.infinity,
      child: _ProductVariantSheet(product: product),
    ),
  );
}

class _ProductVariantSheet extends StatefulWidget {
  final Product product;
  const _ProductVariantSheet({required this.product});

  @override
  State<_ProductVariantSheet> createState() => _ProductVariantSheetState();
}

class _ProductVariantSheetState extends State<_ProductVariantSheet> {
  final Map<String, String> _selectedAttrs = {};
  int _qty = 1;

  @override
  Widget build(BuildContext context) {
    final product = widget.product;
    final attrsList = _extractAttributes(product.productSkus);

    ProductSku? matchedSku;
    for (final s in product.productSkus) {
      if (_isSkuMatch(s, _selectedAttrs, requiredCount: attrsList.length)) {
        matchedSku = s;
        break;
      }
    }

    final isTablet = MediaQuery.of(context).size.shortestSide >= 600;
    final heroSize = isTablet ? 84.0 : 72.0;

    return Container(
      color: UI.bg,
      child: SafeArea(
        minimum: EdgeInsets.fromLTRB(
          isTablet ? 20 : 16,
          12,
          isTablet ? 20 : 16,
          0,
        ),
        child: Column(
          children: [
            _SheetHeader(title: 'Choose Variants', caption: product.name),
            const SizedBox(height: 4),

            // hero
            _Section(
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: (product.primaryImageUrl != null)
                        ? Image.network(
                            product.primaryImageUrl!,
                            width: heroSize,
                            height: heroSize,
                            fit: BoxFit.cover,
                          )
                        : Container(
                            width: heroSize,
                            height: heroSize,
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
                        if (matchedSku != null) ...[
                          const SizedBox(height: 4),
                          Text(
                            matchedSku!.code,
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
                    child: _Section(
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
                                final row = _PurchaseRow(
                                  productId: product.idProduct,
                                  skuId: matchedSku!.idProductSku,
                                  productName: product.name,
                                  skuLabel: matchedSku!.code,
                                  imageUrl: product.primaryImageUrl,
                                  defaultPrice: matchedSku.price,
                                  qty: _qty,
                                );
                                Navigator.pop(context, row);
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
                              : "Add to cart",
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
      for (final attr in sku.attributes) {
        result.putIfAbsent(attr.name, () => {}).add(attr.value);
      }
    }
    return result;
  }

  // helper: apakah SKU sesuai dengan pilihan user
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
    // aktif kalau SEMUA atribut sudah dipilih
    return sel.length == requiredCount;
  }
}

class _LabeledField extends StatelessWidget {
  final String label;
  final Widget child;
  final bool isRequired;
  const _LabeledField({
    required this.label,
    required this.child,
    this.isRequired = false,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              label,
              style: const TextStyle(
                fontWeight: FontWeight.w600,
                color: Color(0xFF374151), // selaras dengan style sheet-mu
              ),
            ),
            if (isRequired) ...[
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: const Color(0xFFEFF4FF),
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(color: const Color(0xFFA5B4FC)),
                ),
                child: const Text(
                  'Required',
                  style: TextStyle(
                    color: Color(0xFF426FD4),
                    fontWeight: FontWeight.w700,
                    fontSize: 11,
                  ),
                ),
              ),
            ],
          ],
        ),
        const SizedBox(height: 6),
        child,
      ],
    );
  }
}

class _StickyFooterBar extends StatelessWidget {
  final bool enabled;
  final VoidCallback onSubmit;
  final VoidCallback onCancel;

  const _StickyFooterBar({
    required this.enabled,
    required this.onSubmit,
    required this.onCancel,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
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
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: onCancel,
                    style: OutlinedButton.styleFrom(
                      foregroundColor: UI.sub,
                      side: const BorderSide(color: UI.line),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                    child: const Text('Cancel'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: FilledButton(
                    onPressed: enabled ? onSubmit : null,
                    style: FilledButton.styleFrom(
                      backgroundColor: UI.blue,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                    child: const Text(
                      'Create',
                      style: TextStyle(fontWeight: FontWeight.w700),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

bool _hasNoVariantAttrs(Product p) {
  // true jika semua SKU tidak punya attributes
  return p.productSkus.every((s) => s.attributes.isEmpty);
}

ProductSku? _defaultSku(Product p) {
  if (p.productSkus.isEmpty) return null;
  // ambil SKU pertama sebagai default
  return p.productSkus.first;
}
