import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:provider/provider.dart';

import 'package:wa_blast/constants/app_colors.dart';
import 'package:wa_blast/providers/notification_provider.dart';
import 'package:wa_blast/screens/notification_detail_list.dart';

class NotificationListScreen extends StatefulWidget {
  static const routeName = '/notification';

  const NotificationListScreen({super.key});

  @override
  State<NotificationListScreen> createState() => _NotificationListScreenState();
}

class _NotificationListScreenState extends State<NotificationListScreen> {
  final ScrollController _scroll = ScrollController();
  bool _pagingBusy = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      final np = context.read<NotificationProvider>();
      await np.fetchNotifications(context);
      await np.fetchUnreadCount(context);
    });
    _scroll.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scroll.removeListener(_onScroll);
    _scroll.dispose();
    super.dispose();
  }

  void _onScroll() async {
    if (_pagingBusy || !_scroll.hasClients) return;
    final pos = _scroll.position;
    if (pos.pixels > pos.maxScrollExtent - 260) {
      _pagingBusy = true;
      try {
        await context.read<NotificationProvider>().fetchMoreNotifications(
          context,
        );
      } finally {
        _pagingBusy = false;
      }
    }
  }

  Future<void> _onRefresh() async {
    final np = context.read<NotificationProvider>();
    await np.fetchNotifications(context);
    await np.fetchUnreadCount(context);
  }

  Future<void> _handleTap(NotificationItem n) async {
    if (!n.isRead) {
      await context.read<NotificationProvider>().markAsRead(
        context,
        n.idNotification,
      );
      await context.read<NotificationProvider>().fetchUnreadCount(context);
    }

    if (!mounted) return;
    await Navigator.of(context).pushNamed(
      NotificationDetailScreen.routeName,
      arguments: n.idNotification,
    );

    if (!mounted) return;
    await context.read<NotificationProvider>().fetchUnreadCount(context);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF6F8FB),
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.transparent,
        foregroundColor: AppColors.textPrimary,
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Notifications',
              style: TextStyle(fontWeight: FontWeight.w800),
            ),
            const SizedBox(width: 8),
            Consumer<NotificationProvider>(
              builder: (_, np, __) {
                final c = np.unreadCount;
                if (c <= 0) return const SizedBox.shrink();
                final text = c > 99 ? '99+' : '$c';
                return Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFF2563EB),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    text,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      height: 1.1,
                    ),
                  ),
                );
              },
            ),
          ],
        ),
        centerTitle: false,
      ),
      body: SafeArea(
        child: Column(
          children: [
            const _NotifHeader(),
            const SizedBox(height: 8),
            Expanded(
              child: Consumer<NotificationProvider>(
                builder: (_, np, __) {
                  if (np.loadingList && np.notifications.isEmpty) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  if (np.notifications.isEmpty) {
                    return const _NotifEmptyState();
                  }

                  return RefreshIndicator(
                    color: AppColors.blue,
                    onRefresh: _onRefresh,
                    child: ListView.separated(
                      controller: _scroll,
                      physics: const AlwaysScrollableScrollPhysics(
                        parent: BouncingScrollPhysics(),
                      ),
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                      itemCount: np.notifications.length + 1,
                      separatorBuilder: (_, __) => const SizedBox(height: 10),
                      itemBuilder: (_, i) {
                        if (i == np.notifications.length) {
                          final show =
                              np.page != null &&
                              (np.page!.currentPage < np.page!.totalPages);
                          return AnimatedSwitcher(
                            duration: const Duration(milliseconds: 200),
                            child: show
                                ? const Padding(
                                    padding: EdgeInsets.all(12),
                                    child: Center(
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                      ),
                                    ),
                                  )
                                : const SizedBox.shrink(),
                          );
                        }
                        final n = np.notifications[i];
                        return _NotifTile(item: n, onTap: () => _handleTap(n));
                      },
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _NotifHeader extends StatelessWidget {
  const _NotifHeader();

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 4, 16, 6),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF1FB4FF), Color(0xFF23D38E)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(18),
        boxShadow: const [
          BoxShadow(
            color: Color(0x1A000000),
            blurRadius: 18,
            offset: Offset(0, 10),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.18),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: Colors.white24),
            ),
            child: const Icon(
              LucideIcons.bell,
              color: Colors.white,
              size: 22,
            ),
          ),
          const SizedBox(width: 12),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Updates & announcements',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                    fontSize: 15,
                  ),
                ),
                SizedBox(height: 4),
                Text(
                  'Tap a notification to view the full detail',
                  style: TextStyle(
                    color: Color(0xFFEFFCF4),
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Consumer<NotificationProvider>(
            builder: (_, np, __) {
              final c = np.unreadCount;
              final label = c <= 0 ? 'All read' : '$c unread';
              return Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  label,
                  style: const TextStyle(
                    color: Color(0xFF0F172A),
                    fontWeight: FontWeight.w800,
                    fontSize: 11.5,
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}

class _NotifTile extends StatelessWidget {
  final NotificationItem item;
  final VoidCallback onTap;

  const _NotifTile({required this.item, required this.onTap});

  static const _primaryBlue = Color(0xFF2563EB);

  @override
  Widget build(BuildContext context) {
    final isRead = item.isRead;

    final Color bg = isRead
        ? Colors.white
        : const Color(0xFFF3F7FF); // unread sedikit biru
    final Color border = isRead
        ? const Color(0xFFE5E7EB)
        : const Color(0xFFBFDBFE);
    final Color titleColor = isRead
        ? const Color(0xFF111827)
        : const Color(0xFF0F172A);
    final Color msgColor = isRead
        ? const Color(0xFF6B7280)
        : const Color(0xFF374151);

    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: border, width: 1),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: isRead ? const Color(0xFFE0ECFF) : _primaryBlue,
                  borderRadius: BorderRadius.circular(11),
                ),
                child: Icon(
                  Icons.notifications_rounded,
                  size: 18,
                  color: isRead ? _primaryBlue : Colors.white,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontWeight: isRead ? FontWeight.w700 : FontWeight.w800,
                        color: titleColor,
                        fontSize: 14.5,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      item.message,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: msgColor,
                        fontSize: 13,
                        height: 1.25,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      _fmtTimeAgo(item),
                      style: const TextStyle(
                        color: Color(0xFF9CA3AF),
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Column(
                children: [
                  Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: isRead ? Colors.transparent : _primaryBlue,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Icon(
                    Icons.chevron_right_rounded,
                    size: 18,
                    color: Color(0xFF94A3B8),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _fmtTimeAgo(NotificationItem n) {
    final DateTime? ts = n.createdAt ?? n.sentAt ?? n.readAt;
    if (ts == null) return '';

    final now = DateTime.now();
    final diff = now.difference(ts);

    if (diff.inSeconds < 60) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    if (diff.inDays < 7) return '${diff.inDays}d ago';

    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    final day = ts.day.toString().padLeft(2, '0');
    final month = months[ts.month - 1];
    final year = ts.year;
    return '$day $month $year';
  }
}

class _NotifEmptyState extends StatelessWidget {
  const _NotifEmptyState();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: const [
            CircleAvatar(
              radius: 32,
              backgroundColor: Color(0xFFE0ECFF),
              child: Icon(
                Icons.notifications_off_rounded,
                size: 30,
                color: Color(0xFF2563EB),
              ),
            ),
            SizedBox(height: 12),
            Text(
              'No notifications yet',
              style: TextStyle(
                fontWeight: FontWeight.w700,
                fontSize: 16,
                color: Color(0xFF111827),
              ),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: 6),
            Text(
              'You will see updates and announcements here once available.',
              style: TextStyle(color: Color(0xFF6B7280), fontSize: 13),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
