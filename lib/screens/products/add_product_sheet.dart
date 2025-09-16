// lib/screens/add_product_sheet.dart
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/material.dart' as vmath;
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:shimmer/shimmer.dart';
import 'package:wa_blast/constants/app_colors.dart';

import 'package:wa_blast/providers/product_provider.dart';
import 'package:wa_blast/widgets/app_snackbar.dart';
import 'package:wa_blast/widgets/variant_section_dynamic.dart';

/// Public helper to show the sheet from other screens.
Future<void> showAddProductSheet(BuildContext context) {
  return showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: Colors.white,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (_) => const _AddProductSheet(),
  );
}

/// Key for VariantsSectionDynamic (local to this file only)
final GlobalKey<VariantsSectionDynamicState> variantsKey =
    GlobalKey<VariantsSectionDynamicState>();

class _AddProductSheet extends StatefulWidget {
  const _AddProductSheet();
  @override
  State<_AddProductSheet> createState() => _AddProductSheetState();
}

class _AddProductSheetState extends State<_AddProductSheet> {
  bool _isSubmitting = false;
  // ====== BASE FORM ======
  final _formKey = GlobalKey<FormState>();
  final _nameC = TextEditingController();
  final _descC = TextEditingController();
  final _priceC = TextEditingController(); // (not used on submit)
  final _stockC = TextEditingController(); // (not used on submit)
  bool _available = true; // optional (not used by API yet)
  bool _attemptedSubmit = false;

  // ====== VARIANTS TOGGLE ======
  bool _useVariants = false;

  // ====== MULTIPLE PRICE (WHOLESALE) ======
  bool _useMultiPrice = false; // new toggle

  // ====== SINGLE SKU (when variants OFF) ======
  final TextEditingController _singleSkuNameC = TextEditingController();
  final TextEditingController _singleSkuPriceC = TextEditingController();

  // ====== DROPDOWNS ======
  String? _selectedBrandId;
  String? _selectedCategoryId;

  // ====== IMAGE PICKER ======
  final ImagePicker _picker = ImagePicker();
  final List<XFile?> _pickedList = List<XFile?>.filled(
    5,
    null,
    growable: false,
  );

  Future<void> _chooseImageFor(int idx) async {
    if (!_slotEnabled(idx)) return;
    final src = await showModalBottomSheet<ImageSource>(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 36,
              height: 4,
              margin: const EdgeInsets.only(top: 8, bottom: 12),
              decoration: BoxDecoration(
                color: const Color(0xFFE5E7EB),
                borderRadius: BorderRadius.circular(99),
              ),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library_outlined),
              title: const Text('Pick from Gallery'),
              onTap: () => Navigator.pop(ctx, ImageSource.gallery),
            ),
            ListTile(
              leading: const Icon(Icons.photo_camera_outlined),
              title: const Text('Take a Photo'),
              onTap: () => Navigator.pop(ctx, ImageSource.camera),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
    if (src == null) return;

    try {
      final picked = await _picker.pickImage(
        source: src,
        maxWidth: 1600,
        maxHeight: 1600,
        imageQuality: 88,
      );
      if (picked != null) setState(() => _pickedList[idx] = picked);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Failed to pick image: $e')));
    }
  }

  void _removeImageAt(int idx) {
    setState(() {
      _pickedList[idx] = null;
      // Optional: compact order so there are no gaps in the middle
      for (int i = 0; i < _pickedList.length - 1; i++) {
        if (_pickedList[i] == null && _pickedList[i + 1] != null) {
          _pickedList[i] = _pickedList[i + 1];
          _pickedList[i + 1] = null;
        }
      }
    });
  }

  bool _slotEnabled(int idx) {
    if (idx == 0) return true;
    return _pickedList[idx - 1] != null; // enabled only if previous slot filled
  }

  bool get _hasAnyImage => _pickedList.any((x) => x != null);

  // ====== DYNAMIC PRICES (for wholesale tiers) ======
  final List<_PriceRow> _prices = [_PriceRow()];

  // Active SKU price (single-SKU or uniform price from Variants). Null if invalid.
  int? get _skuBasePrice {
    if (_useVariants) {
      final st = variantsKey.currentState;
      if (st == null) return null;
      final skus = st
          .buildSkus()
          .where((s) => s.code.trim().isNotEmpty && s.price > 0)
          .toList();
      if (skus.isEmpty) return null;
      // ensure uniform (required to enable multi price)
      final p0 = skus.first.price;
      for (final s in skus) {
        if (s.price != p0) return null;
      }
      return p0;
    } else {
      final p = _toInt(_singleSkuPriceC.text);
      return p > 0 ? p : null;
    }
  }

  // All wholesale tier prices must be filled & strictly less than base SKU price
  bool get _allTierPricesValid {
    if (!_useMultiPrice) return true;
    final base = _skuBasePrice;
    if (base == null) return false; // base SKU price not valid yet
    final filled = _prices.where((e) => e.isFilled).toList();
    if (filled.isEmpty) return false;
    for (final r in filled) {
      final tier = _toInt(r.price.text);
      if (tier >= base) return false;
    }
    return true;
  }

  @override
  void initState() {
    super.initState();
    final prov = context.read<ProductProvider>();
    prov.fetchProductBrands(context);
    prov.fetchProductCategories(context);
  }

  @override
  void dispose() {
    _nameC.dispose();
    _descC.dispose();
    _priceC.dispose();
    _stockC.dispose();
    _singleSkuNameC.dispose();
    _singleSkuPriceC.dispose();
    for (final r in _prices) {
      r.dispose();
    }
    super.dispose();
  }

  // ====== OVERALL VALIDATION ======
  bool get _isValid {
    final baseOk =
        (_formKey.currentState?.validate() ?? false) &&
        _selectedBrandId != null &&
        _selectedCategoryId != null;

    if (!baseOk) return false;

    if (_useMultiPrice && _prices.where((e) => e.isFilled).isEmpty) {
      return false;
    }
    if (_useMultiPrice && !_allTierPricesValid) return false;

    if (_useVariants) {
      final st = variantsKey.currentState;
      if (st == null || !st.hasAtLeastOneRow) return false;
      if (_useMultiPrice && !_variantPricesUniform) return false;
      return true;
    } else {
      final codeOk = _skuNoSpaceValidator(_singleSkuNameC.text) == null;
      final priceOk = _toInt(_singleSkuPriceC.text) > 0;
      return codeOk && priceOk;
    }
  }

  // ====== CHECK: are all variant SKU prices uniform? ======
  bool get _variantPricesUniform {
    final st = variantsKey.currentState;
    if (st == null) return false;
    final skus = st
        .buildSkus()
        .where((s) => s.code.trim().isNotEmpty && s.price > 0)
        .toList();
    if (skus.isEmpty) return false;
    final first = skus.first.price;
    for (final s in skus) {
      if (s.price != first) return false;
    }
    return true;
  }

  // ====== IMAGE SLOT #0 SHORTCUT ======
  Future<void> _chooseImageSource() => _chooseImageFor(0);
  void _removeImage() => _removeImageAt(0);

  // ====== HELPERS ======
  int _toInt(String s) {
    final digits = s.replaceAll('.', '').replaceAll(',', '').trim();
    return int.tryParse(digits) ?? 0;
  }

  static final TextInputFormatter _skuNoSpaceFormatter =
      TextInputFormatter.withFunction((oldValue, newValue) {
        final replaced = newValue.text.replaceAll(RegExp(r'\s+'), '');
        return newValue.copyWith(
          text: replaced,
          selection: TextSelection.collapsed(offset: replaced.length),
        );
      });

  static String? _skuNoSpaceValidator(String? v) {
    final s = (v ?? '').trim();
    if (s.isEmpty) return 'Required';
    if (RegExp(r'\s').hasMatch(s)) return 'No spaces allowed';
    return null;
  }

  // ====== SUBMIT ======
  Future<void> _onSubmit() async {
    try {
      setState(() => _attemptedSubmit = true);

      if (!_formKey.currentState!.validate()) return;
      if (_selectedBrandId == null || _selectedCategoryId == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Please select Brand & Category first.'),
          ),
        );
        return;
      }

      setState(() => _isSubmitting = true);

      final provider = context.read<ProductProvider>();

      // 1) Upload images 0..4 (in order)
      final imagesJson = <Map<String, dynamic>>[];
      for (int i = 0; i < _pickedList.length; i++) {
        final xf = _pickedList[i];
        if (xf == null) break;
        final uploaded = await provider.uploadProductImage(
          context,
          File(xf.path),
        );
        if (uploaded == null) {
          if (!mounted) return;
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(const SnackBar(content: Text('Image upload failed')));
          return;
        }
        imagesJson.add({'image': uploaded, 'position': i + 1});
      }

      // 2) SKUs JSON based on mode
      late final List<Map<String, dynamic>> skusJson;

      if (_useVariants) {
        final st = variantsKey.currentState;
        if (st == null) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Variants section is not ready.')),
          );
          return;
        }
        final skusBuilt = st
            .buildSkus()
            .where((s) => s.code.trim().isNotEmpty && s.price > 0)
            .toList();
        if (skusBuilt.isEmpty) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Fill at least one SKU (name & price).'),
            ),
          );
          return;
        }
        if (_useMultiPrice && !_variantPricesUniform) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'Multiple Price can only be enabled if all SKU prices are identical.',
              ),
            ),
          );
          return;
        }

        skusJson = skusBuilt
            .map(
              (s) => {
                'code': s.code,
                'price': s.price,
                'attributes': s.attributes
                    .map((a) => {'name': a.name, 'value': a.value})
                    .toList(),
              },
            )
            .toList();
      } else {
        final code = _singleSkuNameC.text.trim();
        final price = _toInt(_singleSkuPriceC.text);
        if (code.isEmpty || price <= 0) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Enter a valid SKU Code & Price.')),
          );
          return;
        }
        skusJson = [
          {'code': code, 'price': price, 'attributes': null},
        ];
      }

      // 3) Prices JSON → null when multi price OFF
      final List<Map<String, dynamic>>? pricesJson = _useMultiPrice
          ? _prices
                .where((e) => e.isFilled)
                .map(
                  (e) => {
                    'min_qty': _toInt(e.minQty.text),
                    'price': _toInt(e.price.text),
                  },
                )
                .toList()
          : null;

      // --- PAYLOAD PREVIEW (DEBUG) ---
      final payloadPreview = <String, dynamic>{
        'name': _nameC.text.trim(),
        'description': _descC.text.trim(),
        'product_brand_id': _selectedBrandId!,
        'product_category_id': _selectedCategoryId!,
        'images': imagesJson,
        'skus': skusJson,
        'prices': pricesJson,
      };
      final pretty = const JsonEncoder.withIndent('  ').convert(payloadPreview);
      debugPrint('[ADD_PRODUCT] Payload preview:\n$pretty');

      // 4) Call provider
      final ok = await provider.addProductExactPayload(
        context: context,
        name: _nameC.text.trim(),
        description: _descC.text.trim(),
        productBrandId: _selectedBrandId!,
        productCategoryId: _selectedCategoryId!,
        images: imagesJson,
        skus: skusJson,
        prices: pricesJson,
      );

      if (!mounted) return;
      if (ok) {
        Navigator.of(context).pop();
        AppSnackbar.show(
          context,
          type: AppSnackType.success,
          title: 'Added',
          message: 'Product added successfully.',
        );
      } else {
        AppSnackbar.show(
          context,
          type: AppSnackType.error,
          title: 'Failed',
          message: 'Failed to add product: ${provider.lastError ?? ''}',
        );
      }
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final primary = _resolvePrimary(context);
    final padBottom = MediaQuery.of(context).viewInsets.bottom;
    final base = _skuBasePrice;
    final bool canEnableMultiPriceWhenVariants =
        !_useVariants || (_useVariants && _variantPricesUniform);

    return Padding(
      padding: EdgeInsets.only(bottom: padBottom),
      child: DraggableScrollableSheet(
        initialChildSize: 0.85,
        minChildSize: 0.5,
        maxChildSize: 0.95,
        expand: false,
        builder: (context, controller) {
          return Column(
            mainAxisSize: MainAxisSize.min,
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
              const SizedBox(height: 8),
              Expanded(
                child: SingleChildScrollView(
                  controller: controller,
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
                  child: Form(
                    autovalidateMode: AutovalidateMode.onUserInteraction,
                    key: _formKey,
                    onChanged: () => setState(() {}),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'New Product',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF111827),
                          ),
                        ),
                        const SizedBox(height: 16),

                        // ====== PHOTOS (5 SLOTS) ======
                        const Text(
                          'Product Photo',
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF111827),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: List.generate(5, (i) {
                            final enabled = _slotEnabled(i);
                            final picked = _pickedList[i];
                            return Expanded(
                              child: Padding(
                                padding: EdgeInsets.only(right: i == 4 ? 0 : 8),
                                child: _PhotoSlotBox(
                                  enabled: enabled,
                                  file: picked,
                                  onPick: () => _chooseImageFor(i),
                                  onRemove: () => _removeImageAt(i),
                                ),
                              ),
                            );
                          }),
                        ),
                        const SizedBox(height: 16),

                        // ====== NAME ======
                        const Text(
                          'Product Name',
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF111827),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Field(
                          controller: _nameC,
                          hintText: 'e.g. iPhone 15 Pro +',
                          validator: (v) => (v == null || v.trim().isEmpty)
                              ? 'Required'
                              : null,
                        ),

                        const SizedBox(height: 16),

                        // ====== DESCRIPTION ======
                        const Text(
                          'Description',
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF111827),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Field(
                          controller: _descC,
                          hintText: 'Product description',
                          keyboardType: TextInputType.multiline,
                          validator: (v) => (v == null || v.trim().isEmpty)
                              ? 'Required'
                              : null,
                        ),

                        const SizedBox(height: 16),

                        // ====== BRAND & CATEGORY ======
                        Consumer<ProductProvider>(
                          builder: (context, prov, _) {
                            String? brandError =
                                _attemptedSubmit && _selectedBrandId == null
                                ? 'Required'
                                : null;
                            String? catError =
                                _attemptedSubmit && _selectedCategoryId == null
                                ? 'Required'
                                : null;

                            final selectedBrandName = _selectedBrandId == null
                                ? null
                                : prov.brands
                                      .firstWhere(
                                        (b) =>
                                            b.idProductBrand ==
                                            _selectedBrandId,
                                        orElse: () => prov.brands.isNotEmpty
                                            ? prov.brands.first
                                            : (throw StateError(
                                                'Brand list is empty',
                                              )),
                                      )
                                      .name;

                            final selectedCategoryName =
                                _selectedCategoryId == null
                                ? null
                                : prov.categories
                                      .firstWhere(
                                        (c) =>
                                            c.idProductCategory ==
                                            _selectedCategoryId,
                                        orElse: () => prov.categories.isNotEmpty
                                            ? prov.categories.first
                                            : (throw StateError(
                                                'Category list is empty',
                                              )),
                                      )
                                      .name;

                            return Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                _SelectFieldTile(
                                  label: 'Brand',
                                  placeholder: 'Select a brand',
                                  valueText: selectedBrandName,
                                  errorText: brandError,
                                  onTap: () async {
                                    final picked = await pickBrandId(
                                      context,
                                      selectedId: _selectedBrandId,
                                    );
                                    if (picked != null) {
                                      setState(() => _selectedBrandId = picked);
                                    }
                                  },
                                ),
                                const SizedBox(height: 16),
                                _SelectFieldTile(
                                  label: 'Category',
                                  placeholder: 'Select a category',
                                  valueText: selectedCategoryName,
                                  errorText: catError,
                                  onTap: () async {
                                    final picked = await pickCategoryId(
                                      context,
                                      selectedId: _selectedCategoryId,
                                    );
                                    if (picked != null) {
                                      setState(
                                        () => _selectedCategoryId = picked,
                                      );
                                    }
                                  },
                                ),
                              ],
                            );
                          },
                        ),

                        const SizedBox(height: 16),

                        // ====== USE VARIANTS TOGGLE ======
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF9FAFB),
                            border: Border.all(color: const Color(0xFFE5E7EB)),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Row(
                            children: [
                              const Expanded(
                                child: Text(
                                  'Use Variants',
                                  style: TextStyle(
                                    fontWeight: FontWeight.w700,
                                    color: Color(0xFF111827),
                                  ),
                                ),
                              ),
                              Switch(
                                activeColor: AppColors.primaryDark,
                                value: _useVariants,
                                onChanged: (v) => setState(() {
                                  _useVariants = v;
                                  if (_useVariants && !_variantPricesUniform) {
                                    _useMultiPrice = false;
                                  }
                                }),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 12),

                        // ====== VARIANT CONTENT / SINGLE SKU ======
                        if (_useVariants) ...[
                          VariantsSectionDynamic(key: variantsKey),
                          const SizedBox(height: 16),
                        ] else ...[
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF9FAFB),
                              border: Border.all(
                                color: const Color(0xFFE5E7EB),
                              ),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Single SKU',
                                  style: TextStyle(
                                    fontWeight: FontWeight.w700,
                                    color: Color(0xFF111827),
                                  ),
                                ),
                                const SizedBox(height: 8),
                                TextFormField(
                                  controller: _singleSkuNameC,
                                  inputFormatters: [_skuNoSpaceFormatter],
                                  decoration: const InputDecoration(
                                    isDense: true,
                                    hintText: 'SKU Code (required, no spaces)',
                                    border: OutlineInputBorder(),
                                  ),
                                  validator: _skuNoSpaceValidator,
                                ),
                                const SizedBox(height: 10),
                                TextFormField(
                                  controller: _singleSkuPriceC,
                                  keyboardType: TextInputType.number,
                                  inputFormatters: [
                                    FilteringTextInputFormatter.digitsOnly,
                                  ],
                                  onChanged: (t) {
                                    if (t.isEmpty) return;
                                    final sel = _singleSkuPriceC.selection;
                                    final f = NumberFormat.decimalPattern('id');
                                    final digits = t.replaceAll('.', '');
                                    final newText = f.format(
                                      int.tryParse(digits) ?? 0,
                                    );
                                    _singleSkuPriceC
                                      ..text = newText
                                      ..selection = sel.copyWith(
                                        baseOffset: newText.length,
                                        extentOffset: newText.length,
                                      );
                                  },
                                  decoration: const InputDecoration(
                                    isDense: true,
                                    hintText: 'Price',
                                    border: OutlineInputBorder(),
                                  ),
                                  validator: (v) => (_toInt(v ?? '') > 0)
                                      ? null
                                      : 'Must be > 0',
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 16),
                        ],

                        // ====== MULTIPLE PRICE TOGGLE (+ description) ======
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF9FAFB),
                            border: Border.all(color: const Color(0xFFE5E7EB)),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  const Expanded(
                                    child: Text(
                                      'Multi Price (Wholesale)',
                                      style: TextStyle(
                                        fontWeight: FontWeight.w700,
                                        color: Color(0xFF111827),
                                      ),
                                    ),
                                  ),
                                  Switch(
                                    activeColor: AppColors.primaryDark,
                                    value: _useMultiPrice,
                                    onChanged: canEnableMultiPriceWhenVariants
                                        ? (v) =>
                                              setState(() => _useMultiPrice = v)
                                        : null,
                                  ),
                                ],
                              ),
                              const SizedBox(height: 6),
                              Builder(
                                builder: (_) {
                                  const baseDesc =
                                      'Enable to add several price levels based on minimum quantity (wholesale tiers).';
                                  if (!_useVariants) {
                                    return const Text(
                                      '$baseDesc You can use this even without variants.',
                                      style: TextStyle(
                                        color: Color(0xFF6B7280),
                                      ),
                                    );
                                  }
                                  if (_variantPricesUniform) {
                                    return const Text(
                                      '$baseDesc Allowed because all current SKU prices are identical.',
                                      style: TextStyle(
                                        color: Color(0xFF6B7280),
                                      ),
                                    );
                                  }
                                  return const Text(
                                    'Cannot be enabled: all SKU prices must be identical first.',
                                    style: TextStyle(color: Color(0xFFEF4444)),
                                  );
                                },
                              ),
                              if (_useMultiPrice && base != null) ...[
                                const SizedBox(height: 6),
                                Text(
                                  'Current base SKU price: ${NumberFormat.currency(locale: 'id', symbol: 'Rp. ', decimalDigits: 0).format(base)}. '
                                  'Every wholesale tier price must be STRICTLY LOWER than this value.',
                                  style: const TextStyle(
                                    color: Color(0xFF6B7280),
                                  ),
                                ),
                              ],
                              if (_useMultiPrice &&
                                  !_allTierPricesValid &&
                                  base != null)
                                const Padding(
                                  padding: EdgeInsets.only(top: 6),
                                  child: Text(
                                    'Some wholesale prices are invalid (>= base SKU price).',
                                    style: TextStyle(color: Color(0xFFEF4444)),
                                  ),
                                ),
                            ],
                          ),
                        ),

                        const SizedBox(height: 12),

                        // ====== PRICES (dynamic) — only when Multiple Price ON ======
                        if (_useMultiPrice) ...[
                          const Text(
                            'Prices',
                            style: TextStyle(
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF111827),
                            ),
                          ),
                          const SizedBox(height: 8),
                          ..._prices.asMap().entries.map((entry) {
                            final idx = entry.key;
                            final row = entry.value;
                            return Padding(
                              padding: EdgeInsets.only(
                                bottom: idx == _prices.length - 1 ? 0 : 10,
                              ),
                              child: Row(
                                children: [
                                  Expanded(
                                    child: Field(
                                      controller: row.minQty,
                                      hintText: 'Min Qty',
                                      keyboardType: TextInputType.number,
                                      inputFormatters: [
                                        FilteringTextInputFormatter.digitsOnly,
                                      ],
                                      validator: (v) =>
                                          (_useMultiPrice &&
                                              (v == null || v.trim().isEmpty))
                                          ? 'Required'
                                          : null,
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Field(
                                      controller: row.price,
                                      hintText: 'Price',
                                      keyboardType: TextInputType.number,
                                      inputFormatters: [
                                        FilteringTextInputFormatter.digitsOnly,
                                      ],
                                      validator: (v) {
                                        if (!_useMultiPrice) return null;
                                        if (v == null || v.trim().isEmpty) {
                                          return 'Required';
                                        }
                                        final base = _skuBasePrice;
                                        if (base == null) {
                                          return 'Enter base SKU price first';
                                        }
                                        final tier = _toInt(v);
                                        if (tier <= 0) return 'Must be > 0';
                                        if (tier >= base) {
                                          return 'Must be < base SKU price';
                                        }
                                        return null;
                                      },
                                      onChanged: (t) {
                                        if (t.isEmpty) {
                                          setState(() {});
                                          return;
                                        }
                                        final sel = row.price.selection;
                                        final f = NumberFormat.decimalPattern(
                                          'id',
                                        );
                                        final digits = t.replaceAll('.', '');
                                        final newText = f.format(
                                          int.tryParse(digits) ?? 0,
                                        );
                                        row.price
                                          ..text = newText
                                          ..selection = sel.copyWith(
                                            baseOffset: newText.length,
                                            extentOffset: newText.length,
                                          );
                                        setState(() {}); // refresh error text
                                      },
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  _IconBtn(
                                    icon: idx == _prices.length - 1
                                        ? Icons.add_circle_outline
                                        : Icons.remove_circle_outline,
                                    onTap: () {
                                      setState(() {
                                        if (idx == _prices.length - 1) {
                                          _prices.add(_PriceRow());
                                        } else {
                                          _prices.removeAt(idx).dispose();
                                        }
                                      });
                                    },
                                  ),
                                ],
                              ),
                            );
                          }).toList(),
                          const SizedBox(height: 16),
                        ],

                        const SizedBox(height: 8),
                      ],
                    ),
                  ),
                ),
              ),

              // ====== FOOTER ======
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 40),
                child: SizedBox(
                  height: 48,
                  width: double.infinity,
                  child: _isSubmitting
                      ? Shimmer.fromColors(
                          baseColor: const Color(0xFF9CA3AF), // Gray 400
                          highlightColor: const Color(0xFF6B7280), // Gray 500
                          child: ElevatedButton(
                            onPressed: null, // disabled
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF9CA3AF),
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            child: const Text(
                              'Add new product',
                              style: TextStyle(fontWeight: FontWeight.w600),
                            ),
                          ),
                        )
                      : ElevatedButton(
                          onPressed: _isValid ? _onSubmit : null,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: _isValid
                                ? primary
                                : const Color(0xFFE5E7EB),
                            foregroundColor: _isValid
                                ? Colors.white
                                : const Color(0xFF9CA3AF),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: const Text(
                            'Add new product',
                            style: TextStyle(fontWeight: FontWeight.w600),
                          ),
                        ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Color _resolvePrimary(BuildContext context) {
    final themePrimary = Theme.of(context).colorScheme.primary;
    if (themePrimary != const Color(0xff6200ee)) return themePrimary;
    return const Color(0xFF4C6EF5);
  }
}

/// =========================
/// Reusable Widgets & Helpers (self-contained)
/// =========================

class Field extends StatelessWidget {
  const Field({
    required this.controller,
    this.hintText,
    this.keyboardType,
    this.inputFormatters,
    this.prefix,
    this.validator,
    this.onChanged,
  });

  final TextEditingController controller;
  final String? hintText;
  final TextInputType? keyboardType;
  final List<TextInputFormatter>? inputFormatters;
  final Widget? prefix;
  final String? Function(String?)? validator;
  final ValueChanged<String>? onChanged;

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      onChanged: onChanged,
      keyboardType: keyboardType,
      inputFormatters: inputFormatters,
      validator: validator,
      decoration: InputDecoration(
        isDense: true,
        hintText: hintText,
        filled: true,
        fillColor: const Color(0xFFF3F4F6),
        prefixIconConstraints: const BoxConstraints(minWidth: 0, minHeight: 0),
        prefixIcon: prefix,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 14,
          vertical: 14,
        ),
        enabledBorder: OutlineInputBorder(
          borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
          borderRadius: BorderRadius.circular(10),
        ),
        focusedBorder: OutlineInputBorder(
          borderSide: const BorderSide(color: Color(0xFFCBD5E1)),
          borderRadius: BorderRadius.circular(10),
        ),
      ),
    );
  }
}

class _IconBtn extends StatelessWidget {
  const _IconBtn({required this.icon, required this.onTap});
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkResponse(
      onTap: onTap,
      child: Icon(icon, color: const Color(0xFF4B5563)),
    );
  }
}

class _PriceRow {
  final TextEditingController minQty = TextEditingController();
  final TextEditingController price = TextEditingController();
  bool get isFilled =>
      minQty.text.trim().isNotEmpty && price.text.trim().isNotEmpty;
  void dispose() {
    minQty.dispose();
    price.dispose();
  }
}

class _PhotoSlotBox extends StatelessWidget {
  const _PhotoSlotBox({
    required this.enabled,
    required this.file,
    required this.onPick,
    required this.onRemove,
  });

  final bool enabled;
  final XFile? file;
  final VoidCallback onPick;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final borderColor = enabled
        ? const Color(0xFF4C6EF5)
        : const Color(0xFFE5E7EB);

    return InkWell(
      onTap: enabled ? onPick : null,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        height: 72,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: borderColor, width: 2),
        ),
        clipBehavior: Clip.antiAlias,
        child: Stack(
          fit: StackFit.expand,
          children: [
            if (file == null)
              Center(
                child: Icon(
                  Icons.add_photo_alternate_rounded,
                  size: 22,
                  color: enabled
                      ? const Color(0xFF4C6EF5)
                      : const Color(0xFF9CA3AF),
                ),
              )
            else
              Image.file(
                File(file!.path),
                fit: BoxFit.cover,
                errorBuilder: (c, e, s) => const _ImageErrorPlaceholder(),
              ),
            if (file != null)
              Positioned(
                top: 6,
                right: 6,
                child: InkWell(
                  onTap: onRemove,
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: Colors.black54,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(
                      Icons.close_rounded,
                      size: 14,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
            if (!enabled) Container(color: Colors.white.withOpacity(0.55)),
          ],
        ),
      ),
    );
  }
}

class _ImageErrorPlaceholder extends StatelessWidget {
  const _ImageErrorPlaceholder();
  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Icon(
        Icons.broken_image_rounded,
        size: 32,
        color: Color(0xFF9CA3AF),
      ),
    );
  }
}

class _SelectFieldTile extends StatelessWidget {
  const _SelectFieldTile({
    required this.label,
    required this.placeholder,
    required this.valueText,
    required this.onTap,
    this.errorText,
  });

  final String label;
  final String placeholder;
  final String? valueText;
  final VoidCallback onTap;
  final String? errorText;

  @override
  Widget build(BuildContext context) {
    final hasValue = valueText != null && valueText!.isNotEmpty;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontWeight: FontWeight.w600,
            color: Color(0xFF111827),
          ),
        ),
        const SizedBox(height: 8),
        InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(10),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
            decoration: BoxDecoration(
              color: const Color(0xFFF3F4F6),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: errorText == null
                    ? const Color(0xFFE5E7EB)
                    : const Color(0xFFEF4444),
              ),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    hasValue ? valueText! : placeholder,
                    style: TextStyle(
                      color: hasValue
                          ? const Color(0xFF111827)
                          : const Color(0xFF9CA3AF),
                      fontWeight: hasValue ? FontWeight.w600 : FontWeight.w400,
                    ),
                  ),
                ),
                const Icon(Icons.expand_more, color: Color(0xFF6B7280)),
              ],
            ),
          ),
        ),
        if (errorText != null) ...[
          const SizedBox(height: 6),
          Text(
            errorText!,
            style: const TextStyle(color: Color(0xFFEF4444), fontSize: 12),
          ),
        ],
      ],
    );
  }
}

/// =========== Picker + Creatable ===========
class PickerOption {
  final String id;
  final String label;
  final String? subtitle;
  PickerOption({required this.id, required this.label, this.subtitle});
}

Future<String?> pickBrandId(BuildContext context, {String? selectedId}) async {
  final prov = context.read<ProductProvider>();
  final opts = prov.brands
      .map((b) => PickerOption(id: b.idProductBrand, label: b.name))
      .toList();

  return showListPicker(
    context: context,
    title: 'Choose Brand',
    options: opts,
    selectedId: selectedId,
    enableCreate: true,
    createRowLabel: (kw) => '"$kw" doesn\'t exist — add new brand',
    onCreate: (kw) async {
      final created = await prov.createBrandNoFetch(context, kw);
      if (created == null) return null;
      return PickerOption(id: created.idProductBrand, label: created.name);
    },
  );
}

Future<String?> pickCategoryId(
  BuildContext context, {
  String? selectedId,
}) async {
  final prov = context.read<ProductProvider>();
  final opts = prov.categories
      .map((c) => PickerOption(id: c.idProductCategory, label: c.name))
      .toList();

  return showListPicker(
    context: context,
    title: 'Choose Category',
    options: opts,
    selectedId: selectedId,
    enableCreate: true,
    createRowLabel: (kw) => '"$kw" doesn\'t exist — add new category',
    onCreate: (kw) async {
      final created = await prov.createCategoryNoFetch(context, kw);
      if (created == null) return null;
      return PickerOption(id: created.idProductCategory, label: created.name);
    },
  );
}

Future<String?> showListPicker({
  required BuildContext context,
  required String title,
  required List<PickerOption> options,
  String? selectedId,
  bool enableCreate = false,
  String Function(String keyword)? createRowLabel,
  Future<PickerOption?> Function(String keyword)? onCreate,
}) async {
  final controller = TextEditingController();
  List<PickerOption> filtered = List.of(options);
  String lastQuery = '';

  bool containsLabel(String q) {
    final low = q.toLowerCase();
    return filtered.any((o) => o.label.toLowerCase() == low);
  }

  return showModalBottomSheet<String>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.white,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (ctx) {
      return SafeArea(
        top: false,
        child: DraggableScrollableSheet(
          expand: false,
          initialChildSize: 0.85,
          minChildSize: 0.5,
          maxChildSize: 0.95,
          builder: (_, sheetCtrl) {
            return StatefulBuilder(
              builder: (context, setState) {
                void _doFilter(String q) {
                  final query = q.trim().toLowerCase();
                  lastQuery = q.trim();
                  setState(() {
                    filtered = options
                        .where(
                          (o) =>
                              o.label.toLowerCase().contains(query) ||
                              (o.subtitle ?? '').toLowerCase().contains(query),
                        )
                        .toList();
                  });
                }

                final canShowCreate =
                    enableCreate &&
                    lastQuery.isNotEmpty &&
                    !containsLabel(lastQuery) &&
                    onCreate != null;

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
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              title,
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w700,
                                color: Color(0xFF111827),
                              ),
                            ),
                          ),
                          TextButton(
                            onPressed: () => Navigator.pop(ctx),
                            child: const Text('Close'),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 8),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: TextField(
                        controller: controller,
                        onChanged: _doFilter,
                        decoration: InputDecoration(
                          hintText: 'Search…',
                          isDense: true,
                          filled: true,
                          fillColor: const Color(0xFFF3F4F6),
                          prefixIcon: const Icon(Icons.search, size: 20),
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 12,
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderSide: const BorderSide(
                              color: Color(0xFFE5E7EB),
                            ),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderSide: const BorderSide(
                              color: Color(0xFFCBD5E1),
                            ),
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Divider(height: 1, color: Color(0xFFE5E7EB)),
                    if (canShowCreate)
                      Material(
                        color: Colors.transparent,
                        child: ListTile(
                          onTap: () async {
                            final created = await onCreate!(lastQuery);
                            if (created != null) {
                              setState(() {
                                options.add(created);
                                filtered.insert(0, created);
                                selectedId = created.id;
                              });
                              // ignore: use_build_context_synchronously
                              Navigator.pop(ctx, created.id);
                            }
                          },
                          leading: const Icon(
                            Icons.add_circle_outline,
                            color: Color(0xFF4C6EF5),
                          ),
                          title: Text(
                            createRowLabel?.call(lastQuery) ??
                                '"$lastQuery" not found — + Add New',
                            style: const TextStyle(
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF111827),
                            ),
                          ),
                        ),
                      ),
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
                                fontWeight: FontWeight.w600,
                                color: Color(0xFF111827),
                              ),
                            ),
                            subtitle: (o.subtitle?.isNotEmpty ?? false)
                                ? Text(o.subtitle!)
                                : null,
                            trailing: isSel
                                ? const Icon(
                                    Icons.check_circle,
                                    color: Color(0xFF4C6EF5),
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
        ),
      );
    },
  );
}
