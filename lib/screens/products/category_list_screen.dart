import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:wa_blast/providers/product_provider.dart';
import 'package:wa_blast/widgets/app_snackbar.dart';
import 'package:wa_blast/widgets/empty_state.dart';

import '../../constants/app_colors.dart';

class CategoryListScreen extends StatefulWidget {
  const CategoryListScreen({super.key});

  @override
  State<CategoryListScreen> createState() => _CategoryListScreenState();
}

class _CategoryListScreenState extends State<CategoryListScreen> {
  final TextEditingController _searchC = TextEditingController();
  String _query = '';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<ProductProvider>().fetchProductCategories(context);
    });
    _searchC.addListener(() {
      final next = _searchC.text.trim();
      if (next != _query) setState(() => _query = next);
    });
  }

  @override
  void dispose() {
    _searchC.dispose();
    super.dispose();
  }

  Future<void> _onRefresh() async {
    await context.read<ProductProvider>().fetchProductCategories(context);
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
          'Category List',
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
              onRefresh: _onRefresh,
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
              await showAddCategorySheet(context);
              if (!mounted) return;
              await context.read<ProductProvider>().fetchProductCategories(
                context,
              );
            },
            child: const Text(
              'Add new category',
              style: TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildBody(ProductProvider provider) {
    final all = provider.categories;
    final q = _query.trim();
    final lowerQ = q.toLowerCase();

    final filtered = (lowerQ.isEmpty)
        ? all
        : all.where((c) => (c.name).toLowerCase().contains(lowerQ)).toList();

    return CustomScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      slivers: [
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
            child: _SearchHeader(
              controller: _searchC,
              onClear: () => _searchC.clear(),
            ),
          ),
        ),

        // ===== Loading =====
        if (provider.loadingCategories)
          SliverToBoxAdapter(child: _buildSkeletonList())
        else ...[
          // ===== Empty: no category at all =====
          if (all.isEmpty && q.isEmpty)
            SliverFillRemaining(
              hasScrollBody: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 24, 16, 24),
                child: Column(
                  children: const [
                    SizedBox(height: 8),
                    Expanded(
                      child: Center(
                        child: EmptyState(
                          title: 'No Category',
                          description: 'Please add new category',
                        ),
                      ),
                    ),
                    SizedBox(height: 80),
                  ],
                ),
              ),
            )
          // ===== Empty: no result search =====
          else if (filtered.isEmpty)
            SliverFillRemaining(
              hasScrollBody: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
                child: Column(
                  children: [
                    const SizedBox(height: 12),
                    _NoResultTile(query: q),
                    const SizedBox(height: 12),
                    const Spacer(),
                    const SizedBox(height: 80),
                  ],
                ),
              ),
            )
          // ===== List =====
          else
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 6, 16, 24 + 56),
              sliver: SliverList.separated(
                itemCount: filtered.length,
                separatorBuilder: (_, __) => const SizedBox(height: 12),
                itemBuilder: (_, index) {
                  final cat = filtered[index];
                  return _CategoryTile(
                    id: cat.id,
                    title: cat.name,
                    onEdit: () async {
                      await showEditCategorySheet(
                        context,
                        categoryId: cat.id,
                        initialName: cat.name,
                      );
                      if (!context.mounted) return;
                      await context
                          .read<ProductProvider>()
                          .fetchProductCategories(context);
                    },
                    onDelete: () async {
                      final confirmed = await _confirmDelete(
                        context,
                        title: 'Delete Category',
                        message:
                            'Are you sure you want to delete "${cat.name}"? This action cannot be undone.',
                      );
                      if (confirmed != true) return;

                      final ok = await context
                          .read<ProductProvider>()
                          .deleteProductCategory(context, cat.id);

                      if (!context.mounted) return;

                      if (ok) {
                        AppSnackbar.show(
                          context,
                          type: AppSnackType.success,
                          title: 'Deleted',
                          message: 'Category has been deleted.',
                        );
                        await context
                            .read<ProductProvider>()
                            .fetchProductCategories(context);
                      } else {
                        AppSnackbar.show(
                          context,
                          type: AppSnackType.error,
                          title: 'Failed',
                          message:
                              provider.lastError ??
                              'Failed to delete category.',
                        );
                      }
                    },
                  );
                },
              ),
            ),
        ],
      ],
    );
  }

  Widget _buildSkeletonList() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      child: Column(
        children: List.generate(6, (i) {
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Container(
              height: 64,
              decoration: BoxDecoration(
                color: const Color(0xFFF3F4F6),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFE5E7EB)),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: const Color(0xFFE5E7EB)),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          height: 12,
                          width: double.infinity,
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(6),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Container(
                          height: 10,
                          width: 160,
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(6),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          );
        }),
      ),
    );
  }
}

class _SearchHeader extends StatelessWidget {
  const _SearchHeader({this.controller, this.onClear});

  final TextEditingController? controller;
  final VoidCallback? onClear;

  @override
  Widget build(BuildContext context) {
    final hasText = controller != null && controller!.text.trim().isNotEmpty;

    return TextField(
      controller: controller,
      textInputAction: TextInputAction.search,
      decoration: InputDecoration(
        hintText: 'Search category name…',
        isDense: true,
        filled: true,
        fillColor: const Color(0xFFF3F4F6),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 14,
          vertical: 12,
        ),
        enabledBorder: OutlineInputBorder(
          borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
          borderRadius: BorderRadius.circular(12),
        ),
        focusedBorder: OutlineInputBorder(
          borderSide: const BorderSide(color: Color(0xFFCBD5E1)),
          borderRadius: BorderRadius.circular(12),
        ),
        prefixIcon: const Icon(Icons.search_rounded, size: 20),
        suffixIcon: hasText
            ? IconButton(
                tooltip: 'Clear',
                onPressed: onClear,
                icon: const Icon(Icons.close_rounded, size: 18),
              )
            : null,
      ),
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

class _CategoryTile extends StatelessWidget {
  const _CategoryTile({
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
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: const Color(0xFFEFF6FF),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(
              Icons.category_rounded,
              size: 20,
              color: Color(0xFF4C6EF5),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontWeight: FontWeight.w700,
                color: Color(0xFF111827),
              ),
            ),
          ),
          const SizedBox(width: 10),
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
          SizedBox(
            height: 36,
            child: OutlinedButton.icon(
              onPressed: onDelete,
              icon: const Icon(Icons.delete_rounded, size: 18),
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
      ),
    );
  }
}

// =============================
// ADD / EDIT CATEGORY SHEETS
// =============================

enum CategorySheetMode { create, edit }

Future<void> showAddCategorySheet(BuildContext context) {
  return showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.white,
    useSafeArea: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
    ),
    builder: (_) => const _CategorySheet(mode: CategorySheetMode.create),
  );
}

Future<void> showEditCategorySheet(
  BuildContext context, {
  required String categoryId,
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
    builder: (_) => _CategorySheet(
      mode: CategorySheetMode.edit,
      categoryId: categoryId,
      initialName: initialName,
    ),
  );
}

class _CategorySheet extends StatefulWidget {
  const _CategorySheet({required this.mode, this.categoryId, this.initialName});

  final CategorySheetMode mode;
  final String? categoryId;
  final String? initialName;

  @override
  State<_CategorySheet> createState() => _CategorySheetState();
}

class _CategorySheetState extends State<_CategorySheet> {
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

    if (widget.mode == CategorySheetMode.create) {
      final ok = await provider.addProductCategory(context, name);
      if (!mounted) return;
      Navigator.of(context).pop();
      if (ok) {
        AppSnackbar.show(
          context,
          type: AppSnackType.success,
          title: 'Added',
          message: 'Category added successfully.',
        );
      } else {
        AppSnackbar.show(
          context,
          type: AppSnackType.error,
          title: 'Failed',
          message: provider.lastError ?? 'Failed to add category.',
        );
      }
    } else {
      final id = widget.categoryId!;
      final ok = await provider.updateProductCategory(context, id, name);
      if (!mounted) return;
      Navigator.of(context).pop();
      if (ok) {
        AppSnackbar.show(
          context,
          type: AppSnackType.success,
          title: name,
          message: 'Category updated successfully.',
        );
      } else {
        AppSnackbar.show(
          context,
          type: AppSnackType.error,
          title: 'Failed',
          message: provider.lastError ?? 'Failed to update category.',
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    final isEdit = widget.mode == CategorySheetMode.edit;
    final header = isEdit ? 'Edit Category' : 'New Category';
    final buttonText = isEdit ? 'Save changes' : 'Add new category';

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
                  'Category Name',
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
                      ? 'Category name is required'
                      : null,
                  decoration: const InputDecoration(
                    hintText: 'E.g Electronics',
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
