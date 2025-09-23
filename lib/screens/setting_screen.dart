import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:wa_blast/widgets/modal_login.dart';

import '../constants/app_colors.dart';
import '../providers/auth_provider.dart';

/// ===== Helpers akun (ringkas) =====
Future<List<String>> _getStoredAccountEmails() async {
  final sp = await SharedPreferences.getInstance();

  // prefer format baru: List<String> 'accounts'
  final listStr = sp.getStringList(AuthProvider.kAccountsKey);
  if (listStr != null && listStr.isNotEmpty) {
    return listStr.toSet().toList();
  }

  // fallback: JSON 'accounts' lama
  final raw = sp.getString('accounts');
  if (raw != null && raw.isNotEmpty) {
    try {
      final List list = jsonDecode(raw);
      final emails = <String>[
        for (final e in list)
          if (e is Map &&
              e['email'] is String &&
              (e['email'] as String).isNotEmpty)
            e['email'] as String,
      ];
      if (emails.isNotEmpty) return emails.toSet().toList();
    } catch (_) {}
  }

  // fallback lain (kalau ada)
  return (sp.getStringList('accounts_emails') ?? []).toSet().toList();
}

Future<String?> _getAccountNameByEmail(String email) async {
  final sp = await SharedPreferences.getInstance();
  final snap = sp.getString('account_$email');
  if (snap != null) {
    try {
      final m = jsonDecode(snap) as Map<String, dynamic>;
      final name = (m['name'] as String?)?.trim();
      if (name != null && name.isNotEmpty) return name;
    } catch (_) {}
  }
  return email.split('@').first;
}

Future<int> _getStoredAccountCount() async =>
    (await _getStoredAccountEmails()).length;

Future<bool> _confirmAddAccount(BuildContext context) async {
  final r = await showDialog<bool>(
    context: context,
    builder: (_) => AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      titlePadding: const EdgeInsets.fromLTRB(24, 24, 24, 12),
      contentPadding: const EdgeInsets.symmetric(horizontal: 24),
      actionsPadding: const EdgeInsets.only(right: 16, bottom: 12),
      title: Row(
        children: const [
          Icon(LucideIcons.userPlus, color: AppColors.primary),
          SizedBox(width: 12),
          Text(
            'Tambah Akun Lainnya?',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
          ),
        ],
      ),
      content: const Text(
        'Apakah kamu ingin menambahkan akun lainnya? Kamu bisa login dan berpindah akun kapan saja.',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: Text('Batal', style: TextStyle(color: Colors.black)),
        ),
        ElevatedButton.icon(
          onPressed: () => Navigator.pop(context, true),
          icon: const Icon(LucideIcons.plus, color: Colors.white),
          label: Text('Ya, Tambahkan', style: TextStyle(color: Colors.white)),
          style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary),
        ),
      ],
    ),
  );
  return r == true;
}

void _goToAddAccount(BuildContext context) {
  showAddAccountModal(context);
}

/// ====== UI small widgets ======
class _SectionTitle extends StatelessWidget {
  final String text;
  const _SectionTitle(this.text);
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 18, 16, 8),
      child: Text(
        text,
        style: const TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w700,
          color: Color(0xFF333A46),
        ),
      ),
    );
  }
}

class _MenuTile extends StatelessWidget {
  final String title;
  final String? subtitle;
  final IconData icon;
  final VoidCallback? onTap;
  const _MenuTile({
    required this.title,
    required this.icon,
    this.onTap,
    this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    final box = Container(
      width: 24,
      height: 24,
      decoration: BoxDecoration(
        color: Colors.grey[300],
        borderRadius: BorderRadius.circular(4),
      ),
      child: Icon(icon, size: 16, color: Colors.grey[700]),
    );

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 12),
        minLeadingWidth: 0,
        leading: box,
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
        subtitle: subtitle == null
            ? null
            : Text(subtitle!, style: const TextStyle(color: Colors.grey)),
        trailing: const Icon(LucideIcons.chevronRight, color: Colors.grey),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        tileColor: Colors.grey[100],
        onTap: onTap,
      ),
    );
  }
}

/// ====== ProfileScreen (layout seperti screenshot) ======
class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});
  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  @override
  Widget build(BuildContext context) {
    final auth = Provider.of<AuthProvider>(context);

    return Scaffold(
      backgroundColor: AppColors.white,
      appBar: AppBar(
        automaticallyImplyLeading: false,
        backgroundColor: AppColors.white,
        elevation: 0,
        centerTitle: false,
        title: const Text(
          'Other Menu',
          style: TextStyle(color: AppColors.black),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: TextButton.icon(
              onPressed: () async {
                // logic sama seperti tile "Account"
                final emails = await _getStoredAccountEmails();
                if (emails.length <= 1) {
                  final ok = await _confirmAddAccount(context);
                  if (ok) _goToAddAccount(context);
                  return;
                }
                showModalBottomSheet(
                  context: context,
                  shape: const RoundedRectangleBorder(
                    borderRadius: BorderRadius.vertical(
                      top: Radius.circular(16),
                    ),
                  ),
                  backgroundColor: Colors.white,
                  builder: (_) => _AccountSwitcher(
                    accountsFuture: _getStoredAccountEmails(),
                    getAccountName: _getAccountNameByEmail,
                  ),
                );
              },
              icon: const Icon(
                Icons.account_circle_outlined, // boleh ganti ke ikon lain
                size: 20,
                color: Color(0xFF4C6EF5), // biru seperti contoh
              ),
              label: const Text(
                'Switch Account',
                style: TextStyle(
                  color: Color(0xFF4C6EF5),
                  fontWeight: FontWeight.w600,
                ),
              ),
              style: TextButton.styleFrom(
                foregroundColor: const Color(0xFF4C6EF5),
                padding: const EdgeInsets.symmetric(horizontal: 10),
              ),
            ),
          ),
        ],
      ),

      body: SafeArea(
        child: ListView(
          children: [
            const _SectionTitle('Setting'),
            _MenuTile(
              title: 'Account',
              icon: LucideIcons.user,
              subtitle: null,
              onTap: () async {
                Navigator.pushReplacementNamed(context, '/edit-profile');
              },
            ),
            _MenuTile(
              title: 'Help',
              icon: LucideIcons.helpCircle,
              onTap: () {
                Navigator.pushNamed(context, '/help'); // ganti rute bila perlu
              },
            ),

            const SizedBox(height: 8),
            const _SectionTitle('Others'),
            _MenuTile(
              title: 'Terms & Conditions',
              icon: LucideIcons.fileText,
              onTap: () {
                Navigator.pushNamed(context, '/terms'); // ganti rute bila perlu
              },
            ),
            _MenuTile(
              title: 'Privacy Policy',
              icon: LucideIcons.shield,
              onTap: () {
                Navigator.pushNamed(
                  context,
                  '/privacy',
                ); // ganti rute bila perlu
              },
            ),

            const SizedBox(height: 16),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: SizedBox(
                height: 44,
                child: ElevatedButton(
                  onPressed: () => auth.logout(context),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(
                      0xFFC24340,
                    ), // merah seperti contoh
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text('Logout Account'),
                ),
              ),
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }
}

class _AccountSwitcher extends StatelessWidget {
  final Future<List<String>> accountsFuture;
  final Future<String?> Function(String email) getAccountName;

  const _AccountSwitcher({
    required this.accountsFuture,
    required this.getAccountName,
  });

  @override
  Widget build(BuildContext context) {
    final auth = Provider.of<AuthProvider>(context, listen: false);
    final currentEmail = auth.currentUserEmail; // pastikan sudah ada getter ini

    return FutureBuilder<List<String>>(
      future: accountsFuture,
      builder: (context, snap) {
        final accounts = snap.data ?? [];

        return Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  const Expanded(
                    child: Text(
                      'Switch Account',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(LucideIcons.x),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
              const SizedBox(height: 10),

              // ===== Daftar akun =====
              ListView.builder(
                shrinkWrap: true,
                itemCount: accounts.length + (accounts.length < 5 ? 1 : 0),
                itemBuilder: (context, index) {
                  // Tambah akun di item terakhir (opsional)
                  if (index >= accounts.length) {
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 6.0),
                      child: ListTile(
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 12.0,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        tileColor: AppColors.primary.withOpacity(0.1),
                        leading: const Icon(
                          LucideIcons.userPlus,
                          color: AppColors.primary,
                        ),
                        title: const Text(
                          'Tambahkan Akun Lainnya',
                          style: TextStyle(fontWeight: FontWeight.w600),
                        ),
                        trailing: const Icon(
                          LucideIcons.chevronRight,
                          color: AppColors.primary,
                        ),
                        onTap: () {
                          Navigator.pop(context);
                          showAddAccountModal(
                            Navigator.of(context, rootNavigator: true).context,
                          );
                        },
                      ),
                    );
                  }

                  final email = accounts[index]; // <- email terdefinisi di sini
                  final isActive = email == currentEmail;

                  return FutureBuilder<String?>(
                    future: getAccountName(email),
                    builder: (context, snapshot) {
                      final name = snapshot.data ?? 'Nama tidak ditemukan';

                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 6.0),
                        child: ListTile(
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 12.0,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          tileColor: Colors.grey[100],
                          leading: CircleAvatar(
                            backgroundColor: AppColors.primary,
                            child: Text(
                              email.isNotEmpty ? email[0].toUpperCase() : '?',
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          title: Row(
                            children: [
                              Expanded(
                                child: Text(
                                  name,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                              if (isActive)
                                Container(
                                  margin: const EdgeInsets.only(left: 8),
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 2,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Colors.green.withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: const Text(
                                    'Aktif',
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                      color: Colors.green,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                          subtitle: Text(
                            email,
                            style: const TextStyle(color: Colors.grey),
                          ),
                          trailing: isActive
                              ? null
                              : const Icon(
                                  LucideIcons.chevronRight,
                                  color: Colors.grey,
                                ),
                          onTap: isActive
                              ? null
                              : () async {
                                  Navigator.pop(context);
                                  final success =
                                      await Provider.of<AuthProvider>(
                                        context,
                                        listen: false,
                                      ).switchAccount(email);

                                  if (success) {
                                    Navigator.pushReplacementNamed(
                                      context,
                                      '/splash',
                                    );
                                  } else {
                                    final error = Provider.of<AuthProvider>(
                                      context,
                                      listen: false,
                                    ).error;
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Text(
                                          error ?? 'Gagal switch akun',
                                        ),
                                      ),
                                    );
                                  }
                                },
                        ),
                      );
                    },
                  );
                },
              ),
            ],
          ),
        );
      },
    );
  }
}
