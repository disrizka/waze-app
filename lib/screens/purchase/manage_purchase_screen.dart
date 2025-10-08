import 'package:flutter/material.dart';

class ManagePurchaseScreen extends StatelessWidget {
  const ManagePurchaseScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded),
          onPressed: () => Navigator.pushReplacementNamed(context, '/home'),
        ),
        title: const Text('Manage Purchase'),
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
              'List Menu',
              style: textTheme.bodyMedium?.copyWith(
                color: Colors.black.withOpacity(0.6),
                fontWeight: FontWeight.w600,
              ),
            ),
            // const SizedBox(height: 8),
            // _MenuTile(
            //   icon: Icons.receipt_long_rounded,
            //   title: 'Add Purchase',
            //   onTap: () => Navigator.pushNamed(context, '/purchase/add'),
            // ),
            const SizedBox(height: 8),
            _MenuTile(
              icon: Icons.receipt_long_rounded,
              title: 'Purchase List',
              onTap: () => Navigator.pushNamed(context, '/report/purchase'),
            ),
            const SizedBox(height: 8),
            _MenuTile(
              icon: Icons.factory,
              title: 'Supplier List',
              onTap: () => Navigator.pushNamed(context, '/purchase/supplier'),
            ),
            const SizedBox(height: 8),
            _MenuTile(
              icon: Icons.store,
              title: 'Store List',
              onTap: () => Navigator.pushNamed(context, '/store'),
            ),
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
