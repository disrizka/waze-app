import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
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

  @override
  void initState() {
    super.initState();
    final homeProvider = Provider.of<HomeProvider>(context, listen: false);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      homeProvider.fetchChats();
    });

    _searchController.addListener(() {
      homeProvider.updateSearchQuery(_searchController.text);
    });
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
        leading: CircleAvatar(backgroundColor: Colors.grey.shade300),
        title: Container(
          height: 14,
          width: 100,
          color: Colors.grey.shade300,
          margin: const EdgeInsets.only(bottom: 4),
        ),
        subtitle: Container(height: 12, width: 80, color: Colors.grey.shade300),
        trailing: Container(
          height: 12,
          width: 20,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: Colors.grey.shade300,
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
        backgroundColor: Colors.white,
        title: const Text(
          'Chats',
          style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold),
        ),
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.black54),
            tooltip: 'Refresh',
            onPressed: () {
              Provider.of<HomeProvider>(context, listen: false).fetchChats();
            },
          ),
          IconButton(
            icon: const Icon(Icons.camera_alt_outlined, color: Colors.black54),
            onPressed: () {},
          ),
          IconButton(
            icon: const Icon(Icons.edit, color: Colors.black54),
            onPressed: () {
              Provider.of<AuthProvider>(context, listen: false).logout();
              Navigator.pushReplacementNamed(context, '/');
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
                fillColor: Color(0xFFF2F2F2),
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
                      final isUnread = !(chat['read'] as bool);

                      return ListTile(
                        leading: CircleAvatar(
                          backgroundColor: Colors.green[200],
                          child: Text(
                            chat['name'].toString().substring(0, 1),
                            style: const TextStyle(color: Colors.white),
                          ),
                        ),
                        title: Text(chat['name']),
                        subtitle: Text(chat['number']),
                        trailing: Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(
                              chat['lastUpdate'].toString().substring(11, 16),
                              style: const TextStyle(fontSize: 12),
                            ),
                            if (isUnread)
                              Container(
                                margin: const EdgeInsets.only(top: 10),
                                width: 12,
                                height: 12,
                                decoration: const BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: Colors.green,
                                ),
                                child: const Icon(
                                  Icons.circle,
                                  size: 6,
                                  color: Colors
                                      .green, // atau gunakan Colors.greenAccent jika ingin outline lebih halus
                                ),
                              ),
                          ],
                        ),
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
            color: isActive ? Colors.white : Colors.black,
          ),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 12),
        backgroundColor: isActive ? Colors.green : Colors.grey.shade200,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      ),
    );
  }
}
