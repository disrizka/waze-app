// lib/screens/add_product_screen.dart
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shimmer/shimmer.dart';
import 'package:lucide_icons/lucide_icons.dart';

import 'package:wa_blast/constants/app_colors.dart';
import 'package:wa_blast/providers/product_provider.dart';
import 'package:wa_blast/providers/store_provider.dart';
import 'package:wa_blast/widgets/app_snackbar.dart';
import 'package:wa_blast/widgets/variant_section_dynamic.dart';

final GlobalKey<VariantsSectionDynamicState> variantsKey =
    GlobalKey<VariantsSectionDynamicState>();

class AddProductScreen extends StatefulWidget {
  const AddProductScreen({super.key});

  @override
  State<AddProductScreen> createState() => _AddProductScreenState();
}

class _AddProductScreenState extends State<AddProductScreen> {
  bool _isSubmitting = false;

  final _formKey = GlobalKey<FormState>();
  final _nameC = TextEditingController();
  final _descC = TextEditingController();
  final _priceC = TextEditingController(); // kompat
  final _stockC = TextEditingController(); // kompat

  bool _available = true;
  bool _attemptedSubmit = false;

  bool _useVariants = false;
  bool _useMultiPrice = false;

  final TextEditingController _singleSkuNameC = TextEditingController();
  final TextEditingController _singleSkuPriceC = TextEditingController();

  String? _selectedBrandId;
  String? _selectedCategoryId;

  final ImagePicker _picker = ImagePicker();
  final List<XFile?> _pickedList = List<XFile?>.filled(
    5,
    null,
    growable: false,
  );

  final List<_PriceRow> _prices = [_PriceRow()];

  // =========================
  // ✅ PREMIUM STATUS (NEW)
  // =========================
  bool _loadingPremium = true;
  bool _isPremiumBiz = false;

  Future<void> _loadPremiumStatus() async {
    try {
      final prefs = await SharedPreferences.getInstance();

      // 1) cepat: baca cache bool
      final cached = prefs.getBool('activeBizIsPremium');
      if (cached != null) {
        if (!mounted) return;
        setState(() {
          _isPremiumBiz = cached;
          _loadingPremium = false;
        });
        return;
      }

      // 2) fallback: baca business json + activeBizId
      final activeId = (prefs.getString('activeBizId') ?? '').trim();
      final raw = prefs.getString('business');

      bool isPremium = false;
      if (raw != null && raw.isNotEmpty) {
        try {
          final list = (jsonDecode(raw) as List).cast<Map<String, dynamic>>();
          Map<String, dynamic>? match;
          if (activeId.isNotEmpty) {
            match = list.firstWhere(
              (e) => (e['idBusiness'] ?? '').toString() == activeId,
              orElse: () => <String, dynamic>{},
            );
          }
          if (match != null && match.isNotEmpty) {
            isPremium = (match['isPremium'] ?? false) == true;
          }
        } catch (_) {}
      }

      await prefs.setBool('activeBizIsPremium', isPremium);

      if (!mounted) return;
      setState(() {
        _isPremiumBiz = isPremium;
        _loadingPremium = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _loadingPremium = false);
    }
  }

  // =========================
  // ✅ MODAL MULTI PRICE LOCKED (NEW)
  // =========================
  Future<void> _showMultiPriceLockedModal(BuildContext context) async {
    await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black.withOpacity(0.35),
      builder: (ctx) {
        final size = MediaQuery.of(ctx).size;
        final bool isTablet = size.shortestSide >= 600;
        final double maxWidth = isTablet ? 420 : size.width;

        return SafeArea(
          child: Center(
            child: Container(
              constraints: BoxConstraints(maxWidth: maxWidth),
              margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              padding: const EdgeInsets.fromLTRB(20, 18, 20, 24),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(24),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.16),
                    blurRadius: 24,
                    offset: const Offset(0, 16),
                  ),
                ],
              ),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 8),
                    Row(
                      children: const [
                        CircleAvatar(
                          radius: 18,
                          backgroundColor: Color(0xFFE0ECFF),
                          child: Icon(
                            LucideIcons.gem,
                            size: 18,
                            color: Color(0xFF4C6EF5),
                          ),
                        ),
                        SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            'Premium Multi Price',
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.w800,
                              color: Color(0xFF0F172A),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    const Text(
                      'Unlock wholesale pricing tiers so you can set different prices based on minimum quantity.',
                      style: TextStyle(
                        fontSize: 13,
                        height: 1.4,
                        color: Color(0xFF6B7280),
                      ),
                    ),
                    const SizedBox(height: 18),

                    // ✅ CAROUSEL (Swipe)
                    const _PremiumFeatureCarousel(
                      items: [
                        _PremiumFeatureItem(
                          icon: LucideIcons.layers,
                          title: 'Wholesale tiers',
                          description:
                              'Add multiple price levels based on minimum quantity.',
                        ),
                        _PremiumFeatureItem(
                          icon: LucideIcons.badgePercent,
                          title: 'Smarter pricing',
                          description:
                              'Give better prices for bigger orders without manual edits.',
                        ),
                        _PremiumFeatureItem(
                          icon: LucideIcons.shoppingCart,
                          title: 'Sell more',
                          description:
                              'Encourage customers to buy in bulk with clear tiered pricing.',
                        ),
                        _PremiumFeatureItem(
                          icon: LucideIcons.shieldCheck,
                          title: 'Consistent rules',
                          description:
                              'Keep pricing structured and avoid mistakes during checkout.',
                        ),
                      ],
                    ),

                    const SizedBox(height: 22),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF4C6EF5),
                          elevation: 0,
                          padding: const EdgeInsets.symmetric(vertical: 13),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                        onPressed: () {
                          Navigator.of(ctx).pop(true);
                          Navigator.pushNamed(ctx, '/subscription');
                        },
                        child: const Text(
                          'Upgrade to Premium',
                          style: TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 14,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    SizedBox(
                      width: double.infinity,
                      child: TextButton(
                        onPressed: () => Navigator.of(ctx).pop(false),
                        child: const Text(
                          'Maybe later',
                          style: TextStyle(
                            fontSize: 13,
                            color: Color(0xFF6B7280),
                          ),
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
    );
  }

  Future<bool> _ensureCameraPermission() async {
    try {
      final st = await Permission.camera.status;
      if (st.isGranted) return true;
      if (st.isPermanentlyDenied) {
        if (!mounted) return false;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Camera permission is permanently denied. Please enable it in Settings.',
            ),
          ),
        );
        return false;
      }
      final req = await Permission.camera.request();
      return req.isGranted;
    } catch (_) {
      return false;
    }
  }

  Future<XFile?> _pickOne(ImageSource src) async {
    if (src == ImageSource.camera) {
      final ok = await _ensureCameraPermission();
      if (!ok) return null;
    }
    return await _picker.pickImage(
      source: src,
      maxWidth: 1600,
      maxHeight: 1600,
      imageQuality: 88,
      preferredCameraDevice: CameraDevice.rear,
    );
  }

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
              subtitle: const Text('Android uses Photo Picker (no permission)'),
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
      final picked = await _pickOne(src);
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
    return _pickedList[idx - 1] != null;
  }

  int _toInt(String s) {
    final digits = s.replaceAll('.', '').replaceAll(',', '').trim();
    return int.tryParse(digits) ?? 0;
  }

  int? get _skuBasePrice {
    if (_useVariants) {
      final st = variantsKey.currentState;
      if (st == null) return null;
      final skus = st
          .buildSkus()
          .where((s) => s.code.trim().isNotEmpty && s.price > 0)
          .toList();
      if (skus.isEmpty) return null;
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

  bool get _allTierPricesValid {
    if (!_useMultiPrice) return true;
    final base = _skuBasePrice;
    if (base == null) return false;
    final filled = _prices.where((e) => e.isFilled).toList();
    if (filled.isEmpty) return false;
    for (final r in filled) {
      final tier = _toInt(r.price.text);
      if (tier >= base) return false;
    }
    return true;
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
    if (s.isEmpty) return null;
    if (RegExp(r'\s').hasMatch(s)) return 'No spaces allowed';
    return null;
  }

  @override
  void initState() {
    super.initState();

    // ✅ penting: load premium saat screen dibuka
    Future.microtask(_loadPremiumStatus);

    final prov = context.read<ProductProvider>();
    prov.fetchProductBrands(context);
    prov.fetchProductCategories(context);

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await prov.ensureDefaultStoreLocation(context);
      if (!mounted) return;
      final sp = context.read<StoreProvider>();
      if (sp.stores.isEmpty && !sp.loadingList) {
        await sp.fetchStoreLocations(context);
      }
    });
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

  bool get _isValid {
    final baseOk = (_formKey.currentState?.validate() ?? false);
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

  Future<void> _onSubmit() async {
    try {
      setState(() => _attemptedSubmit = true);
      if (!_formKey.currentState!.validate()) return;

      setState(() => _isSubmitting = true);
      final provider = context.read<ProductProvider>();

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
                'code': s.code.isEmpty ? null : s.code,
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
        if (price <= 0) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Enter a valid SKU Price.')),
          );
          return;
        }
        skusJson = [
          {
            'code': code.isEmpty ? null : code,
            'price': price,
            'attributes': null,
          },
        ];
      }

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

      final desc = _descC.text.trim();
      final brandId = _selectedBrandId;
      final categoryId = _selectedCategoryId;

      final ok = await provider.addProductExactPayload(
        context: context,
        name: _nameC.text.trim(),
        description: desc.isEmpty ? null : desc,
        productBrandId: brandId,
        productCategoryId: categoryId,
        images: imagesJson,
        skus: skusJson,
        prices: pricesJson,
      );

      if (!mounted) return;
      if (ok) {
        AppSnackbar.show(
          context,
          type: AppSnackType.success,
          title: 'Added',
          message: 'Product added successfully.',
        );
        Navigator.of(context).pop(true);
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
    final mq = MediaQuery.of(context);
    final padBottom = mq.viewInsets.bottom;
    final base = _skuBasePrice;

    final bool canEnableMultiPriceWhenVariants =
        !_useVariants || (_useVariants && _variantPricesUniform);

    final baseLabel = (base == null)
        ? ''
        : 'Current base SKU price: ${NumberFormat.currency(locale: 'id', symbol: 'Rp. ', decimalDigits: 0).format(base)}. '
              'Every wholesale tier price must be STRICTLY LOWER than this value.';

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text('Add Product'),
        centerTitle: false,
        elevation: 0,
        backgroundColor: Colors.white,
        foregroundColor: const Color(0xFF111827),
      ),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1100),
            child: SingleChildScrollView(
              padding: EdgeInsets.fromLTRB(20, 12, 20, 20 + padBottom),
              child: Form(
                autovalidateMode: AutovalidateMode.onUserInteraction,
                key: _formKey,
                onChanged: () => setState(() {}),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Photos
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
                            padding: const EdgeInsets.symmetric(horizontal: 4),
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

                    // Name
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
                      keyboardType: TextInputType.text,
                      inputFormatters: const [FirstUppercaseFormatter()],
                      validator: (v) =>
                          (v == null || v.trim().isEmpty) ? 'Required' : null,
                    ),

                    const SizedBox(height: 16),

                    // Description
                    const Text(
                      'Description',
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF111827),
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextFormField(
                      controller: _descC,
                      keyboardType: TextInputType.multiline,
                      maxLines: null,
                      inputFormatters: const [FirstUppercaseFormatter()],
                      decoration: InputDecoration(
                        isDense: true,
                        hintText: 'Product description',
                        filled: true,
                        fillColor: const Color(0xFFF3F4F6),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 14,
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

                    const SizedBox(height: 12),

                    // SKU PRICE under Description (only when variants OFF)
                    if (!_useVariants) ...[
                      const Text(
                        'SKU Price',
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF111827),
                        ),
                      ),
                      const SizedBox(height: 8),
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
                          final newText = f.format(int.tryParse(digits) ?? 0);
                          _singleSkuPriceC
                            ..text = newText
                            ..selection = sel.copyWith(
                              baseOffset: newText.length,
                              extentOffset: newText.length,
                            );
                          setState(() {});
                        },
                        decoration: const InputDecoration(
                          isDense: true,
                          hintText: 'Price',
                          border: OutlineInputBorder(),
                        ),
                        validator: (v) =>
                            (_toInt(v ?? '') > 0) ? null : 'Must be > 0',
                      ),
                      const SizedBox(height: 16),
                    ],

                    // Brand & Category
                    Consumer<ProductProvider>(
                      builder: (context, prov, _) {
                        final selectedBrandName = _selectedBrandId == null
                            ? null
                            : prov.brands
                                  .firstWhere(
                                    (b) => b.idProductBrand == _selectedBrandId,
                                    orElse: () => prov.brands.isNotEmpty
                                        ? prov.brands.first
                                        : (throw StateError(
                                            'Brand list is empty',
                                          )),
                                  )
                                  .name;

                        final selectedCategoryName = _selectedCategoryId == null
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
                              onTap: () async {
                                final picked = await pickCategoryId(
                                  context,
                                  selectedId: _selectedCategoryId,
                                );
                                if (picked != null) {
                                  setState(() => _selectedCategoryId = picked);
                                }
                              },
                            ),
                          ],
                        );
                      },
                    ),
                    const SizedBox(height: 16),

                    // Use Variants toggle
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

                              if (_useVariants) {
                                if (_singleSkuNameC.text.isNotEmpty ||
                                    _singleSkuPriceC.text.isNotEmpty) {
                                  _singleSkuNameC.clear();
                                  _singleSkuPriceC.clear();
                                }
                              }

                              if (_useVariants && !_variantPricesUniform) {
                                _useMultiPrice = false;
                              }
                            }),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),

                    if (_useVariants) ...[
                      VariantsSectionDynamic(key: variantsKey),
                      const SizedBox(height: 16),
                    ] else ...[
                      // Single SKU block (SKU Code only)
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const SizedBox(height: 10),
                          const Text(
                            'SKU Code',
                            style: TextStyle(
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF111827),
                            ),
                          ),
                          const SizedBox(height: 6),
                          TextFormField(
                            controller: _singleSkuNameC,
                            inputFormatters: [_skuNoSpaceFormatter],
                            decoration: const InputDecoration(
                              isDense: true,
                              hintText: 'SKU Code (optional, no spaces)',
                              border: OutlineInputBorder(),
                            ),
                            validator: _skuNoSpaceValidator,
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                    ],

                    // ==========================================================
                    // ✅ MULTI PRICE TOGGLE (PREMIUM GATED) - UPDATED FULL
                    // ==========================================================
                    // Multi Price toggle
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
                              // ✅ Title + badge di kiri
                              Expanded(
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Flexible(
                                      child: Text(
                                        'Multi Price (Wholesale)',
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: TextStyle(
                                          fontWeight: FontWeight.w700,
                                          color: Color(0xFF111827),
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 8),

                                    // ✅ Badge premium nempel di samping title
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 8,
                                        vertical: 4,
                                      ),
                                      decoration: BoxDecoration(
                                        gradient: const LinearGradient(
                                          begin: Alignment.centerLeft,
                                          end: Alignment.centerRight,
                                          colors: [
                                            Color(0xFF6366F1),
                                            Color(0xFF22C55E),
                                          ],
                                        ),
                                        borderRadius: BorderRadius.circular(
                                          999,
                                        ),
                                        boxShadow: [
                                          BoxShadow(
                                            color: Colors.black.withOpacity(
                                              0.16,
                                            ),
                                            blurRadius: 4,
                                            offset: const Offset(0, 2),
                                          ),
                                        ],
                                      ),
                                      child: const Icon(
                                        LucideIcons.gem,
                                        size: 12,
                                        color: Colors.white,
                                      ),
                                    ),
                                  ],
                                ),
                              ),

                              // ✅ Switch tetap kanan
                              Switch(
                                activeColor: AppColors.primaryDark,
                                value: _useMultiPrice,
                                onChanged: (v) async {
                                  if (!_isPremiumBiz) {
                                    await _showMultiPriceLockedModal(context);
                                    return;
                                  }
                                  if (!canEnableMultiPriceWhenVariants) return;
                                  setState(() => _useMultiPrice = v);
                                },
                              ),
                            ],
                          ),

                          const SizedBox(height: 6),

                          // ✅ Deskripsi JANGAN DIHAPUS
                          Builder(
                            builder: (_) {
                              const baseDesc =
                                  'Enable to add several price levels based on minimum quantity (wholesale tiers).';
                              if (!_useVariants) {
                                return const Text(
                                  '$baseDesc You can use this even without variants.',
                                  style: TextStyle(color: Color(0xFF6B7280)),
                                );
                              }
                              if (_variantPricesUniform) {
                                return const Text(
                                  '$baseDesc Allowed because all current SKU prices are identical.',
                                  style: TextStyle(color: Color(0xFF6B7280)),
                                );
                              }
                              return const Text(
                                'Cannot be enabled: all SKU prices must be identical first.',
                                style: TextStyle(color: Color(0xFFEF4444)),
                              );
                            },
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 12),

                    // Prices section
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
                                    final f = NumberFormat.decimalPattern('id');
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
                                    setState(() {});
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
                  ],
                ),
              ),
            ),
          ),
        ),
      ),

      // Footer
      bottomNavigationBar: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
          child: SizedBox(
            height: 48,
            width: double.infinity,
            child: _isSubmitting
                ? Shimmer.fromColors(
                    baseColor: const Color(0xFF9CA3AF),
                    highlightColor: const Color(0xFF6B7280),
                    child: ElevatedButton(
                      onPressed: null,
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
                          ? AppColors.primary
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
      ),
    );
  }
}

// ==========================================================
// ✅ SMALL WIDGETS (NEW) — badge + switch proxy
// ==========================================================

class _PremiumGemBadge extends StatelessWidget {
  const _PremiumGemBadge({required this.enabled, required this.onTap});

  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    // kalau premium → tampil badge kecil “gem”
    // kalau non-premium → tetap tampil, dan tap membuka modal upgrade
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(999),
        onTap: enabled ? null : onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            gradient: enabled
                ? const LinearGradient(
                    begin: Alignment.centerLeft,
                    end: Alignment.centerRight,
                    colors: [Color(0xFF4C6EF5), Color(0xFF22C55E)],
                  )
                : const LinearGradient(
                    begin: Alignment.centerLeft,
                    end: Alignment.centerRight,
                    colors: [Color(0xFF6366F1), Color(0xFF22C55E)],
                  ),
            borderRadius: BorderRadius.circular(999),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.10),
                blurRadius: 6,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: const Icon(LucideIcons.gem, size: 12, color: Colors.white),
        ),
      ),
    );
  }
}

class _SwitchTapProxy extends StatelessWidget {
  const _SwitchTapProxy({
    required this.value,
    required this.enabled,
    required this.onTap,
    required this.activeColor,
  });

  final bool value;
  final bool enabled;
  final VoidCallback onTap;
  final Color activeColor;

  @override
  Widget build(BuildContext context) {
    // Switch disabled biasanya tidak bisa dipakai untuk trigger modal.
    // Jadi: kita tampilkan switch (enabled/disabled) + lapisi tap handler.
    return Stack(
      alignment: Alignment.centerRight,
      children: [
        IgnorePointer(
          ignoring: true, // biar tidak toggle sendiri
          child: Opacity(
            opacity: enabled ? 1.0 : 0.55,
            child: Switch(
              activeColor: activeColor,
              value: enabled ? value : false,
              onChanged: (_) {},
            ),
          ),
        ),
        Positioned.fill(
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: BorderRadius.circular(999),
              onTap: onTap,
            ),
          ),
        ),
      ],
    );
  }
}

// ==========================================================
// ✅ MODAL CAROUSEL (NEW) — same feel as HomeScreen
// ==========================================================

class _PremiumFeatureItem {
  final IconData icon;
  final String title;
  final String description;

  const _PremiumFeatureItem({
    required this.icon,
    required this.title,
    required this.description,
  });
}

class _PremiumFeatureCard extends StatelessWidget {
  final _PremiumFeatureItem item;
  final double scale;
  final double opacity;

  const _PremiumFeatureCard({
    required this.item,
    required this.scale,
    required this.opacity,
  });

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: opacity,
      child: Transform.scale(
        scale: scale,
        child: Container(
          margin: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(24),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.10),
                blurRadius: 18,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(18, 18, 18, 20),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 52,
                  height: 52,
                  decoration: BoxDecoration(
                    color: const Color(0xFFE0ECFF),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Icon(
                    item.icon,
                    size: 26,
                    color: const Color(0xFF4C6EF5),
                  ),
                ),
                const SizedBox(height: 14),
                Text(
                  item.title,
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF111827),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  item.description,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 12,
                    height: 1.35,
                    color: Color(0xFF4B5563),
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

class _PremiumFeatureCarousel extends StatefulWidget {
  final List<_PremiumFeatureItem> items;

  const _PremiumFeatureCarousel({required this.items});

  @override
  State<_PremiumFeatureCarousel> createState() =>
      _PremiumFeatureCarouselState();
}

class _PremiumFeatureCarouselState extends State<_PremiumFeatureCarousel> {
  late final PageController _controller;
  double _currentPage = 0.0;

  @override
  void initState() {
    super.initState();
    _controller = PageController(viewportFraction: 0.72);
    _controller.addListener(() {
      if (!mounted) return;
      setState(() => _currentPage = _controller.page ?? 0.0);
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.items.isEmpty) return const SizedBox.shrink();

    final int currentIndex = _currentPage.round().clamp(
      0,
      widget.items.length - 1,
    );

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          height: 240,
          child: PageView.builder(
            controller: _controller,
            itemCount: widget.items.length,
            physics: const BouncingScrollPhysics(),
            itemBuilder: (context, index) {
              final item = widget.items[index];
              final double distance = (index - _currentPage).abs();
              final double scale = (1 - (distance * 0.14)).clamp(0.86, 1.0);
              final double opacity = (1 - (distance * 0.35)).clamp(0.55, 1.0);

              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: _PremiumFeatureCard(
                  item: item,
                  scale: scale,
                  opacity: opacity,
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 12),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(widget.items.length, (i) {
            final bool active = i == currentIndex;
            return AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              margin: const EdgeInsets.symmetric(horizontal: 3),
              width: active ? 16 : 6,
              height: 6,
              decoration: BoxDecoration(
                color: active
                    ? const Color(0xFF4C6EF5)
                    : const Color(0xFFD1D5DB),
                borderRadius: BorderRadius.circular(99),
              ),
            );
          }),
        ),
        const SizedBox(height: 4),
        const Text(
          'Swipe to see more features',
          style: TextStyle(fontSize: 11, color: Color(0xFF9CA3AF)),
        ),
      ],
    );
  }
}

// ==========================================================
// ORIGINAL HELPERS (unchanged from your snippet)
// ==========================================================

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

    return AspectRatio(
      aspectRatio: 1,
      child: InkWell(
        onTap: enabled ? onPick : null,
        borderRadius: BorderRadius.circular(12),
        child: Container(
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
                    size: 26,
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
    backgroundColor: Colors.transparent,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (ctx) {
      final viewInsets = MediaQuery.of(ctx).viewInsets.bottom;

      return Padding(
        padding: EdgeInsets.only(bottom: viewInsets),
        child: Align(
          alignment: Alignment.bottomCenter,
          child: FractionallySizedBox(
            widthFactor: MediaQuery.of(ctx).size.width < 600 ? 1.0 : 0.96,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 1100, maxHeight: 720),
              child: Material(
                color: Colors.white,
                borderRadius: const RoundedRectangleBorder(
                  borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
                ).borderRadius,
                clipBehavior: Clip.antiAlias,
                child: SafeArea(
                  top: false,
                  child: DraggableScrollableSheet(
                    initialChildSize: 0.60,
                    minChildSize: 0.40,
                    maxChildSize: 0.86,
                    expand: false,
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
                                        (o.subtitle ?? '')
                                            .toLowerCase()
                                            .contains(query),
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
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 20,
                                ),
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
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 20,
                                ),
                                child: TextField(
                                  controller: controller,
                                  onChanged: _doFilter,
                                  decoration: InputDecoration(
                                    hintText: 'Search…',
                                    isDense: true,
                                    filled: true,
                                    fillColor: const Color(0xFFF3F4F6),
                                    prefixIcon: const Icon(
                                      Icons.search,
                                      size: 20,
                                    ),
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
                              const Divider(
                                height: 1,
                                color: Color(0xFFE5E7EB),
                              ),
                              if (canShowCreate)
                                Material(
                                  color: Colors.transparent,
                                  child: ListTile(
                                    onTap: () async {
                                      final created = await onCreate!(
                                        lastQuery,
                                      );
                                      if (created != null) {
                                        setState(() {
                                          options.add(created);
                                          filtered.insert(0, created);
                                          selectedId = created.id;
                                        });
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
                                  padding: const EdgeInsets.fromLTRB(
                                    8,
                                    8,
                                    8,
                                    16,
                                  ),
                                  itemCount: filtered.length,
                                  separatorBuilder: (_, __) => const Divider(
                                    height: 1,
                                    color: Color(0xFFF3F4F6),
                                  ),
                                  itemBuilder: (_, i) {
                                    final o = filtered[i];
                                    final isSel = o.id == selectedId;
                                    return ListTile(
                                      onTap: () => Navigator.pop(ctx, o.id),
                                      leading: Radio<String>(
                                        value: o.id,
                                        groupValue: selectedId,
                                        onChanged: (_) =>
                                            Navigator.pop(ctx, o.id),
                                      ),
                                      title: Text(
                                        o.label,
                                        style: const TextStyle(
                                          fontWeight: FontWeight.w600,
                                          color: Color(0xFF111827),
                                        ),
                                      ),
                                      subtitle:
                                          (o.subtitle?.isNotEmpty ?? false)
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
                ),
              ),
            ),
          ),
        ),
      );
    },
  );
}

class FirstUppercaseFormatter extends TextInputFormatter {
  const FirstUppercaseFormatter();

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final text = newValue.text;
    if (text.isEmpty) return newValue;

    final first = text.characters.first;
    final shouldCap =
        first.toLowerCase() == first && RegExp(r'[a-zA-Z]').hasMatch(first);
    if (!shouldCap) return newValue;

    final capped = first.toUpperCase() + text.characters.skip(1).toString();
    final newOffset = newValue.selection.baseOffset;
    return newValue.copyWith(
      text: capped,
      selection: TextSelection.collapsed(
        offset: newOffset.clamp(0, capped.length),
      ),
    );
  }
}
