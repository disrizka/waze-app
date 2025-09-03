// lib/screens/main_wrapper.dart
import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:wa_blast/constants/app_colors.dart';
import 'package:wa_blast/screens/home_screen.dart';
import 'package:wa_blast/screens/setting_screen.dart';
import 'chat_screen.dart';

class MainWrapper extends StatefulWidget {
  const MainWrapper({super.key});

  @override
  State<MainWrapper> createState() => _MainWrapperState();
}

class _MainWrapperState extends State<MainWrapper> {
  int _selectedIndex = 0;

  final List<Widget> _screens = const [
    HomeScreen(),
    ChatScreen(),
    ProfileScreen(),
  ];

  void _onTabTapped(int index) => setState(() => _selectedIndex = index);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _screens[_selectedIndex],
      bottomNavigationBar: ClipRRect(
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        child: Theme(
          data: Theme.of(context).copyWith(
            splashColor: Colors.transparent,
            highlightColor: Colors.transparent,
            splashFactory: NoSplash.splashFactory, // <— ini hilangkan efek ink
          ),
          child: BottomNavigationBar(
            backgroundColor: Colors.white,
            type: BottomNavigationBarType.fixed,
            currentIndex: _selectedIndex,
            onTap: _onTabTapped,
            selectedItemColor: AppColors.blue,
            unselectedItemColor: AppColors.grey,
            selectedLabelStyle: const TextStyle(fontWeight: FontWeight.w600),
            items: const [
              BottomNavigationBarItem(
                icon: Icon(
                  LucideIcons.layoutGrid,
                ), // default (unselected → filled)
                activeIcon: Icon(
                  LucideIcons.layoutGrid,
                ), // kalau aktif → outlined
                label: 'Home',
              ),
              BottomNavigationBarItem(
                icon: Icon(LucideIcons.messagesSquare),
                activeIcon: Icon(LucideIcons.messagesSquare),
                label: 'Chats',
              ),
              BottomNavigationBarItem(
                icon: Icon(LucideIcons.settings),
                activeIcon: Icon(LucideIcons.settings),
                label: 'Menu',
              ),
            ],
          ),
        ),
      ),
    );
  }
}
