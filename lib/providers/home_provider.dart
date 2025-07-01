import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import '../api/api_service.dart';

class HomeProvider with ChangeNotifier {
  List<Map<String, dynamic>> _chats = [];
  bool _isLoading = false;

  List<Map<String, dynamic>> get chats => _chats;
  bool get isLoading => _isLoading;

  String _searchQuery = '';
  String get searchQuery => _searchQuery;

  bool _isSearching = false;
  bool get isSearching => _isSearching;

  String _activeFilter = 'All';
  String get activeFilter => _activeFilter;

  Timer? _debounce;

  bool _hasError = false;
  bool get hasError => _hasError;

  Future<void> fetchChats() async {
    _isLoading = true;
    _hasError = false; // reset dulu
    notifyListeners();

    try {
      final response = await ApiService.get('/user/message/room');

      if (response.statusCode == 200) {
        final decoded = jsonDecode(response.body);
        final List<dynamic> data = decoded['data'];
        _chats = data.map((e) => e as Map<String, dynamic>).toList();
      } else {
        _hasError = true;
        _chats = []; // kosongkan jika error
      }
    } catch (e) {
      _hasError = true;
      _chats = [];
    }

    _isLoading = false;
    notifyListeners();
  }

  void updateSearchQuery(String query) {
    _isSearching = true;
    if (_debounce?.isActive ?? false) _debounce!.cancel();

    _debounce = Timer(const Duration(milliseconds: 400), () {
      _searchQuery = query.toLowerCase();
      _isSearching = false;

      // Delay notifyListeners to avoid calling during build
      WidgetsBinding.instance.addPostFrameCallback((_) {
        notifyListeners();
      });
    });
  }

  void setActiveFilter(String filter) {
    _activeFilter = filter;
    notifyListeners();
  }

  List<Map<String, dynamic>> get filteredChats {
    return chats.where((chat) {
      final isRead = chat['read'] == true;
      final name = (chat['name'] ?? '').toString().toLowerCase();

      final matchesFilter =
          _activeFilter == 'All' ||
          (_activeFilter == 'Unread' && !isRead) ||
          (_activeFilter == 'Read' && isRead);

      final matchesSearch = _searchQuery.isEmpty || name.contains(_searchQuery);

      return matchesFilter && matchesSearch;
    }).toList();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    super.dispose();
  }
}
