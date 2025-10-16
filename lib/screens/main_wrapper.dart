import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:provider/provider.dart';
import 'package:wa_blast/constants/app_colors.dart';
import 'package:wa_blast/screens/home_screen.dart';
import 'package:wa_blast/screens/chat_screen.dart';
import 'package:wa_blast/providers/role_provider.dart';
import 'package:wa_blast/screens/setting_screen.dart';

class MainWrapper extends StatefulWidget {
  const MainWrapper({super.key});

  @override
  State<MainWrapper> createState() => _MainWrapperState();
}

class _MainWrapperState extends State<MainWrapper> {
  int _selectedIndex = 0;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final args = ModalRoute.of(context)?.settings.arguments;
    final canWaba = context.read<RoleProvider>().canPage('waba');

    if (args is Map && args['tab'] is int) {
      int target = args['tab'] as int;

      // Jika WABA tidak diizinkan, tab index disesuaikan:
      // - 0: Home
      // - 1: (jika WABA disembunyikan → Profile)
      if (!canWaba && target > 0) target = 1;

      if (_selectedIndex != target) setState(() => _selectedIndex = target);
    }
  }

  @override
  Widget build(BuildContext context) {
    final canWaba = context.watch<RoleProvider>().canPage('waba');

    // Tentukan tab & screen secara dinamis
    final screens = <Widget>[
      const HomeScreen(),
      if (canWaba) const ChatScreen(),
      const ProfileScreen(),
    ];

    final items = <BottomNavigationBarItem>[
      const BottomNavigationBarItem(
        icon: Icon(LucideIcons.layoutGrid),
        activeIcon: Icon(LucideIcons.layoutGrid),
        label: 'Home',
      ),
      if (canWaba)
        const BottomNavigationBarItem(
          icon: Icon(LucideIcons.messagesSquare),
          activeIcon: Icon(LucideIcons.messagesSquare),
          label: 'Chats',
        ),
      const BottomNavigationBarItem(
        icon: Icon(LucideIcons.settings),
        activeIcon: Icon(LucideIcons.settings),
        label: 'Setting',
      ),
    ];

    // Pastikan index valid (misal: sebelumnya 1 tapi WABA baru dicabut)
    if (_selectedIndex >= screens.length) {
      _selectedIndex = screens.length - 1;
    }

    return Scaffold(
      body: screens[_selectedIndex],
      bottomNavigationBar: ClipRRect(
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        child: Theme(
          data: Theme.of(context).copyWith(
            splashColor: Colors.transparent,
            highlightColor: Colors.transparent,
            splashFactory: NoSplash.splashFactory,
          ),
          child: BottomNavigationBar(
            backgroundColor: Colors.white,
            type: BottomNavigationBarType.fixed,
            currentIndex: _selectedIndex,
            onTap: (index) => setState(() => _selectedIndex = index),
            selectedItemColor: AppColors.blue,
            unselectedItemColor: AppColors.grey,
            selectedLabelStyle: const TextStyle(fontWeight: FontWeight.w600),
            items: items,
          ),
        ),
      ),
    );
  }
}
