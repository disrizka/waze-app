import 'package:flutter/material.dart';

class ChatTile extends StatelessWidget {
  final String name;
  final String message;

  const ChatTile({super.key, required this.name, required this.message});

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: const CircleAvatar(child: Icon(Icons.person)),
      title: Text(name),
      subtitle: Text(message),
      onTap: () {
        // Future enhancement: open chat detail
      },
    );
  }
}
