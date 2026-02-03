// lib/screens/orders/order_detail_screen.dart
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import 'package:wa_blast/models/store_order_model.dart';
import 'package:wa_blast/providers/order_provider.dart';

class OrderDetailScreen extends StatefulWidget {
  final String idStoreOrder;
  final String? externalId;
  final String? platformName;

  const OrderDetailScreen({
    super.key,
    required this.idStoreOrder,
    this.externalId,
    this.platformName,
  });

  @override
  State<OrderDetailScreen> createState() => _OrderDetailScreenState();
}

class _OrderDetailScreenState extends State<OrderDetailScreen> {
  // Theme
  static const Color _blue = Color(0xFF426FD4);
  static const Color _pageBg = Color(0xFFF7FAFF);

  static const Color _border = Color(0xFFE5E7EB);
  static const Color _textMain = Color(0xFF111827);
  static const Color _textSub = Color(0xFF6B7280);
  static const Color _textMuted = Color(0xFF9CA3AF);

  final _money = NumberFormat.decimalPattern('id_ID');
  final _time = DateFormat('dd MMM yyyy, HH:mm', 'id_ID');

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      await context.read<OrderProvider>().fetchStoreOrderDetail(
        context,
        idStoreOrder: widget.idStoreOrder,
        clearBeforeFetch: true,
      );
    });
  }

  String _safe(String? s, {String fallback = '-'}) {
    final t = (s ?? '').trim();
    return t.isEmpty ? fallback : t;
  }

  String _prettyStatus(String s) {
    final cleaned = s.trim().replaceAll(RegExp(r'[_\-\s]+'), ' ');
    if (cleaned.isEmpty) return '-';
    return cleaned
        .split(RegExp(r'\s+'))
        .where((w) => w.isNotEmpty)
        .map((w) => w[0].toUpperCase() + w.substring(1).toLowerCase())
        .join(' ');
  }

  DateTime _resolveCreatedAt(StoreOrder it) {
    if (it.createTimeEpoch > 0) return it.createdAt;

    final s = it.createTimeLabel.trim();
    if (s.isNotEmpty) {
      try {
        return DateFormat('dd-MM-yyyy HH:mm', 'id_ID').parseStrict(s);
      } catch (_) {}
      final dt2 = DateTime.tryParse(s);
      if (dt2 != null) return dt2;
    }
    return DateTime.now();
  }

  String _formatTxDate(String raw) {
    final v = raw.trim();
    if (v.isEmpty) return '-';
    try {
      final dt = DateTime.parse(v).toLocal();
      return _time.format(dt);
    } catch (_) {
      return v;
    }
  }

  bool _isTiktok(String platform) => platform.toLowerCase().contains('tiktok');

  // =========================
  // CONFIRMATION DIALOG
  // =========================
  Future<bool> _showAcceptConfirmationDialog({
    required BuildContext context,
    required StoreOrder order,
  }) async {
    final idText = _safe(order.externalId, fallback: order.idStoreOrder);
    final totalText = 'Rp ${_money.format(order.totalAmount)}';

    final res = await showDialog<bool>(
      context: context,
      barrierDismissible: true,
      barrierColor: const Color(0xB3000000), // clean dark overlay
      builder: (ctx) {
        return Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: Dialog(
              backgroundColor: Colors.white,
              surfaceTintColor: Colors.white,
              elevation: 0,
              insetPadding: const EdgeInsets.symmetric(horizontal: 18),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(22),
              ),
              child: Consumer<OrderProvider>(
                builder: (context, prov, _) {
                  final disabled = prov.accepting;

                  return Padding(
                    padding: const EdgeInsets.fromLTRB(18, 16, 18, 14),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // top handle / accent
                        Container(
                          width: 44,
                          height: 5,
                          decoration: BoxDecoration(
                            color: const Color(0xFFE5E7EB),
                            borderRadius: BorderRadius.circular(999),
                          ),
                        ),
                        const SizedBox(height: 14),

                        // icon badge
                        Container(
                          width: 56,
                          height: 56,
                          decoration: BoxDecoration(
                            color: const Color(0xFFEFF6FF),
                            borderRadius: BorderRadius.circular(18),
                            border: Border.all(color: _border),
                          ),
                          child: const Icon(
                            Icons.check_circle_rounded,
                            color: _blue,
                            size: 28,
                          ),
                        ),
                        const SizedBox(height: 14),

                        const Text(
                          'Accept this order?',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w900,
                            color: _textMain,
                          ),
                        ),
                        const SizedBox(height: 6),

                        Text(
                          'Pastikan order ini benar. Setelah di-accept, status akan diperbarui.',
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontSize: 12.5,
                            height: 1.35,
                            fontWeight: FontWeight.w800,
                            color: _textSub,
                          ),
                        ),

                        const SizedBox(height: 14),

                        // info box (blue-white)
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF7FAFF),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: _border),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _InfoLine(
                                icon: Icons.receipt_long_rounded,
                                label: 'Order ID',
                                value: idText,
                              ),
                              const SizedBox(height: 8),
                              _InfoLine(
                                icon: Icons.payments_rounded,
                                label: 'Total',
                                value: totalText,
                              ),
                            ],
                          ),
                        ),

                        // error in dialog (if any)
                        if ((prov.acceptError ?? '').trim().isNotEmpty) ...[
                          const SizedBox(height: 12),
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: const Color(0xFFFEE2E2),
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(
                                color: const Color(0xFFFECACA),
                              ),
                            ),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Icon(
                                  Icons.error_outline_rounded,
                                  color: Color(0xFF991B1B),
                                  size: 18,
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    prov.acceptError!.trim(),
                                    style: const TextStyle(
                                      color: Color(0xFF991B1B),
                                      fontWeight: FontWeight.w900,
                                      fontSize: 12,
                                      height: 1.3,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],

                        const SizedBox(height: 14),

                        // actions
                        Row(
                          children: [
                            Expanded(
                              child: OutlinedButton(
                                onPressed: disabled
                                    ? null
                                    : () => Navigator.of(ctx).pop(false),
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: _blue,
                                  side: const BorderSide(color: _blue),
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 12,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(14),
                                  ),
                                ),
                                child: const Text(
                                  'Cancel',
                                  style: TextStyle(fontWeight: FontWeight.w900),
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: FilledButton(
                                onPressed: disabled
                                    ? null
                                    : () => Navigator.of(ctx).pop(true),
                                style: FilledButton.styleFrom(
                                  backgroundColor: _blue,
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 12,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(14),
                                  ),
                                ),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    if (disabled) ...[
                                      const SizedBox(
                                        width: 16,
                                        height: 16,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2.2,
                                          color: Colors.white,
                                        ),
                                      ),
                                      const SizedBox(width: 10),
                                      const Text(
                                        'Processing...',
                                        style: TextStyle(
                                          fontWeight: FontWeight.w900,
                                        ),
                                      ),
                                    ] else ...[
                                      const Icon(Icons.check_rounded, size: 18),
                                      const SizedBox(width: 8),
                                      const Text(
                                        'Yes, accept',
                                        style: TextStyle(
                                          fontWeight: FontWeight.w900,
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),

                        const SizedBox(height: 6),

                        Text(
                          'Tip: kamu bisa refresh detail setelah accept.',
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontSize: 11.5,
                            color: _textMuted,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
          ),
        );
      },
    );

    return res == true;
  }

  Future<void> _doAccept(
    BuildContext context,
    OrderProvider prov,
    StoreOrder order,
  ) async {
    final ok = await prov.acceptStoreOrder(
      context,
      orderId: order.idStoreOrder,
      refreshListOnSuccess: true,
      refreshDetailOnSuccess: true,
    );

    if (!mounted) return;

    if (ok) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Order accepted successfully.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } else {
      final msg = prov.acceptError?.trim().isNotEmpty == true
          ? prov.acceptError!.trim()
          : 'Failed to accept order.';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(msg), behavior: SnackBarBehavior.floating),
      );
    }
  }

  Future<void> _onAcceptPressed(
    BuildContext context,
    OrderProvider prov,
    StoreOrder order,
  ) async {
    // prevent double tap
    if (prov.accepting) return;

    final confirmed = await _showAcceptConfirmationDialog(
      context: context,
      order: order,
    );

    if (!mounted) return;
    if (!confirmed) return;

    await _doAccept(context, prov, order);
  }

  @override
  Widget build(BuildContext context) {
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
        title: const Text(
          'Order Detail',
          style: TextStyle(fontWeight: FontWeight.w900, color: _textMain),
        ),
        actions: [
          IconButton(
            tooltip: 'Refresh',
            onPressed: () =>
                context.read<OrderProvider>().fetchStoreOrderDetail(
                  context,
                  idStoreOrder: widget.idStoreOrder,
                ),
            icon: const Icon(Icons.refresh_rounded),
          ),
          const SizedBox(width: 6),
        ],
      ),

      // Floating bottom accept bar
      bottomNavigationBar: Consumer<OrderProvider>(
        builder: (context, prov, _) {
          final order = prov.orderDetail;
          final canShow = order != null && order.processed == false;
          if (!canShow) return const SizedBox.shrink();

          return SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: _border),
                  boxShadow: const [
                    BoxShadow(
                      color: Color(0x14111827),
                      blurRadius: 18,
                      offset: Offset(0, 10),
                    ),
                  ],
                ),
                padding: const EdgeInsets.all(12),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if ((prov.acceptError ?? '').trim().isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: Row(
                          children: [
                            const Icon(
                              Icons.error_outline_rounded,
                              size: 18,
                              color: Color(0xFF991B1B),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                prov.acceptError!.trim(),
                                style: const TextStyle(
                                  color: Color(0xFF991B1B),
                                  fontWeight: FontWeight.w800,
                                  fontSize: 12,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton(
                        style: FilledButton.styleFrom(
                          backgroundColor: _blue,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 13,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                        onPressed: prov.accepting
                            ? null
                            : () => _onAcceptPressed(context, prov, order!),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            if (prov.accepting) ...[
                              const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2.2,
                                  color: Colors.white,
                                ),
                              ),
                              const SizedBox(width: 10),
                              const Text(
                                'Accepting...',
                                style: TextStyle(fontWeight: FontWeight.w900),
                              ),
                            ] else ...[
                              const Icon(Icons.check_circle_rounded, size: 18),
                              const SizedBox(width: 10),
                              const Text(
                                'Accept order',
                                style: TextStyle(fontWeight: FontWeight.w900),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),

      body: Consumer<OrderProvider>(
        builder: (context, prov, _) {
          final loading = prov.loadingDetail;
          final err = prov.detailError;
          final StoreOrder? order = prov.orderDetail;
          final Map<String, dynamic>? tx = prov.transactionDetail;

          if (loading && order == null) {
            return const Center(child: CircularProgressIndicator());
          }

          if (err != null && order == null) {
            return Padding(
              padding: const EdgeInsets.all(16),
              child: _ErrorBox(
                detail: err,
                onRetry: () => prov.fetchStoreOrderDetail(
                  context,
                  idStoreOrder: widget.idStoreOrder,
                  clearBeforeFetch: true,
                ),
              ),
            );
          }

          if (order == null) {
            return const Padding(
              padding: EdgeInsets.all(16),
              child: _EmptyBox(),
            );
          }

          final idText = _safe(
            (order.externalId.trim().isNotEmpty)
                ? order.externalId.trim()
                : (widget.externalId ?? order.idStoreOrder),
            fallback: order.idStoreOrder,
          );

          final platform = _safe(
            order.platformName.trim().isNotEmpty
                ? order.platformName.trim()
                : widget.platformName,
            fallback: '-',
          );

          final totalText = 'Rp ${_money.format(order.totalAmount)}';
          final createdAt = _time.format(_resolveCreatedAt(order));
          final items = order.items;

          final txStatus = _safe(tx?['status']?.toString(), fallback: '');
          final txNumber = _safe(tx?['number']?.toString(), fallback: '');
          final txCreatedAtRaw = _safe(
            tx?['created_at']?.toString(),
            fallback: '',
          );
          final txNote = _safe(tx?['note']?.toString(), fallback: '');
          final txAmountRaw = tx?['amount'];
          final txAmount = (txAmountRaw is num) ? txAmountRaw.toInt() : null;

          final hasTx =
              tx != null &&
              (txStatus.isNotEmpty ||
                  txNumber.isNotEmpty ||
                  txCreatedAtRaw.isNotEmpty ||
                  txAmount != null ||
                  txNote.isNotEmpty);

          // extra bottom padding supaya list tidak ketutup floating bar
          final extraBottomPad = order.processed ? 18.0 : 120.0;

          return RefreshIndicator(
            color: _blue,
            onRefresh: () => prov.fetchStoreOrderDetail(
              context,
              idStoreOrder: widget.idStoreOrder,
            ),
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: EdgeInsets.fromLTRB(16, 12, 16, extraBottomPad),
              children: [
                // ===== Header Summary (lebih clean)
                _Card(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _IconBadge(
                        icon: Icons.shopping_bag_rounded,
                        bg: const Color(0xFFEFF6FF),
                        fg: const Color(0xFF2F5FD0),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // ID + Order Status chip (1 chip saja)
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Expanded(
                                  child: Text(
                                    idText,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w900,
                                      color: _textMain,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 10),
                                _OrderStatusChip(status: order.status),
                              ],
                            ),
                            const SizedBox(height: 8),

                            // Processed + Date (tanpa chip, rapi)
                            Row(
                              children: [
                                _ProcessedInlineBadge(
                                  processed: order.processed,
                                ),
                                const Spacer(),
                                _MetaLine(
                                  icon: Icons.schedule_rounded,
                                  text: createdAt,
                                ),
                              ],
                            ),

                            const SizedBox(height: 12),

                            // Platform + Total
                            Row(
                              children: [
                                _PlatformMini(
                                  name: platform,
                                  isTiktok: _isTiktok(platform),
                                ),
                                const Spacer(),
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.end,
                                  children: [
                                    const Text(
                                      'Total Price',
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: _textSub,
                                        fontWeight: FontWeight.w800,
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      totalText,
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
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 12),

                // ===== Transaction
                if (hasTx) ...[
                  _Card(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Transaction',
                          style: TextStyle(
                            fontWeight: FontWeight.w900,
                            color: _textMain,
                          ),
                        ),
                        const SizedBox(height: 10),
                        Row(
                          children: [
                            _TinyInfo(
                              icon: Icons.verified_rounded,
                              text: txStatus.isEmpty
                                  ? '-'
                                  : _prettyStatus(txStatus),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: _TinyInfo(
                                icon: Icons.confirmation_number_rounded,
                                text: txNumber.isEmpty ? '-' : txNumber,
                                alignEnd: false,
                              ),
                            ),
                          ],
                        ),
                        if (txCreatedAtRaw.isNotEmpty ||
                            txAmount != null ||
                            txNote.isNotEmpty) ...[
                          const SizedBox(height: 6),
                          Theme(
                            data: Theme.of(context).copyWith(
                              dividerColor: Colors.transparent,
                              splashColor: Colors.transparent,
                              highlightColor: Colors.transparent,
                            ),
                            child: ExpansionTile(
                              tilePadding: EdgeInsets.zero,
                              childrenPadding: const EdgeInsets.only(top: 6),
                              title: const Text(
                                'View detail',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: _textSub,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                              children: [
                                if (txCreatedAtRaw.isNotEmpty)
                                  _DetailRow(
                                    label: 'Created at',
                                    value: _formatTxDate(txCreatedAtRaw),
                                  ),
                                if (txAmount != null)
                                  _DetailRow(
                                    label: 'Amount',
                                    value: 'Rp ${_money.format(txAmount)}',
                                  ),
                                if (txNote.isNotEmpty)
                                  _DetailRow(
                                    label: 'Note',
                                    value: txNote,
                                    isMultiline: true,
                                  ),
                              ],
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                ],

                // ===== Items
                _Card(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Items',
                        style: TextStyle(
                          fontWeight: FontWeight.w900,
                          color: _textMain,
                        ),
                      ),
                      const SizedBox(height: 10),
                      if (items.isEmpty)
                        const Text(
                          'Tidak ada item.',
                          style: TextStyle(
                            color: _textSub,
                            fontWeight: FontWeight.w700,
                          ),
                        )
                      else
                        ListView.separated(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          itemCount: items.length,
                          separatorBuilder: (_, __) =>
                              const SizedBox(height: 12),
                          itemBuilder: (context, i) {
                            final it = items[i];
                            final name = _safe(
                              it.productName,
                              fallback: 'Item',
                            );
                            final qty = it.qty;
                            final price = it.price;
                            final img = _safe(it.skuImage, fallback: '');
                            final sku = _safe(it.sellerSku, fallback: '');
                            final variant = _safe(it.skuName, fallback: '');

                            final lineTotal = price * qty;
                            final lineTotalText =
                                'Rp ${_money.format(lineTotal)}';

                            return Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                _ThumbSmall(url: img),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        name,
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(
                                          fontWeight: FontWeight.w900,
                                          color: _textMain,
                                        ),
                                      ),
                                      const SizedBox(height: 6),
                                      Text(
                                        'Qty $qty • Rp ${_money.format(price)}',
                                        style: const TextStyle(
                                          color: _textSub,
                                          fontWeight: FontWeight.w800,
                                        ),
                                      ),
                                      if (variant.isNotEmpty && variant != '-')
                                        Padding(
                                          padding: const EdgeInsets.only(
                                            top: 4,
                                          ),
                                          child: Text(
                                            'Variant: $variant',
                                            style: const TextStyle(
                                              fontSize: 12,
                                              color: _textMuted,
                                              fontWeight: FontWeight.w800,
                                            ),
                                          ),
                                        ),
                                      if (sku.isNotEmpty && sku != '-')
                                        Padding(
                                          padding: const EdgeInsets.only(
                                            top: 2,
                                          ),
                                          child: Text(
                                            'SKU: $sku',
                                            style: const TextStyle(
                                              fontSize: 12,
                                              color: _textMuted,
                                              fontWeight: FontWeight.w800,
                                            ),
                                          ),
                                        ),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.end,
                                  children: [
                                    const Text(
                                      'Subtotal',
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: _textSub,
                                        fontWeight: FontWeight.w800,
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      lineTotalText,
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w900,
                                        color: _textMain,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            );
                          },
                        ),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _InfoLine extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _InfoLine({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            color: const Color(0xFFEFF6FF),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFFE5E7EB)),
          ),
          child: Icon(icon, size: 16, color: const Color(0xFF2F5FD0)),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: const TextStyle(
                  fontSize: 11.5,
                  color: Color(0xFF6B7280),
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                value,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 13,
                  color: Color(0xFF111827),
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _Card extends StatelessWidget {
  final Widget child;
  const _Card({required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE5E7EB)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0A111827),
            blurRadius: 10,
            offset: Offset(0, 6),
          ),
        ],
      ),
      padding: const EdgeInsets.all(15),
      child: child,
    );
  }
}

class _IconBadge extends StatelessWidget {
  final IconData icon;
  final Color bg;
  final Color fg;
  const _IconBadge({required this.icon, required this.bg, required this.fg});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 44,
      height: 44,
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Icon(icon, color: fg, size: 20),
    );
  }
}

class _PlatformMini extends StatelessWidget {
  final String name;
  final bool isTiktok;
  const _PlatformMini({required this.name, required this.isTiktok});

  @override
  Widget build(BuildContext context) {
    final bg = isTiktok ? const Color(0xFF111827) : const Color(0xFFEFF6FF);
    final fg = isTiktok ? Colors.white : const Color(0xFF2F5FD0);
    final bd = isTiktok ? const Color(0xFF111827) : const Color(0xFFE5E7EB);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
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
          Text(
            name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 12,
              color: fg,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }
}

class _MetaLine extends StatelessWidget {
  final IconData icon;
  final String text;
  const _MetaLine({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 16, color: const Color(0xFF9CA3AF)),
        const SizedBox(width: 6),
        Text(
          text,
          style: const TextStyle(
            fontSize: 12,
            color: Color(0xFF6B7280),
            fontWeight: FontWeight.w900,
          ),
        ),
      ],
    );
  }
}

class _ProcessedInlineBadge extends StatelessWidget {
  final bool processed;
  const _ProcessedInlineBadge({required this.processed});

  @override
  Widget build(BuildContext context) {
    final label = processed ? 'Processed' : 'Unprocessed';
    final icon = processed
        ? Icons.verified_rounded
        : Icons.hourglass_bottom_rounded;

    final Color fg = processed
        ? const Color(0xFF1F3D99)
        : const Color(0xFF9A3412);
    final Color bg = processed
        ? const Color(0xFFEFF6FF)
        : const Color(0xFFFFF7ED);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: fg),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w900,
              color: fg,
            ),
          ),
        ],
      ),
    );
  }
}

class _OrderStatusChip extends StatelessWidget {
  final String status;
  const _OrderStatusChip({required this.status});

  @override
  Widget build(BuildContext context) {
    final key = status.trim().toLowerCase();

    late Color bg;
    late Color fg;
    late Color bd;
    late IconData icon;

    switch (key) {
      case 'completed':
      case 'paid':
      case 'success':
      case 'delivered':
        bg = const Color(0xFFE6F4EA);
        fg = const Color(0xFF166534);
        bd = const Color(0xFFBBF7D0);
        icon = Icons.check_circle_rounded;
        break;
      case 'canceled':
      case 'cancelled':
      case 'void':
      case 'failed':
        bg = const Color(0xFFFEE2E2);
        fg = const Color(0xFF991B1B);
        bd = const Color(0xFFFECACA);
        icon = Icons.cancel_rounded;
        break;
      case 'processing':
      case 'in progress':
        bg = const Color(0xFFEFF6FF);
        fg = const Color(0xFF1F3D99);
        bd = const Color(0xFFDBEAFE);
        icon = Icons.autorenew_rounded;
        break;
      default:
        bg = const Color(0xFFFEF3C7);
        fg = const Color(0xFF92400E);
        bd = const Color(0xFFFDE68A);
        icon = Icons.local_shipping_rounded;
        break;
    }

    final label = status.trim().isEmpty ? '-' : _pretty(status);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: bd),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: fg),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w900,
              color: fg,
            ),
          ),
        ],
      ),
    );
  }

  String _pretty(String s) {
    final cleaned = s.trim().replaceAll(RegExp(r'[_\-\s]+'), ' ');
    if (cleaned.isEmpty) return '-';
    return cleaned
        .split(RegExp(r'\s+'))
        .where((w) => w.isNotEmpty)
        .map((w) => w[0].toUpperCase() + w.substring(1).toLowerCase())
        .join(' ');
  }
}

class _TinyInfo extends StatelessWidget {
  final IconData icon;
  final String text;
  final bool alignEnd;
  final double? maxWidth;

  const _TinyInfo({
    required this.icon,
    required this.text,
    this.alignEnd = false,
    this.maxWidth = 260,
  });

  @override
  Widget build(BuildContext context) {
    final content = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 16, color: const Color(0xFF2F5FD0)),
        const SizedBox(width: 8),
        Text(
          text,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            color: Color(0xFF1F3D99),
            fontWeight: FontWeight.w900,
          ),
        ),
      ],
    );

    final child = (maxWidth == null)
        ? content
        : ConstrainedBox(
            constraints: BoxConstraints(maxWidth: maxWidth!),
            child: content,
          );

    return Align(
      alignment: alignEnd ? Alignment.centerRight : Alignment.centerLeft,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: const Color(0xFFEFF6FF),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: const Color(0xFFE5E7EB)),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
          child: child,
        ),
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  final String label;
  final String value;
  final bool isMultiline;

  const _DetailRow({
    required this.label,
    required this.value,
    this.isMultiline = false,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: isMultiline
            ? CrossAxisAlignment.start
            : CrossAxisAlignment.center,
        children: [
          SizedBox(
            width: 84,
            child: Text(
              label,
              style: const TextStyle(
                fontSize: 12,
                color: Color(0xFF6B7280),
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                color: Color(0xFF111827),
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ThumbSmall extends StatelessWidget {
  final String url;
  const _ThumbSmall({required this.url});

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(14),
      child: Container(
        width: 52,
        height: 52,
        color: const Color(0xFFF3F4F6),
        child: url.trim().isEmpty
            ? const Icon(
                Icons.image_not_supported_rounded,
                color: Color(0xFF9CA3AF),
              )
            : Image.network(
                url,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => const Icon(
                  Icons.broken_image_rounded,
                  color: Color(0xFF9CA3AF),
                ),
              ),
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
            'Gagal memuat detail',
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
            'Detail tidak tersedia',
            style: TextStyle(
              fontWeight: FontWeight.w900,
              color: Color(0xFF111827),
            ),
          ),
          SizedBox(height: 6),
          Text(
            'Coba refresh atau buka dari list lagi.',
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
