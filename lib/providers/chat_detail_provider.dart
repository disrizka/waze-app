import 'dart:convert';
import 'package:flutter/material.dart';
import '../api/api_service.dart';

class ChatDetailProvider with ChangeNotifier {
  bool _isLoading = true;
  bool _hasError = false;
  List<Map<String, dynamic>> _messages = [];
  Map<String, dynamic>? _room;

  bool get isLoading => _isLoading;
  bool get hasError => _hasError;
  List<Map<String, dynamic>> get messages => _messages;
  Map<String, dynamic>? get room => _room;

  Future<void> fetchChatDetail(String roomId) async {
    _isLoading = true;
    _hasError = false;
    notifyListeners();

    try {
      final response = await ApiService.get('/user/message/room/$roomId');
      print('[DEBUG] Status Code: ${response.statusCode}');
      print('[DEBUG] Body: ${response.body}');

      if (response.statusCode == 200) {
        final decoded = jsonDecode(response.body);
        final List<dynamic> data = decoded['data'];
        _messages = data.map((e) => e as Map<String, dynamic>).toList();
        _room = decoded['room'] as Map<String, dynamic>?;
        print('[DEBUG] Parsed Messages: $_messages');
        print('[DEBUG] Room Info: $_room');
      } else {
        _hasError = true;
        _messages = [];
        _room = null;
        print(
          '[ERROR] Failed to fetch chat detail: ${response.statusCode} - ${response.reasonPhrase}',
        );
      }
    } catch (e) {
      _hasError = true;
      _messages = [];
      _room = null;
      print('[EXCEPTION] fetchChatDetail error: $e');
    }

    _isLoading = false;
    notifyListeners();
  }

  void clearMessages() {
    _messages = [];
    notifyListeners();
  }
}
