import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:wa_blast/constants/app_colors.dart';

import '../../helper/business_premium_helper.dart';
import '../../providers/subscription_provider.dart';
import 'subscription_checkout_screen.dart';

class SubscriptionScreen extends StatefulWidget {
  const SubscriptionScreen({super.key});

  static const Color _primaryBlue = Color(0xFF4C6EF5);
  static const Color _backgroundBlue = Color(0xFFF2F5FF);

  @override
  State<SubscriptionScreen> createState() => _SubscriptionScreenState();
}

class _SubscriptionScreenState extends State<SubscriptionScreen> {
  bool _isLoadingPref = true;
  bool _isPremium = false;
  DateTime? _premiumStartAt;
  DateTime? _premiumExpiresAt;

  // ✅ Scroll hint controller/state
  late final ScrollController _scrollCtrl;
  bool _showScrollDownHint = false;

  // perkiraan tinggi footer (buat spacer & posisi hint)
  static const double _upgradeFooterHeight = 210;

  bool _didInitialScrollCheck = false;

  bool get _isExpiringSoon {
    final exp = _premiumExpiresAt;
    if (!_isPremium || exp == null) return false;

    final now = DateTime.now();
    final expLocal = exp.toLocal();

    // kalau sudah lewat, tetap dianggap warning (optional, tapi aman)
    if (expLocal.isBefore(now)) return true;

    final diff = expLocal.difference(now);
    return diff.inDays <= 7;
  }

  @override
  void initState() {
    super.initState();
    _scrollCtrl = ScrollController()..addListener(_onScroll);
    _loadPremiumInfo();
  }

  @override
  void dispose() {
    _scrollCtrl.removeListener(_onScroll);
    _scrollCtrl.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (!mounted) return;

    // ✅ Premium: hint HARUS mati (dan tidak pernah muncul)
    if (_isPremium) {
      if (_showScrollDownHint) {
        setState(() => _showScrollDownHint = false);
      }
      return;
    }

    if (!_scrollCtrl.hasClients) return;
    final pos = _scrollCtrl.position;

    // masih ada konten di bawah?
    final canScrollDown =
        pos.maxScrollExtent > 0 && pos.pixels < (pos.maxScrollExtent - 6);

    if (canScrollDown != _showScrollDownHint) {
      setState(() => _showScrollDownHint = canScrollDown);
    }
  }

  Future<void> _loadPremiumInfo() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final activeId = (prefs.getString('activeBizId') ?? '').trim();
      final businessJson = prefs.getString('business');

      bool isPremium = false;
      DateTime? startAt;
      DateTime? expiresAt;

      if (businessJson != null && businessJson.isNotEmpty) {
        final list = (jsonDecode(businessJson) as List)
            .cast<Map<String, dynamic>>();

        Map<String, dynamic>? match;
        if (activeId.isNotEmpty) {
          match = list.firstWhere(
            (e) => (e['idBusiness'] ?? '').toString() == activeId,
            orElse: () => <String, dynamic>{},
          );
        }

        if (match != null && match.isNotEmpty) {
          isPremium = (match['isPremium'] ?? false) == true;

          final startStr = match['premiumStartAt'];
          final expireStr = match['premiumExpiresAt'];

          if (startStr is String && startStr.isNotEmpty) {
            startAt = DateTime.tryParse(startStr);
          }
          if (expireStr is String && expireStr.isNotEmpty) {
            expiresAt = DateTime.tryParse(expireStr);
          }
        } else {
          isPremium = await BusinessPremiumHelper.isActiveBusinessPremium();
        }
      } else {
        isPremium = await BusinessPremiumHelper.isActiveBusinessPremium();
      }

      if (!mounted) return;
      setState(() {
        _isPremium = isPremium;
        _premiumStartAt = startAt;
        _premiumExpiresAt = expiresAt;
        _isLoadingPref = false;
      });

      // ✅ update hint setelah frame (biar maxScrollExtent kebaca)
      WidgetsBinding.instance.addPostFrameCallback((_) => _onScroll());
    } catch (e, s) {
      debugPrint('[SubscriptionScreen] _loadPremiumInfo error: $e\n$s');
      final isPremium = await BusinessPremiumHelper.isActiveBusinessPremium();
      if (!mounted) return;
      setState(() {
        _isPremium = isPremium;
        _isLoadingPref = false;
      });

      WidgetsBinding.instance.addPostFrameCallback((_) => _onScroll());
    }
  }

  @override
  Widget build(BuildContext context) {
    final subscription = context.watch<SubscriptionProvider>();
    final NumberFormat idrFormatter = NumberFormat('#,###', 'id_ID');

    String unlockSubtitle;
    if (subscription.isLoadingPlans) {
      unlockSubtitle = 'Fetching plan price…';
    } else if (subscription.monthlyPrice > 0) {
      final formatted = idrFormatter.format(subscription.monthlyPrice.round());
      unlockSubtitle =
          'Rp. $formatted/month • inventory, purchase & no Rp 500 fee';
    } else {
      unlockSubtitle = 'View premium plans for pricing details';
    }

    if (_isLoadingPref) {
      return const Scaffold(
        backgroundColor: Colors.white,
        body: SafeArea(child: Center(child: CircularProgressIndicator())),
      );
    }

    final bool isPremiumView = _isPremium;

    final String headlineText = isPremiumView
        ? 'Premium is active'
        : 'Upgrade to Premium\nto unlock business tools';

    final String descriptionText = isPremiumView
        ? 'You have full access to Inventory & Stock Management, Purchase from suppliers, '
              'and transaction fees are waived while Premium is active.'
        : 'Get Inventory & Stock tools, purchase from suppliers, and remove the Rp 500 fee per transaction.';

    if (!_didInitialScrollCheck) {
      _didInitialScrollCheck = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        _onScroll();
      });
    }

    return Scaffold(
      backgroundColor: Colors.white,

      // ✅ Kalau Premium: footer DIHAPUS total
      bottomNavigationBar: isPremiumView
          ? null
          : LayoutBuilder(
              builder: (context, c) {
                return SizedBox(
                  height: _upgradeFooterHeight,
                  child: Stack(
                    clipBehavior: Clip.none,
                    children: [
                      Positioned.fill(
                        child: _StickyUpgradeFooter(
                          key: const ValueKey('upgrade_footer'),
                          unlockSubtitle: unlockSubtitle,
                          onUpgrade: () {
                            Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (_) =>
                                    const SubscriptionCheckoutScreen(),
                              ),
                            );
                          },
                          onContinue: () => Navigator.of(context).pop(),
                        ),
                      ),

                      // ✅ hint ditempel PAS di atas footer (hanya non-premium)
                      Positioned(
                        left: 0,
                        right: 0,
                        top: -42,
                        child: IgnorePointer(
                          child: _ScrollDownHint(visible: _showScrollDownHint),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),

      body: Container(
        color: Colors.white,
        child: SafeArea(
          child: CustomScrollView(
            controller: _scrollCtrl,
            physics: const BouncingScrollPhysics(),
            slivers: [
              SliverToBoxAdapter(
                child: _TopGradientHeader(
                  isPremium: isPremiumView,
                  onClose: () => Navigator.of(context).pop(),
                  onHistory: isPremiumView
                      ? () => Navigator.of(
                          context,
                        ).pushNamed('/subscription/history')
                      : null,
                  title: isPremiumView ? 'Premium' : 'Subscription',
                  subtitle: isPremiumView
                      ? 'You’re all set'
                      : 'Unlock more value',
                ),
              ),
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
                sliver: SliverToBoxAdapter(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _IllustrationCard(),
                      const SizedBox(height: 18),
                      Text(
                        headlineText,
                        style: const TextStyle(
                          fontSize: 26,
                          height: 1.15,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFF111827),
                        ),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        descriptionText,
                        style: const TextStyle(
                          fontSize: 14,
                          height: 1.5,
                          color: Color(0xFF4B5563),
                        ),
                      ),
                      const SizedBox(height: 14),

                      if (isPremiumView) ...[
                        _buildPremiumInfoCard(context),
                        const SizedBox(height: 14),
                        const _SectionTitle(
                          title: 'Your benefits',
                          subtitle:
                              'Everything included in your Premium access',
                        ),
                        const SizedBox(height: 10),
                        const _FeatureGrid(
                          items: [
                            _FeatureItem(
                              icon: Icons.inventory_2_rounded,
                              title: 'Inventory',
                              subtitle: 'Manage products & stock',
                            ),
                            _FeatureItem(
                              icon: Icons.edit_note_rounded,
                              title: 'Stock Management',
                              subtitle: 'Track in/out & adjustments',
                            ),
                            _FeatureItem(
                              icon: Icons.local_shipping_rounded,
                              title: 'Purchase',
                              subtitle: 'Buy from suppliers',
                            ),
                            _FeatureItem(
                              icon: Icons.money_off_csred_rounded,
                              title: 'No transaction fee',
                              subtitle: 'Rp 500 fee is waived',
                            ),
                          ],
                        ),
                      ] else ...[
                        const _FeatureList(
                          items: [
                            _FeatureBullet(
                              icon: Icons.inventory_2_rounded,
                              title: 'Inventory & stock tools',
                              subtitle:
                                  'Access Inventory and manage stock across your products.',
                            ),
                            _FeatureBullet(
                              icon: Icons.local_shipping_rounded,
                              title: 'Purchase from suppliers',
                              subtitle:
                                  'Create purchases and restock items directly from suppliers.',
                            ),
                            _FeatureBullet(
                              icon: Icons.money_off_csred_rounded,
                              title: 'No Rp 500 transaction fee',
                              subtitle:
                                  'While Premium is active, transaction fees are waived.',
                            ),
                            _FeatureBullet(
                              icon: Icons.workspace_premium_rounded,
                              title: 'Premium access',
                              subtitle:
                                  'Unlock all Premium features for your business.',
                            ),
                          ],
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
  }

  Widget _buildPremiumInfoCard(BuildContext context) {
    final dateFormat = DateFormat('d MMMM yyyy', 'en_US');

    String startText = '-';
    String expireText = '-';

    if (_premiumStartAt != null) {
      startText = dateFormat.format(_premiumStartAt!.toLocal());
    }
    if (_premiumExpiresAt != null) {
      expireText = dateFormat.format(_premiumExpiresAt!.toLocal());
    }

    final bool expiringSoon = _isExpiringSoon;

    final Color bg = expiringSoon
        ? const Color(0xFFFFF1F2) // soft red
        : SubscriptionScreen._backgroundBlue;

    final Color border = expiringSoon
        ? const Color(0xFFFECACA) // soft red border
        : AppColors.primary.withOpacity(0.35);

    final Color iconColor = expiringSoon
        ? const Color(0xFFEF4444)
        : SubscriptionScreen._primaryBlue;

    final String infoText = expiringSoon
        ? 'Started on $startText • Expires on $expireText\n'
        : 'Active on $startText until $expireText';
    return _SoftCard(
      background: bg,
      borderColor: border,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.80),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(
              Icons.workspace_premium_rounded,
              color: iconColor,
              size: 26,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Subscription Information',
                  style: TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 14,
                    color: expiringSoon
                        ? const Color(0xFF991B1B)
                        : const Color(0xFF111827),
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  infoText,
                  style: TextStyle(
                    fontSize: 12.5,
                    height: 1.45,
                    color: expiringSoon
                        ? const Color(0xFF7F1D1D)
                        : const Color(0xFF374151),
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// ✅ Hint widget: gradient + animasi halus + blend-in
class _ScrollDownHint extends StatefulWidget {
  const _ScrollDownHint({required this.visible});
  final bool visible;

  @override
  State<_ScrollDownHint> createState() => _ScrollDownHintState();
}

class _ScrollDownHintState extends State<_ScrollDownHint>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c;
  late final Animation<double> _fade;
  late final Animation<double> _float;

  @override
  void initState() {
    super.initState();
    _c = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );

    _fade = CurvedAnimation(parent: _c, curve: Curves.easeInOut);
    _float = Tween<double>(
      begin: 0,
      end: 6,
    ).animate(CurvedAnimation(parent: _c, curve: Curves.easeInOut));

    if (widget.visible) {
      _c.repeat(reverse: true);
    }
  }

  @override
  void didUpdateWidget(covariant _ScrollDownHint oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (widget.visible && !oldWidget.visible) {
      _c
        ..stop()
        ..value = 0
        ..repeat(reverse: true);
    } else if (!widget.visible && oldWidget.visible) {
      _c.stop();
      _c.value = 0;
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedOpacity(
      opacity: widget.visible ? 1 : 0,
      duration: const Duration(milliseconds: 200),
      child: SizedBox(
        height: 44,
        child: Stack(
          alignment: Alignment.center,
          children: [
            Positioned.fill(
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.bottomCenter,
                    end: Alignment.topCenter,
                    colors: [
                      Colors.black.withOpacity(0.14),
                      Colors.black.withOpacity(0.06),
                      Colors.transparent,
                    ],
                  ),
                ),
              ),
            ),
            AnimatedBuilder(
              animation: _c,
              builder: (context, _) {
                return Transform.translate(
                  offset: Offset(0, -_float.value),
                  child: Opacity(
                    opacity: 0.65 + (0.35 * _fade.value),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.65),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: Colors.black.withOpacity(0.06),
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: const [
                          Text(
                            'Scroll down to see more',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF111827),
                            ),
                          ),
                          SizedBox(width: 6),
                          Icon(
                            Icons.keyboard_arrow_down_rounded,
                            size: 18,
                            color: Color(0xFF111827),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

// ========================
// ✅ STICKY FOOTER WIDGETS
// ========================

class _StickyUpgradeFooter extends StatelessWidget {
  const _StickyUpgradeFooter({
    super.key,
    required this.unlockSubtitle,
    required this.onUpgrade,
    required this.onContinue,
  });

  final String unlockSubtitle;
  final VoidCallback onUpgrade;
  final VoidCallback onContinue;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      elevation: 0,
      child: Container(
        child: SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _PrimaryButton(
                  label: 'Upgrade your business',
                  subtitle: unlockSubtitle,
                  color: SubscriptionScreen._primaryBlue,
                  onPressed: onUpgrade,
                ),
                const SizedBox(height: 10),
                OutlinedButton(
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size.fromHeight(52),
                    side: const BorderSide(
                      color: SubscriptionScreen._primaryBlue,
                      width: 1.4,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(28),
                    ),
                    foregroundColor: SubscriptionScreen._primaryBlue,
                    backgroundColor: Colors.white,
                  ),
                  onPressed: onContinue,
                  child: const Text(
                    'Continue with limited access',
                    style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'By upgrading you agree to the subscription terms.',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 12, color: Color(0xFF6B7280)),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _TopGradientHeader extends StatelessWidget {
  const _TopGradientHeader({
    required this.isPremium,
    required this.onClose,
    required this.title,
    required this.subtitle,
    this.onHistory,
  });

  final bool isPremium;
  final VoidCallback onClose;
  final VoidCallback? onHistory;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      child: Column(
        children: [
          Row(
            children: [
              const Spacer(),
              if (onHistory != null)
                IconButton(
                  tooltip: 'Subscription history',
                  icon: const Icon(Icons.description_rounded),
                  color: Colors.black,
                  onPressed: onHistory,
                ),
              IconButton(
                tooltip: 'Close',
                icon: const Icon(Icons.close),
                color: Colors.black,
                onPressed: onClose,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _IllustrationCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Center(
          child: SvgPicture.asset(
            'assets/subscription-page.svg',
            width: 320,
            fit: BoxFit.contain,
          ),
        ),
      ],
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle({required this.title, required this.subtitle});
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w800,
            color: Color(0xFF111827),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          subtitle,
          style: const TextStyle(
            fontSize: 13,
            height: 1.35,
            color: Color(0xFF6B7280),
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}

class _FeatureList extends StatelessWidget {
  const _FeatureList({required this.items});
  final List<_FeatureBullet> items;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: items
          .map(
            (e) =>
                Padding(padding: const EdgeInsets.only(bottom: 10), child: e),
          )
          .toList(),
    );
  }
}

class _FeatureBullet extends StatelessWidget {
  const _FeatureBullet({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  final IconData icon;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return _SoftCard(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: SubscriptionScreen._backgroundBlue,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(icon, color: SubscriptionScreen._primaryBlue, size: 24),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 14,
                    color: Color(0xFF111827),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: const TextStyle(
                    fontSize: 12.5,
                    height: 1.4,
                    color: Color(0xFF4B5563),
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _FeatureGrid extends StatelessWidget {
  const _FeatureGrid({required this.items});
  final List<_FeatureItem> items;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, c) {
        final w = c.maxWidth;
        final crossAxisCount = w >= 560 ? 4 : 2;

        return GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: items.length,
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: crossAxisCount,
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
            childAspectRatio: 1.25,
          ),
          itemBuilder: (_, i) => items[i],
        );
      },
    );
  }
}

class _FeatureItem extends StatelessWidget {
  const _FeatureItem({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  final IconData icon;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return _SoftCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: SubscriptionScreen._backgroundBlue,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(icon, color: SubscriptionScreen._primaryBlue, size: 22),
          ),
          const SizedBox(height: 10),
          Text(
            title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontWeight: FontWeight.w800,
              fontSize: 13.5,
              color: Color(0xFF111827),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            subtitle,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 12,
              height: 1.35,
              color: Color(0xFF6B7280),
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _SoftCard extends StatelessWidget {
  const _SoftCard({required this.child, this.background, this.borderColor});

  final Widget child;
  final Color? background;
  final Color? borderColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: background ?? Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: borderColor ?? const Color(0xFFE5E7EB),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 18,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: child,
    );
  }
}

class _PrimaryButton extends StatelessWidget {
  final String label;
  final String? subtitle;
  final VoidCallback onPressed;
  final Color color;

  const _PrimaryButton({
    required this.label,
    required this.onPressed,
    this.subtitle,
    this.color = const Color(0xFF4C6EF5),
  });

  @override
  Widget build(BuildContext context) {
    return ElevatedButton(
      style: ElevatedButton.styleFrom(
        minimumSize: const Size.fromHeight(60),
        backgroundColor: color,
        foregroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
        elevation: 2,
        shadowColor: color.withOpacity(0.35),
      ),
      onPressed: onPressed,
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 16,
                  ),
                ),
                if (subtitle != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    subtitle!,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 12,
                      color: Colors.white70,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: 8),
          const Icon(Icons.keyboard_arrow_right_rounded, size: 30),
        ],
      ),
    );
  }
}
