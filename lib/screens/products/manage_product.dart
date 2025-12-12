import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:wa_blast/l10n/app_localizations.dart';

import '../../helper/business_premium_helper.dart';

class ManageProductScreen extends StatelessWidget {
  const ManageProductScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final loc = AppLocalizations.of(context)!;

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded),
          onPressed: () => Navigator.of(
            context,
          ).popUntil((route) => route.settings.name == '/home'),
        ),
        title: Text(loc.manageProductTitle),
        centerTitle: false,
        elevation: 0,
      ),
      body: FutureBuilder<bool>(
        future: BusinessPremiumHelper.isActiveBusinessPremium(),
        builder: (context, snapshot) {
          // default: anggap non-premium saat loading / error
          final bool isPremium = snapshot.data ?? false;

          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 8),
                Text(
                  loc.manageProductListMenuLabel,
                  style: textTheme.bodyMedium?.copyWith(
                    color: Colors.black.withOpacity(0.6),
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 8),
                _MenuTile(
                  icon: Icons.list_alt_rounded,
                  title: loc.manageProductProductList,
                  onTap: () => Navigator.pushNamed(context, '/product/list'),
                ),
                const SizedBox(height: 8),
                _MenuTile(
                  icon: Icons.sell,
                  title: loc.manageProductBrandList,
                  onTap: () => Navigator.pushNamed(context, '/product/brand'),
                ),
                const SizedBox(height: 8),
                _MenuTile(
                  icon: Icons.category,
                  title: loc.manageProductCategoryList,
                  onTap: () =>
                      Navigator.pushNamed(context, '/product/category'),
                ),
                const SizedBox(height: 8),

                // 📦 INVENTORY – selalu tampil
                // _MenuTile(
                //   icon: Icons.inventory,
                //   title: 'Inventory',
                //   showDiamondBadge: true, // diamond selalu ada
                //   isDisabled: !isPremium, // gaya abu-abu kalau non-premium
                //   onTap: () {
                //     if (isPremium) {
                //       Navigator.pushNamed(context, '/product/inventory');
                //     } else {
                //       _showInventoryLockedModal(context);
                //     }
                //   },
                // ),

                // const SizedBox(height: 8),
                // _MenuTile(
                //   icon: Icons.inventory_2_rounded,
                //   title: 'Stock Product',
                //   onTap: () {
                //     // TODO: wire up when route is ready
                //   },
                // ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _MenuTile extends StatelessWidget {
  const _MenuTile({
    required this.icon,
    required this.title,
    this.onTap,
    this.showDiamondBadge = false,
    this.isDisabled = false,
  });

  final IconData icon;
  final String title;
  final VoidCallback? onTap;
  final bool showDiamondBadge;
  final bool isDisabled;

  @override
  Widget build(BuildContext context) {
    final textStyle = Theme.of(context).textTheme.bodyLarge?.copyWith(
      fontWeight: FontWeight.w600,
      color: isDisabled ? const Color(0xFF9CA3AF) : null,
    );

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8.0),
          child: Row(
            children: [
              _BlueIcon(
                icon: icon,
                showDiamond: showDiamondBadge,
                dimmed: isDisabled,
              ),
              const SizedBox(width: 12),
              Expanded(child: Text(title, style: textStyle)),
              Icon(
                Icons.chevron_right_rounded,
                size: 20,
                color: isDisabled
                    ? const Color(0xFFCBD5E1)
                    : const Color(0xFF9CA3AF),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _BlueIcon extends StatelessWidget {
  const _BlueIcon({
    required this.icon,
    this.showDiamond = false,
    this.dimmed = false,
  });

  final IconData icon;
  final bool showDiamond;
  final bool dimmed;

  @override
  Widget build(BuildContext context) {
    final Color bg = dimmed ? const Color(0xFFF3F4F6) : const Color(0xFFE9F0FF);
    final Color border = dimmed
        ? const Color(0xFFE5E7EB)
        : const Color(0xFFD6E3FF);
    final Color iconColor = dimmed
        ? const Color(0xFF9CA3AF)
        : const Color(0xFF4C6EF5);

    return SizedBox(
      width: 36,
      height: 36,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned.fill(
            child: Container(
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: bg,
                border: Border.all(color: border),
              ),
              child: Center(child: Icon(icon, size: 20, color: iconColor)),
            ),
          ),
          if (showDiamond)
            Positioned(
              top: -4,
              right: -4,
              child: Container(
                width: 16,
                height: 16,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      Color(0xFF6366F1), // ungu / indigo
                      Color(0xFF22C55E), // hijau
                    ],
                  ),
                ),
                child: const Center(
                  child: Icon(LucideIcons.gem, size: 10, color: Colors.white),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// Modal ketika user non-premium menekan Inventory
Future<void> _showInventoryLockedModal(BuildContext context) async {
  await showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    barrierColor: Colors.black.withOpacity(0.35),
    builder: (ctx) {
      final size = MediaQuery.of(ctx).size;
      final bool isTablet = size.shortestSide >= 600;
      final double maxWidth = isTablet ? 420 : size.width;

      return SafeArea(
        child: Center(
          child: Container(
            constraints: BoxConstraints(maxWidth: maxWidth),
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            padding: const EdgeInsets.fromLTRB(20, 18, 20, 24),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(24),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.16),
                  blurRadius: 24,
                  offset: const Offset(0, 16),
                ),
              ],
            ),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // header: close
                  Row(
                    children: [
                      InkWell(
                        borderRadius: BorderRadius.circular(999),
                        onTap: () => Navigator.of(ctx).pop(false),
                        child: const Padding(
                          padding: EdgeInsets.all(4),
                          child: Icon(
                            Icons.close_rounded,
                            size: 20,
                            color: Color(0xFF9CA3AF),
                          ),
                        ),
                      ),
                      const Spacer(),
                    ],
                  ),
                  const SizedBox(height: 8),

                  // icon + title
                  Row(
                    children: const [
                      CircleAvatar(
                        radius: 18,
                        backgroundColor: Color(0xFFE0ECFF),
                        child: Icon(
                          LucideIcons.gem,
                          size: 18,
                          color: Color(0xFF4C6EF5),
                        ),
                      ),
                      SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'Inventory is a Premium feature',
                          style: TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w800,
                            color: Color(0xFF0F172A),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  const Text(
                    'Upgrade to Premium to manage product stock and monitor stock history in one place.',
                    style: TextStyle(
                      fontSize: 13,
                      height: 1.4,
                      color: Color(0xFF6B7280),
                    ),
                  ),
                  const SizedBox(height: 16),

                  const _PremiumPoint(
                    text: 'Adjust SKU stock whenever you receive products.',
                  ),
                  const SizedBox(height: 6),
                  const _PremiumPoint(
                    text: 'See detailed in and out stock history for each SKU.',
                  ),
                  const SizedBox(height: 6),
                  const _PremiumPoint(
                    text:
                        'Avoid overselling by keeping your inventory always up to date.',
                  ),
                  const SizedBox(height: 20),

                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF4C6EF5),
                        elevation: 0,
                        padding: const EdgeInsets.symmetric(vertical: 13),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                      onPressed: () {
                        Navigator.of(ctx).pop(true);
                        Navigator.pushNamed(ctx, '/subscription');
                      },
                      child: const Text(
                        'Upgrade to Premium',
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 14,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  SizedBox(
                    width: double.infinity,
                    child: TextButton(
                      onPressed: () => Navigator.of(ctx).pop(false),
                      child: const Text(
                        'Maybe later',
                        style: TextStyle(
                          fontSize: 13,
                          color: Color(0xFF6B7280),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    },
  );
}

class _PremiumPoint extends StatelessWidget {
  final String text;
  const _PremiumPoint({required this.text});

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Icon(
          Icons.check_circle_rounded,
          size: 16,
          color: Color(0xFF22C55E),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            text,
            style: const TextStyle(
              fontSize: 12,
              height: 1.3,
              color: Color(0xFF4B5563),
            ),
          ),
        ),
      ],
    );
  }
}
