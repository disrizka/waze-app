// lib/screens/store/store_list_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:wa_blast/constants/app_colors.dart';
import 'package:wa_blast/providers/store_provider.dart';
import 'package:wa_blast/widgets/app_snackbar.dart';
import 'package:wa_blast/widgets/empty_state.dart';
import 'package:wa_blast/widgets/reusable_pickers.dart';

class StoreListScreen extends StatefulWidget {
  const StoreListScreen({super.key});

  @override
  State<StoreListScreen> createState() => _StoreListScreenState();
}

class _StoreListScreenState extends State<StoreListScreen> {
  final TextEditingController _searchC = TextEditingController();
  String _query = '';

  @override
  void initState() {
    super.initState();
    // fetch setelah frame pertama
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<StoreProvider>().fetchStoreLocations(context);
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
          'Store Locations',
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
        child: Consumer<StoreProvider>(
          builder: (context, p, _) {
            if (p.loadingList) {
              return const Center(child: CircularProgressIndicator());
            }

            final all = p.stores;
            final lq = _query.toLowerCase();
            final filtered = (lq.isEmpty)
                ? all
                : all.where((s) {
                    final name = s.name.toLowerCase();
                    final city = (s.city?.name ?? '').toLowerCase();
                    final prov = (s.city?.province?.name ?? '').toLowerCase();
                    return name.contains(lq) ||
                        city.contains(lq) ||
                        prov.contains(lq);
                  }).toList();

            if (all.isEmpty && _query.isEmpty) {
              return RefreshIndicator(
                onRefresh: () => context.read<StoreProvider>().refresh(context),
                child: ListView(
                  padding: EdgeInsets.zero,
                  children: const [
                    _SearchHeader(),
                    SizedBox(height: 8),
                    EmptyState(
                      title: 'No Store Locations',
                      description: 'Please add a store location.',
                    ),
                    SizedBox(height: 200),
                  ],
                ),
              );
            }

            return RefreshIndicator(
              onRefresh: () => context.read<StoreProvider>().refresh(context),
              child: ListView.separated(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 24 + 56),
                itemCount: filtered.length + 1, // +1 untuk header search
                separatorBuilder: (_, __) => const SizedBox(height: 12),
                itemBuilder: (_, index) {
                  if (index == 0) {
                    return _SearchHeader(
                      controller: _searchC,
                      onClear: () => _searchC.clear(),
                    );
                  }

                  if (filtered.isEmpty) {
                    return Padding(
                      padding: const EdgeInsets.only(top: 32),
                      child: _NoResultTile(query: _query),
                    );
                  }

                  final s = filtered[index - 1];
                  final subtitle = [
                    s.city?.name,
                    s.city?.province?.name,
                  ].where((e) => (e ?? '').isNotEmpty).join(' • ');

                  return _StoreTile(
                    id: s.idStoreLocation,
                    title: s.name,
                    subtitle: subtitle.isEmpty ? null : subtitle,
                    onEdit: () {
                      showEditStoreSheet(
                        context,
                        idStoreLocation: s.idStoreLocation,
                        initialName: s.name,
                        // cityId di form aku simpan sebagai int? sesuai contohmu.
                        // Jika id bukan angka, FormField-validasinya tetap jalan,
                        // dan saat submit akan dikirim .toString().
                        initialCityId:
                            null, // biarkan picker tampil sesuai detail bila perlu
                        initialCityName: s.city?.name,
                        initialProvinceName: s.city?.province?.name,
                      );
                    },
                    onDelete: () async {
                      final confirmed = await _confirmDelete(
                        context,
                        title: 'Delete Store',
                        message:
                            'Are you sure you want to delete "${s.name}"? This action cannot be undone.',
                      );
                      if (confirmed != true) return;

                      final ok = await context
                          .read<StoreProvider>()
                          .deleteStoreLocation(context, s.idStoreLocation);

                      if (!context.mounted) return;

                      if (ok) {
                        AppSnackbar.show(
                          context,
                          type: AppSnackType.success,
                          title: 'Deleted',
                          message: 'Store location has been deleted.',
                        );
                      } else {
                        AppSnackbar.show(
                          context,
                          type: AppSnackType.error,
                          title: 'Failed',
                          message: p.lastError ?? 'Failed to delete store.',
                        );
                      }
                    },
                  );
                },
              ),
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
              await showAddStoreSheet(context);
            },
            child: const Text(
              'Add new store',
              style: TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
        ),
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
    final hasText = controller?.text.isNotEmpty == true;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 8),
        TextField(
          controller: controller,
          textInputAction: TextInputAction.search,
          decoration: InputDecoration(
            hintText: 'Search store or city…',
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
            suffixIcon: hasText
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

class _StoreTile extends StatelessWidget {
  const _StoreTile({
    required this.id,
    required this.title,
    this.subtitle,
    this.onEdit,
    this.onDelete,
  });

  final String id;
  final String title;
  final String? subtitle;
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            const Icon(
              Icons.store_mall_directory_rounded,
              size: 40,
              color: Color(0xFF4C6EF5),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF111827),
                    ),
                  ),
                  if (subtitle != null) ...[
                    const SizedBox(height: 2),
                    Text(
                      subtitle!,
                      style: const TextStyle(
                        color: Color(0xFF6B7280),
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        height: 1.2,
                      ),
                    ),
                  ],
                ],
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
            const SizedBox(width: 8),
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
        ),
      ),
    );
  }
}

// =============================
// ADD / EDIT STORE SHEETS
// =============================

enum StoreSheetMode { create, edit }

Future<void> showAddStoreSheet(BuildContext context) {
  return showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.white,
    useSafeArea: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
    ),
    builder: (_) => const _StoreSheet(mode: StoreSheetMode.create),
  );
}

Future<void> showEditStoreSheet(
  BuildContext context, {
  required String idStoreLocation,
  required String initialName,
  String? initialCityId,
  String? initialCityName,
  String? initialProvinceName,
}) {
  return showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.white,
    useSafeArea: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
    ),
    builder: (_) => _StoreSheet(
      mode: StoreSheetMode.edit,
      idStoreLocation: idStoreLocation,
      initialName: initialName,
      initialCityId: initialCityId,
      initialCityName: initialCityName,
      initialProvinceName: initialProvinceName,
    ),
  );
}

class _StoreSheet extends StatefulWidget {
  const _StoreSheet({
    required this.mode,
    this.idStoreLocation,
    this.initialName,
    this.initialCityId,
    this.initialCityName,
    this.initialProvinceName,
  });

  final StoreSheetMode mode;
  final String? idStoreLocation;
  final String? initialName;
  final String? initialCityId; // mengacu ke contohmu (FormField<int>)
  final String? initialCityName;
  final String? initialProvinceName;

  @override
  State<_StoreSheet> createState() => _StoreSheetState();
}

class _StoreSheetState extends State<_StoreSheet> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameC;

  bool _isValid = false;

  // City picker state mengikuti pola contoh penggunaannya:
  String? _cityId;
  String? _cityName;
  String? _provinceName;

  @override
  void initState() {
    super.initState();
    _nameC = TextEditingController(text: widget.initialName ?? '');
    _nameC.addListener(_revalidate);

    _cityId = widget.initialCityId;
    _cityName = widget.initialCityName;
    _provinceName = widget.initialProvinceName;

    WidgetsBinding.instance.addPostFrameCallback((_) => _revalidate());
  }

  void _revalidate() {
    final ok = (_formKey.currentState?.validate() ?? false);
    if (ok != _isValid) setState(() => _isValid = ok);
  }

  @override
  void dispose() {
    _nameC.removeListener(_revalidate);
    _nameC.dispose();
    super.dispose();
  }

  Future<void> _submit(BuildContext context) async {
    if (!(_formKey.currentState?.validate() ?? false)) return;

    final provider = context.read<StoreProvider>();
    final name = _nameC.text.trim();
    final cityIdStr = _cityId ?? '';
    if (cityIdStr.isEmpty) return; // guard

    if (widget.mode == StoreSheetMode.create) {
      final ok = await provider.addStoreLocation(
        context: context,
        name: name,
        cityId: cityIdStr, // String
      );
      if (!mounted) return;
      Navigator.of(context).pop();
      if (ok) {
        AppSnackbar.show(
          context,
          type: AppSnackType.success,
          title: 'Added',
          message: 'Store location added successfully.',
        );
      } else {
        AppSnackbar.show(
          context,
          type: AppSnackType.error,
          title: 'Failed',
          message: provider.lastError ?? 'Failed to add store.',
        );
      }
    } else {
      final id = widget.idStoreLocation!;
      final ok = await provider.updateStoreLocation(
        context: context,
        idStoreLocation: id,
        name: name,
        cityId: cityIdStr,
      );
      if (!mounted) return;
      Navigator.of(context).pop();
      if (ok) {
        AppSnackbar.show(
          context,
          type: AppSnackType.success,
          title: name,
          message: 'Store location updated successfully.',
        );
      } else {
        AppSnackbar.show(
          context,
          type: AppSnackType.error,
          title: 'Failed',
          message: provider.lastError ?? 'Failed to update store.',
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    final isEdit = widget.mode == StoreSheetMode.edit;
    final header = isEdit ? 'Edit Store' : 'New Store';
    final buttonText = isEdit ? 'Save changes' : 'Add new store';

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
                  'Store Name',
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _nameC,
                  autovalidateMode: AutovalidateMode.onUserInteraction,
                  textInputAction: TextInputAction.next,
                  validator: (v) => (v == null || v.trim().isEmpty)
                      ? 'Store name is required'
                      : null,
                  decoration: const InputDecoration(
                    hintText: 'e.g. Branch 1',
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
                const SizedBox(height: 14),

                // ==== CITY PICKER (mengikuti contohmu persis) ====
                FormField<String>(
                  initialValue: _cityId,
                  autovalidateMode: AutovalidateMode.onUserInteraction,
                  validator: (v) =>
                      (v == null || v.isEmpty) ? 'Required' : null,
                  builder: (ff) => SelectFieldTile(
                    label: 'City',
                    valueText: (_cityName == null)
                        ? null
                        : ((_provinceName ?? '').isEmpty
                              ? _cityName
                              : '$_cityName • $_provinceName'),
                    emptyHint: 'Select city',
                    errorText: ff.errorText,
                    onTap: () async {
                      final picked = await showCityPickerSheet(
                        context,
                        selectedId: _cityId, // String
                      );
                      if (picked != null && mounted) {
                        setState(() {
                          _cityId = picked.id; // String
                          _cityName = picked.label;
                          _provinceName =
                              picked.data?.province.name; // Province.name
                        });
                        ff.didChange(_cityId); // notify FormField
                      }
                    },
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

// ======= DIALOG KONFIRMASI =======

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
