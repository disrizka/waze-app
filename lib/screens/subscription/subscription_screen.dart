import 'package:flutter/material.dart';
import 'package:flutter_svg/svg.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:wa_blast/constants/app_colors.dart';
import '../../providers/subscription_provider.dart';
import 'subscription_checkout_screen.dart';

class SubscriptionScreen extends StatelessWidget {
  const SubscriptionScreen({super.key});

  static const Color _primaryBlue = Color(0xFF4C6EF5);
  static const Color _backgroundBlue = Color(0xFFF2F5FF); // biru sangat muda

  @override
  Widget build(BuildContext context) {
    final subscription = Provider.of<SubscriptionProvider>(context);

    // formatter Rupiah dengan titik setiap 3 digit
    final NumberFormat _idrFormatter = NumberFormat('#,###', 'id_ID');

    String unlockSubtitle;
    if (subscription.isLoadingPlans) {
      unlockSubtitle = 'Fetching plan price...';
    } else if (subscription.monthlyPrice > 0) {
      final formatted = _idrFormatter.format(
        subscription.monthlyPrice.round(),
      ); // 650000 -> 650.000
      unlockSubtitle = 'Rp. $formatted/month – cancel anytime';
    } else {
      unlockSubtitle = 'See premium plans for pricing details';
    }

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Close button
              Align(
                alignment: Alignment.topRight,
                child: IconButton(
                  icon: const Icon(Icons.close),
                  color: _primaryBlue,
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ),

              const SizedBox(height: 8),

              // Illustration area
              Center(
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: const BoxDecoration(color: Colors.white),
                  child: SvgPicture.asset(
                    'assets/subscription-page.svg',
                    width: 320,
                  ),
                ),
              ),

              const SizedBox(height: 28),

              const Text(
                'Unlock or subscribe\nto grow your business',
                style: TextStyle(
                  fontSize: 26,
                  height: 1.2,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF111827), // almost black, tetap kontras
                ),
              ),

              const SizedBox(height: 12),

              const Text(
                'Get full access to analytics, automation, and premium tools. '
                'Subscribing is more cost-effective than buying single features.',
                style: TextStyle(
                  fontSize: 14,
                  height: 1.4,
                  color: Color(0xFF4B5563), // abu ke-biru
                ),
              ),

              const SizedBox(height: 16),

              const Spacer(),

              // Big button: unlock all
              _PrimaryButton(
                label: 'Upgrade your business',
                subtitle: unlockSubtitle,
                color: _primaryBlue,
                onPressed: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => const SubscriptionCheckoutScreen(),
                    ),
                  );
                },
              ),

              const SizedBox(height: 12),

              // Secondary button: limited access
              OutlinedButton(
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size.fromHeight(52),
                  side: const BorderSide(color: _primaryBlue, width: 1.4),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(28),
                  ),
                  foregroundColor: _primaryBlue,
                  backgroundColor: Colors.white,
                ),
                onPressed: () {
                  Navigator.of(context).pop();
                },
                child: const Text(
                  'Continue with limited access',
                  style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                ),
              ),

              const SizedBox(height: 10),
            ],
          ),
        ),
      ),
    );
  }

  // Masih bisa dipakai kalau mau ada bubble dekorasi di masa depan
  Widget _smallBubble() {
    return Container(
      width: 26,
      height: 26,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: Colors.white.withOpacity(0.9),
      ),
      child: const Icon(Icons.favorite_rounded, size: 16, color: _primaryBlue),
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
        elevation: 3,
        shadowColor: color.withOpacity(0.4),
      ),
      onPressed: onPressed,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 16,
                  ),
                ),
                if (subtitle != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    subtitle!,
                    style: const TextStyle(fontSize: 12, color: Colors.white70),
                  ),
                ],
              ],
            ),
          ),
          const Icon(Icons.keyboard_arrow_right_rounded, size: 28),
        ],
      ),
    );
  }
}
