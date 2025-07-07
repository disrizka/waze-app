import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:wa_blast/widgets/chat_tile.dart';
import '../constants/app_colors.dart';
import '../providers/auth_provider.dart';
import '../providers/home_provider.dart';
import 'chat_detail_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final TextEditingController _searchController = TextEditingController();
  bool _didInit = false;

  @override
  void initState() {
    super.initState();
    final homeProvider = Provider.of<HomeProvider>(context, listen: false);

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
        final homeProvider = Provider.of<HomeProvider>(context, listen: false);
        homeProvider.fetchChats(context);
      });
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
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
    final homeProvider = Provider.of<HomeProvider>(context);
    final filteredChats = homeProvider.filteredChats;

    return Scaffold(
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
          IconButton(
            icon: const Icon(Icons.refresh, color: AppColors.secondaryText),
            tooltip: 'Refresh',
            onPressed: () {
              Provider.of<HomeProvider>(
                context,
                listen: false,
              ).fetchChats(context);
            },
          ),
          IconButton(
            icon: const Icon(Icons.edit, color: AppColors.secondaryText),
            onPressed: () {
              Provider.of<AuthProvider>(context, listen: false).logout(context);
              Navigator.pushReplacementNamed(context, '/home');
            },
          ),
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
                prefixIcon: Icon(Icons.search),
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
            child: homeProvider.isLoading || homeProvider.isSearching
                ? _buildShimmer()
                : homeProvider.hasError
                ? const Center(child: Text('No message found'))
                : filteredChats.isEmpty
                ? const Center(child: Text('No results found'))
                : ListView.builder(
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
        ],
      ),
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
