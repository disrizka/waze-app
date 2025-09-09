import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:wa_blast/providers/product_provider.dart';
import 'package:wa_blast/widgets/app_snackbar.dart';

import '../constants/app_colors.dart';

class BrandListScreen extends StatelessWidget {
  const BrandListScreen({super.key});

  @override
  Widget build(BuildContext context) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<ProductProvider>().fetchProductBrands(context);
    });
    final colorPrimary = _resolvePrimary(context);

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.white,
        scrolledUnderElevation: 0,
        foregroundColor: const Color(0xFF1F2937),
        title: const Text(
          'Brand List',
          style: TextStyle(
            fontWeight: FontWeight.w700,
            color: Color(0xFF1F2937),
          ),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: () => context.read<ProductProvider>().refresh(context),
          child: Consumer<ProductProvider>(
            builder: (context, provider, _) {
              if (provider.loadingBrands) {
                return const Center(child: CircularProgressIndicator());
              }

              final items = provider.brands;

              if (items.isEmpty) {
                return _EmptyState(
                  colorPrimary: colorPrimary,
                ); // Menampilkan EmptyState jika kosong
              }

              return ListView.separated(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 24 + 56),
                itemCount: items.length,
                separatorBuilder: (_, __) => const SizedBox(height: 16),
                itemBuilder: (_, i) {
                  final brand = items[i]; // asumsi punya .id & .name
                  return _BrandTile(
                    id: brand.id,
                    title: brand.name,
                    onEdit: () {
                      showEditBrandSheet(
                        context,
                        brandId: brand.id,
                        initialName: brand.name,
                      );
                    },
                  );
                },
              );
            },
          ),
        ),
      ),
      bottomNavigationBar: SafeArea(
        minimum: const EdgeInsets.fromLTRB(12, 8, 12, 10),
        child: SizedBox(
          height: 48,
          child: ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primaryDark,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              minimumSize: const Size.fromHeight(48),
            ),
            onPressed: () async {
              await showAddBrandSheet(context);
            },
            child: const Text(
              'Add new brand',
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

class _BrandTile extends StatelessWidget {
  const _BrandTile({required this.id, required this.title, this.onEdit});

  final String id;
  final String title;
  final VoidCallback? onEdit;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        const Icon(Icons.sell, size: 40, color: Color(0xFF4C6EF5)),
        const SizedBox(width: 14),
        Expanded(
          child: Text(
            title,
            style: const TextStyle(
              fontWeight: FontWeight.w700,
              color: Color(0xFF111827),
            ),
          ),
        ),
        const SizedBox(width: 12),
        SizedBox(
          height: 36,
          child: OutlinedButton(
            onPressed: onEdit,
            style: OutlinedButton.styleFrom(
              foregroundColor: const Color(0xFF4C6EF5),
              side: const BorderSide(color: Color(0xFFE5E7EB)),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 14),
            ),
            child: const Text(
              'Edit',
              style: TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
        ),
      ],
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.colorPrimary});
  final Color colorPrimary;

  @override
  Widget build(BuildContext context) {
    return Column(
      // supaya RefreshIndicator bisa bekerja
      crossAxisAlignment: CrossAxisAlignment.center,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        // Gambar di tengah
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
            'No Brands',
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
            'Please to create and add your brand\nto the application',
            textAlign: TextAlign.center,
            style: TextStyle(height: 1.4, color: Color(0xFF6B7280)),
          ),
        ),
        const SizedBox(height: 24),
      ],
    );
  }
}

enum BrandSheetMode { create, edit }

Future<void> showAddBrandSheet(BuildContext context) {
  return showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.white,
    useSafeArea: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
    ),
    builder: (_) => const _BrandSheet(mode: BrandSheetMode.create),
  );
}

Future<void> showEditBrandSheet(
  BuildContext context, {
  required String brandId,
  required String initialName,
}) {
  return showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.white,
    useSafeArea: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
    ),
    builder: (_) => _BrandSheet(
      mode: BrandSheetMode.edit,
      brandId: brandId,
      initialName: initialName,
    ),
  );
}

class _BrandSheet extends StatefulWidget {
  const _BrandSheet({required this.mode, this.brandId, this.initialName});

  final BrandSheetMode mode;
  final String? brandId;
  final String? initialName;

  @override
  State<_BrandSheet> createState() => _BrandSheetState();
}

class _BrandSheetState extends State<_BrandSheet> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;

  bool _isValid = false;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.initialName ?? '');
    _nameController.addListener(_revalidate);
    // validasi awal
    WidgetsBinding.instance.addPostFrameCallback((_) => _revalidate());
  }

  void _revalidate() {
    final ok = (_formKey.currentState?.validate() ?? false);
    if (ok != _isValid) setState(() => _isValid = ok);
  }

  @override
  void dispose() {
    _nameController.removeListener(_revalidate);
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _submit(BuildContext context) async {
    if (!(_formKey.currentState?.validate() ?? false)) return;

    final name = _nameController.text.trim();
    final provider = context.read<ProductProvider>();

    if (widget.mode == BrandSheetMode.create) {
      await provider.addProductBrand(context, name);
      if (!mounted) return;
      Navigator.of(context).pop();
      AppSnackbar.show(
        context,
        type: AppSnackType.success,
        title: 'Added',
        message: 'Brand added successfully.',
      );
    } else {
      // EDIT MODE
      final id = widget.brandId!;
      // Pastikan provider punya method ini, atau sesuaikan namanya.
      await provider.updateProductBrand(context, id, name);
      if (!mounted) return;
      Navigator.of(context).pop();
      AppSnackbar.show(
        context,
        type: AppSnackType.success,
        title: name,
        message: 'Brand updated successfully.',
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    final isEdit = widget.mode == BrandSheetMode.edit;
    final header = isEdit ? 'Edit Brand' : 'New Brand';
    final buttonText = isEdit ? 'Save changes' : 'Add new brand';

    return Padding(
      padding: EdgeInsets.only(
        left: 16,
        right: 16,
        top: 8,
        bottom: bottomInset > 0 ? bottomInset : 16,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 36,
              height: 4,
              margin: const EdgeInsets.only(bottom: 12),
              decoration: BoxDecoration(
                color: const Color(0xFFE5E7EB),
                borderRadius: BorderRadius.circular(99),
              ),
            ),
          ),
          Row(
            children: [
              Expanded(
                child: Text(
                  header,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              IconButton(
                tooltip: 'Close',
                onPressed: () => Navigator.of(context).pop(),
                icon: const Icon(Icons.close_rounded),
              ),
            ],
          ),
          const SizedBox(height: 8),

          Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Brand Name',
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _nameController,
                  autovalidateMode: AutovalidateMode.onUserInteraction,
                  textInputAction: TextInputAction.done,
                  onFieldSubmitted: (_) {
                    if (_isValid) _submit(context);
                  },
                  validator: (value) => (value?.trim().isEmpty ?? true)
                      ? 'Brand name is required'
                      : null,
                  decoration: const InputDecoration(
                    hintText: 'E.g Apple',
                    filled: true,
                    fillColor: Color(0xFFF3F4F6),
                    contentPadding: EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 14,
                    ),
                    border: OutlineInputBorder(
                      borderSide: BorderSide.none,
                      borderRadius: BorderRadius.all(Radius.circular(12)),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _isValid
                          ? AppColors.primaryDark
                          : const Color(0xFFE5E7EB),
                      foregroundColor: _isValid
                          ? Colors.white
                          : const Color(0xFF9CA3AF),
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    onPressed: _isValid ? () => _submit(context) : null,
                    child: Text(
                      buttonText,
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}
