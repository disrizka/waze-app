// lib/screens/orders/store_order_list_screen.dart
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import 'package:wa_blast/models/store_order_model.dart';
import 'package:wa_blast/providers/order_provider.dart';
import 'package:wa_blast/screens/order/order_detail_screen.dart';

class StoreOrderListScreen extends StatefulWidget {
  const StoreOrderListScreen({super.key});

  @override
  State<StoreOrderListScreen> createState() => _StoreOrderListScreenState();
}

class _StoreOrderListScreenState extends State<StoreOrderListScreen> {
  // Theme (blue-white)
  static const Color _blue = Color(0xFF426FD4);
  static const Color _pageBg = Color(0xFFF7FAFF);

  final ScrollController _scrollC = ScrollController();
  final int _limit = 20;

  @override
  void initState() {
    super.initState();

    _scrollC.addListener(_onScroll);

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      await context.read<OrderProvider>().fetchStoreOrders(
        context,
        page: 1,
        limit: _limit,
        append: false,
      );
    });
  }

  @override
  void dispose() {
    _scrollC.removeListener(_onScroll);
    _scrollC.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (!mounted) return;
    final prov = context.read<OrderProvider>();
    if (!prov.hasMore || prov.loadingMore) return;
    if (!_scrollC.hasClients) return;

    final pos = _scrollC.position;
    if (pos.pixels >= pos.maxScrollExtent - 240) {
      prov.loadNextPage(context, limit: _limit);
    }
  }

  DateTime _resolveCreatedAt(StoreOrder it) {
    if (it.createTimeEpoch > 0) {
      return DateTime.fromMillisecondsSinceEpoch(it.createTimeEpoch * 1000);
    }

    final s = it.createTimeLabel.trim();
    if (s.isNotEmpty) {
      try {
        return DateFormat('dd-MM-yyyy HH:mm', 'id_ID').parseStrict(s);
      } catch (_) {
        // ignore
      }

      final dt2 = DateTime.tryParse(s);
      if (dt2 != null) return dt2;
    }

    return DateTime.now();
  }

  @override
  Widget build(BuildContext context) {
    final fTime = DateFormat('dd MMM yyyy, HH:mm', 'id_ID');
    final fMoney = NumberFormat.decimalPattern('id_ID');

    return Scaffold(
      backgroundColor: _pageBg,
      appBar: AppBar(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
        scrolledUnderElevation: 0,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded),
          onPressed: () => Navigator.pop(context),
        ),
        titleSpacing: 0,
        title: const _AppBarTitle(),
        actions: [
          IconButton(
            tooltip: 'Refresh',
            onPressed: () =>
                context.read<OrderProvider>().refresh(context, limit: _limit),
            icon: const Icon(Icons.refresh_rounded),
          ),
          const SizedBox(width: 6),
        ],
      ),
      body: Consumer<OrderProvider>(
        builder: (context, prov, _) {
          final items = prov.orders; // List<StoreOrder>
          final isLoading = prov.loading;
          final error = prov.error;

          return RefreshIndicator(
            onRefresh: () => prov.refresh(context, limit: _limit),
            color: _blue,
            child: CustomScrollView(
              controller: _scrollC,
              physics: const AlwaysScrollableScrollPhysics(),
              slivers: [
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 10),
                    child: Row(
                      children: [
                        _InfoPill(
                          icon: Icons.list_alt_rounded,
                          text: isLoading && items.isEmpty
                              ? 'Loading...'
                              : '${items.length} order',
                        ),
                      ],
                    ),
                  ),
                ),

                if (isLoading && items.isEmpty)
                  const SliverToBoxAdapter(
                    child: Padding(
                      padding: EdgeInsets.fromLTRB(16, 28, 16, 24),
                      child: Center(child: CircularProgressIndicator()),
                    ),
                  )
                else if (error != null && items.isEmpty)
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
                    sliver: SliverToBoxAdapter(
                      child: _ErrorBox(
                        detail: error,
                        onRetry: () => prov.fetchStoreOrders(
                          context,
                          page: 1,
                          limit: _limit,
                          append: false,
                        ),
                      ),
                    ),
                  )
                else if (items.isEmpty)
                  const SliverPadding(
                    padding: EdgeInsets.fromLTRB(16, 12, 16, 24),
                    sliver: SliverToBoxAdapter(child: _EmptyBox()),
                  )
                else ...[
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(16, 6, 16, 18),
                    sliver: SliverList.separated(
                      itemCount: items.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 12),
                      itemBuilder: (context, index) {
                        final StoreOrder it = items[index];

                        final title = it.externalId.trim().isNotEmpty
                            ? it.externalId.trim()
                            : it.idStoreOrder;

                        final dt = _resolveCreatedAt(it);

                        return _OrderCard(
                          title: title,
                          timeText: fTime.format(dt),
                          status: it.status,
                          totalText: 'Rp ${fMoney.format(it.totalAmount)}',
                          itemsCount: it.items.length,
                          platformName: it.platformName.trim(),
                          onTap: () {
                            // ✅ navigate ke detail
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => OrderDetailScreen(
                                  idStoreOrder: it.idStoreOrder,
                                  externalId: it.externalId.trim().isEmpty
                                      ? null
                                      : it.externalId.trim(),
                                  platformName: it.platformName.trim().isEmpty
                                      ? null
                                      : it.platformName.trim(),
                                ),
                              ),
                            );
                          },
                        );
                      },
                    ),
                  ),
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 28),
                      child: Center(
                        child: prov.loadingMore
                            ? const SizedBox(
                                height: 24,
                                width: 24,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : const SizedBox.shrink(),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          );
        },
      ),
    );
  }
}

class _AppBarTitle extends StatelessWidget {
  const _AppBarTitle();

  @override
  Widget build(BuildContext context) {
    return const Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Orders',
          style: TextStyle(
            fontWeight: FontWeight.w900,
            color: Color(0xFF111827),
          ),
        ),
        SizedBox(height: 2),
        Text(
          'History',
          style: TextStyle(
            fontSize: 12,
            color: Color(0xFF6B7280),
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }
}

class _InfoPill extends StatelessWidget {
  final IconData icon;
  final String text;

  const _InfoPill({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
      decoration: BoxDecoration(
        color: const Color(0xFFEFF6FF),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: const Color(0xFF2F5FD0)),
          const SizedBox(width: 8),
          Text(
            text,
            style: const TextStyle(
              fontSize: 12,
              color: Color(0xFF1F3D99),
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }
}

class _OrderCard extends StatelessWidget {
  static const Color _border = Color(0xFFE5E7EB);

  static const Color _textMain = Color(0xFF111827);
  static const Color _textSub = Color(0xFF6B7280);
  static const Color _textMuted = Color(0xFF9CA3AF);

  static const Color _blueDark = Color(0xFF2F5FD0);
  static const Color _blueSoft = Color(0xFFEFF6FF);

  final String title;
  final String timeText;
  final String status;

  final String totalText;
  final int itemsCount;

  final String platformName;

  final VoidCallback? onTap;

  const _OrderCard({
    required this.title,
    required this.timeText,
    required this.status,
    required this.totalText,
    required this.itemsCount,
    required this.platformName,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onTap,
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: _border),
          ),
          padding: const EdgeInsets.fromLTRB(14, 14, 14, 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: _blueSoft,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: _border),
                    ),
                    child: const Icon(
                      Icons.shopping_bag_rounded,
                      size: 20,
                      color: _blueDark,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w900,
                            color: _textMain,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          timeText,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 12,
                            color: _textMuted,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 10),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      _StatusChip(status: status),
                      const SizedBox(height: 8),
                      const Icon(
                        Icons.chevron_right_rounded,
                        color: _textMuted,
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Container(height: 1, color: _border),
              const SizedBox(height: 12),
              Row(
                children: [
                  _PlatformPill(platformName: platformName),
                  const Spacer(),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      const Text(
                        'Total',
                        style: TextStyle(
                          fontSize: 12,
                          color: _textSub,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        totalText,
                        textAlign: TextAlign.right,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w900,
                          color: _textMain,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              // const SizedBox(height: 10),
              // _MetaPill(
              //   icon: Icons.inventory_2_rounded,
              //   text: '$itemsCount item',
              // ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PlatformPill extends StatelessWidget {
  final String platformName;
  const _PlatformPill({required this.platformName});

  bool get _isTiktok {
    final k = platformName.trim().toLowerCase();
    return k.contains('tiktok');
  }

  @override
  Widget build(BuildContext context) {
    final name = platformName.trim().isEmpty ? '-' : platformName.trim();
    final bg = _isTiktok ? const Color(0xFF111827) : const Color(0xFFEFF6FF);
    final fg = _isTiktok ? Colors.white : const Color(0xFF2F5FD0);
    final bd = _isTiktok ? const Color(0xFF111827) : const Color(0xFFE5E7EB);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: bd),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.public_rounded, size: 16, color: fg),
          const SizedBox(width: 8),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 220),
            child: Text(
              name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 12,
                color: fg,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _MetaPill extends StatelessWidget {
  final IconData icon;
  final String text;

  const _MetaPill({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
      decoration: BoxDecoration(
        color: const Color(0xFFF9FAFB),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: const Color(0xFF9CA3AF)),
          const SizedBox(width: 8),
          Text(
            text,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 12,
              color: Color(0xFF6B7280),
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  final String status;
  const _StatusChip({required this.status});

  String _pretty(String s) {
    final cleaned = s.trim().replaceAll(RegExp(r'[_\\-]+'), ' ');
    if (cleaned.isEmpty) return cleaned;

    return cleaned
        .split(RegExp(r'\\s+'))
        .where((w) => w.isNotEmpty)
        .map((w) => w[0].toUpperCase() + w.substring(1).toLowerCase())
        .join(' ');
  }

  @override
  Widget build(BuildContext context) {
    final raw = status.trim();
    if (raw.isEmpty) return const SizedBox.shrink();

    final key = raw.toLowerCase();

    Color bg;
    Color fg;
    Color border;

    switch (key) {
      case 'completed':
      case 'paid':
      case 'success':
        bg = const Color(0xFFE6F4EA);
        fg = const Color(0xFF166534);
        border = const Color(0xFFBBF7D0);
        break;
      case 'canceled':
      case 'cancelled':
      case 'void':
      case 'failed':
        bg = const Color(0xFFFEE2E2);
        fg = const Color(0xFF991B1B);
        border = const Color(0xFFFECACA);
        break;
      default:
        bg = const Color(0xFFFEF3C7);
        fg = const Color(0xFF92400E);
        border = const Color(0xFFFDE68A);
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: border),
      ),
      child: Text(
        _pretty(raw),
        style: TextStyle(fontSize: 12, fontWeight: FontWeight.w900, color: fg),
      ),
    );
  }
}

class _ErrorBox extends StatelessWidget {
  final String? detail;
  final VoidCallback onRetry;
  const _ErrorBox({required this.detail, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFFEE2E2),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFFCA5A5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Gagal memuat data',
            style: TextStyle(
              fontWeight: FontWeight.w900,
              color: Color(0xFF991B1B),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            detail ?? '-',
            style: const TextStyle(
              color: Color(0xFF7F1D1D),
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 10),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Coba lagi'),
              style: TextButton.styleFrom(
                foregroundColor: const Color(0xFF991B1B),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptyBox extends StatelessWidget {
  const _EmptyBox();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE5E7EB)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0A111827),
            blurRadius: 10,
            offset: Offset(0, 6),
          ),
        ],
      ),
      child: const Column(
        children: [
          Icon(Icons.receipt_long_rounded, size: 34, color: Color(0xFF9CA3AF)),
          SizedBox(height: 10),
          Text(
            'Belum ada order',
            style: TextStyle(
              fontWeight: FontWeight.w900,
              color: Color(0xFF111827),
            ),
          ),
          SizedBox(height: 6),
          Text(
            'Store order akan muncul di sini setelah ada transaksi.',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Color(0xFF6B7280),
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}
