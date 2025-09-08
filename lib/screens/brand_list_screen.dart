import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:wa_blast/providers/product_provider.dart';

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
              if (provider.isLoading) {
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
                separatorBuilder: (_, __) => const SizedBox(height: 12),
                itemBuilder: (_, i) {
                  final brand = items[i];
                  return _BrandTile(
                    title: brand.name,
                    onEdit: () {
                      // Action to edit brand if necessary
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Edit "${brand.name}"')),
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
              backgroundColor: AppColors.primary,
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
  const _BrandTile({required this.title, this.onEdit});

  final String title;
  final VoidCallback? onEdit;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Icon(Icons.tag, size: 40, color: Color(0xFF4C6EF5)),
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
        // Align(
        //   alignment: Alignment.center,
        //   child: SizedBox(
        //     height: 36,
        //     child: ElevatedButton(
        //       onPressed: onEdit,
        //       style: ElevatedButton.styleFrom(
        //         backgroundColor: const Color(0xFF4C6EF5),
        //         foregroundColor: Colors.white,
        //         elevation: 0,
        //         padding: const EdgeInsets.symmetric(horizontal: 16),
        //         shape: RoundedRectangleBorder(
        //           borderRadius: BorderRadius.circular(10),
        //         ),
        //       ),
        //       child: const Text(
        //         'Edit',
        //         style: TextStyle(fontWeight: FontWeight.w600),
        //       ),
        //     ),
        //   ),
        // ),
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

Future<void> showAddBrandSheet(BuildContext context) {
  return showModalBottomSheet(
    context: context,
    isScrollControlled: false,
    backgroundColor: Colors.white,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (_) => const _AddBrandSheet(),
  );
}

class _AddBrandSheet extends StatefulWidget {
  const _AddBrandSheet();

  @override
  State<_AddBrandSheet> createState() => _AddBrandSheetState();
}

class _AddBrandSheetState extends State<_AddBrandSheet> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();

  bool get _isValid => _formKey.currentState?.validate() ?? false;

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _addBrand(BuildContext context) async {
    if (_isValid) {
      final brandName = _nameController.text.trim();

      await context.read<ProductProvider>().addProductBrand(context, brandName);
      Navigator.of(context).pop();
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Brand added successfully')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 10),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'New Brand',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 16),
            const Text(
              'Brand Name',
              style: TextStyle(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            TextFormField(
              controller: _nameController,
              validator: (value) => value?.trim().isEmpty ?? true
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
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton(
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
                onPressed: _isValid ? () => _addBrand(context) : null,
                child: const Text(
                  'Add new brand',
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
