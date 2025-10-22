import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:wa_blast/providers/sales_provider.dart';
import 'package:wa_blast/widgets/app_snackbar.dart';
import 'package:wa_blast/widgets/empty_state.dart';
import 'package:wa_blast/widgets/reusable_pickers.dart';
import '../../constants/app_colors.dart';

class CustomerListScreen extends StatefulWidget {
  const CustomerListScreen({super.key});

  @override
  State<CustomerListScreen> createState() => _CustomerListScreenState();
}

class _CustomerListScreenState extends State<CustomerListScreen> {
  final TextEditingController _searchC = TextEditingController();
  String _query = '';

  @override
  void initState() {
    super.initState();
    // fetch setelah frame pertama agar aman dari initState context
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<SalesProvider>().fetchCustomers(context);
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
    final provider = context.watch<SalesProvider>();

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.white,
        scrolledUnderElevation: 0,
        foregroundColor: const Color(0xFF1F2937),
        title: const Text(
          'Customer List',
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
        child: Builder(
          builder: (_) {
            if (provider.loadingCustomers) {
              return const Center(child: CircularProgressIndicator());
            }

            final all = provider.customers;
            final lowerQ = _query.toLowerCase();
            final filtered = (lowerQ.isEmpty)
                ? all
                : all.where((c) {
                    final name = (c.name).toLowerCase();
                    final phone = (c.phone).toLowerCase();
                    final email = (c.email).toLowerCase();
                    final cityName = (c.city?.name ?? '').toLowerCase();
                    return name.contains(lowerQ) ||
                        phone.contains(lowerQ) ||
                        email.contains(lowerQ) ||
                        cityName.contains(lowerQ);
                  }).toList();

            // Kosong & tidak sedang mencari
            if (all.isEmpty && _query.isEmpty) {
              return RefreshIndicator(
                onRefresh: () =>
                    context.read<SalesProvider>().fetchCustomers(context),
                child: ListView(
                  padding: EdgeInsets.zero,
                  children: const [
                    _SearchHeader(),
                    SizedBox(height: 8),
                    EmptyState(
                      title: 'No Customers',
                      description: 'Please add a customer.',
                    ),
                    SizedBox(height: 200),
                  ],
                ),
              );
            }

            // Tampilkan list + header search
            return RefreshIndicator(
              onRefresh: () =>
                  context.read<SalesProvider>().fetchCustomers(context),
              child: ListView.separated(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 16 + 56),
                itemCount: filtered.isEmpty
                    ? 2
                    : filtered.length + 1, // +1 untuk search header
                separatorBuilder: (_, __) => const SizedBox(height: 8),
                itemBuilder: (_, index) {
                  if (index == 0) {
                    return _SearchHeader(
                      controller: _searchC,
                      onClear: () => _searchC.clear(),
                    );
                  }

                  // Tidak ada hasil pencarian
                  if (filtered.isEmpty) {
                    return Padding(
                      padding: const EdgeInsets.only(top: 24),
                      child: _NoResultTile(query: _query),
                    );
                  }

                  final c = filtered[index - 1];
                  return _CustomerRow(
                    name: c.name,
                    phone: c.phone,
                    city: c.city?.name ?? '-',
                    onEdit: () async {
                      await showEditCustomerSheet(
                        context,
                        idCustomer: c.idCustomer,
                        initialName: c.name,
                        initialPhone: c.phone,
                        initialEmail: c.email,
                        // city di response tidak menyertakan id city, jadi kita minta input ulang city_id
                        initialCityId: null,
                        initialAddress: c.address,
                      );
                    },
                    onDelete: () async {
                      final confirmed = await _confirmDelete(
                        context,
                        title: 'Delete Customer',
                        message:
                            'Are you sure you want to delete "${c.name}"? This action cannot be undone.',
                      );
                      if (confirmed != true) return;

                      final ok = await context
                          .read<SalesProvider>()
                          .deleteCustomer(context, c.idCustomer);

                      if (!context.mounted) return;

                      if (ok) {
                        AppSnackbar.show(
                          context,
                          type: AppSnackType.success,
                          title: 'Deleted',
                          message: 'Customer has been deleted.',
                        );
                      } else {
                        AppSnackbar.show(
                          context,
                          type: AppSnackType.error,
                          title: 'Failed',
                          message:
                              provider.consumeLastError() ??
                              'Failed to delete customer.',
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
              await showAddCustomerSheet(context);
            },
            child: const Text(
              'Add new customer',
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
            hintText: 'Search name, phone, email, or city…',
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

/// ====== ROW LIST CUSTOMER (versi ringkas) ======
class _CustomerRow extends StatelessWidget {
  const _CustomerRow({
    required this.name,
    required this.phone,
    required this.city,
    this.onEdit,
    this.onDelete,
  });

  final String name;
  final String phone;
  final String city;
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;

  String _initials(String input) {
    final s = input.trim();
    if (s.isEmpty) return '?';
    final parts = s.split(RegExp(r'\s+'));
    if (parts.length == 1) {
      final w = parts.first;
      return w.substring(0, w.length >= 2 ? 2 : 1).toUpperCase();
    }
    final a = parts.first.isNotEmpty ? parts.first[0] : '';
    final b = parts.last.isNotEmpty ? parts.last[0] : '';
    final joined = (a + b).trim();
    return joined.isEmpty ? '?' : joined.toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    final subStyle = const TextStyle(
      color: Color(0xFF6B7280),
      fontWeight: FontWeight.w500,
    );

    return Material(
      color: Colors.white,
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onEdit, // tap = Edit
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: ListTile(
            contentPadding: const EdgeInsets.symmetric(horizontal: 0),
            leading: CircleAvatar(
              radius: 20,
              backgroundColor: const Color(0xFFEFF3FF),
              child: Text(
                _initials(name),
                style: const TextStyle(
                  color: Color(0xFF3B5CCC),
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            title: Text(
              name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontWeight: FontWeight.w700,
                color: Color(0xFF111827),
              ),
            ),
            subtitle: Text(
              city == '-' ? phone : '$phone • $city',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: subStyle,
            ),
            trailing: PopupMenuButton<int>(
              tooltip: 'More',
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              itemBuilder: (context) => const [
                PopupMenuItem<int>(value: 0, child: Text('Edit')),
                PopupMenuItem<int>(
                  value: 1,
                  child: Text(
                    'Delete',
                    style: TextStyle(color: Color(0xFFEF4444)),
                  ),
                ),
              ],
              onSelected: (v) {
                if (v == 0) {
                  onEdit?.call();
                } else if (v == 1) {
                  onDelete?.call();
                }
              },
              child: const Icon(
                Icons.more_horiz_rounded,
                color: Color(0xFF6B7280),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// =============================
// ADD / EDIT CUSTOMER SHEETS
// =============================

enum CustomerSheetMode { create, edit }

Future<void> showAddCustomerSheet(BuildContext context) {
  return showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.white,
    useSafeArea: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
    ),
    builder: (_) => const _CustomerSheet(mode: CustomerSheetMode.create),
  );
}

Future<void> showEditCustomerSheet(
  BuildContext context, {
  required String idCustomer,
  required String initialName,
  required String initialPhone,
  required String initialEmail,
  int? initialCityId,
  required String initialAddress,
}) {
  return showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.white,
    useSafeArea: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
    ),
    builder: (_) => _CustomerSheet(
      mode: CustomerSheetMode.edit,
      idCustomer: idCustomer,
      initialName: initialName,
      initialPhone: initialPhone,
      initialEmail: initialEmail,
      initialCityId: initialCityId,
      initialAddress: initialAddress,
    ),
  );
}

class _CustomerSheet extends StatefulWidget {
  const _CustomerSheet({
    required this.mode,
    this.idCustomer,
    this.initialName,
    this.initialPhone,
    this.initialEmail,
    this.initialCityId,
    this.initialAddress,
  });

  final CustomerSheetMode mode;
  final String? idCustomer;
  final String? initialName;
  final String? initialPhone;
  final String? initialEmail;
  final int? initialCityId;
  final String? initialAddress;

  @override
  State<_CustomerSheet> createState() => _CustomerSheetState();
}

class _CustomerSheetState extends State<_CustomerSheet> {
  final _formKey = GlobalKey<FormState>();

  late final TextEditingController _nameC;
  late final TextEditingController _phoneC;
  late final TextEditingController _emailC;
  String? _cityId; // String dari picker
  String? _cityName; // untuk display
  String? _provinceName; // untuk display

  late final TextEditingController _addressC;

  bool _isValid = false;

  dynamic _pickedCityData;

  @override
  void initState() {
    super.initState();
    _nameC = TextEditingController(text: widget.initialName ?? '');
    _phoneC = TextEditingController(text: widget.initialPhone ?? '');
    _emailC = TextEditingController(text: widget.initialEmail ?? '');
    _addressC = TextEditingController(text: widget.initialAddress ?? '');

    // kalau EDIT dan kamu punya initialCityId, isi _cityId.
    if (widget.initialCityId != null) {
      _cityId = widget.initialCityId.toString();
    }

    for (final c in [_nameC, _phoneC, _emailC, _addressC]) {
      c.addListener(_revalidate);
    }
    WidgetsBinding.instance.addPostFrameCallback((_) => _revalidate());
  }

  void _revalidate() {
    final ok = (_formKey.currentState?.validate() ?? false);
    if (ok != _isValid) setState(() => _isValid = ok);
  }

  @override
  void dispose() {
    _nameC.removeListener(_revalidate);
    _phoneC.removeListener(_revalidate);
    _emailC.removeListener(_revalidate);
    _addressC.removeListener(_revalidate);

    _nameC.dispose();
    _phoneC.dispose();
    _emailC.dispose();
    _addressC.dispose();

    super.dispose();
  }

  String? _required(String? v, {String label = 'This field'}) {
    if (v == null || v.trim().isEmpty) return '$label is required';
    return null;
  }

  String? _validateEmail(String? v) {
    if ((v ?? '').trim().isEmpty) return 'Email is required';
    final s = v!.trim();
    final ok = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(s);
    return ok ? null : 'Invalid email format';
  }

  String? _validateCityId(String? v) {
    if ((v ?? '').trim().isEmpty) return 'City is required';
    return null;
  }

  Future<void> _submit(BuildContext context) async {
    if (!(_formKey.currentState?.validate() ?? false)) return;

    final name = _nameC.text.trim();
    final phone = _phoneC.text.trim();
    final email = _emailC.text.trim();
    final address = _addressC.text.trim();

    // cityIdRaw bisa String (UUID) atau angka yang berbentuk string.
    final Object? cityIdRaw = _cityId; // <= langsung pakai raw
    if (cityIdRaw == null ||
        (cityIdRaw is String && cityIdRaw.trim().isEmpty)) {
      if (mounted) {
        AppSnackbar.show(
          context,
          type: AppSnackType.error,
          title: 'City required',
          message: 'Please pick a city.',
        );
      }
      return;
    }

    final prov = context.read<SalesProvider>();

    if (widget.mode == CustomerSheetMode.create) {
      final created = await prov.createCustomer(
        context,
        name: name,
        phone: phone,
        email: email,
        cityId: cityIdRaw, // <= kirim apa adanya
        address: address,
      );
      if (!mounted) return;
      Navigator.of(context).pop();
      if (created != null) {
        AppSnackbar.show(
          context,
          type: AppSnackType.success,
          title: 'Added',
          message: 'Customer added successfully.',
        );
      } else {
        AppSnackbar.show(
          context,
          type: AppSnackType.error,
          title: 'Failed',
          message: prov.consumeLastError() ?? 'Failed to add customer.',
        );
      }
    } else {
      final id = widget.idCustomer!;
      final updated = await prov.updateCustomer(
        context,
        idCustomer: id,
        name: name,
        phone: phone,
        email: email,
        cityId: cityIdRaw, // <= kirim apa adanya
        address: address,
      );
      if (!mounted) return;
      Navigator.of(context).pop();
      if (updated != null) {
        AppSnackbar.show(
          context,
          type: AppSnackType.success,
          title: updated.name,
          message: 'Customer updated successfully.',
        );
      } else {
        AppSnackbar.show(
          context,
          type: AppSnackType.error,
          title: 'Failed',
          message: prov.consumeLastError() ?? 'Failed to update customer.',
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    final isEdit = widget.mode == CustomerSheetMode.edit;
    final header = isEdit ? 'Edit Customer' : 'New Customer';
    final buttonText = isEdit ? 'Save changes' : 'Add new customer';

    return Padding(
      padding: EdgeInsets.only(
        left: 16,
        right: 16,
        top: 8,
        bottom: bottomInset > 0 ? bottomInset : 16,
      ),
      child: SingleChildScrollView(
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
                  // Name
                  const _Label('Full Name'),
                  const SizedBox(height: 8),
                  TextFormField(
                    controller: _nameC,
                    autovalidateMode: AutovalidateMode.onUserInteraction,
                    textInputAction: TextInputAction.next,
                    validator: (v) => _required(v, label: 'Full name'),
                    decoration: _inputDecoration('E.g. John Doe'),
                  ),
                  const SizedBox(height: 14),

                  // Phone
                  const _Label('Phone Number'),
                  const SizedBox(height: 8),
                  TextFormField(
                    controller: _phoneC,
                    autovalidateMode: AutovalidateMode.onUserInteraction,
                    keyboardType: TextInputType.phone,
                    textInputAction: TextInputAction.next,
                    validator: (v) => _required(v, label: 'Phone number'),
                    decoration: _inputDecoration('E.g. 081234567890'),
                  ),
                  const SizedBox(height: 14),

                  // Email
                  const _Label('Email'),
                  const SizedBox(height: 8),
                  TextFormField(
                    controller: _emailC,
                    autovalidateMode: AutovalidateMode.onUserInteraction,
                    keyboardType: TextInputType.emailAddress,
                    textInputAction: TextInputAction.next,
                    validator: _validateEmail,
                    decoration: _inputDecoration('E.g. customer@abc.com'),
                  ),
                  const SizedBox(height: 14),

                  // City ID (via picker)
                  // const _Label('City ID'),
                  const SizedBox(height: 8),
                  FormField<String>(
                    initialValue: _cityId,
                    autovalidateMode: AutovalidateMode.onUserInteraction,
                    validator: _validateCityId,
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
                          selectedId: _cityId, // highlight pilihan saat ini
                        );
                        if (picked != null && mounted) {
                          setState(() {
                            _cityId = picked.id;
                            _cityName = picked.label;
                            _provinceName = picked.data?.province.name;
                            _pickedCityData = picked.data; // simpan objek city
                          });
                          ff.didChange(_cityId);
                          _revalidate();
                        }
                      },
                    ),
                  ),

                  const SizedBox(height: 14),

                  // Address
                  const _Label('Address'),
                  const SizedBox(height: 8),
                  TextFormField(
                    controller: _addressC,
                    autovalidateMode: AutovalidateMode.onUserInteraction,
                    textInputAction: TextInputAction.done,
                    minLines: 2,
                    maxLines: 4,
                    validator: (v) => _required(v, label: 'Address'),
                    onFieldSubmitted: (_) {
                      if (_isValid) _submit(context);
                    },
                    decoration: _inputDecoration('Street / District / City'),
                  ),

                  const SizedBox(height: 18),
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
      ),
    );
  }

  InputDecoration _inputDecoration(String hint) => const InputDecoration(
    filled: true,
    fillColor: Color(0xFFF3F4F6),
    contentPadding: EdgeInsets.symmetric(horizontal: 14, vertical: 14),
    border: OutlineInputBorder(
      borderSide: BorderSide.none,
      borderRadius: BorderRadius.all(Radius.circular(12)),
    ),
  ).copyWith(hintText: hint);
}

class _Label extends StatelessWidget {
  const _Label(this.text, {this.trailing});
  final String text;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text(text, style: const TextStyle(fontWeight: FontWeight.w600)),
        if (trailing != null) ...[const SizedBox(width: 8), trailing!],
      ],
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
