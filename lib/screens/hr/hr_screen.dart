import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:wa_blast/providers/hr_provider.dart';

class HrScreen extends StatefulWidget {
  const HrScreen({super.key});

  @override
  State<HrScreen> createState() => _HrScreenState();
}

class _HrScreenState extends State<HrScreen> {
  @override
  void initState() {
    super.initState();
    // fetch setelah frame pertama
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final hr = context.read<HrProvider>();
      hr.fetchInviteHistory(context);
      hr.fetchRoles(context);
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final hr = context.watch<HrProvider>();

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.white,
        foregroundColor: const Color(0xFF0F172A),
        titleSpacing: 0,
        title: const Text(
          'Employee Invitation',
          style: TextStyle(fontWeight: FontWeight.w700),
        ),
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Header
            Container(
              width: double.infinity,
              color: Colors.white,
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: Text(
                'Invitation History',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: const Color(0xFF0F172A),
                ),
              ),
            ),

            // List
            Expanded(
              child: Builder(
                builder: (_) {
                  if (hr.loadingHistory) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  if ((hr.historyError ?? '').isNotEmpty) {
                    return Center(
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Text(
                          hr.historyError!,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            color: Color(0xFFEF4444),
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    );
                  }
                  if (hr.history.isEmpty) {
                    return const _EmptyState();
                  }
                  return ListView.separated(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    itemCount: hr.history.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 12),
                    itemBuilder: (context, index) {
                      final item = hr.history[index];
                      return _InviteTile(item: item);
                    },
                  );
                },
              ),
            ),

            // Bottom Button
            SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
                child: SizedBox(
                  width: double.infinity,
                  height: 56,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF4463FF),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      elevation: 0,
                    ),
                    onPressed: () async {
                      await showModalBottomSheet(
                        context: context,
                        isScrollControlled: true,
                        useSafeArea: true,
                        backgroundColor: Colors.white,
                        shape: const RoundedRectangleBorder(
                          borderRadius: BorderRadius.vertical(
                            top: Radius.circular(16),
                          ),
                        ),
                        builder: (_) => const _AddEmployeeSheet(),
                      );
                    },
                    child: const Text(
                      'Add new employee',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.person_add_alt_1_rounded,
            size: 48,
            color: Colors.grey.shade400,
          ),
          const SizedBox(height: 12),
          const Text(
            'Belum ada undangan',
            style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
          ),
          const SizedBox(height: 4),
          Text(
            'Kirim undangan untuk menambahkan karyawan.',
            style: TextStyle(color: Colors.grey.shade600),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

class _InviteTile extends StatelessWidget {
  const _InviteTile({required this.item});
  final HrInviteHistoryItem item;

  @override
  Widget build(BuildContext context) {
    final status = _deriveStatus(item);
    final pill = _StatusPill(text: status.$1, color: status.$2, bg: status.$3);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: const Color(0xFFE5E7EB)),
        ),
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            CircleAvatar(
              radius: 24,
              backgroundColor: const Color(0xFFE2E8F0),
              child: const Icon(Icons.person_rounded, color: Color(0xFF334155)),
            ),
            const SizedBox(width: 16),

            // Email + Role + Timestamps
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.email,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    item.roleName.isEmpty ? '—' : item.roleName,
                    style: TextStyle(
                      color: const Color(0xFF334155).withOpacity(.8),
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  if (item.expiresAt != null || item.usedAt != null) ...[
                    const SizedBox(height: 6),
                    Text(
                      [
                        if (item.expiresAt != null)
                          'Expires: ${item.expiresAt}',
                        if (item.usedAt != null) 'Used: ${item.usedAt}',
                      ].join(' • '),
                      style: TextStyle(
                        color: const Color(0xFF64748B).withOpacity(.9),
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ],
              ),
            ),

            // Status pill
            pill,
          ],
        ),
      ),
    );
  }

  /// returns (label, textColor, bgColor)
  (String, Color, Color) _deriveStatus(HrInviteHistoryItem it) {
    final now = DateTime.now();
    final used = it.usedAt != null;
    final expired = it.expiresAt != null && it.expiresAt!.isBefore(now);

    if (used) {
      return (
        'Used',
        const Color(0xFF16A34A),
        const Color(0xFF16A34A).withOpacity(.12),
      );
    }
    if (expired) {
      return (
        'Expired',
        const Color(0xFFEF4444),
        const Color(0xFFEF4444).withOpacity(.12),
      );
    }
    return ('Invited', const Color(0xFF1F2937), const Color(0xFFE5E7EB));
  }
}

class _StatusPill extends StatelessWidget {
  const _StatusPill({
    required this.text,
    required this.color,
    required this.bg,
  });
  final String text;
  final Color color;
  final Color bg;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: color,
          fontSize: 12,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

class _AddEmployeeSheet extends StatefulWidget {
  const _AddEmployeeSheet();

  @override
  State<_AddEmployeeSheet> createState() => _AddEmployeeSheetState();
}

class _AddEmployeeSheetState extends State<_AddEmployeeSheet> {
  final _formKey = GlobalKey<FormState>();
  final _emailC = TextEditingController();
  HrRole? _selectedRole; // <— simpan role terpilih

  @override
  void dispose() {
    _emailC.dispose();
    super.dispose();
  }

  Future<void> _pickRole() async {
    final picked = await showRolePickerSheet(context);
    if (picked != null) {
      setState(() => _selectedRole = picked);
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedRole == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Pilih role terlebih dahulu')),
      );
      return;
    }

    final hr = context.read<HrProvider>();
    final url = await hr.inviteEmployee(
      context,
      email: _emailC.text.trim(),
      roleId: _selectedRole!.id,
    );

    if (!mounted) return;
    final err = hr.consumeLastError();
    final msg = hr.consumeLastMessage();

    Navigator.pop(context);

    if (err != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(err), backgroundColor: const Color(0xFFEF4444)),
      );
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg ?? 'Undangan terkirim'),
        action: (url != null && url.isNotEmpty)
            ? SnackBarAction(
                label: 'Copy URL',
                onPressed: () {
                  /* copy ke clipboard */
                },
              )
            : null,
      ),
    );

    // refresh history
    context.read<HrProvider>().fetchInviteHistory(context);
  }

  @override
  Widget build(BuildContext context) {
    final inset = MediaQuery.of(context).viewInsets.bottom;

    return Padding(
      padding: EdgeInsets.only(bottom: inset),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 8),
              const Text(
                'Invite Employee',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF0F172A),
                ),
              ),
              const SizedBox(height: 12),

              // EMAIL
              const _FieldLabel('Email'),
              TextFormField(
                controller: _emailC,
                keyboardType: TextInputType.emailAddress,
                decoration: _decoration().copyWith(hintText: 'user@mail.com'),
                validator: (v) {
                  final s = v?.trim() ?? '';
                  if (s.isEmpty) return 'Wajib diisi';
                  final ok = RegExp(r'^[^@]+@[^@]+\.[^@]+').hasMatch(s);
                  if (!ok) return 'Format email tidak valid';
                  return null;
                },
              ),
              const SizedBox(height: 12),

              // ROLE (read-only field that opens sheet)
              const _FieldLabel('Role'),
              GestureDetector(
                onTap: _pickRole,
                child: AbsorbPointer(
                  child: TextFormField(
                    decoration: _decoration().copyWith(
                      hintText: 'Select role',
                      suffixIcon: const Icon(Icons.expand_more_rounded),
                    ),
                    controller: TextEditingController(
                      text: _selectedRole?.name ?? '',
                    ),
                    validator: (_) =>
                        _selectedRole == null ? 'Pilih role' : null,
                  ),
                ),
              ),

              const SizedBox(height: 16),

              SizedBox(
                height: 50,
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: context.watch<HrProvider>().submitting
                      ? null
                      : _submit,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF4463FF),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    elevation: 0,
                    textStyle: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                  child: Text(
                    context.watch<HrProvider>().submitting
                        ? 'Sending...'
                        : 'Send Invite',
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  InputDecoration _decoration() => const InputDecoration(
    filled: true,
    fillColor: Colors.white,
    contentPadding: EdgeInsets.symmetric(horizontal: 14, vertical: 14),
    border: OutlineInputBorder(
      borderRadius: BorderRadius.all(Radius.circular(10)),
      borderSide: BorderSide(color: Color(0xFFE5E7EB), width: 1.4),
    ),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.all(Radius.circular(10)),
      borderSide: BorderSide(color: Color(0xFFE5E7EB), width: 1.4),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.all(Radius.circular(10)),
      borderSide: BorderSide(color: Color(0xFF4C6EF5), width: 1.6),
    ),
  );
}

class _FieldLabel extends StatelessWidget {
  const _FieldLabel(this.text);
  final String text;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: Text(
      text,
      style: const TextStyle(
        fontWeight: FontWeight.w800,
        fontSize: 16,
        color: Color(0xFF0F172A),
      ),
    ),
  );
}

Future<HrRole?> showRolePickerSheet(BuildContext context) async {
  // pastikan roles sudah di-load
  final hr = context.read<HrProvider>();
  if (hr.roles.isEmpty && !hr.loadingRoles) {
    await hr.fetchRoles(context);
  }

  return showModalBottomSheet<HrRole>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: Colors.white,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
    ),
    builder: (_) => const _RolePickerSheet(),
  );
}

class _RolePickerSheet extends StatefulWidget {
  const _RolePickerSheet();

  @override
  State<_RolePickerSheet> createState() => _RolePickerSheetState();
}

class _RolePickerSheetState extends State<_RolePickerSheet> {
  final TextEditingController _searchC = TextEditingController();
  String _query = '';

  @override
  void initState() {
    super.initState();
    _searchC.addListener(() {
      final next = _searchC.text.trim().toLowerCase();
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
    final hr = context.watch<HrProvider>();

    final roles = hr.roles.where((r) {
      if (_query.isEmpty) return true;
      return r.name.toLowerCase().contains(_query);
    }).toList();

    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.7,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      builder: (context, controller) {
        return Column(
          children: [
            // handle
            const SizedBox(height: 8),
            Container(
              width: 44,
              height: 5,
              decoration: BoxDecoration(
                color: const Color(0xFFE5E7EB),
                borderRadius: BorderRadius.circular(999),
              ),
            ),
            const SizedBox(height: 12),

            // title
            const Text(
              'Select Role',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: Color(0xFF0F172A),
              ),
            ),
            const SizedBox(height: 12),

            // search
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: TextField(
                controller: _searchC,
                decoration: const InputDecoration(
                  hintText: 'Search role name…',
                  filled: true,
                  fillColor: Colors.white,
                  contentPadding: EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 12,
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.all(Radius.circular(10)),
                    borderSide: BorderSide(
                      color: Color(0xFFE5E7EB),
                      width: 1.2,
                    ),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.all(Radius.circular(10)),
                    borderSide: BorderSide(
                      color: Color(0xFFE5E7EB),
                      width: 1.2,
                    ),
                  ),
                  prefixIcon: Icon(Icons.search_rounded),
                ),
              ),
            ),
            const SizedBox(height: 8),

            // list
            Expanded(
              child: RefreshIndicator(
                onRefresh: () async {
                  await context.read<HrProvider>().fetchRoles(context);
                },
                child: hr.loadingRoles
                    ? const Center(child: CircularProgressIndicator())
                    : roles.isEmpty
                    ? ListView(
                        controller: controller,
                        children: const [
                          SizedBox(height: 48),
                          Center(
                            child: Text(
                              'No roles found',
                              style: TextStyle(
                                fontWeight: FontWeight.w700,
                                color: Color(0xFF6B7280),
                              ),
                            ),
                          ),
                        ],
                      )
                    : ListView.separated(
                        controller: controller,
                        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                        itemCount: roles.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 8),
                        itemBuilder: (_, i) {
                          final r = roles[i];
                          return ListTile(
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                              side: const BorderSide(color: Color(0xFFE5E7EB)),
                            ),
                            tileColor: Colors.white,
                            leading: CircleAvatar(
                              backgroundColor: const Color(0xFFE9F0FF),
                              child: const Icon(
                                Icons.badge_rounded,
                                color: Color(0xFF4C6EF5),
                              ),
                            ),
                            title: Text(
                              r.name,
                              style: const TextStyle(
                                fontWeight: FontWeight.w800,
                                color: Color(0xFF0F172A),
                              ),
                            ),
                            subtitle: r.isPrimary
                                ? const Text(
                                    'Primary role',
                                    style: TextStyle(
                                      color: Color(0xFF64748B),
                                      fontWeight: FontWeight.w600,
                                    ),
                                  )
                                : null,
                            onTap: () => Navigator.pop(context, r),
                          );
                        },
                      ),
              ),
            ),
          ],
        );
      },
    );
  }
}
