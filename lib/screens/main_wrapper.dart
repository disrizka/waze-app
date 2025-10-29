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

  // Flag agar argumen route hanya di-apply sekali.
  bool _appliedInitialArgs = false;

  // Untuk mendeteksi perubahan canWaba antar rebuild.
  bool? _lastCanWaba;

  /// Map argumen `tab` (int atau String) ke index aktual,
  /// sambil memperhatikan `canWaba`.
  int _resolveTabIndex(dynamic tabArg, bool canWaba) {
    if (tabArg is int) {
      var idx = tabArg;
      if (!canWaba && idx > 0) idx = 1;
      return idx.clamp(0, canWaba ? 2 : 1);
    }

    if (tabArg is String) {
      switch (tabArg.toLowerCase()) {
        case 'home':
          return 0;
        case 'chats':
          return canWaba ? 1 : 0;
        case 'settings':
        case 'setting':
          return canWaba ? 2 : 1;
      }
    }

    return 0;
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    final canWaba = context.read<RoleProvider>().canPage('waba');

    // 1) Apply argumen route HANYA SEKALI saat pertama kali widget siap.
    if (!_appliedInitialArgs) {
      final args = ModalRoute.of(context)?.settings.arguments;
      if (args is Map && args['tab'] != null) {
        _selectedIndex = _resolveTabIndex(args['tab'], canWaba);
      }
      _appliedInitialArgs = true;
      _lastCanWaba = canWaba;
      // Tidak perlu setState; didChangeDependencies dipanggil sebelum build berikutnya.
      return;
    }

    // 2) Jika izin WABA berubah (mis. dicabut/diberi), selaraskan index.
    if (_lastCanWaba != canWaba) {
      // Struktur index: [Home, (Chats jika canWaba), Settings]
      if (!canWaba && _selectedIndex == 1) {
        // Sedang di tab Chats, tapi kini Chats hilang → fallback ke Home.
        _selectedIndex = 0;
      }
      // Pastikan index tidak out-of-range setelah perubahan canWaba.
      final maxIndex = canWaba ? 2 : 1;
      if (_selectedIndex > maxIndex) {
        _selectedIndex = maxIndex;
      }
      _lastCanWaba = canWaba;
      // Tidak wajib setState di sini; build berikutnya akan dipanggil setelah ini.
    }
  }

  @override
  Widget build(BuildContext context) {
    final canWaba = context.watch<RoleProvider>().canPage('waba');

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

    // Guard bila index tidak valid (mis. WABA berubah).
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
