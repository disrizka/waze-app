import 'package:dotted_border/dotted_border.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:wa_blast/widgets/reusable_pickers.dart';

import '../../providers/purchase_provider.dart';
// Opsional: jika kamu sudah punya ProductProvider, import ini agar dropdown Product terisi.
// Hapus import berikut jika tidak diperlukan.
// ignore: unused_import
import '../../providers/product_provider.dart';

import '../detail_purchase_screen.dart';

class PurchaseScreen extends StatelessWidget {
  const PurchaseScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded),
          onPressed: () => Navigator.pushReplacementNamed(context, '/purchase'),
        ),
        title: const Text('Purchase'),
      ),
      body: const _PurchaseList(),

      // === Add New Purchase button (fixed di bawah) ===
      bottomNavigationBar: SafeArea(
        minimum: const EdgeInsets.fromLTRB(12, 8, 12, 20),
        child: SizedBox(
          height: 46,
          child: ElevatedButton.icon(
            icon: const Icon(Icons.add_rounded),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF426FD4),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              minimumSize: const Size.fromHeight(46),
            ),
            onPressed: () async {
              final result = await showAddPurchaseSheet(context);
              if (result != null && context.mounted) {
                // TODO: kirim ke provider/API kalau sudah siap.
                // Misal:
                // final ok = await context.read<PurchaseProvider>().createPurchase(context, result);
                // if (ok) context.read<PurchaseProvider>().fetchPurchases(context);

                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      'Draft Purchase: supplier=${result.supplierName} • product=${result.skuLabel} • qty=${result.qty} • price=${result.price}',
                    ),
                    backgroundColor: const Color(0xFF059669),
                  ),
                );
              }
            },
            label: const Text(
              'Add New Purchase',
              style: TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
        ),
      ),
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
        return ListView.builder(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 24 + 72),
          itemCount: items.length + 1,
          itemBuilder: (context, index) {
            if (index == 0) {
              return const Padding(
                padding: EdgeInsets.only(bottom: 12),
                child: Text(
                  'History Purchase',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF6B7280),
                  ),
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
                        _StatusChip(status: item.status),
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
                    '/detail-purchase',
                    arguments: {'code': item.code},
                  );
                },
                child: card,
              ),
            );
          },
        );
      },
    );
  }
}

class _StatusChip extends StatelessWidget {
  final PurchaseStatus status;
  const _StatusChip({required this.status});

  @override
  Widget build(BuildContext context) {
    late String label;
    late final Color dot;
    late final Color textColor;

    switch (status) {
      case PurchaseStatus.inProgress:
        label = 'In Progress';
        dot = const Color(0xFFB45309);
        textColor = const Color(0xFFB45309);
        break;
      case PurchaseStatus.completed:
        label = 'Completed';
        dot = const Color(0xFF059669);
        textColor = const Color(0xFF059669);
        break;
      case PurchaseStatus.canceled:
        label = 'Canceled';
        dot = const Color(0xFFDC2626);
        textColor = const Color(0xFFDC2626);
        break;
    }

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(color: dot, shape: BoxShape.circle),
        ),
        const SizedBox(width: 6),
        Text(
          label,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: textColor,
          ),
        ),
      ],
    );
  }
}

/// ======================================================================
/// ADD PURCHASE SHEET + SELECTOR SHEETS
/// ======================================================================

/// Model sederhana untuk hasil sheet
class AddPurchaseResult {
  final String supplierId;
  final String supplierName;
  final String skuId; // ← ganti dari productId
  final String skuLabel; // ← ganti dari productName (tampilan)
  final int qty;
  final int price;
  AddPurchaseResult({
    required this.supplierId,
    required this.supplierName,
    required this.skuId,
    required this.skuLabel,
    required this.qty,
    required this.price,
  });

  Map<String, dynamic> toJson() => {
    'supplier_id': supplierId,
    'supplier_name': supplierName,
    'sku_id': skuId,
    'sku_label': skuLabel,
    'qty': qty,
    'price': price,
  };
}

Future<AddPurchaseResult?> showAddPurchaseSheet(BuildContext context) {
  return showModalBottomSheet<AddPurchaseResult>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: Colors.white,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
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

  String? _supplierId;
  String? _supplierName;

  String? _skuId;
  String? _skuLabel;

  final _qtyC = TextEditingController();
  final _priceC = TextEditingController();

  final _money = NumberFormat.decimalPattern('id_ID');

  @override
  void dispose() {
    _qtyC.dispose();
    _priceC.dispose();
    super.dispose();
  }

  void _selectSupplier() async {
    // pastikan supplier sudah dimuat
    final p = context.read<PurchaseProvider>();
    if (p.suppliers.isEmpty) {
      await p.fetchSuppliers(context);
    }
    final picked = await showModalBottomSheet<_PickOption>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => _SelectSupplierSheet(),
    );

    if (picked != null) {
      setState(() {
        _supplierId = picked.id;
        _supplierName = picked.label;
      });
    }
  }

  String? _validateInt(String? v, {bool allowZero = false}) {
    if (v == null || v.trim().isEmpty) return 'This field is required';
    final raw = v.replaceAll('.', '').replaceAll(',', '');
    final n = int.tryParse(raw);
    if (n == null) return 'Invalid number';
    if (!allowZero && n <= 0) return 'Must be greater than 0';
    return null;
  }

  Future<void> _selectSku() async {
    final picked = await showSkuPickerSheet(
      context,
      selectedId: _skuId, // highlight jika sudah ada pilihan
    );
    if (picked != null && mounted) {
      setState(() {
        _skuId = picked.id; // ← simpan SKU ID
        _skuLabel = picked.label; // ← tampilkan di field (kode / var utama)
        // picked.subtitle sudah memuat "Product • VariantUtama"
        // kalau mau, kamu bisa simpan subtitle juga untuk ditampilkan di UI lain.
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final insets = MediaQuery.of(context).viewInsets;
    return Padding(
      padding: EdgeInsets.only(bottom: insets.bottom),
      child: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header drag-handle
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    margin: const EdgeInsets.only(bottom: 14),
                    decoration: BoxDecoration(
                      color: const Color(0xFFE5E7EB),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const Text(
                  'Add New Purchase',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF111827),
                  ),
                ),
                const SizedBox(height: 14),

                // Supplier selector
                const Text(
                  'Supplier',
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF374151),
                  ),
                ),
                const SizedBox(height: 8),
                // 1) Field klik-untuk-pilih (di form mana pun):
                PickerField(
                  placeholder: 'Select supplier',
                  value: _supplierName,
                  onTap: () async {
                    final picked = await showSupplierPickerSheet(
                      context,
                      selectedId:
                          _supplierId, // <<— highlight supplier yang sekarang kepilih
                    );
                    if (picked != null && mounted) {
                      setState(() {
                        _supplierId = picked.id;
                        _supplierName = picked.label;
                      });
                    }
                  },
                ),

                const SizedBox(height: 14),

                const Text(
                  'SKU',
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF374151),
                  ),
                ),
                const SizedBox(height: 8),
                PickerField(
                  placeholder: 'Select SKU',
                  value: _skuLabel, // tampilkan kode/label sku
                  onTap: _selectSku,
                ),

                const SizedBox(height: 14),

                // Qty
                const Text(
                  'Stock (Qty)',
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF374151),
                  ),
                ),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _qtyC,
                  keyboardType: TextInputType.number,
                  validator: (v) => _validateInt(v),
                  decoration: _tiDecoration(hint: '0'),
                ),

                const SizedBox(height: 14),

                // Price
                const Text(
                  'Price',
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF374151),
                  ),
                ),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _priceC,
                  keyboardType: TextInputType.number,
                  validator: (v) => _validateInt(v, allowZero: false),
                  onChanged: (v) {
                    // optional: formatting kasat mata
                    final raw = v.replaceAll(RegExp(r'[^\d]'), '');
                    if (raw.isEmpty) return;
                    final sel = TextSelection.collapsed(
                      offset: _priceC.selection.baseOffset,
                    );
                    _priceC.value = TextEditingValue(
                      text: _money.format(int.tryParse(raw) ?? 0),
                      selection: sel,
                    );
                  },
                  decoration: _tiDecoration(hint: '0'),
                ),

                const SizedBox(height: 18),

                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => Navigator.pop(context),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: const Color(0xFF6B7280),
                          side: const BorderSide(color: Color(0xFFE5E7EB)),
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
                      child: ElevatedButton(
                        onPressed: () {
                          if (_supplierId == null) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Please select a supplier first'),
                              ),
                            );
                            return;
                          }
                          if (_skuId == null) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Please select SKU first'),
                              ),
                            );
                            return;
                          }
                          if (!_formKey.currentState!.validate()) return;

                          final qty = int.parse(
                            _qtyC.text.replaceAll('.', '').replaceAll(',', ''),
                          );
                          final price = int.parse(
                            _priceC.text
                                .replaceAll('.', '')
                                .replaceAll(',', ''),
                          );

                          Navigator.pop(
                            context,
                            AddPurchaseResult(
                              supplierId: _supplierId!,
                              supplierName: _supplierName ?? '',
                              skuId: _skuId!,
                              skuLabel: _skuLabel ?? '',
                              qty: qty,
                              price: price,
                            ),
                          );
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF426FD4),
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                        ),
                        child: const Text(
                          'Create',
                          style: TextStyle(fontWeight: FontWeight.w600),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  InputDecoration _tiDecoration({required String hint}) => InputDecoration(
    hintText: hint,
    isDense: true,
    filled: true,
    fillColor: const Color(0xFFF5F9FF),
    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
    enabledBorder: OutlineInputBorder(
      borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
      borderRadius: BorderRadius.circular(10),
    ),
    focusedBorder: OutlineInputBorder(
      borderSide: const BorderSide(color: Color(0xFF64B5F6)),
      borderRadius: BorderRadius.circular(10),
    ),
  );
}

/// Field tampilan selector (klik untuk buka sheet)
class _PickerField extends StatelessWidget {
  const _PickerField({
    required this.placeholder,
    required this.onTap,
    this.value,
  });

  final String placeholder;
  final String? value;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: const Color(0xFFF5F9FF),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: const Color(0xFFE5E7EB)),
        ),
        child: Row(
          children: [
            Expanded(
              child: Text(
                value?.isNotEmpty == true ? value! : placeholder,
                style: TextStyle(
                  color: value?.isNotEmpty == true
                      ? const Color(0xFF111827)
                      : const Color(0xFF9CA3AF),
                  fontWeight: value?.isNotEmpty == true
                      ? FontWeight.w600
                      : null,
                ),
              ),
            ),
            const Icon(Icons.expand_more_rounded, color: Color(0xFF9CA3AF)),
          ],
        ),
      ),
    );
  }
}

/// Option sederhana buat selector
class _PickOption {
  final String id;
  final String label;
  final String? subtitle;
  _PickOption({required this.id, required this.label, this.subtitle});
}

/// ====================== Supplier Selector Sheet ======================

class _SelectSupplierSheet extends StatefulWidget {
  @override
  State<_SelectSupplierSheet> createState() => _SelectSupplierSheetState();
}

class _SelectSupplierSheetState extends State<_SelectSupplierSheet> {
  final _searchC = TextEditingController();

  @override
  void dispose() {
    _searchC.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final prov = context.watch<PurchaseProvider>();
    final all = prov.suppliers
        .map(
          (s) => _PickOption(
            id: s.idSupplier,
            label: s.name,
            subtitle: [
              if ((s.city?.name ?? '').isNotEmpty) s.city!.name,
              if ((s.phone ?? '').isNotEmpty) s.phone!,
              if ((s.email ?? '').isNotEmpty) s.email!,
            ].join(' • '),
          ),
        )
        .toList();

    final q = _searchC.text.trim().toLowerCase();
    final items = q.isEmpty
        ? all
        : all
              .where(
                (o) =>
                    o.label.toLowerCase().contains(q) ||
                    (o.subtitle ?? '').toLowerCase().contains(q),
              )
              .toList();

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // drag handle
          Container(
            width: 40,
            height: 4,
            margin: const EdgeInsets.only(bottom: 12, top: 6),
            decoration: BoxDecoration(
              color: const Color(0xFFE5E7EB),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const Text(
            'Select Supplier',
            style: TextStyle(
              fontWeight: FontWeight.w800,
              fontSize: 16,
              color: Color(0xFF111827),
            ),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: _searchC,
            onChanged: (_) => setState(() {}),
            decoration: InputDecoration(
              hintText: 'Search supplier…',
              isDense: true,
              filled: true,
              fillColor: const Color(0xFFF5F9FF),
              prefixIcon: const Icon(
                Icons.search,
                size: 20,
                color: Color(0xFF9CA3AF),
              ),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 14,
                vertical: 12,
              ),
              enabledBorder: OutlineInputBorder(
                borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
                borderRadius: BorderRadius.circular(10),
              ),
              focusedBorder: OutlineInputBorder(
                borderSide: const BorderSide(color: Color(0xFF64B5F6)),
                borderRadius: BorderRadius.circular(10),
              ),
            ),
          ),
          const SizedBox(height: 10),
          Flexible(
            child: ListView.separated(
              shrinkWrap: true,
              itemCount: items.length,
              separatorBuilder: (_, __) => const SizedBox(height: 6),
              itemBuilder: (_, i) {
                final o = items[i];
                return ListTile(
                  onTap: () => Navigator.pop(context, o),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  tileColor: Colors.white,
                  leading: const Icon(
                    Icons.store_rounded,
                    color: Color(0xFF6B7280),
                  ),
                  title: Text(
                    o.label,
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                  subtitle: (o.subtitle?.isNotEmpty == true)
                      ? Text(
                          o.subtitle!,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        )
                      : null,
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

/// ====================== Product Selector Sheet ======================

class _SelectProductSheet extends StatefulWidget {
  const _SelectProductSheet({required this.initial});
  final List<_PickOption> initial;

  @override
  State<_SelectProductSheet> createState() => _SelectProductSheetState();
}

class _SelectProductSheetState extends State<_SelectProductSheet> {
  final _searchC = TextEditingController();
  List<_PickOption> _items = [];

  @override
  void initState() {
    super.initState();
    _items = widget.initial;
  }

  @override
  void dispose() {
    _searchC.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Jika initial kosong, tampilkan info supaya user memahami perlu sink produk dulu
    final q = _searchC.text.trim().toLowerCase();
    final filtered = q.isEmpty
        ? _items
        : _items
              .where(
                (o) =>
                    o.label.toLowerCase().contains(q) ||
                    (o.subtitle ?? '').toLowerCase().contains(q),
              )
              .toList();

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // drag handle
          Container(
            width: 40,
            height: 4,
            margin: const EdgeInsets.only(bottom: 12, top: 6),
            decoration: BoxDecoration(
              color: const Color(0xFFE5E7EB),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const Text(
            'Select Product',
            style: TextStyle(
              fontWeight: FontWeight.w800,
              fontSize: 16,
              color: Color(0xFF111827),
            ),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: _searchC,
            onChanged: (_) => setState(() {}),
            decoration: InputDecoration(
              hintText: 'Search product…',
              isDense: true,
              filled: true,
              fillColor: const Color(0xFFF5F9FF),
              prefixIcon: const Icon(
                Icons.search,
                size: 20,
                color: Color(0xFF9CA3AF),
              ),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 14,
                vertical: 12,
              ),
              enabledBorder: OutlineInputBorder(
                borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
                borderRadius: BorderRadius.circular(10),
              ),
              focusedBorder: OutlineInputBorder(
                borderSide: const BorderSide(color: Color(0xFF64B5F6)),
                borderRadius: BorderRadius.circular(10),
              ),
            ),
          ),
          const SizedBox(height: 10),
          if (_items.isEmpty)
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: const Color(0xFFF9FAFB),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFE5E7EB)),
              ),
              child: const Text(
                'Product list is empty here.\nMake sure ProductProvider has loaded products.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Color(0xFF6B7280)),
              ),
            )
          else
            Flexible(
              child: ListView.separated(
                shrinkWrap: true,
                itemCount: filtered.length,
                separatorBuilder: (_, __) => const SizedBox(height: 6),
                itemBuilder: (_, i) {
                  final o = filtered[i];
                  return ListTile(
                    onTap: () => Navigator.pop(context, o),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    tileColor: Colors.white,
                    leading: const Icon(
                      Icons.inventory_2_rounded,
                      color: Color(0xFF6B7280),
                    ),
                    title: Text(
                      o.label,
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                    subtitle: (o.subtitle?.isNotEmpty == true)
                        ? Text(
                            o.subtitle!,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          )
                        : null,
                  );
                },
              ),
            ),
        ],
      ),
    );
  }
}
