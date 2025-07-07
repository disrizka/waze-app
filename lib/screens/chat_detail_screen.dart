import 'dart:io';

import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:provider/provider.dart';
import 'package:shimmer/shimmer.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:wa_blast/widgets/chat_bubble.dart';

import '../constants/app_colors.dart';
import '../providers/chat_detail_provider.dart';

class ChatDetailScreen extends StatefulWidget {
  final String roomId;
  const ChatDetailScreen({super.key, required this.roomId});

  @override
  State<ChatDetailScreen> createState() => _ChatDetailScreenState();
}

class _ChatDetailScreenState extends State<ChatDetailScreen> {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();

    _messageController.addListener(() {
      setState(() {});
    });

    final provider = ChatDetailProvider();
    provider.addListener(() {
      if (!provider.isLoading && provider.messages.isNotEmpty) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (_scrollController.hasClients) {
            _scrollController.jumpTo(
              _scrollController.position.maxScrollExtent,
            );
          }
        });
      }
    });

    provider.fetchChatDetail(context, widget.roomId);
  }

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) =>
          ChatDetailProvider()..fetchChatDetail(context, widget.roomId),
      child: Scaffold(
        backgroundColor: AppColors.background,
        resizeToAvoidBottomInset: true,
        appBar: AppBar(
          backgroundColor: AppColors.white,
          foregroundColor: AppColors.primaryText,
          title: Consumer<ChatDetailProvider>(
            builder: (context, provider, _) {
              final name = provider.room?['name'] ?? 'Chat Detail';
              final number = provider.room?['number'] ?? '';
              return Row(
                children: [
                  CircleAvatar(
                    radius: 18,
                    backgroundColor: AppColors.primary,
                    child: Text(
                      name.toString().substring(0, 1).toUpperCase(),
                      style: const TextStyle(color: AppColors.white),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          name,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                          overflow: TextOverflow.ellipsis,
                          maxLines: 1,
                        ),
                        Text(
                          '+$number',
                          style: const TextStyle(
                            fontSize: 13,
                            color: AppColors.secondaryText,
                          ),
                          overflow: TextOverflow.ellipsis,
                          maxLines: 1,
                        ),
                      ],
                    ),
                  ),
                ],
              );
            },
          ),
          actions: [
            Consumer<ChatDetailProvider>(
              builder: (context, provider, _) {
                final number = provider.room?['number'];
                if (number == null || number.toString().isEmpty)
                  return const SizedBox();
                return Padding(
                  padding: const EdgeInsets.only(right: 12),
                  child: IconButton(
                    icon: const Icon(Icons.call, color: AppColors.primary),
                    onPressed: () {
                      _launchPhoneDialer(number.toString());
                    },
                  ),
                );
              },
            ),
          ],
        ),
        body: Consumer<ChatDetailProvider>(
          builder: (context, provider, _) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (!provider.isLoading &&
                  provider.messages.isNotEmpty &&
                  _scrollController.hasClients) {
                _scrollController.jumpTo(
                  _scrollController.position.maxScrollExtent,
                );
              }
            });

            return Column(
              children: [
                Expanded(
                  child: provider.isLoading
                      ? ListView.builder(
                          itemCount: 8,
                          padding: const EdgeInsets.all(12),
                          itemBuilder: (context, index) {
                            return Shimmer.fromColors(
                              baseColor: AppColors.shimmerBase,
                              highlightColor: AppColors.shimmerHighlight,
                              child: Padding(
                                padding: const EdgeInsets.symmetric(
                                  vertical: 8.0,
                                ),
                                child: Row(
                                  crossAxisAlignment: CrossAxisAlignment.end,
                                  children: [
                                    Container(
                                      width: 200,
                                      height: 60,
                                      decoration: BoxDecoration(
                                        color: AppColors.white,
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        )
                      : provider.hasError
                      ? const Center(child: Text('Failed to load messages'))
                      : provider.messages.isEmpty
                      ? const Center(child: Text('No messages in this chat'))
                      : ListView.builder(
                          controller: _scrollController,
                          padding: const EdgeInsets.all(10),
                          itemCount: provider.messages.length,
                          itemBuilder: (context, index) {
                            final message = provider.messages[index];
                            return ChatBubble(
                              message: message['message'] ?? '',
                              timestamp: message['createdAt'] ?? '',
                              isMe:
                                  message['idUser'] != null &&
                                  message['idUser'].toString().isNotEmpty,
                            );
                          },
                        ),
                ),
                Padding(
                  padding: MediaQuery.of(context).viewInsets,
                  child: SafeArea(
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 6,
                      ),
                      decoration: const BoxDecoration(color: AppColors.white),
                      child: Row(
                        children: [
                          IconButton(
                            icon: const Icon(
                              Icons.chat_bubble,
                              color: AppColors.primary,
                            ),
                            onPressed: () {},
                          ),
                          Flexible(
                            child: Container(
                              constraints: const BoxConstraints(maxHeight: 150),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 6,
                              ),
                              decoration: BoxDecoration(
                                color: AppColors.inputBackground,
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(color: AppColors.border),
                              ),
                              child: TextField(
                                controller: _messageController,
                                keyboardType: TextInputType.multiline,
                                maxLines: null,
                                minLines: 1,
                                decoration: const InputDecoration(
                                  hintText: 'Type a message',
                                  border: InputBorder.none,
                                  isCollapsed: true,
                                ),
                              ),
                            ),
                          ),
                          AnimatedSwitcher(
                            duration: const Duration(milliseconds: 250),
                            transitionBuilder: (child, animation) =>
                                FadeTransition(
                                  opacity: animation,
                                  child: SizeTransition(
                                    sizeFactor: animation,
                                    axis: Axis.horizontal,
                                    child: child,
                                  ),
                                ),
                            child: _messageController.text.trim().isEmpty
                                ? const SizedBox(
                                    key: ValueKey('empty'),
                                    width: 30,
                                  )
                                : Row(
                                    key: const ValueKey('filled'),
                                    children: [
                                      const SizedBox(width: 6),
                                      IconButton(
                                        icon: const Icon(
                                          Icons.send,
                                          color: AppColors.primary,
                                        ),
                                        onPressed: () {
                                          final message = _messageController
                                              .text
                                              .trim();
                                          if (message.isNotEmpty) {
                                            final provider =
                                                Provider.of<ChatDetailProvider>(
                                                  context,
                                                  listen: false,
                                                );
                                            provider.sendMessage(
                                              context,
                                              widget.roomId,
                                              message,
                                            );
                                            _messageController.clear();
                                            setState(() {});
                                          }
                                        },
                                      ),
                                    ],
                                  ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  Future<void> _launchPhoneDialer(String number) async {
    final Uri uri = Uri(scheme: 'tel', path: number);

    if (Platform.isAndroid) {
      if (await Permission.phone.request().isGranted) {
        if (await canLaunchUrl(uri)) {
          await launchUrl(uri, mode: LaunchMode.externalApplication);
        } else {
          _showSnackBar('Tidak dapat membuka dialer');
        }
      } else {
        _showSnackBar('Izin panggilan ditolak');
      }
    } else if (Platform.isIOS) {
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } else {
        _showSnackBar('Tidak dapat membuka dialer');
      }
    }
  }

  void _showSnackBar(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }
}
