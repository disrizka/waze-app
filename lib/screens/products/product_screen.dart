import 'dart:async';
import 'dart:io';
import 'package:intl/intl.dart';

import 'package:dotted_border/dotted_border.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import 'package:wa_blast/constants/app_colors.dart';
import 'package:wa_blast/providers/product_provider.dart';
import 'package:wa_blast/screens/products/add_product_sheet.dart';
import 'package:wa_blast/screens/products/edit_product_sheet.dart';
import 'package:wa_blast/widgets/app_snackbar.dart';
import 'package:wa_blast/widgets/variant_section_dynamic.dart';

String _formatRp(int value) {
  final f = NumberFormat.currency(
    locale: 'id',
    symbol: 'Rp. ',
    decimalDigits: 0,
  );
  return f.format(value);
}

final GlobalKey<VariantsSectionDynamicState> variantsKey =
    GlobalKey<VariantsSectionDynamicState>();

class PickerOption {
  final String id;
  final String label;
  final String? subtitle;
  PickerOption({required this.id, required this.label, this.subtitle});
}

class ProductScreen extends StatelessWidget {
  const ProductScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final colorPrimary = _resolvePrimary(context);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      final prov = context.read<ProductProvider>();
      prov.fetchProducts(context);
      // preload dropdown data sekali
      prov.fetchProductBrands(context);
      prov.fetchProductCategories(context);
    });

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.white,
        scrolledUnderElevation: 0,
        foregroundColor: const Color(0xFF1F2937),
        title: const Text(
          'Product List',
          style: TextStyle(
            fontWeight: FontWeight.w700,
            color: Color(0xFF1F2937),
          ),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded),
          onPressed: () =>
              Navigator.pushReplacementNamed(context, '/manage-product'),
        ),
      ),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: () =>
              context.read<ProductProvider>().fetchProducts(context),
          child: Consumer<ProductProvider>(
            builder: (context, provider, _) {
              if (provider.loadingProducts) {
                return const Center(child: CircularProgressIndicator());
              }
              final items = provider.products;
              if (items.isEmpty) {
                return _EmptyState(colorPrimary: colorPrimary);
              }
              return ListView.separated(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 24 + 56),
                itemCount: items.length,
                separatorBuilder: (_, __) => const SizedBox(height: 12),
                itemBuilder: (_, i) {
                  final p = items[i];
                  final priceLabel = _formatRp(p.basePrice ?? 0);
                  final img = p.primaryImageUrl ?? 'assets/empty_box.png';
                  return _ProductTile(
                    title: p.name,
                    priceLabel: priceLabel,
                    image: img,
                    onTap: () {
                      Navigator.pushNamed(
                        context,
                        '/product/detail-product',
                        arguments: p.idProduct,
                      );
                    },
                    onEdit: () => showEditProductSheet(context, p.idProduct),
                    onDelete: () async {
                      final confirm = await showDialog<bool>(
                        context: context,
                        builder: (context) {
                          return AlertDialog(
                            backgroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                            title: Row(
                              children: const [
                                Icon(
                                  Icons.warning_amber_rounded,
                                  color: Colors.red,
                                  size: 28,
                                ),
                                SizedBox(width: 8),
                                Text(
                                  'Delete Product',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: Colors.black,
                                  ),
                                ),
                              ],
                            ),
                            content: Text(
                              'Are you sure you want to permanently delete "${p.name}"?',
                              style: const TextStyle(
                                fontSize: 15,
                                color: Colors.black87,
                              ),
                            ),
                            actionsPadding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 8,
                            ),
                            actions: [
                              TextButton(
                                onPressed: () => Navigator.pop(context, false),
                                style: TextButton.styleFrom(
                                  foregroundColor: Colors.grey[700],
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 16,
                                    vertical: 12,
                                  ),
                                ),
                                child: const Text('Cancel'),
                              ),
                              ElevatedButton(
                                onPressed: () => Navigator.pop(context, true),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.red,
                                  foregroundColor: Colors.white,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 20,
                                    vertical: 12,
                                  ),
                                ),
                                child: const Text('Delete'),
                              ),
                            ],
                          );
                        },
                      );

                      if (confirm == true) {
                        final ok = await context
                            .read<ProductProvider>()
                            .deleteProduct(context, p.idProduct);
                        if (ok && context.mounted) {
                          AppSnackbar.show(
                            context,
                            type: AppSnackType.success,
                            message: 'Product successfully deleted',
                          );
                        }
                      }
                    },
                  );
                },
              );
            },
          ),
        ),
      ),
      bottomNavigationBar: SafeArea(
        minimum: const EdgeInsets.fromLTRB(12, 8, 12, 30),
        child: SizedBox(
          height: 48,
          child: ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.blueButton,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              minimumSize: const Size.fromHeight(48),
            ),
            onPressed: () async {
              await showAddProductSheet(context);
              // refresh setelah create (jika sukses)
              // ignore: use_build_context_synchronously
              context.read<ProductProvider>().fetchProducts(context);
            },
            child: const Text(
              'Add new product',
              style: TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
        ),
      ),
    );
  }

  Color _resolvePrimary(BuildContext context) {
    final themePrimary = Theme.of(context).colorScheme.primary;
    if (themePrimary != const Color(0xff6200ee)) return themePrimary;
    return const Color(0xFF4C6EF5);
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.colorPrimary});
  final Color colorPrimary;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Center(
          child: Image.asset(
            'assets/empty_box.png',
            width: 180,
            height: 180,
            fit: BoxFit.contain,
          ),
        ),
        const SizedBox(height: 24),
        const Center(
          child: Text(
            'No Product',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: Color(0xFF111827),
            ),
          ),
        ),
        const SizedBox(height: 8),
        const Center(
          child: Text(
            'Please to create and add your product\nto the application',
            textAlign: TextAlign.center,
            style: TextStyle(height: 1.4, color: Color(0xFF6B7280)),
          ),
        ),
        const SizedBox(height: 24),
      ],
    );
  }
}

class _ProductTile extends StatelessWidget {
  const _ProductTile({
    required this.title,
    required this.priceLabel,
    required this.image,
    this.onTap, // <— tambah
    this.onEdit,
    this.onDelete,
  });

  final String title;
  final String priceLabel;
  final String image;
  final VoidCallback? onTap; // <— tambah
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap, // <— tambahkan
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _SquareImage(image: image),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF111827),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    priceLabel,
                    style: const TextStyle(color: Color(0xFF6B7280)),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            _MoreButtonAnchored(onEdit: onEdit, onDelete: onDelete),
          ],
        ),
      ),
    );
  }
}

class _SquareImage extends StatelessWidget {
  const _SquareImage({required this.image});
  final String image;

  @override
  Widget build(BuildContext context) {
    final isNetwork =
        image.isNotEmpty &&
        (image.startsWith('http://') || image.startsWith('https://'));
    Widget _fallback() => const _ImageErrorPlaceholder();

    final Widget child = isNetwork
        ? Image.network(
            image,
            fit: BoxFit.cover,
            loadingBuilder: (ctx, child, progress) => progress == null
                ? child
                : const Center(
                    child: SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  ),
            errorBuilder: (ctx, err, stack) => _fallback(),
          )
        : (image.isNotEmpty
              ? Image.asset(
                  image,
                  fit: BoxFit.cover,
                  errorBuilder: (ctx, err, stack) => _fallback(),
                )
              : _fallback());

    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: Container(
        width: 90,
        height: 90,
        color: const Color(0xFFF3F4F6),
        child: child,
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

/// --------------------------------------------------------------------------
/// EDIT PRODUCT
/// --------------------------------------------------------------------------

Future<void> openEditProductById(BuildContext context, String idProduct) async {
  final prov = context.read<ProductProvider>();

  // Ambil detail + pastikan list dropdown siap dulu
  await Future.wait([
    prov.fetchProductBrands(context),
    prov.fetchProductCategories(context),
  ]);

  final detail = await prov.fetchProductDetail(context, idProduct);
  if (detail == null) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Gagal memuat detail produk: ${prov.lastError ?? ''}'),
        ),
      );
    }
    return;
  }

  if (!context.mounted) return;
  await showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: Colors.white,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (_) => _EditProductSheet(product: detail),
  );

  if (!context.mounted) return;
  context.read<ProductProvider>().fetchProducts(context);
}

Future<void> showEditProductSheetById(
  BuildContext context,
  String idProduct,
) async {
  final prov = context.read<ProductProvider>();

  // Ambil detail dulu agar sheet muncul sudah ter-isi
  final detail = await prov.fetchProductDetail(context, idProduct);
  if (detail == null) {
    if (context.mounted) {
      AppSnackbar.show(
        context,
        type: AppSnackType.error,
        title: 'Gagal',
        message: 'Tidak bisa mengambil detail produk. ${prov.lastError ?? ''}',
      );
    }
    return;
  }

  // Buka sheet dengan model detail
  // ignore: use_build_context_synchronously
  await showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: Colors.white,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (_) => _EditProductSheet(product: detail),
  );
}

class _EditProductSheet extends StatefulWidget {
  const _EditProductSheet({required this.product});
  final Product product;

  @override
  State<_EditProductSheet> createState() => _EditProductSheetState();
}

class _EditProductSheetState extends State<_EditProductSheet> {
  final _formKey = GlobalKey<FormState>();
  bool _attemptedSubmit = false;
  late final TextEditingController _nameC;
  late final TextEditingController _descC;

  String? _selectedBrandId;
  String? _selectedCategoryId;

  final ImagePicker _picker = ImagePicker();
  XFile? _picked;
  String? _existingImageUrl; // preview
  String? _existingImageFilename; // kirim saat tidak ganti

  final List<_PriceRow> _prices = [];
  final List<_SkuRow> _skus = [];

  @override
  void initState() {
    super.initState();
    final p = widget.product;

    _nameC = TextEditingController(text: p.name);
    _descC = TextEditingController(text: p.description);

    _selectedBrandId = p.productBrand?.idProductBrand;
    _selectedCategoryId = p.productCategory?.idProductCategory;

    if (p.productImages.isNotEmpty) {
      final imgs = [...p.productImages]
        ..sort((a, b) => a.position.compareTo(b.position));
      final first = imgs.first;
      _existingImageUrl = first.imagePath;
      _existingImageFilename =
          first.image; // penting untuk payload bila tidak ganti gambar
    }

    if (p.productPrices.isNotEmpty) {
      for (final pr in p.productPrices) {
        final row = _PriceRow()
          ..minQty.text = '${pr.minQty}'
          ..price.text = NumberFormat.decimalPattern('id').format(pr.price);
        _prices.add(row);
      }
    } else {
      _prices.add(_PriceRow());
    }

    if (p.productSkus.isNotEmpty) {
      for (final s in p.productSkus) {
        final skuRow = _SkuRow()
          ..code.text = s.code
          ..price.text = NumberFormat.decimalPattern('id').format(s.price);

        if (s.attributes.isNotEmpty) {
          skuRow.attrs.clear();
          for (final a in s.attributes) {
            final ar = _AttrRow()
              ..name.text = a.name
              ..value.text = a.value;
            skuRow.attrs.add(ar);
          }
        }
        _skus.add(skuRow);
      }
    } else {
      _skus.add(_SkuRow());
    }

    // jaga-jaga kalau list brand/category belum ada
    final prov = context.read<ProductProvider>();
    prov.fetchProductBrands(context);
    prov.fetchProductCategories(context);
  }

  @override
  void dispose() {
    _nameC.dispose();
    _descC.dispose();
    for (final r in _prices) {
      r.dispose();
    }
    for (final s in _skus) {
      s.dispose();
    }
    super.dispose();
  }

  bool get _isValid =>
      (_formKey.currentState?.validate() ?? false) &&
      _selectedBrandId != null &&
      _selectedCategoryId != null &&
      _prices.where((e) => e.isFilled).isNotEmpty &&
      _skus.where((e) => e.isFilled).isNotEmpty;

  Future<void> _chooseImageSource() async {
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
              title: const Text('Pilih dari Galeri'),
              onTap: () => Navigator.pop(ctx, ImageSource.gallery),
            ),
            ListTile(
              leading: const Icon(Icons.photo_camera_outlined),
              title: const Text('Ambil dari Kamera'),
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
      if (picked != null) {
        setState(() {
          _picked = picked;
          _existingImageUrl = null; // stop preview lama
          _existingImageFilename = null; // jangan kirim filename lama
        });
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Gagal memilih gambar: $e')));
    }
  }

  void _removeImage() {
    setState(() {
      _picked = null;
      _existingImageUrl = null;
      _existingImageFilename = null;
    });
  }

  int _toInt(String s) {
    final digits = s.replaceAll('.', '').replaceAll(',', '').trim();
    return int.tryParse(digits) ?? 0;
  }

  Future<void> _onSubmit() async {
    setState(() => _attemptedSubmit = true);

    if (!_formKey.currentState!.validate()) return;
    if (_selectedBrandId == null || _selectedCategoryId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Pilih brand & category terlebih dahulu.'),
        ),
      );
      return;
    }

    final provider = context.read<ProductProvider>();

    // (1) Upload image baru (jika user mengganti)
    String? uploadedFilename;
    if (_picked != null) {
      uploadedFilename = await provider.uploadProductImage(
        context,
        File(_picked!.path),
      );
      if (uploadedFilename == null) {
        if (!mounted) return;
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Upload gambar gagal')));
        return;
      }
    }

    final images = <NewImage>[];
    if (uploadedFilename != null) {
      // user ganti gambar
      images.add(NewImage(filename: uploadedFilename, position: 1));
    } else if (_existingImageFilename != null &&
        _existingImageFilename!.isNotEmpty) {
      // user TIDAK ganti gambar -> pakai filename lama dari detail
      images.add(NewImage(filename: _existingImageFilename!, position: 1));
    }

    final prices = _prices
        .where((e) => e.isFilled)
        .map(
          (e) => NewPrice(
            minQty: _toInt(e.minQty.text),
            price: _toInt(e.price.text),
          ),
        )
        .toList();

    final skus = _skus
        .where((e) => e.isFilled)
        .map(
          (e) => NewSku(
            code: e.code.text.trim(),
            price: _toInt(e.price.text),
            attributes: e.attrs
                .where((a) => a.isFilled)
                .map(
                  (a) => NewSkuAttribute(
                    name: a.name.text.trim(),
                    value: a.value.text.trim(),
                  ),
                )
                .toList(),
          ),
        )
        .toList();

    final ok = await provider.updateProduct(
      context: context,
      idProduct: widget.product.idProduct,
      name: _nameC.text.trim(),
      description: _descC.text.trim(),
      productBrandId: _selectedBrandId!,
      productCategoryId: _selectedCategoryId!,
      images: images,
      skus: skus,
      prices: prices,
    );

    if (!mounted) return;
    if (ok) {
      Navigator.of(context).pop();
      AppSnackbar.show(
        context,
        type: AppSnackType.success,
        title: 'Updated',
        message: 'Product updated successfully.',
      );
    } else {
      AppSnackbar.show(
        context,
        type: AppSnackType.error,
        title: 'Failed',
        message: 'Failed to update product: ${provider.lastError ?? ''}',
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final primary = _resolvePrimary(context);
    final padBottom = MediaQuery.of(context).viewInsets.bottom;

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
                          'Edit Product',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF111827),
                          ),
                        ),
                        const SizedBox(height: 16),

                        // PHOTO (show existing OR picked)
                        const Text(
                          'Product Photo',
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF111827),
                          ),
                        ),
                        const SizedBox(height: 8),
                        InkWell(
                          onTap: _chooseImageSource,
                          borderRadius: BorderRadius.circular(12),
                          child: DottedBorder(
                            options: const RoundedRectDottedBorderOptions(
                              color: Color(0xFF4C6EF5),
                              strokeWidth: 2,
                              dashPattern: <double>[8, 6],
                              radius: Radius.circular(12),
                              padding: EdgeInsets.all(0),
                            ),
                            child: Container(
                              height: 120,
                              width: double.infinity,
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              clipBehavior: Clip.antiAlias,
                              child: Builder(
                                builder: (_) {
                                  if (_picked != null) {
                                    return Stack(
                                      fit: StackFit.expand,
                                      children: [
                                        Image.file(
                                          File(_picked!.path),
                                          fit: BoxFit.cover,
                                          errorBuilder: (c, e, s) =>
                                              const _ImageErrorPlaceholder(),
                                        ),
                                        Positioned(
                                          top: 8,
                                          right: 8,
                                          child: _closeBtn(_removeImage),
                                        ),
                                      ],
                                    );
                                  }
                                  if (_existingImageUrl != null &&
                                      _existingImageUrl!.isNotEmpty) {
                                    return Stack(
                                      fit: StackFit.expand,
                                      children: [
                                        Image.network(
                                          _existingImageUrl!,
                                          fit: BoxFit.cover,
                                          errorBuilder: (c, e, s) =>
                                              const _ImageErrorPlaceholder(),
                                        ),
                                        Positioned(
                                          top: 8,
                                          right: 8,
                                          child: _closeBtn(_removeImage),
                                        ),
                                      ],
                                    );
                                  }
                                  return const Center(
                                    child: Text(
                                      'Upload file',
                                      style: TextStyle(color: Colors.black54),
                                    ),
                                  );
                                },
                              ),
                            ),
                          ),
                        ),

                        const SizedBox(height: 16),

                        // NAME
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
                          hintText: 'E.g iPhone 15 Pro +',
                          validator: (v) => (v == null || v.trim().isEmpty)
                              ? 'Required'
                              : null,
                        ),

                        const SizedBox(height: 16),

                        // DESCRIPTION
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
                          hintText: 'Deskripsi produk',
                          keyboardType: TextInputType.multiline,
                          validator: (v) => (v == null || v.trim().isEmpty)
                              ? 'Required'
                              : null,
                        ),

                        const SizedBox(height: 16),

                        Consumer<ProductProvider>(
                          builder: (context, prov, _) {
                            final brandOpts = prov.brands
                                .map(
                                  (b) => PickerOption(
                                    id: b.idProductBrand,
                                    label: b.name,
                                  ),
                                )
                                .toList();

                            final catOpts = prov.categories
                                .map(
                                  (c) => PickerOption(
                                    id: c.idProductCategory,
                                    label: c.name,
                                  ),
                                )
                                .toList();

                            // === BRAND NAME (match ke list; jika belum ada, fallback ke detail) ===
                            String? selectedBrandName;
                            if (_selectedBrandId != null) {
                              final idx = prov.brands.indexWhere(
                                (b) => b.idProductBrand == _selectedBrandId,
                              );
                              if (idx != -1 &&
                                  prov.brands[idx].name.isNotEmpty) {
                                selectedBrandName = prov.brands[idx].name;
                              } else {
                                selectedBrandName = widget
                                    .product
                                    .productBrand
                                    ?.name; // fallback
                              }
                            }

                            // === CATEGORY NAME (match ke list; jika belum ada, fallback ke detail) ===
                            String? selectedCategoryName;
                            if (_selectedCategoryId != null) {
                              final idx = prov.categories.indexWhere(
                                (c) =>
                                    c.idProductCategory == _selectedCategoryId,
                              );
                              if (idx != -1 &&
                                  prov.categories[idx].name.isNotEmpty) {
                                selectedCategoryName =
                                    prov.categories[idx].name;
                              } else {
                                selectedCategoryName = widget
                                    .product
                                    .productCategory
                                    ?.name; // fallback
                              }
                            }

                            return Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                _SelectFieldTile(
                                  label: 'Brand',
                                  placeholder: 'Pilih brand',
                                  valueText:
                                      (selectedBrandName?.isNotEmpty ?? false)
                                      ? selectedBrandName
                                      : null,
                                  onTap: () async {
                                    final picked = await showListPicker(
                                      context: context,
                                      title: 'Pilih Brand',
                                      options: brandOpts,
                                      selectedId: _selectedBrandId,
                                    );
                                    if (picked != null)
                                      setState(() => _selectedBrandId = picked);
                                  },
                                  errorText:
                                      (_attemptedSubmit &&
                                          _selectedBrandId == null)
                                      ? 'Required'
                                      : null,
                                ),
                                const SizedBox(height: 16),
                                _SelectFieldTile(
                                  label: 'Category',
                                  placeholder: 'Pilih category',
                                  valueText:
                                      (selectedCategoryName?.isNotEmpty ??
                                          false)
                                      ? selectedCategoryName
                                      : null,
                                  onTap: () async {
                                    final picked = await showListPicker(
                                      context: context,
                                      title: 'Pilih Category',
                                      options: catOpts,
                                      selectedId: _selectedCategoryId,
                                    );
                                    if (picked != null)
                                      setState(
                                        () => _selectedCategoryId = picked,
                                      );
                                  },
                                  errorText:
                                      (_attemptedSubmit &&
                                          _selectedCategoryId == null)
                                      ? 'Required'
                                      : null,
                                ),
                              ],
                            );
                          },
                        ),

                        const SizedBox(height: 16),

                        // PRICES (dynamic)
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
                                        (v == null || v.trim().isEmpty)
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
                                    validator: (v) =>
                                        (v == null || v.trim().isEmpty)
                                        ? 'Required'
                                        : null,
                                    onChanged: (t) {
                                      if (t.isEmpty) return;
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

                        // SKUs (dynamic)
                        const Text(
                          'SKUs',
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF111827),
                          ),
                        ),
                        const SizedBox(height: 8),
                        ..._skus.asMap().entries.map((entry) {
                          final i = entry.key;
                          final sku = entry.value;
                          return Container(
                            margin: const EdgeInsets.only(bottom: 12),
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF9FAFB),
                              border: Border.all(
                                color: const Color(0xFFE5E7EB),
                              ),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Column(
                              children: [
                                Row(
                                  children: [
                                    Expanded(
                                      child: Field(
                                        controller: sku.code,
                                        hintText: 'SKU Code',
                                        validator: (v) =>
                                            (v == null || v.trim().isEmpty)
                                            ? 'Required'
                                            : null,
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Field(
                                        controller: sku.price,
                                        hintText: 'SKU Price',
                                        keyboardType: TextInputType.number,
                                        inputFormatters: [
                                          FilteringTextInputFormatter
                                              .digitsOnly,
                                        ],
                                        validator: (v) =>
                                            (v == null || v.trim().isEmpty)
                                            ? 'Required'
                                            : null,
                                        onChanged: (t) {
                                          if (t.isEmpty) return;
                                          final sel = sku.price.selection;
                                          final f = NumberFormat.decimalPattern(
                                            'id',
                                          );
                                          final digits = t.replaceAll('.', '');
                                          final newText = f.format(
                                            int.tryParse(digits) ?? 0,
                                          );
                                          sku.price
                                            ..text = newText
                                            ..selection = sel.copyWith(
                                              baseOffset: newText.length,
                                              extentOffset: newText.length,
                                            );
                                        },
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    _IconBtn(
                                      icon: i == _skus.length - 1
                                          ? Icons.add_circle_outline
                                          : Icons.remove_circle_outline,
                                      onTap: () {
                                        setState(() {
                                          if (i == _skus.length - 1) {
                                            _skus.add(_SkuRow());
                                          } else {
                                            _skus.removeAt(i).dispose();
                                          }
                                        });
                                      },
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 8),
                                Align(
                                  alignment: Alignment.centerLeft,
                                  child: Text(
                                    'Attributes',
                                    style: Theme.of(context)
                                        .textTheme
                                        .bodyMedium
                                        ?.copyWith(fontWeight: FontWeight.w600),
                                  ),
                                ),
                                const SizedBox(height: 8),
                                ...sku.attrs.asMap().entries.map((aEntry) {
                                  final ai = aEntry.key;
                                  final attr = aEntry.value;
                                  return Padding(
                                    padding: EdgeInsets.only(
                                      bottom: ai == sku.attrs.length - 1
                                          ? 0
                                          : 8,
                                    ),
                                    child: Row(
                                      children: [
                                        Expanded(
                                          child: Field(
                                            controller: attr.name,
                                            hintText: 'Name',
                                            validator: (v) =>
                                                (v == null || v.trim().isEmpty)
                                                ? 'Required'
                                                : null,
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        Expanded(
                                          child: Field(
                                            controller: attr.value,
                                            hintText: 'Value',
                                            validator: (v) =>
                                                (v == null || v.trim().isEmpty)
                                                ? 'Required'
                                                : null,
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        _IconBtn(
                                          icon: ai == sku.attrs.length - 1
                                              ? Icons.add_circle_outline
                                              : Icons.remove_circle_outline,
                                          onTap: () {
                                            setState(() {
                                              if (ai == sku.attrs.length - 1) {
                                                sku.attrs.add(_AttrRow());
                                              } else {
                                                sku.attrs
                                                    .removeAt(ai)
                                                    .dispose();
                                              }
                                            });
                                          },
                                        ),
                                      ],
                                    ),
                                  );
                                }).toList(),
                              ],
                            ),
                          );
                        }).toList(),

                        const SizedBox(height: 20),
                      ],
                    ),
                  ),
                ),
              ),

              // FOOTER
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 40),
                child: SizedBox(
                  height: 48,
                  width: double.infinity,
                  child: ElevatedButton(
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
                    onPressed: _isValid ? _onSubmit : null,
                    child: const Text(
                      'Save changes',
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

  Widget _closeBtn(VoidCallback onTap) => InkWell(
    onTap: onTap,
    child: Container(
      padding: const EdgeInsets.all(6),
      decoration: BoxDecoration(
        color: Colors.black54,
        borderRadius: BorderRadius.circular(8),
      ),
      child: const Icon(Icons.close_rounded, color: Colors.white, size: 16),
    ),
  );

  Color _resolvePrimary(BuildContext context) {
    final themePrimary = Theme.of(context).colorScheme.primary;
    if (themePrimary != const Color(0xff6200ee)) return themePrimary;
    return const Color(0xFF4C6EF5);
  }
}

/// Reusable Field
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

/// ------- Dynamic rows helpers -------

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

class _SkuRow {
  final TextEditingController code = TextEditingController();
  final TextEditingController price = TextEditingController();
  final List<_AttrRow> attrs = [_AttrRow()];
  bool get isFilled =>
      code.text.trim().isNotEmpty && price.text.trim().isNotEmpty;
  void dispose() {
    code.dispose();
    price.dispose();
    for (final a in attrs) {
      a.dispose();
    }
  }
}

// === Signature showListPicker: GANTI dengan yang ini ===
Future<String?> showListPicker({
  required BuildContext context,
  required String title,
  required List<PickerOption> options,
  String? selectedId,

  // 🔽 parameter baru:
  bool enableCreate = false,
  String Function(String keyword)? createRowLabel, // teks baris CTA
  Future<PickerOption?> Function(String keyword)? onCreate, // aksi create
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
                            child: const Text('Tutup'),
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
                          hintText: 'Cari…',
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

                    // 🔽 CTA "Add new ..." ketika tidak ada hasil yang cocok
                    if (canShowCreate)
                      Material(
                        color: Colors.transparent,
                        child: ListTile(
                          onTap: () async {
                            // panggil onCreate, jika berhasil:
                            final created = await onCreate!(lastQuery);
                            if (created != null) {
                              setState(() {
                                options.add(created);
                                filtered.insert(0, created);
                                selectedId = created.id; // auto-select
                              });
                              // tutup sheet dan kembalikan id
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

Future<String?> pickBrandId(BuildContext context, {String? selectedId}) async {
  final prov = context.read<ProductProvider>();
  final opts = prov.brands
      .map((b) => PickerOption(id: b.idProductBrand, label: b.name))
      .toList();

  return showListPicker(
    context: context,
    title: 'Pilih Brand',
    options: opts,
    selectedId: selectedId,
    enableCreate: true,
    createRowLabel: (kw) => '"$kw" is not exists, add new brand',
    onCreate: (kw) async {
      final created = await prov.createBrandNoFetch(context, kw);
      if (created == null) return null;
      // Masukkan ke list sheet via return PickerOption
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
    title: 'Pilih Category',
    options: opts,
    selectedId: selectedId,
    enableCreate: true,
    createRowLabel: (kw) => '"$kw" is not exists, add new category',
    onCreate: (kw) async {
      final created = await prov.createCategoryNoFetch(context, kw);
      if (created == null) return null;
      return PickerOption(id: created.idProductCategory, label: created.name);
    },
  );
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
        height: 72, // sesuaikan bila perlu
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
                  enabled
                      ? Icons.add_photo_alternate_rounded
                      : Icons.add_photo_alternate_rounded,
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
  final String? valueText; // null → belum dipilih
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

class _AttrRow {
  final TextEditingController name = TextEditingController();
  final TextEditingController value = TextEditingController();
  bool get isFilled =>
      name.text.trim().isNotEmpty && value.text.trim().isNotEmpty;
  void dispose() {
    name.dispose();
    value.dispose();
  }
}

class _MoreButtonAnchored extends StatefulWidget {
  const _MoreButtonAnchored({this.onEdit, this.onDelete, Key? key})
    : super(key: key);
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;

  @override
  State<_MoreButtonAnchored> createState() => _MoreButtonAnchoredState();
}

class _MoreButtonAnchoredState extends State<_MoreButtonAnchored> {
  final LayerLink _link = LayerLink();
  final GlobalKey _btnKey = GlobalKey();
  OverlayEntry? _entry;
  bool _isOpen = false;

  void _toggleMenu() {
    if (_isOpen) {
      _hideMenu();
    } else {
      _showMenu();
    }
  }

  void _showMenu() {
    final box = _btnKey.currentContext!.findRenderObject() as RenderBox;
    final buttonSize = box.size;

    const double menuWidth = 200;
    const double gap = 8;

    final offset = Offset(
      buttonSize.width - menuWidth,
      buttonSize.height + gap,
    );

    _entry = OverlayEntry(
      builder: (context) {
        return Stack(
          children: [
            // backdrop tap-outside
            Positioned.fill(
              child: GestureDetector(
                behavior: HitTestBehavior.translucent,
                onTap: _hideMenu,
                onPanDown: (_) => _hideMenu(),
              ),
            ),
            CompositedTransformFollower(
              link: _link,
              showWhenUnlinked: false,
              offset: offset,
              child: _PopoverMenu(
                width: menuWidth,
                onEdit: () {
                  _hideMenu();
                  widget.onEdit?.call();
                },
                onDelete: () {
                  _hideMenu();
                  widget.onDelete?.call();
                },
              ),
            ),
          ],
        );
      },
    );

    Overlay.of(context).insert(_entry!);
    setState(() => _isOpen = true);
  }

  void _hideMenu() {
    _entry?.remove();
    _entry = null;
    if (_isOpen) setState(() => _isOpen = false);
  }

  @override
  void dispose() {
    _hideMenu();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bgColor = _isOpen ? const Color(0xFF4C6EF5) : const Color(0xFFF3F4F6);
    final iconColor = _isOpen ? Colors.white : const Color(0xFF4B5563);

    return CompositedTransformTarget(
      link: _link,
      child: InkWell(
        key: _btnKey,
        borderRadius: BorderRadius.circular(10),
        onTap: _toggleMenu,
        child: Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: bgColor,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: const Color(0xFFE5E7EB)),
          ),
          child: Icon(Icons.more_vert_rounded, color: iconColor),
        ),
      ),
    );
  }
}

class _PopoverMenu extends StatelessWidget {
  const _PopoverMenu({
    required this.width,
    required this.onEdit,
    required this.onDelete,
    Key? key,
  }) : super(key: key);

  final double width;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: Container(
        width: width,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: const Color(0xFFE5E7EB)),
          boxShadow: const [
            BoxShadow(
              blurRadius: 20,
              offset: Offset(0, 10),
              color: Color(0x1A000000), // shadow halus
            ),
          ],
        ),
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _MenuRow(icon: Icons.edit_rounded, label: 'Edit', onTap: onEdit),
            _MenuRow(
              icon: Icons.delete_rounded,
              label: 'Delete',
              isDestructive: true,
              onTap: onDelete,
            ),
          ],
        ),
      ),
    );
  }
}

class _MenuRow extends StatelessWidget {
  const _MenuRow({
    required this.icon,
    required this.label,
    required this.onTap,
    this.isDestructive = false,
    Key? key,
  }) : super(key: key);

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool isDestructive;

  @override
  Widget build(BuildContext context) {
    final color = isDestructive
        ? const Color(0xFFEF4444)
        : const Color(0xFF111827);
    final iconBg = isDestructive
        ? const Color(0xFFFFF1F2)
        : const Color(0xFFF3F4F6);

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        child: Row(
          children: [
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: iconBg,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(icon, size: 18, color: color),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                label,
                style: TextStyle(fontWeight: FontWeight.w600, color: color),
              ),
            ),
            const Icon(
              Icons.chevron_right_rounded,
              size: 18,
              color: Color(0xFF9CA3AF),
            ),
          ],
        ),
      ),
    );
  }
}
