import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:wa_blast/providers/product_provider.dart';
import 'package:wa_blast/widgets/app_snackbar.dart';
import 'package:wa_blast/widgets/empty_state.dart';

import '../../constants/app_colors.dart';

class BrandListScreen extends StatefulWidget {
  const BrandListScreen({super.key});

  @override
  State<BrandListScreen> createState() => _BrandListScreenState();
}

class _BrandListScreenState extends State<BrandListScreen> {
  final TextEditingController _searchC = TextEditingController();
  String _query = '';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<ProductProvider>().fetchProductBrands(context);
    });
    _searchC.addListener(() {
      final next = _searchC.text.trim();
      if (next != _query) {
        setState(() => _query = next);
      }
    });
  }

  @override
  void dispose() {
    _searchC.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
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
          onPressed: () => Navigator.of(
            context,
          ).popUntil((route) => route.settings.name == '/product'),
        ),
      ),
      body: SafeArea(
        child: Consumer<ProductProvider>(
          builder: (context, provider, _) {
            return RefreshIndicator(
              onRefresh: () => context.read<ProductProvider>().refresh(context),
              child: _buildBody(provider),
            );
          },
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

  Widget _buildBody(ProductProvider provider) {
    if (provider.loadingBrands) {
      return const Center(child: CircularProgressIndicator());
    }

    final all = provider.brands;
    final lowerQ = _query.toLowerCase();
    final filtered = (lowerQ.isEmpty)
        ? all
        : all.where((b) => (b.name).toLowerCase().contains(lowerQ)).toList();

    // Jika belum ada brand sama sekali dan tidak sedang mencari
    if (all.isEmpty && _query.isEmpty) {
      return ListView(
        padding: EdgeInsets.zero,
        children: const [
          _SearchHeader(),
          SizedBox(height: 8),
          EmptyState(title: 'No Brand', description: 'Please add new brand'),
          SizedBox(height: 200), // biar bisa pull to refresh
        ],
      );
    }

    // Tampilkan list dengan header search sebagai item pertama
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24 + 56),
      itemCount: filtered.length + 1, // +1 untuk header search
      separatorBuilder: (_, __) => const SizedBox(height: 16),
      itemBuilder: (_, index) {
        if (index == 0) {
          return _SearchHeader(
            controller: _searchC,
            onClear: () {
              _searchC.clear();
            },
          );
        }

        // Jika tidak ada hasil pencarian
        if (filtered.isEmpty) {
          return Padding(
            padding: const EdgeInsets.only(top: 32),
            child: _NoResultTile(query: _query),
          );
        }

        final brand = filtered[index - 1];
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
          onDelete: () async {
            final confirmed = await _confirmDelete(
              context,
              title: 'Delete Brand',
              message:
                  'Are you sure you want to delete "${brand.name}"? This action cannot be undone.',
            );
            if (confirmed != true) return;

            await context.read<ProductProvider>().deleteProductBrand(
              context,
              brand.id,
            );

            if (!context.mounted) return;
            AppSnackbar.show(
              context,
              type: AppSnackType.success,
              title: 'Deleted',
              message: 'Brand has been deleted.',
            );
          },
        );
      },
    );
  }
}

class _SearchHeader extends StatelessWidget {
  const _SearchHeader({this.controller, this.onClear});

  final TextEditingController? controller;
  final VoidCallback? onClear;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 8),
        TextField(
          controller: controller,
          textInputAction: TextInputAction.search,
          decoration: InputDecoration(
            hintText: 'Search brand name…',
            filled: true,
            fillColor: const Color(0xFFF3F4F6),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 14,
              vertical: 12,
            ),
            border: const OutlineInputBorder(
              borderSide: BorderSide.none,
              borderRadius: BorderRadius.all(Radius.circular(12)),
            ),
            prefixIcon: const Icon(Icons.search_rounded),
            suffixIcon: (controller != null && controller!.text.isNotEmpty)
                ? IconButton(
                    tooltip: 'Clear',
                    onPressed: onClear,
                    icon: const Icon(Icons.close_rounded),
                  )
                : null,
          ),
        ),
      ],
    );
  }
}

class _NoResultTile extends StatelessWidget {
  const _NoResultTile({required this.query});
  final String query;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 18),
      decoration: BoxDecoration(
        color: const Color(0xFFF9FAFB),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Row(
        children: [
          const Icon(Icons.search_off_rounded),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'No results for “$query”.',
              style: const TextStyle(
                color: Color(0xFF6B7280),
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _BrandTile extends StatelessWidget {
  const _BrandTile({
    required this.id,
    required this.title,
    this.onEdit,
    this.onDelete,
  });

  final String id;
  final String title;
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;

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
        // Edit
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
        const SizedBox(width: 8),
        // Delete
        SizedBox(
          height: 36,
          child: OutlinedButton.icon(
            onPressed: onDelete,
            label: const Text(
              'Delete',
              style: TextStyle(fontWeight: FontWeight.w600),
            ),
            style: OutlinedButton.styleFrom(
              foregroundColor: const Color(0xFFEF4444),
              side: const BorderSide(color: Color(0xFFF3F4F6)),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 12),
            ),
          ),
        ),
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
      final id = widget.brandId!;
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

Future<bool?> _confirmDelete(
  BuildContext context, {
  required String title,
  required String message,
}) {
  return showDialog<bool>(
    context: context,
    builder: (context) {
      return AlertDialog(
        backgroundColor: Colors.white,
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            style: TextButton.styleFrom(
              foregroundColor: const Color(0xFF4C6EF5),
            ),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(
              foregroundColor: const Color(0xFFEF4444),
            ),
            child: const Text('Delete'),
          ),
        ],
      );
    },
  );
}
