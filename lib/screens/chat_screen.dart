// lib/screens/chat_screen.dart
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:wa_blast/providers/chat_provider.dart';
import 'package:wa_blast/widgets/chat_tile.dart';
import 'package:wa_blast/widgets/modal_login.dart';
import '../constants/app_colors.dart';
import '../providers/auth_provider.dart';
import 'chat_detail_screen.dart';

class ChatScreen extends StatefulWidget {
  const ChatScreen({super.key});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final TextEditingController _searchController = TextEditingController();
  bool _didInit = false;

  Future<int> _getStoredAccountCount() async {
    final prefs = await SharedPreferences.getInstance();
    final accounts = prefs.getStringList('accounts');
    return accounts?.length ?? 0;
  }

  Future<List<String>> _getStoredAccounts() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getStringList('accounts') ?? [];
  }

  @override
  void initState() {
    super.initState();
    final homeProvider = Provider.of<ChatProvider>(context, listen: false);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      homeProvider.fetchChats(context);
    });

    _searchController.addListener(() {
      homeProvider.updateSearchQuery(_searchController.text);
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_didInit) {
      _didInit = true;
      Future.microtask(() {
        final homeProvider = Provider.of<ChatProvider>(context, listen: false);
        homeProvider.fetchChats(context);
      });
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<String?> _getAccountName(String email) async {
    final prefs = await SharedPreferences.getInstance();
    final jsonString = prefs.getString('account_$email');
    if (jsonString == null) return null;

    try {
      final data = jsonDecode(jsonString);
      return data['name'];
    } catch (e) {
      return null;
    }
  }

  Widget _buildShimmer() {
    return ListView.builder(
      itemCount: 8,
      itemBuilder: (context, index) => ListTile(
        leading: const CircleAvatar(backgroundColor: AppColors.shimmerBase),
        title: Container(
          height: 14,
          width: 100,
          color: AppColors.shimmerBase,
          margin: const EdgeInsets.only(bottom: 4),
        ),
        subtitle: Container(
          height: 12,
          width: 80,
          color: AppColors.shimmerBase,
        ),
        trailing: Container(
          height: 12,
          width: 20,
          decoration: const BoxDecoration(
            shape: BoxShape.circle,
            color: AppColors.shimmerBase,
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final homeProvider = Provider.of<ChatProvider>(context);
    final filteredChats = homeProvider.filteredChats;

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        automaticallyImplyLeading: false,
        backgroundColor: AppColors.white,
        title: const Text(
          'Chats',
          style: TextStyle(
            color: AppColors.primaryText,
            fontWeight: FontWeight.bold,
          ),
        ),
        elevation: 0,
        actions: [
          const SizedBox(),
          const SizedBox(),
          // Consumer<AuthProvider>(
          //   builder: (context, auth, _) {
          //     final name = auth.name ?? '';
          //     final initial = name.isNotEmpty ? name[0].toUpperCase() : '?';

          //     return FutureBuilder<int>(
          //       future: _getStoredAccountCount(),
          //       builder: (context, snapshot) {
          //         final accountCount = snapshot.data ?? 1;
          //         final isSingleAccount = accountCount <= 1;

          //         return PopupMenuButton<String>(
          //           onSelected: (value) async {
          //             switch (value) {
          //               case 'switch':
          //                 final accounts = await _getStoredAccounts();

          //                 if (isSingleAccount) {
          //                   final confirm = await showDialog<bool>(
          //                     context: context,
          //                     builder: (context) {
          //                       return AlertDialog(
          //                         shape: RoundedRectangleBorder(
          //                           borderRadius: BorderRadius.circular(16),
          //                         ),
          //                         titlePadding: const EdgeInsets.fromLTRB(
          //                           24,
          //                           24,
          //                           24,
          //                           12,
          //                         ),
          //                         contentPadding: const EdgeInsets.symmetric(
          //                           horizontal: 24,
          //                         ),
          //                         actionsPadding: const EdgeInsets.only(
          //                           right: 16,
          //                           bottom: 12,
          //                         ),
          //                         title: Row(
          //                           children: const [
          //                             Icon(
          //                               LucideIcons.userPlus,
          //                               color: AppColors.primary,
          //                             ),
          //                             SizedBox(width: 12),
          //                             Text(
          //                               'Tambah Akun Lainnya?',
          //                               style: TextStyle(
          //                                 fontWeight: FontWeight.bold,
          //                                 fontSize: 18,
          //                                 color: AppColors.primaryText,
          //                               ),
          //                             ),
          //                           ],
          //                         ),
          //                         content: const Text(
          //                           'Apakah kamu ingin menambahkan akun lainnya? Kamu bisa login dan berpindah akun kapan saja.',
          //                           style: TextStyle(
          //                             fontSize: 14,
          //                             color: AppColors.secondaryText,
          //                           ),
          //                         ),
          //                         actions: [
          //                           TextButton(
          //                             onPressed: () =>
          //                                 Navigator.pop(context, false),
          //                             child: const Text(
          //                               'Batal',
          //                               style: TextStyle(color: Colors.black),
          //                             ),
          //                           ),
          //                           ElevatedButton.icon(
          //                             onPressed: () =>
          //                                 Navigator.pop(context, true),
          //                             icon: const Icon(LucideIcons.plus),
          //                             label: const Text('Ya, Tambahkan'),
          //                             style: ElevatedButton.styleFrom(
          //                               backgroundColor: AppColors.primary,
          //                               foregroundColor: Colors.white,
          //                               shape: RoundedRectangleBorder(
          //                                 borderRadius: BorderRadius.circular(
          //                                   8,
          //                                 ),
          //                               ),
          //                             ),
          //                           ),
          //                         ],
          //                       );
          //                     },
          //                   );

          //                   if (confirm == true) {
          //                     final rootContext = Navigator.of(
          //                       context,
          //                       rootNavigator: true,
          //                     ).context;
          //                     Future.microtask(() {
          //                       showAddAccountModal(rootContext);
          //                     });
          //                   }
          //                 } else {
          //                   showModalBottomSheet(
          //                     context: context,
          //                     shape: const RoundedRectangleBorder(
          //                       borderRadius: BorderRadius.vertical(
          //                         top: Radius.circular(16),
          //                       ),
          //                     ),
          //                     backgroundColor: Colors.white,
          //                     builder: (context) {
          //                       return _AccountSwitcher(
          //                         accountsFuture: _getStoredAccounts(),
          //                         getAccountName: _getAccountName,
          //                       );
          //                     },
          //                   );
          //                 }
          //                 break;

          //               case 'logout':
          //                 auth.logout(context);
          //                 break;
          //             }
          //           },
          //           itemBuilder: (context) => [
          //             PopupMenuItem(
          //               value: 'switch',
          //               child: Row(
          //                 children: [
          //                   Icon(
          //                     isSingleAccount
          //                         ? LucideIcons.userPlus
          //                         : LucideIcons.users,
          //                     color: Colors.black54,
          //                   ),
          //                   const SizedBox(width: 10),
          //                   Text(
          //                     isSingleAccount
          //                         ? 'Add Account'
          //                         : 'Switch Account',
          //                   ),
          //                 ],
          //               ),
          //             ),
          //             const PopupMenuItem(
          //               value: 'logout',
          //               child: Row(
          //                 children: [
          //                   Icon(LucideIcons.logOut, color: Colors.black54),
          //                   SizedBox(width: 10),
          //                   Text('Logout'),
          //                 ],
          //               ),
          //             ),
          //           ],
          //           shape: RoundedRectangleBorder(
          //             borderRadius: BorderRadius.circular(12),
          //           ),
          //           color: Colors.white,
          //           offset: const Offset(0, 50),
          //           elevation: 8,
          //           child: Padding(
          //             padding: const EdgeInsets.only(right: 16.0),
          //             child: CircleAvatar(
          //               backgroundColor: AppColors.primary,
          //               child: Text(
          //                 initial,
          //                 style: const TextStyle(
          //                   color: Colors.white,
          //                   fontWeight: FontWeight.bold,
          //                 ),
          //               ),
          //             ),
          //           ),
          //         );
          //       },
          //     );
          //   },
          // ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            child: TextField(
              controller: _searchController,
              decoration: const InputDecoration(
                hintText: 'Search by name',
                prefixIcon: Icon(LucideIcons.search),
                filled: true,
                fillColor: AppColors.background,
                contentPadding: EdgeInsets.all(12),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.all(Radius.circular(25)),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                _FilterChip(
                  label: 'All',
                  isActive: homeProvider.activeFilter == 'All',
                  onTap: () => homeProvider.setActiveFilter('All'),
                ),
                const SizedBox(width: 8),
                _FilterChip(
                  label: 'Unread',
                  isActive: homeProvider.activeFilter == 'Unread',
                  onTap: () => homeProvider.setActiveFilter('Unread'),
                ),
                const SizedBox(width: 8),
                _FilterChip(
                  label: 'Read',
                  isActive: homeProvider.activeFilter == 'Read',
                  onTap: () => homeProvider.setActiveFilter('Read'),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          Expanded(
            child: RefreshIndicator(
              color: Colors.blue,
              triggerMode: RefreshIndicatorTriggerMode
                  .anywhere, // ✅ tarik dari mana saja
              edgeOffset: 0, // posisi awal indikator
              displacement:
                  56, // jarak turun indikator (feel lebih cepat muncul)
              onRefresh: () async {
                await context.read<ChatProvider>().fetchChats(context);
              },
              child: homeProvider.isLoading || homeProvider.isSearching
                  ? ListView.builder(
                      physics:
                          const AlwaysScrollableScrollPhysics(), // <- penting
                      itemCount: 8,
                      itemBuilder: (context, index) => ListTile(
                        leading: const CircleAvatar(
                          backgroundColor: AppColors.shimmerBase,
                        ),
                        title: Container(
                          height: 14,
                          width: 100,
                          color: AppColors.shimmerBase,
                          margin: const EdgeInsets.only(bottom: 4),
                        ),
                        subtitle: Container(
                          height: 12,
                          width: 80,
                          color: AppColors.shimmerBase,
                        ),
                        trailing: Container(
                          height: 12,
                          width: 20,
                          decoration: const BoxDecoration(
                            shape: BoxShape.circle,
                            color: AppColors.shimmerBase,
                          ),
                        ),
                      ),
                    )
                  : homeProvider.hasError
                  ? ListView(
                      physics:
                          const AlwaysScrollableScrollPhysics(), // <- penting
                      children: const [
                        SizedBox(height: 200),
                        Center(child: Text('No message found')),
                      ],
                    )
                  : homeProvider.filteredChats.isEmpty
                  ? ListView(
                      physics:
                          const AlwaysScrollableScrollPhysics(), // <- penting
                      children: const [
                        SizedBox(height: 200),
                        Center(child: Text('No results found')),
                      ],
                    )
                  : ListView.builder(
                      physics: const BouncingScrollPhysics(
                        parent: AlwaysScrollableScrollPhysics(), // <- penting
                      ),
                      itemCount: filteredChats.length,
                      itemBuilder: (context, index) {
                        final chat = filteredChats[index];
                        return ChatTile(
                          chat: chat,
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => ChatDetailScreen(
                                  roomId: chat['idUserMessageRoom'].toString(),
                                ),
                              ),
                            );
                          },
                        );
                      },
                    ),
            ),
          ),
        ],
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
              ListView.builder(
                shrinkWrap: true,
                itemCount: accounts.length + (accounts.length < 5 ? 1 : 0),
                itemBuilder: (context, index) {
                  if (index < accounts.length) {
                    final email = accounts[index];
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
                                email[0].toUpperCase(),
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                            title: Text(
                              name,
                              style: const TextStyle(
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            subtitle: Text(
                              email,
                              style: const TextStyle(color: Colors.grey),
                            ),
                            trailing: const Icon(
                              LucideIcons.chevronRight,
                              color: Colors.grey,
                            ),
                            onTap: () async {
                              Navigator.pop(context);
                              final success = await Provider.of<AuthProvider>(
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
                                    content: Text(error ?? 'Gagal switch akun'),
                                  ),
                                );
                              }
                            },
                          ),
                        );
                      },
                    );
                  } else {
                    // Tambah akun
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
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            color: AppColors.primaryText,
                          ),
                        ),
                        trailing: const Icon(
                          LucideIcons.chevronRight,
                          color: AppColors.primary,
                        ),
                        onTap: () async {
                          Navigator.pop(context);
                          final rootContext = Navigator.of(
                            context,
                            rootNavigator: true,
                          ).context;

                          final confirm = await showDialog<bool>(
                            context: context,
                            builder: (context) {
                              return AlertDialog(
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(16),
                                ),
                                titlePadding: const EdgeInsets.fromLTRB(
                                  24,
                                  24,
                                  24,
                                  12,
                                ),
                                contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 24,
                                ),
                                actionsPadding: const EdgeInsets.only(
                                  right: 16,
                                  bottom: 12,
                                ),
                                title: Row(
                                  children: const [
                                    Icon(
                                      LucideIcons.userPlus,
                                      color: AppColors.primary,
                                    ),
                                    SizedBox(width: 12),
                                    Text(
                                      'Tambah Akun Lainnya?',
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 18,
                                        color: AppColors.primaryText,
                                      ),
                                    ),
                                  ],
                                ),
                                content: const Text(
                                  'Apakah kamu ingin menambahkan akun lainnya? Kamu bisa login dan berpindah akun kapan saja.',
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: AppColors.secondaryText,
                                  ),
                                ),
                                actions: [
                                  TextButton(
                                    onPressed: () =>
                                        Navigator.pop(context, false),
                                    child: const Text(
                                      'Batal',
                                      style: TextStyle(color: Colors.black),
                                    ),
                                  ),
                                  ElevatedButton.icon(
                                    onPressed: () =>
                                        Navigator.pop(context, true),
                                    icon: const Icon(LucideIcons.plus),
                                    label: const Text('Ya, Tambahkan'),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: AppColors.primary,
                                      foregroundColor: Colors.white,
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                    ),
                                  ),
                                ],
                              );
                            },
                          );

                          if (confirm == true) {
                            Future.microtask(() {
                              showAddAccountModal(rootContext);
                            });
                          }
                        },
                      ),
                    );
                  }
                },
              ),
            ],
          ),
        );
      },
    );
  }
}

class _FilterChip extends StatelessWidget {
  final String label;
  final bool isActive;
  final VoidCallback onTap;

  const _FilterChip({
    required this.label,
    required this.isActive,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Chip(
        label: Text(
          label,
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: isActive ? AppColors.white : AppColors.primaryText,
          ),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 12),
        backgroundColor: isActive ? AppColors.primary : AppColors.chipInactive,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      ),
    );
  }
}
