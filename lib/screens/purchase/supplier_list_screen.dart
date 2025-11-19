import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:wa_blast/constants/app_colors.dart';
import 'package:wa_blast/providers/purchase_provider.dart';
import 'package:wa_blast/screens/purchase/form/supplier_form_sheets.dart';
import 'package:wa_blast/widgets/empty_state.dart';

class SupplierScreen extends StatefulWidget {
  const SupplierScreen({super.key});

  @override
  State<SupplierScreen> createState() => _SupplierScreenState();
}

class _SupplierScreenState extends State<SupplierScreen> {
  final _searchC = TextEditingController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<PurchaseProvider>().fetchSuppliers(context);
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
      appBar: AppBar(
        elevation: 0,
        scrolledUnderElevation: 0,
        backgroundColor: AppColors.white,
        foregroundColor: AppColors.textPrimary,
        title: const Text(
          'Suppliers',
          style: TextStyle(
            fontWeight: FontWeight.w700,
            color: AppColors.textPrimary,
          ),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded),
          onPressed: () => Navigator.of(
            context,
          ).popUntil((route) => route.settings.name == '/purchase'),
        ),
      ),
      backgroundColor: AppColors.white,
      body: SafeArea(
        child: Column(
          children: [
            // Search
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
              child: TextField(
                controller: _searchC,
                onChanged: (_) => setState(() {}),
                textInputAction: TextInputAction.search,
                decoration: InputDecoration(
                  hintText: 'Search supplier…',
                  hintStyle: const TextStyle(color: AppColors.textSecondary),
                  isDense: true,
                  filled: true,
                  fillColor: AppColors.inputBackground,
                  prefixIcon: const Icon(
                    Icons.search,
                    size: 20,
                    color: AppColors.textSecondary,
                  ),
                  suffixIcon: (_searchC.text.isNotEmpty)
                      ? IconButton(
                          icon: const Icon(
                            Icons.close_rounded,
                            size: 18,
                            color: AppColors.disabledFg,
                          ),
                          onPressed: () {
                            _searchC.clear();
                            setState(() {});
                          },
                        )
                      : null,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 12,
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderSide: const BorderSide(color: AppColors.divider),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderSide: const BorderSide(color: AppColors.blue400),
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
            ),

            Expanded(
              child: Consumer<PurchaseProvider>(
                builder: (context, prov, _) {
                  if (prov.loadingSuppliers) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  if (prov.supplierError != null) {
                    return _ErrorState(message: prov.supplierError!);
                  }

                  final q = _searchC.text.trim().toLowerCase();
                  final items = prov.suppliers.where((s) {
                    if (q.isEmpty) return true;
                    final name = s.name.toLowerCase();
                    final phone = (s.phone ?? '').toLowerCase();
                    final email = (s.email ?? '').toLowerCase();
                    final city = (s.city?.name ?? '').toLowerCase();
                    return name.contains(q) ||
                        phone.contains(q) ||
                        email.contains(q) ||
                        city.contains(q);
                  }).toList();

                  if (items.isEmpty) {
                    return EmptyState(
                      title: 'No Supplier',
                      description: 'Please add new supplier',
                    );
                  }

                  return RefreshIndicator(
                    onRefresh: () => prov.fetchSuppliers(context),
                    color: AppColors.primary,
                    backgroundColor: AppColors.card,
                    child: ListView.separated(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 16 + 56),
                      itemCount: items.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 8),
                      itemBuilder: (_, i) {
                        final s = items[i];
                        final subtitleParts = <String>[
                          if ((s.city?.name ?? '').isNotEmpty) s.city!.name,
                          if ((s.phone ?? '').isNotEmpty) s.phone!,
                          if ((s.email ?? '').isNotEmpty) s.email!,
                        ];
                        final subtitle = subtitleParts.join(' • ');
                        final logoUrl = _resolveLogoUrl(s.logoPath);
                        final isDeleting = prov.deletingSupplierIds.contains(
                          s.idSupplier,
                        );

                        return Container(
                          decoration: BoxDecoration(
                            color: AppColors.card,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: ListTile(
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            onTap: () {
                              Navigator.pushNamed(
                                context,
                                '/purchase/supplier/detail',
                                arguments: {'id': s.idSupplier},
                              );
                            },

                            leading: _Avatar(logoUrl: logoUrl),
                            title: Text(
                              s.name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontWeight: FontWeight.w700,
                                color: AppColors.textPrimary,
                              ),
                            ),
                            subtitle: (subtitle.isNotEmpty)
                                ? Text(
                                    subtitle,
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      color: AppColors.textSecondary,
                                    ),
                                  )
                                : null,
                            trailing: _MoreButtonAnchored(
                              enabled: !isDeleting,
                              onEdit: () async {
                                final saved = await showEditSupplierSheet(
                                  context,
                                  supplierId: s.idSupplier,
                                );
                                if (saved == true && context.mounted) {
                                  context
                                      .read<PurchaseProvider>()
                                      .fetchSuppliers(context);
                                }
                              },
                              onDelete: () async {
                                final confirm = await showDialog<bool>(
                                  context: context,
                                  builder: (context) {
                                    return _DeleteDialog(
                                      title: 'Delete Supplier',
                                      message:
                                          'Are you sure you want to permanently delete "${s.name}"?',
                                    );
                                  },
                                );

                                if (confirm == true) {
                                  final ok = await context
                                      .read<PurchaseProvider>()
                                      .removeSupplier(context, s.idSupplier);
                                  if (!context.mounted) return;
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      backgroundColor: ok
                                          ? AppColors.success
                                          : AppColors.danger,
                                      content: Text(
                                        ok
                                            ? 'Supplier deleted successfully'
                                            : (context
                                                      .read<PurchaseProvider>()
                                                      .deleteSupplierError ??
                                                  'Delete failed'),
                                        style: const TextStyle(
                                          color: AppColors.white,
                                        ),
                                      ),
                                    ),
                                  );
                                }
                              },
                            ),
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 8,
                            ),
                          ),
                        );
                      },
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),

      // Add button
      bottomNavigationBar: SafeArea(
        minimum: const EdgeInsets.fromLTRB(12, 8, 12, 20),
        child: SizedBox(
          height: 46,
          child: ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: AppColors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              minimumSize: const Size.fromHeight(46),
            ),
            onPressed: () async {
              final created = await showAddSupplierSheet(context);
              if (created == true && context.mounted) {
                context.read<PurchaseProvider>().fetchSuppliers(context);
              }
            },
            child: const Text(
              'Add new supplier',
              style: TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
        ),
      ),
    );
  }

  String? _resolveLogoUrl(String? logoPath) {
    if (logoPath == null || logoPath.isEmpty) return null;
    if (logoPath.startsWith('http')) return logoPath;
    const baseCdn = 'https://wave-cdn.eon.id'; // sesuaikan sesuai backend
    return '$baseCdn${logoPath.startsWith('/') ? '' : '/'}$logoPath';
  }
}

/// =======================
/// Widgets pendukung
/// =======================

class _Avatar extends StatelessWidget {
  const _Avatar({this.logoUrl});
  final String? logoUrl;

  @override
  Widget build(BuildContext context) {
    final has = (logoUrl != null && logoUrl!.isNotEmpty);
    return ClipRRect(
      borderRadius: BorderRadius.circular(10),
      child: Container(
        width: 44,
        height: 44,
        color: AppColors.greyBackground,
        child: has
            ? Image.network(
                logoUrl!,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => _ph(),
                loadingBuilder: (c, child, p) => p == null
                    ? child
                    : const Center(
                        child: SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                      ),
              )
            : _ph(),
      ),
    );
  }

  Widget _ph() => const Icon(Icons.store_rounded, color: AppColors.disabledFg);
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.message});
  final String message;

  @override
  Widget build(BuildContext context) {
    return ListView(
      children: [
        const SizedBox(height: 80),
        const Icon(
          Icons.error_outline_rounded,
          size: 60,
          color: AppColors.danger,
        ),
        const SizedBox(height: 12),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Text(
            message,
            textAlign: TextAlign.center,
            style: const TextStyle(color: AppColors.danger),
          ),
        ),
      ],
    );
  }
}

/// Dialog konfirmasi delete (diselaraskan dengan AppColors)
class _DeleteDialog extends StatelessWidget {
  const _DeleteDialog({required this.title, required this.message});
  final String title;
  final String message;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: AppColors.card,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: Row(
        children: const [
          Icon(Icons.warning_amber_rounded, color: AppColors.danger, size: 28),
          SizedBox(width: 8),
          Text(
            'Delete Supplier',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: AppColors.black,
            ),
          ),
        ],
      ),
      content: Text(
        message,
        style: const TextStyle(fontSize: 15, color: AppColors.primaryText),
      ),
      actionsPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          style: TextButton.styleFrom(
            foregroundColor: AppColors.textSecondary,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          ),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: () => Navigator.pop(context, true),
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.danger,
            foregroundColor: AppColors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          ),
          child: const Text('Delete'),
        ),
      ],
    );
  }
}

/// Kebab menu (3 titik) — disamakan dengan halaman product
class _MoreButtonAnchored extends StatefulWidget {
  const _MoreButtonAnchored({
    this.onEdit,
    this.onDelete,
    this.enabled = true,
    Key? key,
  }) : super(key: key);
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;
  final bool enabled;

  @override
  State<_MoreButtonAnchored> createState() => _MoreButtonAnchoredState();
}

class _MoreButtonAnchoredState extends State<_MoreButtonAnchored> {
  final LayerLink _link = LayerLink();
  final GlobalKey _btnKey = GlobalKey();
  OverlayEntry? _entry;
  bool _isOpen = false;

  void _toggleMenu() {
    if (!widget.enabled) return;
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
    final bgColor = _isOpen ? AppColors.primary : AppColors.greyBackground;
    final iconColor = _isOpen ? AppColors.white : AppColors.textSecondary;

    return CompositedTransformTarget(
      link: _link,
      child: InkWell(
        key: _btnKey,
        borderRadius: BorderRadius.circular(10),
        onTap: _toggleMenu,
        child: Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: widget.enabled ? bgColor : AppColors.greyBackground,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: AppColors.divider),
          ),
          child: Icon(
            Icons.more_vert_rounded,
            color: widget.enabled ? iconColor : AppColors.disabledFg,
          ),
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
          color: AppColors.card,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.divider),
          boxShadow: const [
            BoxShadow(
              blurRadius: 20,
              offset: Offset(0, 10),
              color: Color(0x1A000000),
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
    final color = isDestructive ? AppColors.danger : AppColors.textPrimary;
    final iconBg = AppColors.greyBackground;

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
              color: AppColors.disabledFg,
            ),
          ],
        ),
      ),
    );
  }
}
