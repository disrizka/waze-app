import 'dart:convert';
import 'package:flutter/material.dart';
import '../services/api_service.dart';

class ChatDetailProvider with ChangeNotifier {
  bool _isLoading = true;
  bool _hasError = false;
  List<Map<String, dynamic>> _messages = [];
  Map<String, dynamic>? _room;

  bool get isLoading => _isLoading;
  bool get hasError => _hasError;
  List<Map<String, dynamic>> get messages => _messages;
  Map<String, dynamic>? get room => _room;

  Future<void> fetchChatDetail(BuildContext context, String roomId) async {
    _isLoading = true;
    _hasError = false;
    notifyListeners();

    try {
      final response = await ApiService.get(
        context,
        '/user/message/room/$roomId',
      );
      debugPrint('[DEBUG] Status Code: ${response.statusCode}');
      debugPrint('[DEBUG] Body: ${response.body}');

      if (response.statusCode == 200) {
        final decoded = jsonDecode(response.body);
        final List<dynamic> data = decoded['data'];
        _messages = data.map((e) => e as Map<String, dynamic>).toList();
        _room = decoded['room'] as Map<String, dynamic>?;
      } else {
        _hasError = true;
        _messages = [];
        _room = null;
        debugPrint(
          '[ERROR] Failed to fetch chat detail: ${response.statusCode}',
        );
      }
    } catch (e) {
      _hasError = true;
      _messages = [];
      _room = null;
      debugPrint('[EXCEPTION] fetchChatDetail error: $e');
    }

    _isLoading = false;
    notifyListeners();
  }

  void clearMessages() {
    _messages = [];
    notifyListeners();
  }

  Future<void> sendMessage(
    BuildContext context,
    String roomId,
    String message,
  ) async {
    if (message.trim().isEmpty) return;

    try {
      final payload = {'idUserMessageRoom': roomId, 'message': message};

      final response = await ApiService.post(
        context,
        '/user/message/send',
        payload,
      );

      debugPrint('[SEND] Status Code: ${response.statusCode}');
      debugPrint('[SEND] Body: ${response.body}');

      if (response.statusCode == 200) {
        await fetchChatDetail(context, roomId);
      } else {
        debugPrint('[SEND ERROR] Gagal mengirim: ${response.statusCode}');
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Gagal mengirim pesan')));
      }
    } catch (e) {
      debugPrint('[SEND EXCEPTION] $e');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Terjadi kesalahan saat mengirim pesan')),
      );
    }
  }
}
