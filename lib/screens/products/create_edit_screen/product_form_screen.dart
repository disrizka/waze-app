// lib/screens/product_form_screen.dart
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shimmer/shimmer.dart';

import 'package:wa_blast/constants/app_colors.dart';
import 'package:wa_blast/providers/product_provider.dart';
import 'package:wa_blast/providers/store_provider.dart';
import 'package:wa_blast/widgets/app_snackbar.dart';

// ✅ NEW: import VariantsEditorScreen
import 'package:wa_blast/screens/variants_editor_screen.dart';

class ProductFormScreen extends StatefulWidget {
  const ProductFormScreen({super.key, this.idProduct});

  /// null => add mode, not null => edit mode
  final String? idProduct;

  bool get isEdit => (idProduct ?? '').trim().isNotEmpty;

  @override
  State<ProductFormScreen> createState() => _ProductFormScreenState();
}

class _ProductFormScreenState extends State<ProductFormScreen> {
  bool _isSubmitting = false;

  final _formKey = GlobalKey<FormState>();
  final _nameC = TextEditingController();
  final _descC = TextEditingController();

  bool _attemptedSubmit = false;

  bool _useVariants = false;
  bool _useMultiPrice = false;

  // Single SKU (when variants OFF)
  final TextEditingController _singleSkuCodeC = TextEditingController();
  final TextEditingController _singleSkuPriceC = TextEditingController();

  // Dropdowns
  String? _selectedBrandId;
  String? _selectedCategoryId;

  final ImagePicker _picker = ImagePicker();

  // Images (5 slots) — support existing (edit) + picked (add/edit)
  final List<_ImageSlot> _slots = List<_ImageSlot>.generate(
    5,
    (i) => _ImageSlot(position: i + 1),
    growable: false,
  );

  // ✅ Track image changes (edit mode)
  bool _imagesDirty = false;

  // Wholesale prices tiers
  final List<_PriceRow> _prices = [_PriceRow()];

  // ===== Premium gate (same as add) =====
  bool _loadingPremium = true;
  bool _isPremiumBiz = false;

  // ===== Detail loading (edit mode) =====
  bool _hydrating = false;
  bool _hydratedFromDetail = false;

  // ==========================================================
  // ✅ VARIANTS NEW STATE (replacing inline VariantsSectionDynamic)
  // ==========================================================
  List<Map<String, dynamic>>? _variantsSkusJson; // from VariantsEditorScreen
  List<String> _variantNames = const [];
  bool _variantPricesUniformCached = false;
  int? _uniformBasePriceCached;

  // =========================
  // Utils
  // =========================
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

  /// ✅ opsional, tapi tidak boleh ada spasi
  static String? _skuNoSpaceValidator(String? v) {
    final s = (v ?? '').trim();
    if (s.isEmpty) return null;
    if (RegExp(r'\s').hasMatch(s)) return 'No spaces allowed';
    return null;
  }

  // ==========================================================
  // ✅ VARIANTS helpers
  // ==========================================================
  List<String> _extractVariantNamesFromSkus(List<Map<String, dynamic>> skus) {
    final set = <String>{};
    for (final s in skus) {
      final attrs = (s['attributes'] as List?) ?? const [];
      for (final a in attrs) {
        final name = (a['name'] ?? '').toString().trim();
        if (name.isNotEmpty) set.add(name);
      }
    }
    final list = set.toList()..sort();
    return list;
  }

  bool _isUniformPrice(List<Map<String, dynamic>> skus) {
    final prices = skus
        .map((e) => (e['price'] as int?) ?? 0)
        .where((p) => p > 0)
        .toList();
    if (prices.isEmpty) return false;
    final p0 = prices.first;
    for (final p in prices) {
      if (p != p0) return false;
    }
    return true;
  }

  int? _uniformBasePrice(List<Map<String, dynamic>> skus) {
    if (!_isUniformPrice(skus)) return null;
    final prices = skus
        .map((e) => (e['price'] as int?) ?? 0)
        .where((p) => p > 0)
        .toList();
    if (prices.isEmpty) return null;
    return prices.first;
  }

  int? get _skuBasePrice {
    if (_useVariants) {
      final skus = (_variantsSkusJson ?? const [])
          .map((e) => (e['price'] as int?) ?? 0)
          .where((p) => p > 0)
          .toList();
      if (skus.isEmpty) return null;

      final p0 = skus.first;
      for (final p in skus) {
        if (p != p0) return null;
      }
      return p0;
    } else {
      final p = _toInt(_singleSkuPriceC.text);
      return p > 0 ? p : null;
    }
  }

  bool get _variantPricesUniform {
    if (!_useVariants) return false;
    return _variantPricesUniformCached;
  }

  bool get _allVariantPricesFilled {
    if (!_useVariants) return false;
    final list = _variantsSkusJson ?? const [];
    if (list.isEmpty) return false;

    for (final e in list) {
      final p = (e['price'] as int?) ?? 0;
      if (p <= 0) return false;
    }
    return true;
  }

  Future<void> _openVariantsEditor() async {
    // ✅ Edit mode: prefills from hydrated variants
    // ✅ Create mode: first open = null (empty). If user already saved variants, reopen should show last result.
    final initial = (_variantsSkusJson != null && _variantsSkusJson!.isNotEmpty)
        ? _variantsSkusJson
        : null;

    final res = await Navigator.push<VariantsEditorResult>(
      context,
      MaterialPageRoute(
        builder: (_) => VariantsEditorScreen(initialSkusJson: initial),
      ),
    );

    if (!mounted || res == null) return;

    setState(() {
      _variantsSkusJson = res.skusJson;
      _variantNames = res.variantNames..sort();
      _variantPricesUniformCached = res.pricesUniform;
      _uniformBasePriceCached = res.uniformBasePrice;

      // Kalau variants berubah jadi tidak uniform, matikan multi price (konteks lama)
      if (_useMultiPrice && !_variantPricesUniformCached) {
        _useMultiPrice = false;
      }
    });
  }

  void _clearVariantsState() {
    _variantsSkusJson = null;
    _variantNames = const [];
    _variantPricesUniformCached = false;
    _uniformBasePriceCached = null;
  }

  // =========================
  // Premium status (same as add)
  // =========================
  Future<void> _loadPremiumStatus() async {
    try {
      final prefs = await SharedPreferences.getInstance();

      final cached = prefs.getBool('activeBizIsPremium');
      if (cached != null) {
        if (!mounted) return;
        setState(() {
          _isPremiumBiz = cached;
          _loadingPremium = false;
        });
        return;
      }

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

  // =========================
  // Camera permission & picker
  // =========================
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
      if (picked != null) {
        setState(() {
          _slots[idx].picked = picked;
          // ✅ mark changed only when user actually picks/replaces image
          _imagesDirty = true;
        });
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Failed to pick image: $e')));
    }
  }

  void _removeImageAt(int idx) {
    setState(() {
      // ✅ mark image changed when user removes
      _imagesDirty = true;

      _slots[idx].clear();
      // compact
      for (int i = 0; i < _slots.length - 1; i++) {
        if (_slots[i].isEmpty && !_slots[i + 1].isEmpty) {
          _slots[i].copyFrom(_slots[i + 1]);
          _slots[i + 1].clear();
        }
      }
    });
  }

  bool _slotEnabled(int idx) {
    if (idx == 0) return true;
    return !_slots[idx - 1].isEmpty;
  }

  // =========================
  // Tier rules (same as add)
  // =========================
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

  // =========================
  // Hydrate for edit mode
  // =========================
  Future<void> _fetchDetailAndHydrate() async {
    if (!widget.isEdit) return;
    if (_hydrating || _hydratedFromDetail) return;

    setState(() => _hydrating = true);
    try {
      final prov = context.read<ProductProvider>();
      final p = await prov.fetchProductDetail(context, widget.idProduct!);
      if (!mounted) return;

      if (p == null) {
        AppSnackbar.show(
          context,
          type: AppSnackType.error,
          title: 'Failed',
          message: prov.lastError ?? 'Failed to load product detail.',
        );
        Navigator.pop(context);
        return;
      }

      _nameC.text = p.name;
      _descC.text = (p.description ?? '');

      _selectedBrandId = p.productBrand?.idProductBrand;
      _selectedCategoryId = p.productCategory?.idProductCategory;

      // images
      final imgs = [...p.productImages]
        ..sort((a, b) => a.position.compareTo(b.position));
      for (int i = 0; i < _slots.length; i++) {
        if (i < imgs.length) {
          _slots[i]
            ..existingFilename = imgs[i].image
            ..existingUrl = imgs[i].imagePath
            ..picked = null;
        } else {
          _slots[i].clear();
        }
      }

      // ✅ after hydrate, user hasn't changed images yet
      _imagesDirty = false;

      // variants vs single sku
      final skus = p.productSkus;
      final shouldUseVariants =
          (skus.length > 1) ||
          (skus.length == 1 && skus.first.attributes.isNotEmpty);
      _useVariants = shouldUseVariants;

      if (_useVariants) {
        // ✅ Build initial skus json for VariantsEditor (prefill)
        final initSkus = skus
            .map(
              (s) => {
                'code': (s.code ?? '').trim().isEmpty ? null : s.code,
                'price': (s.price > 0) ? s.price : null,
                'attributes': s.attributes
                    .map((a) => {'name': a.name, 'value': a.value})
                    .toList(),
              },
            )
            .toList();

        _variantsSkusJson = initSkus;
        _variantNames = _extractVariantNamesFromSkus(initSkus);
        _variantPricesUniformCached = _isUniformPrice(initSkus);
        _uniformBasePriceCached = _uniformBasePrice(initSkus);
      } else {
        _clearVariantsState();
        if (skus.isNotEmpty) {
          _singleSkuCodeC.text = (skus.first.code ?? '');
          _singleSkuPriceC.text = NumberFormat.decimalPattern(
            'id',
          ).format(skus.first.price);
        }
      }

      // multi price tiers
      if (p.productPrices.isNotEmpty) {
        _useMultiPrice = true;
        for (final r in _prices) {
          r.dispose();
        }
        _prices.clear();

        for (final pr in p.productPrices) {
          final row = _PriceRow();
          row.minQty.text = pr.minQty.toString();
          row.price.text = NumberFormat.decimalPattern('id').format(pr.price);
          _prices.add(row);
        }
      } else {
        _useMultiPrice = false;
        for (final r in _prices) {
          r.dispose();
        }
        _prices
          ..clear()
          ..add(_PriceRow());
      }

      // ✅ if existing multi price but variants are not uniform, force off (konteks lama)
      if (_useVariants && _useMultiPrice && !_variantPricesUniformCached) {
        _useMultiPrice = false;
      }

      _hydratedFromDetail = true;
      if (mounted) setState(() {});
    } finally {
      if (mounted) setState(() => _hydrating = false);
    }
  }

  // =========================
  // Validation (mirip Add)
  // =========================
  bool get _canSubmitSilently {
    if (_nameC.text.trim().isEmpty) return false;

    if (!_useVariants) {
      if (_toInt(_singleSkuPriceC.text) <= 0) return false;
      if (_skuNoSpaceValidator(_singleSkuCodeC.text) != null) return false;
    } else {
      if ((_variantsSkusJson ?? const []).isEmpty) return false;
      if (!_allVariantPricesFilled) return false;
      if (_useMultiPrice && !_variantPricesUniform) return false;
    }

    if (_useMultiPrice) {
      if (_prices.where((e) => e.isFilled).isEmpty) return false;
      if (!_allTierPricesValid) return false;
    }

    return true;
  }

  // =========================
  // Submit (add or edit)
  // =========================
  Future<void> _onSubmit() async {
    try {
      setState(() => _attemptedSubmit = true);
      if (!_formKey.currentState!.validate()) return;

      setState(() => _isSubmitting = true);

      final provider = context.read<ProductProvider>();

      // 1) Upload / reuse images
      List<Map<String, dynamic>>? imagesMaps;

      final bool shouldSendImages = !widget.isEdit || _imagesDirty;

      if (shouldSendImages) {
        imagesMaps = <Map<String, dynamic>>[];

        for (int i = 0; i < _slots.length; i++) {
          final s = _slots[i];
          String? filename;

          if (s.picked != null) {
            final uploaded = await provider.uploadProductImage(
              context,
              File(s.picked!.path),
            );
            if (uploaded == null) {
              if (!mounted) return;
              AppSnackbar.show(
                context,
                type: AppSnackType.error,
                title: 'Upload',
                message: 'Image upload failed at slot ${i + 1}',
              );
              return;
            }
            filename = uploaded;
          } else if (s.existingFilename != null &&
              s.existingFilename!.isNotEmpty) {
            filename = s.existingFilename!;
          }

          if (filename != null) {
            imagesMaps.add({'image': filename, 'position': i + 1});
          }
        }
      } else {
        // ✅ Edit mode & user did not touch images => send null
        imagesMaps = null;
      }

      // 2) Build SKUs
      late final List<Map<String, dynamic>> skusMaps;
      late final List<NewSku> skusModels;

      if (_useVariants) {
        final list = _variantsSkusJson ?? const [];

        if (list.isEmpty) {
          AppSnackbar.show(
            context,
            type: AppSnackType.error,
            title: 'Variants',
            message: 'Please add variants.',
          );
          return;
        }

        // ✅ NEW: semua SKU harus punya price
        final anyZero = list.any((e) => ((e['price'] as int?) ?? 0) <= 0);
        if (anyZero) {
          AppSnackbar.show(
            context,
            type: AppSnackType.error,
            title: 'Variants',
            message: 'Price is required for every SKU.',
          );
          return;
        }

        if (_useMultiPrice && !_variantPricesUniform) {
          AppSnackbar.show(
            context,
            type: AppSnackType.error,
            title: 'Wholesale',
            message:
                'Multiple Price can only be enabled if all SKU prices are identical.',
          );
          return;
        }

        // ✅ kirim SEMUA SKU (karena price mandatory)
        skusMaps = list
            .map(
              (e) => {
                'code': ((e['code'] ?? '') as String).trim().isEmpty
                    ? null
                    : ((e['code'] ?? '') as String).trim(),
                'price': (e['price'] as int?) ?? 0,
                'attributes': ((e['attributes'] as List?) ?? const [])
                    .map(
                      (a) => {
                        'name': (a['name'] ?? '').toString(),
                        'value': (a['value'] ?? '').toString(),
                      },
                    )
                    .toList(),
              },
            )
            .toList();

        // kalau variabel ini masih ada di file kamu, biarin kosong:
        skusModels = const <NewSku>[];
      } else {
        final code = _singleSkuCodeC.text.trim();
        final price = _toInt(_singleSkuPriceC.text);
        if (price <= 0) {
          AppSnackbar.show(
            context,
            type: AppSnackType.error,
            title: 'SKU',
            message: 'Enter a valid SKU Price.',
          );
          return;
        }

        final sku = NewSku(
          code: code.trim(), // boleh '' kalau kosong
          price: price,
          attributes: const [],
        );

        skusModels = [sku];
        skusMaps = [
          {
            'code': code.isEmpty ? null : code,
            'price': price,
            'attributes': null,
          },
        ];
      }

      // 3) Prices tiers
      final pricesMaps = _useMultiPrice
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

      final pricesModels = _useMultiPrice
          ? _prices
                .where((e) => e.isFilled)
                .map(
                  (e) => NewPrice(
                    minQty: _toInt(e.minQty.text),
                    price: _toInt(e.price.text),
                  ),
                )
                .toList()
          : <NewPrice>[];

      // 4) Submit add vs edit
      final desc = _descC.text.trim();
      final brandId = _selectedBrandId;
      final categoryId = _selectedCategoryId;

      bool ok = false;

      if (!widget.isEdit) {
        ok = await provider.addProductExactPayload(
          context: context,
          name: _nameC.text.trim(),
          description: desc.isEmpty ? null : desc,
          productBrandId: brandId,
          productCategoryId: categoryId,
          images: imagesMaps ?? const [],
          skus: skusMaps,
          prices: pricesMaps,
        );
      } else {
        ok = await provider.updateProductExactPayload(
          context: context,
          idProduct: widget.idProduct!,
          name: _nameC.text.trim(),
          description: _descC.text.trim().isEmpty ? null : _descC.text.trim(),
          productBrandId: _selectedBrandId,
          productCategoryId: _selectedCategoryId,
          images: imagesMaps, // ✅ nullable (null kalau user tidak ubah gambar)
          skus: skusMaps,
          prices: _useMultiPrice ? pricesMaps : null,
        );
      }

      if (!mounted) return;

      if (ok) {
        AppSnackbar.show(
          context,
          type: AppSnackType.success,
          title: widget.isEdit ? 'Saved' : 'Added',
          message: widget.isEdit
              ? 'Product updated successfully.'
              : 'Product added successfully.',
        );
        Navigator.of(context).pop(true);
      } else {
        AppSnackbar.show(
          context,
          type: AppSnackType.error,
          title: 'Failed',
          message:
              'Failed to ${widget.isEdit ? 'update' : 'add'} product: ${provider.lastError ?? ''}',
        );
      }
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  // =========================
  // Lifecycle
  // =========================
  @override
  void initState() {
    super.initState();

    Future.microtask(_loadPremiumStatus);

    final prov = context.read<ProductProvider>();
    prov.fetchProductBrands(context);
    prov.fetchProductCategories(context);

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final sp = context.read<StoreProvider>();
      await prov.ensureDefaultStoreLocation(context);
      if (!mounted) return;
      if (sp.stores.isEmpty && !sp.loadingList) {
        await sp.fetchStoreLocations(context);
      }
      if (widget.isEdit) {
        await _fetchDetailAndHydrate();
      }
    });
  }

  @override
  void dispose() {
    _nameC.dispose();
    _descC.dispose();
    _singleSkuCodeC.dispose();
    _singleSkuPriceC.dispose();
    for (final r in _prices) {
      r.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final mq = MediaQuery.of(context);
    final padBottom = mq.viewInsets.bottom;

    final canSubmit = _canSubmitSilently;
    final base = _skuBasePrice;

    final bool canEnableMultiPriceWhenVariants =
        !_useVariants || (_useVariants && _variantPricesUniform);

    final baseLabel = (base == null)
        ? ''
        : 'Current base SKU price: ${NumberFormat.currency(locale: 'id', symbol: 'Rp. ', decimalDigits: 0).format(base)}. '
              'Every wholesale tier price must be STRICTLY LOWER than this value.';

    final title = widget.isEdit ? 'Edit Product' : 'Add Product';

    // loading overlay for edit hydrate / premium load
    final showOverlay = widget.isEdit && !_hydratedFromDetail && _hydrating;

    final variantErrorText = (_attemptedSubmit && _useVariants)
        ? ((_variantsSkusJson == null || _variantsSkusJson!.isEmpty)
              ? 'Please add variants.'
              : (!_allVariantPricesFilled
                    ? 'Price is required for every SKU.'
                    : null))
        : null;

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: Text(title),
        centerTitle: false,
        elevation: 0,
        backgroundColor: Colors.white,
        foregroundColor: const Color(0xFF111827),
      ),
      body: SafeArea(
        child: Stack(
          children: [
            Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 1100),
                child: SingleChildScrollView(
                  padding: EdgeInsets.fromLTRB(20, 12, 20, 20 + padBottom),
                  child: Form(
                    autovalidateMode: _attemptedSubmit
                        ? AutovalidateMode.onUserInteraction
                        : AutovalidateMode.disabled,
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
                            final slot = _slots[i];
                            return Expanded(
                              child: Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 4,
                                ),
                                child: _PhotoSlotBox(
                                  enabled: enabled,
                                  file: slot.picked,
                                  imageUrl: slot.existingUrl,
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
                          validator: (v) => (v == null || v.trim().isEmpty)
                              ? 'Required'
                              : null,
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

                        // Single SKU price (when variants OFF)
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
                              final newText = f.format(
                                int.tryParse(digits) ?? 0,
                              );
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

                        // Brand & Category (opsional, mirip Add)
                        Consumer<ProductProvider>(
                          builder: (context, prov, _) {
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
                                  placeholder: 'Select a brand (optional)',
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
                                  placeholder: 'Select a category (optional)',
                                  valueText: selectedCategoryName,
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

                        // Use Variants
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
                                    // clear single fields
                                    if (_singleSkuCodeC.text.isNotEmpty ||
                                        _singleSkuPriceC.text.isNotEmpty) {
                                      _singleSkuCodeC.clear();
                                      _singleSkuPriceC.clear();
                                    }
                                  } else {
                                    // ✅ turning off variants clears variants result
                                    _clearVariantsState();
                                    _useMultiPrice = false;
                                  }
                                }),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 12),

                        // ==========================================================
                        // ✅ VARIANTS SECTION (summary + open editor) / Single SKU code
                        // ==========================================================
                        if (_useVariants) ...[
                          _VariantsSummaryCard(
                            variantNames: _variantNames,
                            hasAnySkus:
                                (_variantsSkusJson ?? const []).isNotEmpty,
                            onTap: _openVariantsEditor,
                            errorText: variantErrorText,
                          ),
                          const SizedBox(height: 16),
                        ] else ...[
                          const Text(
                            'SKU Code',
                            style: TextStyle(
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF111827),
                            ),
                          ),
                          const SizedBox(height: 6),
                          TextFormField(
                            controller: _singleSkuCodeC,
                            inputFormatters: [_skuNoSpaceFormatter],
                            decoration: const InputDecoration(
                              isDense: true,
                              hintText: 'SKU Code (optional, no spaces)',
                              border: OutlineInputBorder(),
                            ),
                            validator: _skuNoSpaceValidator,
                          ),
                          const SizedBox(height: 16),
                        ],

                        // Multi Price toggle (premium gated)
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
                                  Switch(
                                    activeColor: AppColors.primaryDark,
                                    value: _useMultiPrice,
                                    onChanged: (v) async {
                                      if (_loadingPremium) return;
                                      if (!_isPremiumBiz) {
                                        await _showMultiPriceLockedModal(
                                          context,
                                        );
                                        return;
                                      }
                                      if (!canEnableMultiPriceWhenVariants) {
                                        // blocked
                                        return;
                                      }
                                      setState(() => _useMultiPrice = v);
                                    },
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
                                  baseLabel,
                                  style: const TextStyle(
                                    color: Color(0xFF6B7280),
                                  ),
                                ),
                              ],
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
                                      validator: (v) {
                                        if (!_useMultiPrice) return null;
                                        if (v == null || v.trim().isEmpty) {
                                          return 'Required';
                                        }
                                        return null;
                                      },
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
            if (showOverlay)
              Positioned.fill(
                child: Container(
                  color: Colors.white.withOpacity(0.65),
                  child: const Center(child: CircularProgressIndicator()),
                ),
              ),
          ],
        ),
      ),
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
                      child: Text(
                        widget.isEdit ? 'Save changes' : 'Add new product',
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                    ),
                  )
                : ElevatedButton(
                    onPressed: _onSubmit,
                    // biar mirip add: tombol bisa ditekan tapi form akan menandai errors saat attemptedSubmit
                    style: ElevatedButton.styleFrom(
                      backgroundColor: canSubmit
                          ? AppColors.primary
                          : const Color(0xFFE5E7EB),
                      foregroundColor: canSubmit
                          ? Colors.white
                          : const Color(0xFF9CA3AF),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: Text(
                      widget.isEdit ? 'Save changes' : 'Add new product',
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                  ),
          ),
        ),
      ),
    );
  }
}

// ==========================================================
// ✅ NEW: variants summary card (ProductForm shows only names)
// ==========================================================
class _VariantsSummaryCard extends StatelessWidget {
  const _VariantsSummaryCard({
    required this.variantNames,
    required this.hasAnySkus,
    required this.onTap,
    this.errorText,
  });

  final List<String> variantNames;
  final bool hasAnySkus;
  final VoidCallback onTap;
  final String? errorText;

  @override
  Widget build(BuildContext context) {
    final hasNames = variantNames.isNotEmpty;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Variants',
          style: TextStyle(
            fontWeight: FontWeight.w600,
            color: Color(0xFF111827),
          ),
        ),
        const SizedBox(height: 8),
        InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: Container(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
            decoration: BoxDecoration(
              color: const Color(0xFFF9FAFB),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: errorText == null
                    ? const Color(0xFFE5E7EB)
                    : const Color(0xFFEF4444),
              ),
            ),
            child: Row(
              children: [
                const Icon(Icons.tune_rounded, color: Color(0xFF4C6EF5)),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        hasAnySkus ? 'Edit variants' : 'Add variants',
                        style: const TextStyle(
                          fontWeight: FontWeight.w800,
                          color: Color(0xFF111827),
                        ),
                      ),
                      const SizedBox(height: 4),
                      if (!hasNames)
                        const Text(
                          'No variants yet. Tap to create (e.g. Color, Size).',
                          style: TextStyle(
                            fontSize: 12,
                            color: Color(0xFF6B7280),
                            height: 1.3,
                            fontWeight: FontWeight.w600,
                          ),
                        )
                      else
                        Wrap(
                          spacing: 6,
                          runSpacing: 6,
                          children: variantNames
                              .map(
                                (n) => Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 10,
                                    vertical: 6,
                                  ),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFEFF6FF),
                                    borderRadius: BorderRadius.circular(999),
                                    border: Border.all(
                                      color: const Color(0xFFBFDBFE),
                                    ),
                                  ),
                                  child: Text(
                                    n,
                                    style: const TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w800,
                                      color: Color(0xFF1D4ED8),
                                    ),
                                  ),
                                ),
                              )
                              .toList(),
                        ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                const Icon(
                  Icons.chevron_right_rounded,
                  color: Color(0xFF6B7280),
                ),
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

// ==========================================================
// Helpers / Widgets (UNCHANGED)
// ==========================================================

class _ImageSlot {
  _ImageSlot({required this.position});
  final int position;

  String? existingFilename;
  String? existingUrl;
  XFile? picked;

  bool get isEmpty =>
      picked == null && (existingFilename == null || existingFilename!.isEmpty);

  void clear() {
    existingFilename = null;
    existingUrl = null;
    picked = null;
  }

  void copyFrom(_ImageSlot other) {
    existingFilename = other.existingFilename;
    existingUrl = other.existingUrl;
    picked = other.picked;
  }
}

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
    this.imageUrl,
  });

  final bool enabled;
  final XFile? file;
  final String? imageUrl;
  final VoidCallback onPick;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final borderColor = enabled
        ? const Color(0xFF4C6EF5)
        : const Color(0xFFE5E7EB);

    Widget? preview;
    if (file != null) {
      preview = Image.file(
        File(file!.path),
        fit: BoxFit.cover,
        errorBuilder: (c, e, s) => const _ImageErrorPlaceholder(),
      );
    } else if ((imageUrl ?? '').isNotEmpty) {
      preview = Image.network(
        imageUrl!,
        fit: BoxFit.cover,
        errorBuilder: (c, e, s) => const _ImageErrorPlaceholder(),
      );
    }

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
              if (preview == null)
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
                preview,
              if (preview != null)
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

// ==========================================================
// Premium carousel (UNCHANGED)
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
// Select + picker (UNCHANGED)
// ==========================================================

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
