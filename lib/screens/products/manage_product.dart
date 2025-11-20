import 'package:flutter/material.dart';
import 'package:wa_blast/l10n/app_localizations.dart';

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
      body: Padding(
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
            ), // product list dulu
            const SizedBox(height: 8),
            _MenuTile(
              icon: Icons.category,
              title: loc.manageProductCategoryList,
              onTap: () => Navigator.pushNamed(context, '/product/category'),
            ),

            // const SizedBox(height: 8),
            // _MenuTile(
            //   icon: Icons.inventory_2_rounded,
            //   title: 'Stock Product',
            //   onTap: () {
            //     // TODO: wire up when route is ready
            //     // Navigator.pushNamed(context, '/stock-product');
            //   },
            // ),
          ],
        ),
      ),
    );
  }
}

class _MenuTile extends StatelessWidget {
  const _MenuTile({required this.icon, required this.title, this.onTap});

  final IconData icon;
  final String title;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8.0),
          child: Row(
            children: [
              _BlueIcon(icon: icon),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  title,
                  style: Theme.of(
                    context,
                  ).textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.w600),
                ),
              ),
              const Icon(Icons.chevron_right_rounded, size: 20),
            ],
          ),
        ),
      ),
    );
  }
}

class _BlueIcon extends StatelessWidget {
  const _BlueIcon({required this.icon});
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 36,
      height: 36,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: const Color(0xFFE9F0FF), // soft blue bg
        border: Border.all(color: const Color(0xFFD6E3FF)),
      ),
      child: Center(
        child: Icon(
          icon,
          size: 20,
          color: const Color(0xFF4C6EF5), // primary blue
        ),
      ),
    );
  }
}
