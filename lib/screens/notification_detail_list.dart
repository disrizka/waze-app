// lib/screens/notification_detail_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:wa_blast/providers/notification_provider.dart';
import 'package:wa_blast/constants/app_colors.dart';
import 'package:wa_blast/services/deep_link_service.dart';

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

    if (!mounted) return;

    if (detail != null && !detail.isRead) {
      await np.markAsRead(context, detail.idNotification);
      if (!mounted) return;
      // refresh unread badge
      await np.fetchUnreadCount(context);
    }

    if (mounted) {
      setState(() {}); // render ulang jika perlu
    }
  }

  /// Handler generic untuk semua URL (actionUrl dan URL di dalam message)
  Future<void> _handleUrl(String? rawUrl) async {
    final url = rawUrl?.trim();
    if (url == null || url.isEmpty) return;

    // http / https -> buka web (browser / webview sesuai konfigurasi url_launcher)
    if (url.startsWith('http')) {
      final uri = Uri.tryParse(url);
      if (uri != null && await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      }
      return;
    }

    final uri = Uri.tryParse(url);
    if (uri != null && uri.scheme == 'waveup') {
      await DeepLinkService.handleInAppUrl(url);
      return;
    }

    // selain http(s) -> nanti bisa di-mapping ke deep link internal
    // Contoh: waveup://something
    // TODO: sesuaikan dengan kebutuhan routing internal app
    // Navigator.pushNamed(context, '/somewhere');
  }

  Future<void> _openAction(NotificationItem n) async {
    await _handleUrl(n.actionUrl);
  }

  @override
  Widget build(BuildContext context) {
    final np = context.watch<NotificationProvider>();
    final n = np.notificationDetail; // detail terakhir yang di-fetch
    final loading = np.loadingDetail && n == null;

    return Scaffold(
      backgroundColor: const Color(0xFFF3F4F6),
      appBar: AppBar(
        title: const Text(
          'Notification',
          style: TextStyle(color: AppColors.black, fontWeight: FontWeight.w700),
        ),
        elevation: 0,
        centerTitle: false,
        backgroundColor: AppColors.white,
        foregroundColor: Colors.black,
      ),
      body: loading
          ? const Center(child: CircularProgressIndicator())
          : (n == null
                ? const _DetailError()
                : SingleChildScrollView(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 20,
                    ),
                    child: Align(
                      alignment: Alignment.topCenter,
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 480),
                        child: _buildDetailCard(context, n),
                      ),
                    ),
                  )),
    );
  }

  Widget _buildDetailCard(BuildContext context, NotificationItem n) {
    return Card(
      elevation: 0,
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: const BorderSide(color: Color(0xFFE5E7EB), width: 0.6),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header icon + badge
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xFFE0ECFF),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: const Icon(
                    LucideIcons.bell,
                    size: 18,
                    color: Color(0xFF1D4ED8),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'WaveUp Notification',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 13,
                      color: Color(0xFF6B7280),
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: n.isRead
                        ? const Color(0xFFF3F4F6)
                        : const Color(0xFFEEF2FF),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    n.isRead ? 'Read' : 'NEW',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: n.isRead
                          ? const Color(0xFF6B7280)
                          : const Color(0xFF4F46E5),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),

            // Title
            Text(
              n.title,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: Color(0xFF111827),
                height: 1.3,
              ),
            ),
            const SizedBox(height: 8),

            // Timestamp
            Row(
              children: [
                const Icon(
                  LucideIcons.clock,
                  size: 16,
                  color: Color(0xFF9CA3AF),
                ),
                const SizedBox(width: 6),
                Text(
                  _fmtDateTime(n.sentAt ?? n.createdAt),
                  style: const TextStyle(
                    fontSize: 12,
                    color: Color(0xFF6B7280),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Optional image
            if (n.imageUrl != null && n.imageUrl!.isNotEmpty) ...[
              ClipRRect(
                borderRadius: BorderRadius.circular(14),
                child: AspectRatio(
                  aspectRatio: 16 / 9,
                  child: Image.network(
                    n.imageUrl!,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => Container(
                      color: const Color(0xFFF3F4F6),
                      child: const Center(
                        child: Icon(
                          Icons.image_not_supported_outlined,
                          color: Color(0xFF9CA3AF),
                          size: 32,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 16),
            ],

            // Message with clickable links
            _MessageWithLinks(message: n.message, onTapLink: _handleUrl),

            const SizedBox(height: 20),

            // Action button jika ada actionUrl
            if (n.actionUrl != null && n.actionUrl!.trim().isNotEmpty)
              SizedBox(
                height: 44,
                width: double.infinity,
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF1D4ED8),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    elevation: 0,
                  ),
                  onPressed: () => _openAction(n),
                  label: const Text(
                    'Open',
                    style: TextStyle(fontWeight: FontWeight.w700),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _MessageWithLinks extends StatelessWidget {
  final String message;
  final Future<void> Function(String? url) onTapLink;

  const _MessageWithLinks({
    super.key,
    required this.message,
    required this.onTapLink,
  });

  @override
  Widget build(BuildContext context) {
    final spans = _buildSpans(
      text: message,
      style: const TextStyle(
        fontSize: 15,
        height: 1.5,
        color: Color(0xFF111827),
      ),
    );

    return SelectableText.rich(TextSpan(children: spans));
  }

  List<TextSpan> _buildSpans({required String text, required TextStyle style}) {
    final List<TextSpan> spans = [];
    final urlRegex = RegExp(
      r'(https?:\/\/[^\s]+|waveup:\/\/[^\s]+)',
      caseSensitive: false,
    );

    int start = 0;
    final matches = urlRegex.allMatches(text);

    for (final match in matches) {
      if (match.start > start) {
        spans.add(
          TextSpan(text: text.substring(start, match.start), style: style),
        );
      }

      final urlText = text.substring(match.start, match.end);
      spans.add(
        TextSpan(
          text: urlText,
          style: style.copyWith(
            color: const Color(0xFF1D4ED8),
            fontWeight: FontWeight.w600,
            decoration: TextDecoration.underline,
          ),
          recognizer: TapGestureRecognizer()
            ..onTap = () {
              onTapLink(urlText);
            },
        ),
      );

      start = match.end;
    }

    if (start < text.length) {
      spans.add(TextSpan(text: text.substring(start), style: style));
    }

    return spans;
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
              style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
              textAlign: TextAlign.center,
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
