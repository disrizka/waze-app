import 'package:flutter/material.dart';

class ChatTile extends StatelessWidget {
  final Map<String, dynamic> chat;
  final VoidCallback onTap;

  const ChatTile({super.key, required this.chat, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final isUnread = !(chat['read'] as bool);
    final name = chat['name']?.toString() ?? '';
    final number = chat['number']?.toString() ?? '';
    final time = (chat['lastUpdate'] ?? '').toString();
    final initial = name.isNotEmpty ? name[0].toUpperCase() : '?';

    return ListTile(
      leading: CircleAvatar(
        backgroundColor: Colors.green[200],
        child: Text(initial, style: const TextStyle(color: Colors.white)),
      ),
      title: Text(name),
      subtitle: Text('+$number'),
      trailing: Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Text(
            time.length >= 16 ? time.substring(11, 16) : '',
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
              child: const Icon(Icons.circle, size: 6, color: Colors.green),
            ),
        ],
      ),
      onTap: onTap,
    );
  }
}
