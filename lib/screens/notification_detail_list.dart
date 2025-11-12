// lib/screens/notification_detail_screen.dart
import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:wa_blast/providers/notification_provider.dart';
import 'package:wa_blast/constants/app_colors.dart';

class NotificationDetailScreen extends StatefulWidget {
  static const routeName = '/notification/detail';

  final String idNotification;
  const NotificationDetailScreen({super.key, required this.idNotification});

  @override
  State<NotificationDetailScreen> createState() =>
      _NotificationDetailScreenState();

  /// Helper untuk push dengan arguments dari mana saja
  static Future<void> open(BuildContext context, String idNotification) async {
    await Navigator.pushNamed(
      context,
      NotificationDetailScreen.routeName,
      arguments: idNotification,
    );
    // setelah kembali, segarkan badge
    // ignore: use_build_context_synchronously
    await context.read<NotificationProvider>().fetchUnreadCount(context);
  }
}

class _NotificationDetailScreenState extends State<NotificationDetailScreen> {
  bool _firstRun = true;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_firstRun) {
      _firstRun = false;
      _load();
    }
  }

  Future<void> _load() async {
    final np = context.read<NotificationProvider>();
    final detail = await np.fetchNotificationDetail(
      context,
      widget.idNotification,
    );
    if (detail != null && !detail.isRead) {
      await np.markAsRead(context, detail.idNotification);
      // refresh unread badge
      // ignore: use_build_context_synchronously
      await np.fetchUnreadCount(context);
      setState(() {}); // render ulang
    }
  }

  Future<void> _openAction(NotificationItem n) async {
    final url = n.actionUrl?.trim();
    if (url == null || url.isEmpty) return;

    if (url.startsWith('http')) {
      final uri = Uri.tryParse(url);
      if (uri != null && await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      }
    } else {
      // TODO: handle waveup://xxx -> route internal app
      // Navigator.pushNamed(context, '/somewhere');
    }
  }

  @override
  Widget build(BuildContext context) {
    final np = context.watch<NotificationProvider>();
    final n = np.notificationDetail; // detail terakhir yang di-fetch
    final loading = np.loadingDetail && n == null;

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Notification Detail',
          style: TextStyle(color: AppColors.black),
        ),
        backgroundColor: AppColors.white,
        foregroundColor: Colors.black,
      ),
      body: loading
          ? const Center(child: CircularProgressIndicator())
          : (n == null
                ? const _DetailError()
                : SingleChildScrollView(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // title + pill read
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: Text(
                                n.title,
                                style: const TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w800,
                                  color: Color(0xFF111827),
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: n.isRead
                                    ? const Color(0xFFE5E7EB)
                                    : const Color(0xFFFEF3C7),
                                borderRadius: BorderRadius.circular(999),
                                border: Border.all(
                                  color: n.isRead
                                      ? const Color(0xFFD1D5DB)
                                      : const Color(0xFFF59E0B),
                                ),
                              ),
                              child: Text(
                                n.isRead ? 'Read' : 'NEW',
                                style: TextStyle(
                                  color: n.isRead
                                      ? const Color(0xFF374151)
                                      : const Color(0xFFB45309),
                                  fontSize: 11,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),

                        // timestamps
                        Row(
                          children: [
                            const Icon(
                              LucideIcons.clock,
                              size: 16,
                              color: Color(0xFF6B7280),
                            ),
                            const SizedBox(width: 6),
                            Text(
                              _fmtDateTime(n.sentAt ?? n.createdAt),
                              style: const TextStyle(color: Color(0xFF6B7280)),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),

                        // image
                        if (n.imageUrl != null && n.imageUrl!.isNotEmpty) ...[
                          ClipRRect(
                            borderRadius: BorderRadius.circular(12),
                            child: Image.network(
                              n.imageUrl!,
                              fit: BoxFit.cover,
                              errorBuilder: (_, __, ___) => Container(
                                height: 160,
                                color: const Color(0xFFF3F4F6),
                                child: const Center(
                                  child: Icon(
                                    Icons.image_not_supported_outlined,
                                    color: Color(0xFF9CA3AF),
                                  ),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 16),
                        ],

                        // message
                        Text(
                          n.message,
                          style: const TextStyle(
                            fontSize: 15,
                            height: 1.35,
                            color: Color(0xFF111827),
                          ),
                        ),
                        const SizedBox(height: 20),

                        // action
                        if (n.actionUrl != null && n.actionUrl!.isNotEmpty)
                          SizedBox(
                            height: 44,
                            width: double.infinity,
                            child: ElevatedButton.icon(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF1D4ED8),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(10),
                                ),
                              ),
                              onPressed: () => _openAction(n),
                              icon: const Icon(
                                LucideIcons.link,
                                color: Colors.white,
                                size: 18,
                              ),
                              label: const Text(
                                'Open Link',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                  )),
    );
  }
}

class _DetailError extends StatelessWidget {
  const _DetailError();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: const [
            Icon(LucideIcons.alertTriangle, size: 40, color: Color(0xFFDC2626)),
            SizedBox(height: 12),
            Text(
              'Gagal memuat detail notifikasi',
              style: TextStyle(fontWeight: FontWeight.w700),
            ),
          ],
        ),
      ),
    );
  }
}

String _fmtDateTime(DateTime? dt) {
  if (dt == null) return '—';
  // tampilkan jelas: 2025-11-11 15:05
  final y = dt.year.toString().padLeft(4, '0');
  final m = dt.month.toString().padLeft(2, '0');
  final d = dt.day.toString().padLeft(2, '0');
  final h = dt.hour.toString().padLeft(2, '0');
  final min = dt.minute.toString().padLeft(2, '0');
  return '$y-$m-$d $h:$min';
}
