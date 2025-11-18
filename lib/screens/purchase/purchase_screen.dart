import 'package:dotted_border/dotted_border.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:wa_blast/constants/design_system.dart';
import 'package:wa_blast/models/product_model.dart';
import 'package:wa_blast/widgets/reusable_pickers.dart';
import '../../providers/purchase_provider.dart';
import '../../providers/product_provider.dart';

class PurchaseScreen extends StatefulWidget {
  const PurchaseScreen({super.key});

  @override
  State<PurchaseScreen> createState() => _PurchaseScreenState();
}

class _PurchaseScreenState extends State<PurchaseScreen> {
  @override
  void initState() {
    super.initState();
    // fetch purchases setelah frame pertama agar aman dari initState context
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      context.read<PurchaseProvider>().fetchPurchases(context);
      // Opsional: preload supplier untuk sheet
      // context.read<PurchaseProvider>().fetchSuppliers(context);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded),
          onPressed: () => Navigator.of(
            context,
          ).popUntil((route) => route.settings.name == '/purchase'),
        ),
        // 🆕 Judul alami
        title: Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.baseline,
          textBaseline: TextBaseline.alphabetic,
          children: const [
            Text('Purchase', style: TextStyle(fontWeight: FontWeight.w800)),
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
        scrolledUnderElevation: 0,
      ),
      body: const _PurchaseList(),

      bottomNavigationBar: SafeArea(
        minimum: const EdgeInsets.fromLTRB(16, 8, 16, 20),
        child: SizedBox(
          height: 50,
          child: FilledButton.icon(
            icon: const Icon(Icons.add_rounded),
            label: const Text(
              'Add New Purchase',
              style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
            ),
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFF426FD4),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
              minimumSize: const Size.fromHeight(50),
            ),
            onPressed: () {
              Navigator.pushNamed(context, '/purchase/add');
            },
          ),
        ),
      ),

      // === Add New Purchase button (fixed di bawah) ===
      // bottomNavigationBar: SafeArea(
      //   minimum: const EdgeInsets.fromLTRB(12, 8, 12, 20),
      //   child: SizedBox(
      //     height: 46,
      //     child: ElevatedButton.icon(
      //       icon: const Icon(Icons.add_rounded),
      //       style: ElevatedButton.styleFrom(
      //         backgroundColor: const Color(0xFF426FD4),
      //         foregroundColor: Colors.white,
      //         shape: RoundedRectangleBorder(
      //           borderRadius: BorderRadius.circular(12),
      //         ),
      //         minimumSize: const Size.fromHeight(46),
      //       ),
      //       onPressed: () async {
      //         final ok = await showAddPurchaseSheet(context);
      //         if (!context.mounted || ok != true) return;

      //         await context.read<PurchaseProvider>().fetchPurchases(context);
      //         ScaffoldMessenger.of(context).showSnackBar(
      //           const SnackBar(
      //             content: Text('Purchase created successfully'),
      //             backgroundColor: Color(0xFF059669),
      //           ),
      //         );
      //       },
      //       label: const Text(
      //         'Add New Purchase',
      //         style: TextStyle(fontWeight: FontWeight.w600),
      //       ),
      //     ),
      //   ),
      // ),
    );
  }
}

class _PurchaseList extends StatelessWidget {
  const _PurchaseList();

  @override
  Widget build(BuildContext context) {
    final fTime = DateFormat('hh:mm:ss a');
    final fMoney = NumberFormat.decimalPattern('id_ID');

    return Consumer<PurchaseProvider>(
      builder: (context, prov, _) {
        final items = prov.items;
        final isLoading = prov.loadingPurchases;
        final error = prov.purchaseError;

        // Pull to refresh bungkus ListView manapun
        return RefreshIndicator(
          onRefresh: () =>
              context.read<PurchaseProvider>().fetchPurchases(context),
          color: const Color(0xFF426FD4),
          child: Builder(
            builder: (context) {
              if (isLoading && items.isEmpty) {
                return ListView(
                  padding: const EdgeInsets.fromLTRB(16, 24, 16, 24 + 72),
                  children: const [Center(child: CircularProgressIndicator())],
                );
              }

              if (error != null && items.isEmpty) {
                return ListView(
                  padding: const EdgeInsets.fromLTRB(16, 24, 16, 24 + 72),
                  children: [
                    _ErrorBox(
                      message: error,
                      onRetry: () => context
                          .read<PurchaseProvider>()
                          .fetchPurchases(context),
                    ),
                  ],
                );
              }

              if (items.isEmpty) {
                return ListView(
                  padding: const EdgeInsets.fromLTRB(16, 24, 16, 24 + 72),
                  children: const [_EmptyBox()],
                );
              }

              return ListView.builder(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 24 + 72),
                itemCount: items.length + 1,
                itemBuilder: (context, index) {
                  if (index == 0) {
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: Row(
                        children: [
                          const Expanded(
                            child: Text(
                              'History Purchase',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: Color(0xFF6B7280),
                              ),
                            ),
                          ),
                          if (isLoading)
                            const SizedBox(
                              height: 16,
                              width: 16,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            ),
                        ],
                      ),
                    );
                  }

                  final item = items[index - 1];

                  final card = DottedBorder(
                    options: RoundedRectDottedBorderOptions(
                      color: const Color(0xFFD1D5DB),
                      dashPattern: const [6, 6],
                      strokeWidth: 1.4,
                      radius: const Radius.circular(12),
                      padding: const EdgeInsets.all(0),
                    ),
                    child: Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // header
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Container(
                                width: 44,
                                height: 44,
                                decoration: BoxDecoration(
                                  color: Colors.indigo.shade50,
                                  shape: BoxShape.circle,
                                ),
                                child: Icon(
                                  Icons.shopping_bag_rounded,
                                  size: 20,
                                  color: Colors.indigo.shade700,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      item.code,
                                      style: const TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.w700,
                                        color: Color(0xFF111827),
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      fTime.format(item.time),
                                      style: const TextStyle(
                                        fontSize: 12,
                                        color: Color(0xFF9CA3AF),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              // (status chip dihapus sesuai permintaan)
                            ],
                          ),
                          const SizedBox(height: 16),
                          // amounts
                          Row(
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text(
                                      'Total amount',
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: Color(0xFF6B7280),
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      'Rp. ${fMoney.format(item.totalAmount)}',
                                      style: const TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.w700,
                                        color: Color(0xFF111827),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  const Text(
                                    'Quantity',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Color(0xFF6B7280),
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    '${item.quantity}',
                                    style: const TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.w700,
                                      color: Color(0xFF111827),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  );

                  return Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: () {
                        Navigator.pushNamed(
                          context,
                          '/purchase/list/detail',
                          arguments: {
                            // ✅ kirim 'number' (atau sesuaikan dengan detail screen-mu)
                            'id': item.idTransaction,
                          },
                        );
                      },

                      child: card,
                    ),
                  );
                },
              );
            },
          ),
        );
      },
    );
  }
}

/// ======================================================================
/// ADD PURCHASE SHEET + SELECTOR SHEETS
/// ======================================================================

/// ======================================================================
/// ADD PURCHASE SHEET + SELECTOR SHEETS  (REPLACED)
/// ======================================================================

// Row model untuk sheet ini
class _PurchaseRow {
  final String productId;
  final String skuId;
  final String productName;
  final String skuLabel; // <-- NEW: nama SKU (atau fallback ke kode)
  final String? imageUrl; // <-- NEW: gambar SKU (opsional)
  final int price; // harga unit asli (SKU)
  int qty;
  int discountPerItem; // diskon per item (IDR)
  int get unitPriceAfterDisc =>
      (price - discountPerItem).clamp(0, 1 << 31).toInt(); // ← add .toInt()
  int get lineTotal => unitPriceAfterDisc * qty;

  _PurchaseRow({
    required this.productId,
    required this.skuId,
    required this.productName,
    required this.skuLabel, // <-- NEW (wajib)
    required this.price,
    this.imageUrl, // <-- NEW (opsional)
    this.qty = 1,
    this.discountPerItem = 0,
  });
}

// Buka sheet Add Purchase dan return payload Map siap kirim
// sebelumnya: Future<Map<String, dynamic>?> showAddPurchaseSheet(...)
Future<bool?> showAddPurchaseSheet(BuildContext context) {
  return showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: Colors.white,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
    ),
    builder: (_) => const _AddPurchaseSheet(),
  );
}

class _AddPurchaseSheet extends StatefulWidget {
  const _AddPurchaseSheet();

  @override
  State<_AddPurchaseSheet> createState() => _AddPurchaseSheetState();
}

class _AddPurchaseSheetState extends State<_AddPurchaseSheet> {
  final _formKey = GlobalKey<FormState>();
  bool _submitting = false; // <-- NEW

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

  // items
  final Map<String, _PurchaseRow> _rows = {}; // key: skuId

  @override
  void dispose() {
    _numberC.dispose();
    _referenceC.dispose();
    _noteC.dispose();
    _discountOrderC.dispose();
    _shippingFeeC.dispose();
    super.dispose();
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

  String _generateDefaultReference() {
    // 6 digit “acak cepat”
    final seed = DateTime.now().millisecondsSinceEpoch;
    final six = 100000 + (seed % 900000);
    return 'REF-$six';
  }

  @override
  void initState() {
    super.initState();
    if (_referenceC.text.trim().isEmpty) {
      _referenceC.text = _generateDefaultReference();
    }
  }

  /// Alokasikan order discount (IDR) proporsional ke tiap baris.
  /// Return: skuId -> disc per unit (pembulatan ke bawah).
  Map<String, int> _allocOrderDiscountPerUnit() {
    final od = _orderDiscount;
    if (od <= 0 || _rows.isEmpty) return const {};

    // basis proporsi: line total setelah discount per item
    final bases = <String, int>{};
    var baseSum = 0;
    for (final r in _rows.values) {
      final base = (r.unitPriceAfterDisc * r.qty);
      if (base > 0) {
        bases[r.skuId] = base;
        baseSum += base;
      }
    }
    if (baseSum == 0) return const {};

    // hitung disc per-row, lalu konversi ke disc per-unit
    final perUnit = <String, int>{};
    var allocated = 0;
    for (final r in _rows.values) {
      final base = bases[r.skuId] ?? 0;
      if (base == 0) {
        perUnit[r.skuId] = 0;
        continue;
      }
      final rowDisc = (od * base ~/ baseSum); // floor
      allocated += rowDisc;
      final perUnitDisc = (r.qty > 0) ? (rowDisc ~/ r.qty) : 0;
      perUnit[r.skuId] = perUnitDisc;
    }

    // jika ada sisa karena pembulatan ke bawah, tambahkan ke item pertama
    final remain = od - allocated;
    if (remain > 0) {
      final first = _rows.values.first;
      perUnit[first.skuId] =
          (perUnit[first.skuId] ?? 0) +
          (remain ~/ (first.qty > 0 ? first.qty : 1));
    }

    // pastikan tidak negatif melebihi harga unit
    perUnit.updateAll((sku, d) {
      final r = _rows[sku]!;
      final maxDisc = r.unitPriceAfterDisc;
      return d.clamp(0, maxDisc).toInt(); // ← pastikan kembali sebagai int
    });

    return perUnit;
  }

  Future<void> _openSkuPicker() async {
    final picked = await showModalBottomSheet<List<_PurchaseRow>>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (_) => ChangeNotifierProvider.value(
        // kalau kamu pakai ProductProvider, pass instance-nya di sini
        value: context.read<ProductProvider>(),
        child: _ProductGridPicker(initial: _rows),
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

  int get _grandTotal {
    final t = _subtotalItems - _orderDiscount + _shippingFee;
    return t < 0 ? 0 : t;
  }

  Map<String, dynamic> _buildPayload() {
    return {
      "number": _numberC.text.trim(),
      "store_location_id": _storeId,
      "note": _noteC.text.trim(),
      "reference": _referenceC.text.trim(),
      "discount": _orderDiscount,
      "shipping_fee": 0,
      "items": _rows.values
          .where((r) => r.qty > 0) // <-- filter aman
          .map(
            (r) => {
              "product_id": r.productId,
              "product_sku_id": r.skuId,
              "qty": r.qty,
              "price": r.unitPriceAfterDisc,
              "discount": r.discountPerItem,
            },
          )
          .toList(),
    };
  }

  Future<void> _submit() async {
    if (_rows.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Tambahkan minimal 1 SKU')));
      return;
    }
    if (_storeId == null || _storeId!.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Pilih store location dulu')),
      );
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
      Navigator.pop<bool>(context, true); // -> sukses
    } else {
      final err =
          context.read<PurchaseProvider>().consumeLastError() ?? 'Failed';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(err), backgroundColor: const Color(0xFFDC2626)),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final hasItems = _rows.isNotEmpty;
    return Container(
      color: UI.bg,
      child: SafeArea(
        minimum: const EdgeInsets.fromLTRB(16, 12, 16, 0),
        child: Column(
          children: [
            const _SheetHeader(
              title: 'Add Purchase',
              caption: 'Susun pesanan dengan cepat',
            ),
            Expanded(
              child: ListView(
                children: [
                  _Section(
                    titleWidget: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Items',
                          style: TextStyle(fontWeight: FontWeight.w800),
                        ),
                        TextButton.icon(
                          onPressed: _openSkuPicker,
                          icon: const Icon(Icons.add_rounded, size: 18),
                          label: const Text('Add SKU'),
                          style: TextButton.styleFrom(foregroundColor: UI.blue),
                        ),
                      ],
                    ),
                    child: (_rows.isEmpty)
                        ? _emptyItemsHint()
                        : _ItemsDataTable(
                            rows: _rows.values.toList(),
                            orderDiscPerUnit: _allocOrderDiscountPerUnit(),
                            onDiscountChanged: (skuId, value) => setState(() {
                              _rows[skuId]!.discountPerItem = value.clamp(
                                0,
                                1 << 31,
                              );
                            }),
                            onRemove: (skuId) =>
                                setState(() => _rows.remove(skuId)),
                            onQtyChanged: (skuId, nextQty) => setState(() {
                              if (nextQty <= 0) {
                                _rows.remove(skuId); // qty 0 -> hapus baris
                              } else {
                                final row = _rows[skuId];
                                if (row != null) {
                                  _rows[skuId] = row..qty = nextQty;
                                }
                              }
                            }),
                          ),
                  ),
                  const SizedBox(height: 12),
                  _Section(
                    title: 'Purchase details',
                    child: Form(
                      key: _formKey,
                      child: Column(
                        children: [
                          // _LabeledField(
                          //   label: 'Number (optional)',
                          //   child: TextFormField(
                          //     controller: _numberC,
                          //     decoration: UI.input(
                          //       'Leave blank to auto-generate',
                          //     ),
                          //   ),
                          // ),
                          const SizedBox(height: 12),
                          _LabeledField(
                            label: 'Store location',
                            child: PickerField(
                              placeholder: 'Select store location',
                              value: _storeName,
                              onTap: _pickStore,
                            ),
                          ),
                          const SizedBox(height: 12),
                          _LabeledField(
                            label: 'Note',
                            child: TextFormField(
                              controller: _noteC,
                              maxLines: 2,
                              decoration: UI.input('Pembelian stok awal…'),
                            ),
                          ),
                          const SizedBox(height: 12),
                          _LabeledField(
                            label: 'Discount (order, IDR)',
                            child: TextFormField(
                              controller: _discountOrderC,
                              keyboardType: TextInputType.number,
                              inputFormatters: [
                                FilteringTextInputFormatter.digitsOnly,
                              ],
                              decoration: UI.input('0'),
                              onChanged: (_) => setState(() {}),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                ],
              ),
            ),

            // Sticky footer cantik
            _StickyFooterBar(
              subtotal: _subtotalItems,
              discount: _orderDiscount,
              grandTotal: _grandTotal,
              enabled: hasItems && _storeId != null && !_submitting,
              onSubmit: _submit,
              onCancel: () => Navigator.pop(context),
            ),
          ],
        ),
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
}

/// ----- Row tile dalam daftar items (Qty, Discount per-row, Price read-only) -----

class _PurchaseRowTile extends StatefulWidget {
  final _PurchaseRow row;
  final int orderDiscPerUnit; // <-- NEW
  final void Function(int? discountPerItem) onDiscountChanged;
  final VoidCallback onRemove;

  const _PurchaseRowTile({
    required this.row,
    required this.orderDiscPerUnit, // <-- NEW
    required this.onDiscountChanged,
    required this.onRemove,
    Key? key,
  }) : super(key: key);

  @override
  State<_PurchaseRowTile> createState() => _PurchaseRowTileState();
}

class _PurchaseRowTileState extends State<_PurchaseRowTile> {
  late final TextEditingController _discC;
  final _money = NumberFormat.decimalPattern('id_ID');

  @override
  void initState() {
    super.initState();
    _discC = TextEditingController(text: widget.row.discountPerItem.toString());
  }

  @override
  void didUpdateWidget(covariant _PurchaseRowTile oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.row.discountPerItem != widget.row.discountPerItem &&
        _discC.text != widget.row.discountPerItem.toString()) {
      _discC.text = widget.row.discountPerItem.toString();
    }
  }

  @override
  void dispose() {
    _discC.dispose();
    super.dispose();
  }

  int get _effectiveUnitPrice {
    final afterItem = widget.row.unitPriceAfterDisc;
    final afterOrder = (afterItem - widget.orderDiscPerUnit)
        .clamp(0, 1 << 31)
        .toInt(); // ←
    return afterOrder;
  }

  int get _effectiveLineTotal => _effectiveUnitPrice * widget.row.qty;

  Widget _priceBox() {
    final p0 = widget.row.price;
    final p1 = widget.row.unitPriceAfterDisc; // setelah diskon per item
    final p2 = _effectiveUnitPrice; // + alokasi order disc

    // 3 kondisi tampilan: tanpa diskon, diskon per item, diskon per item + order
    if (widget.orderDiscPerUnit <= 0 && widget.row.discountPerItem <= 0) {
      return _roBox(_money.format(p0));
    }
    if (widget.orderDiscPerUnit <= 0) {
      // hanya diskon per item
      return _strikeThenBold(_money.format(p0), _money.format(p1));
    }
    // ada order disc juga
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          _money.format(p0),
          style: const TextStyle(
            color: Color(0xFF9CA3AF),
            decoration: TextDecoration.lineThrough,
          ),
        ),
        const SizedBox(height: 2),
        if (widget.row.discountPerItem > 0)
          Text(
            _money.format(p1),
            style: const TextStyle(
              color: Color(0xFF9CA3AF),
              decoration: TextDecoration.lineThrough,
            ),
          ),
        const SizedBox(height: 2),
        Text(
          _money.format(p2),
          style: const TextStyle(fontWeight: FontWeight.w700),
        ),
      ],
    );
  }

  Widget _roBox(String text) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
    decoration: BoxDecoration(
      border: Border.all(color: const Color(0xFFE5E7EB)),
      borderRadius: BorderRadius.circular(10),
      color: const Color(0xFFF3F4F6),
    ),
    child: Text(text, style: const TextStyle(fontWeight: FontWeight.w600)),
  );

  Widget _strikeThenBold(String oldText, String newText) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
    decoration: BoxDecoration(
      border: Border.all(color: const Color(0xFFE5E7EB)),
      borderRadius: BorderRadius.circular(10),
      color: const Color(0xFFF3F4F6),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          oldText,
          style: const TextStyle(
            color: Color(0xFF9CA3AF),
            decoration: TextDecoration.lineThrough,
          ),
        ),
        const SizedBox(height: 2),
        Text(newText, style: const TextStyle(fontWeight: FontWeight.w700)),
      ],
    ),
  );

  @override
  Widget build(BuildContext context) {
    final money = NumberFormat.decimalPattern('id_ID');

    // Fallback kecil untuk gambar SKU
    Widget _imgFallback() => Container(
      width: 48,
      height: 48,
      color: const Color(0xFFF3F4F6),
      child: const Icon(Icons.image, color: Color(0xFFA3A3A3), size: 20),
    );

    // Header: gambar + nama produk + nama SKU + tombol remove
    Widget _header() {
      final img = ClipRRect(
        borderRadius: BorderRadius.circular(10),
        child: (widget.row.imageUrl != null && widget.row.imageUrl!.isNotEmpty)
            ? Image.network(
                widget.row.imageUrl!,
                width: 48,
                height: 48,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => _imgFallback(),
              )
            : _imgFallback(),
      );

      return Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          img,
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.row.productName,
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
                    color: Color(0xFF111827),
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  widget.row.skuLabel, // <- tampilkan nama/kode SKU
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
          const SizedBox(width: 8),
          IconButton(
            onPressed: widget.onRemove,
            icon: const Icon(Icons.delete_outline, color: Color(0xFF9CA3AF)),
            tooltip: 'Remove',
          ),
        ],
      );
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _header(),
          const SizedBox(height: 12),

          // Grid Qty / Discount / Price (responsif)
          LayoutBuilder(
            builder: (context, cons) {
              final isNarrow = cons.maxWidth < 360;
              const gap = SizedBox(width: 8);

              final discCell = Expanded(
                flex: 5,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Discount / item (IDR)',
                      style: TextStyle(color: Color(0xFF6B7280)),
                    ),
                    const SizedBox(height: 6),
                    TextField(
                      controller: _discC,
                      keyboardType: TextInputType.number,
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                      decoration: const InputDecoration(
                        hintText: '0',
                        isDense: true,
                        border: OutlineInputBorder(),
                        contentPadding: EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 10,
                        ),
                        prefixText: 'Rp ',
                      ),
                      onChanged: (v) {
                        final n = int.tryParse(v);
                        widget.onDiscountChanged(n ?? 0);
                      },
                    ),
                  ],
                ),
              );

              if (isNarrow) {
                return Column(
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          flex: 3,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Qty',
                                style: TextStyle(color: Color(0xFF6B7280)),
                              ),
                              const SizedBox(height: 6),
                              _roBox('× ${widget.row.qty}'),
                            ],
                          ),
                        ),
                        gap,
                        discCell,
                      ],
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(
                          flex: 4,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Price',
                                style: TextStyle(color: Color(0xFF6B7280)),
                              ),
                              const SizedBox(height: 6),
                              _priceBox(),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ],
                );
              }

              // Layout lebar
              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    flex: 3,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Qty',
                          style: TextStyle(color: Color(0xFF6B7280)),
                        ),
                        const SizedBox(height: 6),
                        _roBox('× ${widget.row.qty}'),
                      ],
                    ),
                  ),
                  gap,
                  discCell,
                  gap,
                  Expanded(
                    flex: 4,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Price',
                          style: TextStyle(color: Color(0xFF6B7280)),
                        ),
                        const SizedBox(height: 6),
                        _priceBox(),
                      ],
                    ),
                  ),
                ],
              );
            },
          ),

          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Line total',
                style: TextStyle(color: Color(0xFF6B7280)),
              ),
              Text(
                'Rp. ${money.format(_effectiveLineTotal)}',
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
            ],
          ),
          const Divider(height: 20, color: Color(0xFFE5E7EB)),
        ],
      ),
    );
  }
}

/// ----- Multi SKU picker (flatten dari ProductProvider.products -> productSkus) -----

// ===============================
// SKU MULTI PICKER (Purchase) — styled like AddProductSheet
// ===============================
class _SkuMultiPicker extends StatefulWidget {
  const _SkuMultiPicker({required this.initial});
  final Map<String, _PurchaseRow> initial; // skuId -> row

  @override
  State<_SkuMultiPicker> createState() => _SkuMultiPickerState();
}

class _SkuMultiPickerState extends State<_SkuMultiPicker> {
  final _searchC = TextEditingController();
  String _q = '';

  late Map<String, _PurchaseRow> _temp;

  @override
  void initState() {
    super.initState();
    _temp = Map<String, _PurchaseRow>.from(widget.initial);

    // listen perubahan search
    _searchC.addListener(() {
      final next = _searchC.text.trim();
      if (next != _q) setState(() => _q = next);
    });

    // auto-load katalog pertama kali
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final pp = context.read<PurchaseProvider>();
      if (!pp.loadingSkus && pp.skus.isEmpty) {
        await pp.loadCatalog(context);
        if (mounted) setState(() {});
      }
    });
  }

  @override
  void dispose() {
    _searchC.dispose();
    super.dispose();
  }

  // toggle pilih/batal
  void _toggle(PosSku s) {
    setState(() {
      if (_temp.containsKey(s.skuId)) {
        _temp.remove(s.skuId);
      } else {
        _temp[s.skuId] = _PurchaseRow(
          productId: s.productId,
          skuId: s.skuId,
          productName: s.productName,
          skuLabel: (s.skuCode.isNotEmpty == true)
              ? s.skuCode
              : s.skuCode, // <-- NEW
          imageUrl: s.imageUrl, // <-- NEW
          price: s.price,
          qty: 1,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final prov = context.watch<PurchaseProvider>();

    // filter data
    final q = _q.toLowerCase();
    final data = (q.isEmpty)
        ? prov.skus
        : prov.skus.where((e) {
            final n = e.productName.toLowerCase();
            final c = e.skuCode.toLowerCase();
            return n.contains(q) || c.contains(q);
          }).toList();

    // ringkasan pilihan saat ini
    final selectedItems = _temp.length;
    final selectedQty = _temp.values.fold<int>(0, (sum, it) => sum + it.qty);

    // body sliver: loading / error / list
    Widget listSliver;
    if (prov.loadingSkus && prov.skus.isEmpty) {
      listSliver = const SliverFillRemaining(
        hasScrollBody: false,
        child: Center(child: CircularProgressIndicator()),
      );
    } else if (prov.catalogError != null) {
      listSliver = SliverFillRemaining(
        hasScrollBody: false,
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
                'Failed to load SKUs',
                style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
              ),
              const SizedBox(height: 6),
              Text(
                prov.catalogError!,
                textAlign: TextAlign.center,
                style: const TextStyle(color: Color(0xFF6B7280)),
              ),
              const SizedBox(height: 12),
              OutlinedButton(
                onPressed: () => prov.loadCatalog(context),
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
      );
    } else if (data.isEmpty) {
      listSliver = const SliverFillRemaining(
        hasScrollBody: false,
        child: Center(child: Text('No SKUs found')),
      );
    } else {
      listSliver = SliverList.separated(
        itemCount: data.length,
        separatorBuilder: (_, __) =>
            const Divider(height: 1, color: Color(0xFFE5E7EB)),
        itemBuilder: (_, i) {
          final s = data[i];
          final selected = _temp.containsKey(s.skuId);
          final row = _temp[s.skuId];
          return _SkuRowForPurchase(
            sku: s,
            selected: selected,
            qty: row?.qty ?? 0,
            onChoose: () => _toggle(s),
            onMinus: selected
                ? () {
                    setState(() {
                      final next = (row!.qty - 1);
                      if (next <= 0) {
                        _temp.remove(s.skuId); // <-- hapus kalau 0
                      } else {
                        _temp[s.skuId] = row..qty = next;
                      }
                    });
                  }
                : null,

            onPlus: selected
                ? () => setState(() => _temp[s.skuId] = row!..qty = row.qty + 1)
                : null,
          );
        },
      );
    }

    return SafeArea(
      minimum: const EdgeInsets.fromLTRB(16, 12, 16, 16),
      child: SizedBox(
        height: MediaQuery.of(context).size.height * 0.85,
        child: Column(
          children: [
            // ===== scrollable content
            Expanded(
              child: CustomScrollView(
                slivers: [
                  // drag handle + title (reuse punyamu)
                  const SliverToBoxAdapter(
                    child: _SheetHeader(title: 'Add SKUs'),
                  ),

                  // sticky search
                  SliverPersistentHeader(
                    pinned: true,
                    delegate: _StickySearchHeaderDelegate(
                      controller: _searchC,
                      onClear: () => _searchC.clear(),
                    ),
                  ),

                  // list / loading / error
                  listSliver,

                  const SliverToBoxAdapter(child: SizedBox(height: 12)),
                ],
              ),
            ),

            // ===== footer ringkasan + CTA
            // ===== footer ringkasan + CTA (REVISED)
            SafeArea(
              top: false,
              // beri padding kiri-kanan dan bawah agar tidak mepet gestur area
              minimum: const EdgeInsets.fromLTRB(16, 10, 16, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Container(height: 1, color: const Color(0xFFE5E7EB)),
                  if (selectedItems > 0)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(12, 10, 12, 8),
                      child: Text(
                        '$selectedItems item • $selectedQty qty',
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF6B7280),
                          fontSize: 12,
                        ),
                      ),
                    ),
                  // tombol tidak lagi mepet, ada padding bawaan dari SafeArea.minimum
                  SizedBox(
                    height: 52,
                    child: FilledButton.icon(
                      onPressed: () =>
                          Navigator.pop(context, _temp.values.toList()),
                      icon: const Icon(Icons.check_rounded, size: 20),
                      label: const Text('Use Selected'),
                      style: FilledButton.styleFrom(
                        elevation: 0,
                        backgroundColor: const Color(0xFF426FD4),
                        foregroundColor: Colors.white,
                        minimumSize: const Size.fromHeight(52),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                        textStyle: const TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 15,
                          letterSpacing: 0.3,
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

// ===== Row satu SKU untuk Purchase picker (mirip estetika AddProductSheet) =====
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
    final priceText = NumberFormat.decimalPattern('id_ID').format(sku.price);

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
                const SizedBox(height: 6),
                Text(
                  'Rp. $priceText',
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF111827),
                  ),
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

class _ErrorBox extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;
  const _ErrorBox({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFFEE2E2),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFFCA5A5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Failed to load purchases',
            style: TextStyle(
              fontWeight: FontWeight.w700,
              color: Color(0xFF991B1B),
            ),
          ),
          const SizedBox(height: 6),
          Text(message, style: const TextStyle(color: Color(0xFF7F1D1D))),
          const SizedBox(height: 10),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Retry'),
              style: TextButton.styleFrom(
                foregroundColor: const Color(0xFF991B1B),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// -------- Labeled field helper (judul kecil di atas sebuah field) --------
class _LabeledField extends StatelessWidget {
  final String label;
  final Widget child;
  const _LabeledField({required this.label, required this.child});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontWeight: FontWeight.w600,
            color: Color(0xFF374151), // selaras dengan style sheet-mu
          ),
        ),
        const SizedBox(height: 6),
        child,
      ],
    );
  }
}

class _EmptyBox extends StatelessWidget {
  const _EmptyBox();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFF9FAFB),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Column(
        children: const [
          Icon(Icons.receipt_long_rounded, size: 32, color: Color(0xFF9CA3AF)),
          SizedBox(height: 8),
          Text(
            'No purchases yet',
            style: TextStyle(
              fontWeight: FontWeight.w700,
              color: Color(0xFF111827),
            ),
          ),
          SizedBox(height: 6),
          Text(
            'Pull down to refresh or create a new purchase.',
            textAlign: TextAlign.center,
            style: TextStyle(color: Color(0xFF6B7280)),
          ),
        ],
      ),
    );
  }
}

class _ItemsDataTable extends StatelessWidget {
  const _ItemsDataTable({
    required this.rows,
    required this.orderDiscPerUnit,
    required this.onDiscountChanged,
    required this.onRemove,
    required this.onQtyChanged,
  });

  final List<_PurchaseRow> rows;
  final Map<String, int> orderDiscPerUnit; // skuId -> disc/unit
  final void Function(String skuId, int value) onDiscountChanged;
  final void Function(String skuId) onRemove;
  final void Function(String skuId, int nextQty) onQtyChanged;

  @override
  Widget build(BuildContext context) {
    final money = NumberFormat.decimalPattern('id_ID');

    // Lebar minimum supaya kolom tidak terlalu sempit di layar kecil
    const minTableWidth = 980.0;

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: ConstrainedBox(
        constraints: const BoxConstraints(minWidth: minTableWidth),
        child: DataTable(
          // --- FIX tinggi baris: set min & max agar normalized ---
          headingRowHeight: 44,
          dataRowMinHeight: 52,
          dataRowMaxHeight: 60, // >= dataRowMinHeight
          // -------------------------------------------------------
          columnSpacing: 16,
          dividerThickness: 1,
          headingTextStyle: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: Color(0xFF6B7280),
          ),
          columns: const [
            DataColumn(label: Text('Product')),
            DataColumn(label: Text('SKU')),
            DataColumn(numeric: true, label: Text('Qty')),
            DataColumn(numeric: true, label: Text('Disc/Item')),
            DataColumn(numeric: true, label: Text('Unit (Base)')),
            DataColumn(numeric: true, label: Text('Unit (Effective)')),
            DataColumn(numeric: true, label: Text('Line Total')),
            DataColumn(label: Text('')),
          ],
          rows: rows.map((r) {
            final ord = orderDiscPerUnit[r.skuId] ?? 0;
            final unitAfterItem = (r.price - r.discountPerItem).clamp(
              0,
              1 << 31,
            );
            final unitEffective = (unitAfterItem - ord).clamp(0, 1 << 31);
            final lineTotal = unitEffective * r.qty;

            Widget thumb() {
              final fallback = Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: const Color(0xFFF3F4F6),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(
                  Icons.image,
                  color: Color(0xFFA3A3A3),
                  size: 18,
                ),
              );
              return ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: (r.imageUrl != null && r.imageUrl!.isNotEmpty)
                    ? Image.network(
                        r.imageUrl!,
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
                          r.productName,
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
                    r.skuLabel,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: Color(0xFF6B7280)),
                  ),
                ),

                // Qty (read-only; kalau mau editable ganti ke _QtyPill + setState di parent)
                // Qty (editable)
                DataCell(
                  Align(
                    alignment: Alignment.centerRight,
                    child: _QtyEditor(
                      qty: r.qty,
                      onMinus: () {
                        final next = r.qty - 1;
                        onQtyChanged(
                          r.skuId,
                          next,
                        ); // kalau 0, parent boleh hapus
                      },
                      onPlus: () => onQtyChanged(r.skuId, r.qty + 1),
                      onTyped: (v) => onQtyChanged(r.skuId, v),
                    ),
                  ),
                ),

                // Discount / Item (editable, right aligned)
                DataCell(
                  SizedBox(
                    width: 120,
                    child: TextFormField(
                      initialValue: r.discountPerItem.toString(),
                      textAlign: TextAlign.right,
                      keyboardType: TextInputType.number,
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                      decoration: const InputDecoration(
                        isDense: true,
                        border: OutlineInputBorder(),
                        contentPadding: EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 8,
                        ),
                        prefixText: 'Rp ',
                      ),
                      onChanged: (v) =>
                          onDiscountChanged(r.skuId, int.tryParse(v) ?? 0),
                    ),
                  ),
                ),

                // Unit (Base)
                DataCell(Text(money.format(r.price))),

                // Unit (Effective)  (after-item - allocated order disc)
                DataCell(
                  (ord > 0 || r.discountPerItem > 0)
                      ? Text(
                          money.format(unitEffective),
                          style: const TextStyle(fontWeight: FontWeight.w700),
                        )
                      : Text(
                          money.format(r.price),
                          style: const TextStyle(fontWeight: FontWeight.w700),
                        ),
                ),

                // Line total
                DataCell(
                  Text(
                    money.format(lineTotal),
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                ),

                // Remove
                DataCell(
                  IconButton(
                    tooltip: 'Remove',
                    icon: const Icon(
                      Icons.delete_outline,
                      color: Color(0xFF9CA3AF),
                    ),
                    onPressed: () => onRemove(r.skuId),
                  ),
                ),
              ],
            );
          }).toList(),
        ),
      ),
    );
  }
}

// ===============================
// SKU GROUPED MULTI PICKER (per Produk)
// ===============================

class _QtyEditor extends StatefulWidget {
  final int qty;
  final VoidCallback onMinus;
  final VoidCallback onPlus;
  final void Function(int value) onTyped;

  const _QtyEditor({
    required this.qty,
    required this.onMinus,
    required this.onPlus,
    required this.onTyped,
    Key? key,
  }) : super(key: key);

  @override
  State<_QtyEditor> createState() => _QtyEditorState();
}

class _QtyEditorState extends State<_QtyEditor> {
  late final TextEditingController _c;

  @override
  void initState() {
    super.initState();
    _c = TextEditingController(text: widget.qty.toString());
  }

  @override
  void didUpdateWidget(covariant _QtyEditor oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.qty != widget.qty) {
      _c.text = widget.qty.toString();
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

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
            tooltip: 'Minus',
            visualDensity: VisualDensity.compact,
            onPressed: widget.onMinus,
            icon: const Icon(Icons.remove_rounded),
          ),
          SizedBox(
            width: 56,
            child: TextField(
              controller: _c,
              textAlign: TextAlign.center,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              decoration: const InputDecoration(
                border: InputBorder.none,
                isDense: true,
                contentPadding: EdgeInsets.symmetric(vertical: 8),
              ),
              onChanged: (t) {
                final v = int.tryParse(t) ?? 0;
                widget.onTyped(v);
              },
              onSubmitted: (t) {
                final v = int.tryParse(t) ?? 0;
                widget.onTyped(v);
              },
            ),
          ),
          IconButton(
            tooltip: 'Plus',
            visualDensity: VisualDensity.compact,
            onPressed: widget.onPlus,
            icon: const Icon(Icons.add_rounded),
          ),
        ],
      ),
    );
  }
}

class _ProductGroup {
  final String productId;
  final String productName;
  final String? thumbUrl;
  final List<PosSku> skus;

  _ProductGroup({
    required this.productId,
    required this.productName,
    required this.skus,
    this.thumbUrl,
  });
}

class _SkuGroupedMultiPicker extends StatefulWidget {
  const _SkuGroupedMultiPicker({required this.initial});
  final Map<String, _PurchaseRow> initial; // skuId -> row

  @override
  State<_SkuGroupedMultiPicker> createState() => _SkuGroupedMultiPickerState();
}

class _SkuGroupedMultiPickerState extends State<_SkuGroupedMultiPicker> {
  final _searchC = TextEditingController();
  String _q = '';

  late Map<String, _PurchaseRow> _temp; // skuId -> row
  final Set<String> _expanded = {}; // productId yg terbuka

  @override
  void initState() {
    super.initState();
    _temp = Map<String, _PurchaseRow>.from(widget.initial);

    _searchC.addListener(() {
      final next = _searchC.text.trim();
      if (next != _q) setState(() => _q = next);
    });

    // auto-load katalog pertama kali
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final pp = context.read<PurchaseProvider>();
      if (!pp.loadingSkus && pp.skus.isEmpty) {
        await pp.loadCatalog(context);
        if (mounted) setState(() {});
      }
    });
  }

  @override
  void dispose() {
    _searchC.dispose();
    super.dispose();
  }

  // Grouping helper
  List<_ProductGroup> _groupSkus(List<PosSku> list, String query) {
    final q = query.toLowerCase();
    // filter lebih dulu
    final filtered = (q.isEmpty)
        ? list
        : list.where((e) {
            final pn = e.productName.toLowerCase();
            final sc = e.skuCode.toLowerCase();
            return pn.contains(q) || sc.contains(q);
          }).toList();

    final map = <String, List<PosSku>>{};
    for (final s in filtered) {
      (map[s.productId] ??= []).add(s);
    }

    return map.entries.map((e) {
      final productId = e.key;
      final skus = e.value;
      final productName = skus.first.productName;
      final thumb = skus.first.imageUrl; // pakai gambar SKU pertama
      return _ProductGroup(
        productId: productId,
        productName: productName,
        thumbUrl: thumb,
        skus: skus,
      );
    }).toList()..sort((a, b) => a.productName.compareTo(b.productName));
  }

  void _toggleSku(PosSku s) {
    setState(() {
      if (_temp.containsKey(s.skuId)) {
        _temp.remove(s.skuId);
      } else {
        _temp[s.skuId] = _PurchaseRow(
          productId: s.productId,
          skuId: s.skuId,
          productName: s.productName,
          skuLabel: (s.skuCode.isNotEmpty) ? s.skuCode : s.skuCode,
          imageUrl: s.imageUrl,
          price: s.price,
          qty: 1,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final prov = context.watch<PurchaseProvider>();
    final selectedItems = _temp.length;
    final selectedQty = _temp.values.fold<int>(0, (sum, it) => sum + it.qty);

    // state → groups
    final groups = _groupSkus(prov.skus, _q);

    // STATE: isi list
    Widget bodySliver;
    if (prov.loadingSkus && prov.skus.isEmpty) {
      bodySliver = const SliverFillRemaining(
        hasScrollBody: false,
        child: Center(child: CircularProgressIndicator()),
      );
    } else if (prov.catalogError != null) {
      bodySliver = SliverFillRemaining(
        hasScrollBody: false,
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
                'Failed to load SKUs',
                style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
              ),
              const SizedBox(height: 6),
              Text(
                prov.catalogError!,
                textAlign: TextAlign.center,
                style: const TextStyle(color: Color(0xFF6B7280)),
              ),
              const SizedBox(height: 12),
              OutlinedButton(
                onPressed: () => prov.loadCatalog(context),
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
      );
    } else if (groups.isEmpty) {
      bodySliver = const SliverFillRemaining(
        hasScrollBody: false,
        child: Center(child: Text('No products / SKUs found')),
      );
    } else {
      bodySliver = SliverList.separated(
        itemCount: groups.length,
        separatorBuilder: (_, __) =>
            const Divider(height: 1, color: Color(0xFFE5E7EB)),
        itemBuilder: (_, i) {
          final g = groups[i];
          final expanded = _expanded.contains(g.productId);

          // Header produk
          final productHeader = InkWell(
            onTap: () {
              setState(() {
                if (expanded) {
                  _expanded.remove(g.productId);
                } else {
                  _expanded.add(g.productId);
                }
              });
            },
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Row(
                children: [
                  _ProductThumb(url: g.thumbUrl),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      g.productName,
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 14,
                        color: Color(0xFF111827),
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF3F4F6),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      '${g.skus.length} SKU',
                      style: const TextStyle(
                        fontSize: 11,
                        color: Color(0xFF6B7280),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  const SizedBox(width: 6),
                  Icon(
                    expanded ? Icons.expand_less : Icons.expand_more,
                    color: const Color(0xFF6B7280),
                  ),
                ],
              ),
            ),
          );

          // List SKU di dalam produk
          final skuChildren = (!expanded)
              ? const SizedBox.shrink()
              : Column(
                  children: [
                    for (final s in g.skus) ...[
                      const Divider(height: 1, color: Color(0xFFE5E7EB)),
                      _SkuLine(
                        sku: s,
                        selected: _temp.containsKey(s.skuId),
                        qty: _temp[s.skuId]?.qty ?? 0,
                        onChoose: () => _toggleSku(s),
                        onMinus: _temp.containsKey(s.skuId)
                            ? () {
                                setState(() {
                                  final row = _temp[s.skuId]!;
                                  final next = row.qty - 1;
                                  if (next <= 0) {
                                    _temp.remove(s.skuId);
                                  } else {
                                    _temp[s.skuId] = row..qty = next;
                                  }
                                });
                              }
                            : null,
                        onPlus: _temp.containsKey(s.skuId)
                            ? () {
                                setState(() {
                                  final row = _temp[s.skuId]!;
                                  _temp[s.skuId] = row..qty = row.qty + 1;
                                });
                              }
                            : null,
                      ),
                    ],
                  ],
                );

          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 0),
            child: Column(children: [productHeader, skuChildren]),
          );
        },
      );
    }

    return SafeArea(
      minimum: const EdgeInsets.fromLTRB(16, 12, 16, 16),
      child: SizedBox(
        height: MediaQuery.of(context).size.height * 0.85,
        child: Column(
          children: [
            const _SheetHeader(title: 'Add SKUs by Product'),
            // Sticky search
            SizedBox(
              height: 56,
              child: _StickySearchHeaderDelegate(
                controller: _searchC,
                onClear: () => _searchC.clear(),
              ).build(context, 0, false),
            ),
            const SizedBox(height: 4),
            Expanded(
              child: CustomScrollView(
                slivers: [
                  bodySliver,
                  const SliverToBoxAdapter(child: SizedBox(height: 12)),
                ],
              ),
            ),

            // Footer ringkas + CTA
            SafeArea(
              top: false,
              minimum: const EdgeInsets.only(top: 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Container(height: 1, color: const Color(0xFFE5E7EB)),
                  if (selectedItems > 0)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(12, 10, 12, 6),
                      child: Text(
                        '$selectedItems item • $selectedQty qty',
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF6B7280),
                          fontSize: 12,
                        ),
                      ),
                    ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 6, 16, 8),
                    child: FilledButton.icon(
                      onPressed: () =>
                          Navigator.pop(context, _temp.values.toList()),
                      icon: const Icon(Icons.check, size: 18),
                      label: const Text('Use selected'),
                      style: FilledButton.styleFrom(
                        elevation: 0,
                        backgroundColor: const Color(0xFF426FD4),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        textStyle: const TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 14,
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

class _ProductThumb extends StatelessWidget {
  final String? url;
  const _ProductThumb({this.url});

  @override
  Widget build(BuildContext context) {
    final fallback = Container(
      width: 44,
      height: 44,
      decoration: BoxDecoration(
        color: const Color(0xFFF3F4F6),
        borderRadius: BorderRadius.circular(10),
      ),
      child: const Icon(Icons.image, color: Color(0xFFA3A3A3), size: 18),
    );
    return ClipRRect(
      borderRadius: BorderRadius.circular(10),
      child: (url != null && url!.isNotEmpty)
          ? Image.network(
              url!,
              width: 44,
              height: 44,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => fallback,
            )
          : fallback,
    );
  }
}

class _StickyFooterBar extends StatelessWidget {
  final int subtotal, discount, grandTotal;
  final bool enabled;
  final VoidCallback onSubmit;
  final VoidCallback onCancel;

  const _StickyFooterBar({
    required this.subtotal,
    required this.discount,
    required this.grandTotal,
    required this.enabled,
    required this.onSubmit,
    required this.onCancel,
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
          children: [
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _miniKV('Subtotal', 'Rp ${money.format(subtotal)}'),
                      _miniKV('Discount', '- Rp ${money.format(discount)}'),
                      const SizedBox(height: 4),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'Grand total',
                            style: TextStyle(
                              fontWeight: FontWeight.w800,
                              color: UI.text,
                            ),
                          ),
                          Text(
                            'Rp ${money.format(grandTotal)}',
                            style: const TextStyle(
                              fontWeight: FontWeight.w800,
                              color: UI.text,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
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

  Widget _miniKV(String k, String v) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 2),
    child: Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(k, style: const TextStyle(color: UI.sub)),
        Text(v, style: const TextStyle(color: UI.sub)),
      ],
    ),
  );
}

Future<_PurchaseRow?> showProductVariantSheet(
  BuildContext context,
  Product product,
) {
  return showModalBottomSheet<_PurchaseRow>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: Colors.white,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
    ),
    builder: (_) => _ProductVariantSheet(product: product),
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

    final price = matchedSku?.price ?? product.basePrice ?? 0;
    final money = NumberFormat.decimalPattern('id_ID');

    return Container(
      color: UI.bg,
      child: SafeArea(
        minimum: const EdgeInsets.fromLTRB(16, 12, 16, 0),
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
                                  price: matchedSku.price,
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

  // helper: ambil daftar atribut dari semua SKU
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

class _SkuLine extends StatelessWidget {
  final PosSku sku;
  final bool selected;
  final int qty;
  final VoidCallback onChoose;
  final VoidCallback? onMinus;
  final VoidCallback? onPlus;

  const _SkuLine({
    required this.sku,
    required this.selected,
    required this.qty,
    required this.onChoose,
    this.onMinus,
    this.onPlus,
  });

  @override
  Widget build(BuildContext context) {
    final priceText = NumberFormat.decimalPattern('id_ID').format(sku.price);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
      child: Row(
        children: [
          // spacer kecil agar align dengan thumb produk
          const SizedBox(width: 44), // sejajar dgn _ProductThumb width
          const SizedBox(width: 12),
          // info SKU
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Kode / nama varian
                Text(
                  sku.skuCode,
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 13,
                    color: Color(0xFF111827),
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Text(
                  'Rp. $priceText',
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF111827),
                  ),
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

  // Ambil base price dari Product.basePrice (sudah ada di model)
  int? _price(Product p) => p.basePrice;

  Future<void> _pickVariant(Product p) async {
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
      List<Product> base = List<Product>.from(
        prov.products,
      ); // atau: [...prov.products]

      if (_q.isNotEmpty) {
        final q = _q.toLowerCase();
        base = base.where((p) {
          final inName = p.name.toLowerCase().contains(q);
          final inSku = p.productSkus.any(
            (s) => s.code.toLowerCase().contains(q),
          );
          return inName || inSku;
        }).toList(); // sudah mutable
      }

      base.sort((a, b) => a.name.compareTo(b.name)); // aman sekarang
      return base;
    }();

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

      return Expanded(
        child: GridView.builder(
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
            childAspectRatio: 0.62, // ← cegah overflow
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
              basePrice: _price(p),
            );
          },
        ),
      );
    }

    return SafeArea(
      minimum: const EdgeInsets.fromLTRB(16, 12, 16, 16),
      child: SizedBox(
        height: MediaQuery.of(context).size.height * 0.9,
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
                  Container(height: 1, color: const Color(0xFFE5E7EB)),
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
                    padding: const EdgeInsets.fromLTRB(16, 6, 16, 8),
                    child: FilledButton.icon(
                      onPressed: () =>
                          Navigator.pop(context, _temp.values.toList()),
                      icon: const Icon(Icons.check, size: 18),
                      label: const Text('Use selected'),
                      style: FilledButton.styleFrom(
                        elevation: 0,
                        backgroundColor: const Color(0xFF426FD4),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        textStyle: const TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 14,
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

class _ProductCardFromModel extends StatelessWidget {
  const _ProductCardFromModel({
    required this.product,
    required this.onAdd,
    required this.selectedQty,
    this.thumbUrl,
    this.basePrice,
  });

  final Product product;
  final VoidCallback onAdd;
  final int selectedQty;
  final String? thumbUrl;
  final int? basePrice;

  @override
  Widget build(BuildContext context) {
    final money = NumberFormat.decimalPattern('id_ID');

    Widget image() {
      final fallback = Container(
        decoration: BoxDecoration(
          color: const Color(0xFFF3F4F6),
          borderRadius: BorderRadius.circular(12),
        ),
        child: const Center(child: Icon(Icons.image, color: Color(0xFFA3A3A3))),
      );
      return ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: (thumbUrl != null && thumbUrl!.isNotEmpty)
            ? Image.network(
                thumbUrl!,
                height: 110, // ← fix height: anti overflow
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
        border: Border.all(color: UI.line),
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
              product.name,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontWeight: FontWeight.w800,
                color: UI.text,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              (basePrice != null) ? 'Rp. ${money.format(basePrice)}' : '—',
              style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15),
            ),
            const Spacer(),
            SizedBox(
              height: 40,
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
                child: Text(
                  selectedQty > 0 ? 'Add more variants' : 'Add',
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
