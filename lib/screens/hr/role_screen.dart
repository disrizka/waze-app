// lib/screens/hr/role_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:wa_blast/providers/hr_provider.dart';

class RoleScreen extends StatefulWidget {
  const RoleScreen({super.key});

  @override
  State<RoleScreen> createState() => _RoleScreenState();
}

class _RoleScreenState extends State<RoleScreen> {
  @override
  void initState() {
    super.initState();
    // fetch setelah frame pertama
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final hr = context.read<HrProvider>();
      await hr.fetchRoles(context);
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
          'Roles',
          style: TextStyle(fontWeight: FontWeight.w700),
        ),
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Header
            Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: Text(
                'Role List',
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
                  if (hr.loadingRoles) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  if ((hr.rolesError ?? '').isNotEmpty) {
                    return Center(
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Text(
                          hr.rolesError!,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            color: Color(0xFFEF4444),
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    );
                  }
                  if (hr.roles.isEmpty) {
                    return const _EmptyRoles();
                  }
                  return RefreshIndicator(
                    onRefresh: () =>
                        context.read<HrProvider>().fetchRoles(context),
                    child: ListView.separated(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      itemCount: hr.roles.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 12),
                      itemBuilder: (_, i) => _RoleTile(role: hr.roles[i]),
                    ),
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
                        builder: (_) => const _AddRoleSheet(),
                      );
                    },
                    child: const Text(
                      'Add new role',
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

class _EmptyRoles extends StatelessWidget {
  const _EmptyRoles();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.admin_panel_settings_rounded,
            size: 48,
            color: Colors.grey.shade400,
          ),
          const SizedBox(height: 12),
          const Text(
            'Belum ada role',
            style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
          ),
          const SizedBox(height: 4),
          Text(
            'Tambahkan role baru untuk mengatur akses karyawan.',
            style: TextStyle(color: Colors.grey.shade600),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

class _RoleTile extends StatelessWidget {
  const _RoleTile({required this.role});
  final HrRole role;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFE5E7EB)),
        ),
        child: ListTile(
          leading: CircleAvatar(
            backgroundColor: const Color(0xFFE9F0FF),
            child: const Icon(Icons.badge_rounded, color: Color(0xFF4C6EF5)),
          ),
          title: Text(
            role.name,
            style: const TextStyle(fontWeight: FontWeight.w800),
          ),
          subtitle: role.isPrimary
              ? const Text(
                  'Primary role',
                  style: TextStyle(
                    color: Color(0xFF64748B),
                    fontWeight: FontWeight.w600,
                  ),
                )
              : null,
          onTap: () {
            // TODO: detail/edit role (opsional)
          },
        ),
      ),
    );
  }
}

/// ===============
/// ADD ROLE SHEET
/// ===============
class _AddRoleSheet extends StatefulWidget {
  const _AddRoleSheet();

  @override
  State<_AddRoleSheet> createState() => _AddRoleSheetState();
}

class _AddRoleSheetState extends State<_AddRoleSheet> {
  final _formKey = GlobalKey<FormState>();
  final _nameC = TextEditingController();
  final TextEditingController _searchC = TextEditingController();
  String _query = '';

  /// selections: Map<menuId, Set<submenuId>>
  final Map<int, Set<int>> _selections = {};

  @override
  void initState() {
    super.initState();
    // load admin menus (untuk checklist)
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final prov = context.read<HrProvider>();
      if (prov.adminMenus.isEmpty && !prov.loadingAdminMenus) {
        await prov.fetchAdminMenus(context);
      }
    });
    _searchC.addListener(() {
      final next = _searchC.text.trim().toLowerCase();
      if (next != _query) setState(() => _query = next);
    });
  }

  @override
  void dispose() {
    _nameC.dispose();
    _searchC.dispose();
    super.dispose();
  }

  void _toggleMenu(int menuId, bool checked) {
    setState(() {
      if (checked) {
        _selections.putIfAbsent(menuId, () => <int>{});
      } else {
        _selections.remove(menuId);
      }
    });
  }

  void _toggleSubmenu(int menuId, int subId, bool checked) {
    setState(() {
      _selections.putIfAbsent(menuId, () => <int>{});
      if (checked) {
        _selections[menuId]!.add(subId);
      } else {
        _selections[menuId]!.remove(subId);
      }
    });
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selections.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Pilih minimal satu menu')));
      return;
    }

    final prov = context.read<HrProvider>();
    final created = await prov.createRole(
      context,
      name: _nameC.text.trim(),
      menuSelections: _selections,
    );

    if (!mounted) return;
    final err = prov.consumeLastError();
    final msg = prov.consumeLastMessage();

    Navigator.pop(context);

    if (err != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(err), backgroundColor: const Color(0xFFEF4444)),
      );
      return;
    }

    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(msg ?? 'Role created')));

    // refresh list roles (jaga-jaga jika API tidak mengembalikan role baru)
    if (created == null) {
      context.read<HrProvider>().fetchRoles(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    final hr = context.watch<HrProvider>();
    final inset = MediaQuery.of(context).viewInsets.bottom;

    final menus = hr.adminMenus.where((m) {
      if (_query.isEmpty) return true;
      final q = _query;
      if (m.name.toLowerCase().contains(q)) return true;
      return m.submenu.any((s) => s.name.toLowerCase().contains(q));
    }).toList();

    return Padding(
      padding: EdgeInsets.only(bottom: inset),
      child: DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.9,
        minChildSize: 0.6,
        maxChildSize: 0.95,
        builder: (context, controller) {
          return SingleChildScrollView(
            controller: controller,
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // handle
                  const SizedBox(height: 8),
                  Center(
                    child: Container(
                      width: 44,
                      height: 5,
                      decoration: BoxDecoration(
                        color: const Color(0xFFE5E7EB),
                        borderRadius: BorderRadius.circular(999),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),

                  const Text(
                    'Add New Role',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF0F172A),
                    ),
                  ),
                  const SizedBox(height: 12),

                  const _FieldLabel('Role Name'),
                  TextFormField(
                    controller: _nameC,
                    decoration: _inputDeco().copyWith(hintText: 'Role Name'),
                    validator: (v) => (v == null || v.trim().isEmpty)
                        ? 'Nama role wajib diisi'
                        : null,
                  ),
                  const SizedBox(height: 12),

                  const _FieldLabel('Search Menu / Submenu'),
                  TextField(
                    controller: _searchC,
                    decoration: _inputDeco().copyWith(
                      hintText: 'Ketik untuk mencari…',
                      prefixIcon: const Icon(Icons.search_rounded),
                    ),
                  ),
                  const SizedBox(height: 12),

                  // MENUS LIST
                  if (hr.loadingAdminMenus)
                    const Center(
                      child: Padding(
                        padding: EdgeInsets.all(16),
                        child: CircularProgressIndicator(),
                      ),
                    )
                  else if ((hr.adminMenusError ?? '').isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.all(12),
                      child: Text(
                        hr.adminMenusError!,
                        style: const TextStyle(
                          color: Color(0xFFEF4444),
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    )
                  else if (menus.isEmpty)
                    const Padding(
                      padding: EdgeInsets.all(12),
                      child: Text(
                        'Menu kosong',
                        style: TextStyle(fontWeight: FontWeight.w700),
                      ),
                    )
                  else
                    ListView.separated(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: menus.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 8),
                      itemBuilder: (_, i) {
                        final m = menus[i];
                        final selectedMenu = _selections.containsKey(m.id);
                        final selectedSubs = _selections[m.id] ?? <int>{};

                        return Container(
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: const Color(0xFFE5E7EB)),
                          ),
                          child: ExpansionTile(
                            tilePadding: const EdgeInsets.symmetric(
                              horizontal: 12,
                            ),
                            childrenPadding: const EdgeInsets.fromLTRB(
                              12,
                              0,
                              12,
                              12,
                            ),
                            leading: Checkbox(
                              value: selectedMenu,
                              onChanged: (v) {
                                _toggleMenu(m.id, v == true);
                              },
                            ),
                            title: Text(
                              m.name,
                              style: const TextStyle(
                                fontWeight: FontWeight.w800,
                                color: Color(0xFF0F172A),
                              ),
                            ),
                            subtitle: Text(
                              selectedSubs.isEmpty
                                  ? 'No submenu selected'
                                  : '${selectedSubs.length} submenu selected',
                              style: const TextStyle(
                                color: Color(0xFF64748B),
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            initiallyExpanded: selectedMenu,
                            children: [
                              if (m.submenu.isEmpty)
                                const Padding(
                                  padding: EdgeInsets.symmetric(vertical: 8),
                                  child: Text(
                                    'Tidak ada submenu',
                                    style: TextStyle(
                                      color: Color(0xFF6B7280),
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                )
                              else
                                Column(
                                  children: m.submenu.map((s) {
                                    final checked = selectedSubs.contains(s.id);
                                    return CheckboxListTile(
                                      value: checked,
                                      dense: true,
                                      controlAffinity:
                                          ListTileControlAffinity.leading,
                                      contentPadding: EdgeInsets.zero,
                                      title: Text(
                                        s.name,
                                        style: const TextStyle(
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                      onChanged: selectedMenu
                                          ? (v) => _toggleSubmenu(
                                              m.id,
                                              s.id,
                                              v == true,
                                            )
                                          : null,
                                    );
                                  }).toList(),
                                ),
                            ],
                          ),
                        );
                      },
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
                            ? 'Saving...'
                            : 'Save Role',
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  InputDecoration _inputDeco() => const InputDecoration(
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
