import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import 'package:wa_blast/constants/design_system.dart';
import 'package:wa_blast/models/product_model.dart';
import 'package:wa_blast/providers/product_provider.dart';
import 'package:wa_blast/providers/stock_provider.dart';
import 'package:wa_blast/widgets/reusable_pickers.dart';
import 'package:wa_blast/models/product_model.dart' hide City, StoreLocation;

/// Row model untuk initial stock
class _InitialStockRow {
  final String productId;
  final String skuId;
  final String productName;
  final String skuLabel; // nama/kode SKU
  final String? imageUrl;
  final int price; // harga unit SKU
  int qty;
  int discountPerItem; // diskon per item (IDR)

  int get unitPriceAfterDisc =>
      (price - discountPerItem).clamp(0, 1 << 31).toInt();
  int get lineTotal => unitPriceAfterDisc * qty;

  _InitialStockRow({
    required this.productId,
    required this.skuId,
    required this.productName,
    required this.skuLabel,
    required this.price,
    this.imageUrl,
    this.qty = 1,
    this.discountPerItem = 0,
  });
}

class AddInitialStockPage extends StatefulWidget {
  const AddInitialStockPage({super.key});

  @override
  State<AddInitialStockPage> createState() => _AddInitialStockPageState();
}

class _AddInitialStockPageState extends State<AddInitialStockPage> {
  final _formKey = GlobalKey<FormState>();
  bool _submitting = false;

  // meta fields
  final _noteC = TextEditingController();
  final _discountOrderC = TextEditingController(text: '0');
  int get _orderDiscount => int.tryParse(_discountOrderC.text.trim()) ?? 0;

  String? _storeId;
  String _storeName = '';

  // items
  final Map<String, _InitialStockRow> _rows = {}; // key: skuId

  // ===== Responsive helpers =====
  bool get _isTablet {
    final shortest = MediaQuery.of(context).size.shortestSide;
    return shortest >= 600;
  }

  double get _maxContentWidth => _isTablet ? 960 : double.infinity;
  EdgeInsets get _screenPadding => _isTablet
      ? const EdgeInsets.fromLTRB(24, 12, 24, 0)
      : const EdgeInsets.fromLTRB(16, 12, 16, 0);

  @override
  void dispose() {
    _noteC.dispose();
    _discountOrderC.dispose();
    super.dispose();
  }

  /// Bangun list InitialStockItem untuk dikirim ke StockProvider.createInitialStock
  List<InitialStockItem> _buildItems() {
    return _rows.values
        .where((r) => r.qty > 0)
        .map(
          (r) => InitialStockItem(
            productId: r.productId,
            productSkuId: r.skuId,
            qty: r.qty,
            // price = harga dasar SKU (sebelum diskon header)
            price: r.price,
            // diskon per item (optional), kalau 0 biarkan null
            discount: r.discountPerItem > 0 ? r.discountPerItem : null,
          ),
        )
        .toList();
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

  /// Alokasikan order discount ke tiap baris (IDR per unit)
  Map<String, int> _allocOrderDiscountPerUnit() {
    final od = _orderDiscount;
    if (od <= 0 || _rows.isEmpty) return const {};

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

    final perUnit = <String, int>{};
    var allocated = 0;
    for (final r in _rows.values) {
      final base = bases[r.skuId] ?? 0;
      if (base == 0) {
        perUnit[r.skuId] = 0;
        continue;
      }
      final rowDisc = (od * base ~/ baseSum);
      allocated += rowDisc;
      final perUnitDisc = (r.qty > 0) ? (rowDisc ~/ r.qty) : 0;
      perUnit[r.skuId] = perUnitDisc;
    }

    final remain = od - allocated;
    if (remain > 0) {
      final first = _rows.values.first;
      perUnit[first.skuId] =
          (perUnit[first.skuId] ?? 0) +
          (remain ~/ (first.qty > 0 ? first.qty : 1));
    }

    perUnit.updateAll((sku, d) {
      final r = _rows[sku]!;
      final maxDisc = r.unitPriceAfterDisc;
      return d.clamp(0, maxDisc).toInt();
    });

    return perUnit;
  }

  Future<void> _openSkuPicker() async {
    // Pakai helper SKU picker generic
    final picked = await showSkuPickerSheet(
      context,
      // optional: kalau mau highlight SKU terakhir dipilih
      // selectedId: _rows.isNotEmpty ? _rows.values.last.skuId : null,
    );

    if (picked == null || !mounted) return;

    final sku = picked.data;
    if (sku == null) return;

    // Cari Product yang punya SKU ini supaya bisa ambil idProduct & nama produknya
    final productProv = context.read<ProductProvider>();
    Product? product;
    for (final p in productProv.products) {
      final found = p.productSkus.any(
        (s) => s.idProductSku == sku.idProductSku,
      );
      if (found) {
        product = p;
        break;
      }
    }

    if (product == null) {
      // Harusnya nggak kejadian, karena SKU list di picker juga di-build dari ProductProvider
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Produk untuk SKU ini tidak ditemukan.')),
      );
      return;
    }

    setState(() {
      final key = sku.idProductSku;
      final existing = _rows[key];

      if (existing != null) {
        // Kalau SKU sudah ada, tambah qty saja
        existing.qty += 1;
      } else {
        // Tambah baris baru
        _rows[key] = _InitialStockRow(
          productId: product!.idProduct,
          skuId: sku.idProductSku,
          productName: product!.name,
          skuLabel: sku.code.isNotEmpty ? sku.code : picked.label,
          imageUrl: product!.primaryImageUrl,
          price: sku.price,
          qty: 1,
        );
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
    final t = _subtotalItems - _orderDiscount;
    return t < 0 ? 0 : t;
  }

  /// Payload untuk API:
  /// POST /waveup/:idBusiness/initial-stock
  /// {
  ///   "store_location_id": "...",
  ///   "note": "...",
  ///   "discount": 3500,
  ///   "items": [
  ///     {
  ///       "product_id": "...",
  ///       "product_sku_id": "...",
  ///       "qty": 100,
  ///       "price": 5000,
  ///       "discount": 0
  ///     }
  ///   ]
  /// }
  Map<String, dynamic> _buildPayload() {
    return {
      "store_location_id": _storeId,
      "note": _noteC.text.trim(),
      "discount": _orderDiscount,
      "items": _rows.values
          .where((r) => r.qty > 0)
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

    final items = _buildItems();
    if (items.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Qty semua SKU tidak boleh 0')),
      );
      return;
    }

    setState(() => _submitting = true);

    final sp = context.read<StockProvider>();
    final ok = await sp.createInitialStock(
      context: context,
      storeLocationId: _storeId!, // sudah dicek non-null di atas
      note: _noteC.text.trim(),
      // header discount (optional)
      discount: _orderDiscount > 0 ? _orderDiscount : null,
      items: items,
    );

    if (!mounted) return;
    setState(() => _submitting = false);

    if (ok) {
      await _showCreatedDialog();
    } else {
      final err = sp.lastError ?? 'Failed to create initial stock.';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(err), backgroundColor: const Color(0xFFDC2626)),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final hasItems = _rows.isNotEmpty;

    return Scaffold(
      backgroundColor: UI.bg,
      appBar: AppBar(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
        scrolledUnderElevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded),
          onPressed: () => Navigator.maybePop(context),
        ),
        // Judul ala purchase: "Stock  /initial"
        title: Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.baseline,
          textBaseline: TextBaseline.alphabetic,
          children: const [
            Text('Stock', style: TextStyle(fontWeight: FontWeight.w800)),
            SizedBox(width: 8),
            Text(
              '/initial',
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
      ),

      body: SafeArea(
        minimum: _screenPadding,
        child: Center(
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: _maxContentWidth),
            child: Column(
              children: [
                // --- Items ---
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
                              style: TextButton.styleFrom(
                                foregroundColor: UI.blue,
                              ),
                            ),
                          ],
                        ),
                        child: (_rows.isEmpty)
                            ? _emptyItemsHint()
                            : _ItemsDataTable(
                                rows: _rows.values.toList(),
                                orderDiscPerUnit: _allocOrderDiscountPerUnit(),
                                onDiscountChanged: (skuId, value) =>
                                    setState(() {
                                      _rows[skuId]!.discountPerItem = value
                                          .clamp(0, 1 << 31);
                                    }),
                                onRemove: (skuId) =>
                                    setState(() => _rows.remove(skuId)),
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
                      ),
                      const SizedBox(height: 12),

                      // --- Details ---
                      _Section(
                        title: 'Initial stock details',
                        child: Form(
                          key: _formKey,
                          child: Column(
                            children: [
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
                                  decoration: UI.input(
                                    'PEMBELIAN AWAL TANGGAL …',
                                  ),
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

                // --- Sticky footer ---
                Center(
                  child: ConstrainedBox(
                    constraints: BoxConstraints(maxWidth: _maxContentWidth),
                    child: _StickyFooterBar(
                      subtotal: _subtotalItems,
                      discount: _orderDiscount,
                      grandTotal: _grandTotal,
                      enabled: hasItems && _storeId != null && !_submitting,
                      onSubmit: _submit,
                      onCancel: () => Navigator.maybePop(context),
                    ),
                  ),
                ),
              ],
            ),
          ),
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

  Future<void> _showCreatedDialog() async {
    await showGeneralDialog(
      context: context,
      barrierDismissible: false,
      barrierLabel: 'Initial Stock Created',
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
                      'Initial Stock Saved',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 18,
                        color: UI.text,
                      ),
                    ),
                    const SizedBox(height: 6),
                    const Text(
                      'Data stok awal berhasil disimpan.',
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
                          // arahkan ke /stock (list initial stock)
                          Navigator.of(context).pushNamedAndRemoveUntil(
                            '/stock/initial-stock',
                            (route) => route.settings.name == '/stock',
                          );
                        },
                        child: const Text(
                          'Continue',
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
}

/// ====== HELPER WIDGETS & PICKER (re-use style AddPurchase) ======

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

/// Grid picker product -> pilih SKU (via variant sheet)
class _ProductGridPicker extends StatefulWidget {
  const _ProductGridPicker({required this.initial});
  final Map<String, _InitialStockRow> initial; // skuId -> row

  @override
  State<_ProductGridPicker> createState() => _ProductGridPickerState();
}

class _ProductGridPickerState extends State<_ProductGridPicker> {
  final _searchC = TextEditingController();
  String _q = '';
  late Map<String, _InitialStockRow> _temp;

  bool get _isTablet => MediaQuery.of(context).size.shortestSide >= 600;

  @override
  void initState() {
    super.initState();
    _temp = Map<String, _InitialStockRow>.from(widget.initial);
    _searchC.addListener(() {
      final t = _searchC.text.trim();
      if (t != _q) setState(() => _q = t);
    });

    // load produk pertama kali
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

  String? _thumb(Product p) => p.primaryImageUrl;
  int? _price(Product p) => p.basePrice;

  Future<void> _pickVariant(Product p) async {
    // QUICK-ADD kalau tidak punya varian
    if (_hasNoVariantAttrs(p)) {
      final s = _defaultSku(p);
      if (s == null) return;

      setState(() {
        final key = s.idProductSku;
        final cur = _temp[key];
        if (cur == null) {
          _temp[key] = _InitialStockRow(
            productId: p.idProduct,
            skuId: s.idProductSku,
            productName: p.name,
            skuLabel: s.code,
            imageUrl: p.primaryImageUrl,
            price: s.price,
            qty: 1,
          );
        } else {
          _temp[key] = cur..qty = cur.qty + 1;
        }
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Added 1 — ${p.name}'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    // NORMAL: buka variant sheet
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
          padding: _isTablet
              ? const EdgeInsets.fromLTRB(16, 8, 16, 16)
              : const EdgeInsets.fromLTRB(12, 8, 12, 12),
          gridDelegate: _isTablet
              ? const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 3,
                  crossAxisSpacing: 16,
                  mainAxisSpacing: 16,
                  mainAxisExtent: 320,
                )
              : const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  crossAxisSpacing: 12,
                  mainAxisSpacing: 12,
                  childAspectRatio: 0.62,
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

                body(),

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
                          height: 50,
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
    this.basePrice,
  });

  final Product product;
  final VoidCallback onAdd;
  final int selectedQty;
  final String? thumbUrl;
  final int? basePrice;

  @override
  Widget build(BuildContext context) {
    final isTablet = MediaQuery.of(context).size.shortestSide >= 600;
    final money = NumberFormat.decimalPattern('id_ID');

    Widget image() {
      final fallback = Container(
        decoration: BoxDecoration(
          color: const Color(0xFFF3F4F6),
          borderRadius: BorderRadius.circular(12),
        ),
        child: const Center(child: Icon(Icons.image, color: Color(0xFFA3A3A3))),
      );
      final h = isTablet ? 128.0 : 110.0;
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
        padding: EdgeInsets.all(isTablet ? 12 : 12),
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
            Text(
              product.name,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontWeight: FontWeight.w800,
                color: UI.text,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              (basePrice != null) ? 'Rp. ${money.format(basePrice)}' : '—',
              style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15),
            ),
            const Spacer(),
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
            color: Color(0xFF374151),
          ),
        ),
        const SizedBox(height: 6),
        child,
      ],
    );
  }
}

/// Footer ringkasan + tombol
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
                            'Total value',
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

class _ItemsDataTable extends StatelessWidget {
  const _ItemsDataTable({
    required this.rows,
    required this.orderDiscPerUnit,
    required this.onDiscountChanged,
    required this.onRemove,
    required this.onQtyChanged,
  });

  final List<_InitialStockRow> rows;
  final Map<String, int> orderDiscPerUnit; // skuId -> disc/unit
  final void Function(String skuId, int value) onDiscountChanged;
  final void Function(String skuId) onRemove;
  final void Function(String skuId, int nextQty) onQtyChanged;

  @override
  Widget build(BuildContext context) {
    final money = NumberFormat.decimalPattern('id_ID');

    const minTableWidth = 880.0;

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: ConstrainedBox(
        constraints: const BoxConstraints(minWidth: minTableWidth),
        child: DataTable(
          headingRowHeight: 44,
          dataRowMinHeight: 52,
          dataRowMaxHeight: 60,
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
                DataCell(
                  Text(
                    r.skuLabel,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: Color(0xFF6B7280)),
                  ),
                ),
                DataCell(
                  Align(
                    alignment: Alignment.centerRight,
                    child: _QtyEditor(
                      qty: r.qty,
                      onMinus: () {
                        final next = r.qty - 1;
                        onQtyChanged(r.skuId, next);
                      },
                      onPlus: () => onQtyChanged(r.skuId, r.qty + 1),
                      onTyped: (v) => onQtyChanged(r.skuId, v),
                    ),
                  ),
                ),
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
                DataCell(Text(money.format(r.price))),
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
                DataCell(
                  Text(
                    money.format(lineTotal),
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                ),
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

bool _hasNoVariantAttrs(Product p) {
  return p.productSkus.every((s) => s.attributes.isEmpty);
}

ProductSku? _defaultSku(Product p) {
  if (p.productSkus.isEmpty) return null;
  return p.productSkus.first;
}

/// Variant picker → balikin _InitialStockRow
Future<_InitialStockRow?> showProductVariantSheet(
  BuildContext context,
  Product product,
) {
  final isTablet = MediaQuery.of(context).size.shortestSide >= 600;
  return showModalBottomSheet<_InitialStockRow>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: Colors.transparent,
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

    final price = matchedSku?.price ?? product.basePrice ?? 0;
    final money = NumberFormat.decimalPattern('id_ID');

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
                                final row = _InitialStockRow(
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
                              : "Add — Rp ${money.format(price)}",
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
}
