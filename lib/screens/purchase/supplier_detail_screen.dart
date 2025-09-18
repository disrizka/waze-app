// lib/screens/purchase/supplier_detail_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import 'package:wa_blast/constants/app_colors.dart';
import 'package:wa_blast/providers/purchase_provider.dart';
import 'package:wa_blast/screens/purchase/form/supplier_form_sheets.dart';

class SupplierDetailScreen extends StatefulWidget {
  const SupplierDetailScreen({super.key, required this.supplierId});
  final String supplierId;

  @override
  State<SupplierDetailScreen> createState() => _SupplierDetailScreenState();
}

class _SupplierDetailScreenState extends State<SupplierDetailScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<PurchaseProvider>().fetchSupplierDetail(
        context,
        widget.supplierId,
      );
    });
  }

  Future<void> _refresh() async {
    await context.read<PurchaseProvider>().fetchSupplierDetail(
      context,
      widget.supplierId,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<PurchaseProvider>(
      builder: (context, prov, _) {
        final d = prov.supplierDetail;
        final isLoading = prov.loadingSupplierDetail;
        final error = prov.supplierDetailError;

        return Scaffold(
          backgroundColor: AppColors.white,
          appBar: AppBar(
            centerTitle: false,
            elevation: 0,
            scrolledUnderElevation: 0,
            backgroundColor: AppColors.white,
            foregroundColor: AppColors.textPrimary,
            title: Text(
              'Supplier Detail',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
              ),
            ),
            actions: [
              if (d != null)
                IconButton(
                  tooltip: 'Edit',
                  icon: const Icon(Icons.edit_rounded),
                  onPressed: () async {
                    final saved = await showEditSupplierSheet(
                      context,
                      supplierId: d.idSupplier,
                    );
                    if (saved == true && mounted) _refresh();
                  },
                ),
              if (d != null)
                IconButton(
                  tooltip: 'Delete',
                  icon: const Icon(Icons.delete_outline_rounded),
                  onPressed: () => _confirmDelete(context, d.idSupplier, prov),
                ),
            ],
          ),
          body: RefreshIndicator(
            onRefresh: _refresh,
            color: AppColors.primary,
            backgroundColor: AppColors.card,
            child: isLoading
                ? const _Loading()
                : (error != null)
                ? _Error(message: error, onRetry: _refresh)
                : (d == null)
                ? const _Empty()
                : ListView(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
                    children: [
                      // HEADER KOMPAK
                      Row(
                        children: [
                          Hero(
                            tag: 'supplier-logo-${d.name}',
                            child: _Logo(logoPath: d.logoPath),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  d.name,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.w800,
                                    color: AppColors.textPrimary,
                                  ),
                                ),
                                const SizedBox(height: 6),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),

                      // INFO: RINGKAS DALAM LISTTILE
                      _Card(
                        child: Column(
                          children: [
                            if ((d.phone ?? '').isNotEmpty)
                              _InfoTile(
                                icon: Icons.call_rounded,
                                title: d.phone!,
                                onTap: () => _copy('Phone', d.phone!),
                              ),
                            if ((d.email ?? '').isNotEmpty)
                              _InfoTile(
                                icon: Icons.alternate_email_rounded,
                                title: d.email!,
                                onTap: () => _copy('Email', d.email!),
                              ),
                            if ((d.city?.name ?? '').isNotEmpty)
                              _InfoTile(
                                icon: Icons.location_city_rounded,
                                title: d.city!.name,
                              ),
                          ],
                        ),
                      ),
                      if ((d.address ?? '').trim().isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: 12.0),
                          child: _Card(
                            child: _InfoTile(
                              icon: Icons.map_rounded,
                              title: 'Address',
                              subtitle: d.address!.trim(),
                              trailing: IconButton(
                                icon: const Icon(
                                  Icons.copy_rounded,
                                  color: AppColors.textSecondary,
                                ),
                                onPressed: () => _copy('Address', d.address!),
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
          ),
        );
      },
    );
  }

  Future<void> _confirmDelete(
    BuildContext context,
    String supplierId,
    PurchaseProvider prov,
  ) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => const _DeleteDialog(
        title: 'Delete Supplier',
        message: 'Are you sure you want to permanently delete this supplier?',
      ),
    );
    if (ok != true) return;

    final success = await prov.removeSupplier(context, supplierId);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: success ? AppColors.success : AppColors.danger,
        content: Text(
          success
              ? 'Supplier deleted'
              : (prov.deleteSupplierError ?? 'Delete failed'),
          style: const TextStyle(color: AppColors.white),
        ),
      ),
    );
    if (success) Navigator.pop(context);
  }

  Future<void> _copy(String label, String v) async {
    await Clipboard.setData(ClipboardData(text: v));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('$label copied'),
        backgroundColor: AppColors.primary,
      ),
    );
  }
}

/// ====== UI MINIMAL ======

class _Logo extends StatelessWidget {
  const _Logo({this.logoPath});
  final String? logoPath;

  @override
  Widget build(BuildContext context) {
    final url = _resolveLogoUrl(logoPath);
    final has = url != null && url.isNotEmpty;
    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: Container(
        width: 56,
        height: 56,
        color: AppColors.greyBackground,
        child: has
            ? Image.network(
                url!,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => _ph(),
                loadingBuilder: (c, child, p) =>
                    p == null ? child : _ph(loading: true),
              )
            : _ph(),
      ),
    );
  }

  Widget _ph({bool loading = false}) => Center(
    child: loading
        ? const SizedBox(
            width: 16,
            height: 16,
            child: CircularProgressIndicator(strokeWidth: 2),
          )
        : const Icon(Icons.store_rounded, color: AppColors.disabledFg),
  );

  String? _resolveLogoUrl(String? path) {
    if (path == null || path.isEmpty) return null;
    if (path.startsWith('http')) return path;
    const base = 'https://wave-cdn.eon.id';
    return '$base${path.startsWith('/') ? '' : '/'}$path';
  }
}

class _MiniChip extends StatelessWidget {
  const _MiniChip(this.icon, this.label);
  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.inputBackground,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: AppColors.divider),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: AppColors.textSecondary),
          const SizedBox(width: 6),
          Text(
            label,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: AppColors.textPrimary,
            ),
          ),
        ],
      ),
    );
  }
}

class _Card extends StatelessWidget {
  const _Card({required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.divider),
      ),
      child: child,
    );
  }
}

class _InfoTile extends StatelessWidget {
  const _InfoTile({
    required this.icon,
    required this.title,
    this.subtitle,
    this.trailing,
    this.onTap,
  });

  final IconData icon;
  final String title;
  final String? subtitle;
  final Widget? trailing;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final titleStyle = const TextStyle(
      fontWeight: FontWeight.w700,
      color: AppColors.textPrimary,
    );
    final subtitleStyle = const TextStyle(
      color: AppColors.textSecondary,
      height: 1.35,
    );

    return ListTile(
      onTap: onTap,
      dense: true,
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      leading: Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          color: AppColors.greyBackground,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(icon, color: AppColors.textSecondary, size: 18),
      ),
      title: Text(
        title,
        style: titleStyle,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      subtitle: (subtitle == null || subtitle!.isEmpty)
          ? null
          : Text(subtitle!, style: subtitleStyle),
      trailing: trailing,
    );
  }
}

class _Loading extends StatelessWidget {
  const _Loading();

  @override
  Widget build(BuildContext context) {
    Widget bar(double w, {double h = 12}) => Container(
      width: w,
      height: h,
      decoration: BoxDecoration(
        color: AppColors.greyBackground,
        borderRadius: BorderRadius.circular(8),
      ),
    );
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      children: [
        Row(
          children: [
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: AppColors.greyBackground,
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(child: bar(double.infinity)),
          ],
        ),
        const SizedBox(height: 16),
        Container(
          decoration: BoxDecoration(
            color: AppColors.card,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.divider),
          ),
          padding: const EdgeInsets.all(12),
          child: Column(
            children: [
              bar(double.infinity),
              const SizedBox(height: 10),
              bar(double.infinity),
            ],
          ),
        ),
      ],
    );
  }
}

class _Error extends StatelessWidget {
  const _Error({required this.message, required this.onRetry});
  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return ListView(
      children: [
        const SizedBox(height: 80),
        const Icon(
          Icons.error_outline_rounded,
          size: 56,
          color: AppColors.danger,
        ),
        const SizedBox(height: 10),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Text(
            message,
            textAlign: TextAlign.center,
            style: const TextStyle(color: AppColors.danger),
          ),
        ),
        const SizedBox(height: 12),
        Center(
          child: OutlinedButton.icon(
            onPressed: onRetry,
            icon: const Icon(Icons.refresh_rounded),
            label: const Text('Retry'),
          ),
        ),
      ],
    );
  }
}

class _Empty extends StatelessWidget {
  const _Empty();

  @override
  Widget build(BuildContext context) {
    return ListView(
      children: const [
        SizedBox(height: 80),
        Icon(
          Icons.inventory_2_rounded,
          size: 56,
          color: AppColors.textSecondary,
        ),
        SizedBox(height: 10),
        Center(
          child: Text(
            'No data',
            style: TextStyle(color: AppColors.textSecondary),
          ),
        ),
      ],
    );
  }
}

/// Dialog konfirmasi delete (tetap minimal)
class _DeleteDialog extends StatelessWidget {
  const _DeleteDialog({required this.title, required this.message});
  final String title;
  final String message;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: AppColors.card,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      title: Text(
        title,
        style: const TextStyle(
          fontWeight: FontWeight.w800,
          color: AppColors.textPrimary,
        ),
      ),
      content: Text(
        message,
        style: const TextStyle(color: AppColors.textPrimary),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          style: ElevatedButton.styleFrom(backgroundColor: AppColors.danger),
          onPressed: () => Navigator.pop(context, true),
          child: const Text('Delete'),
        ),
      ],
    );
  }
}
