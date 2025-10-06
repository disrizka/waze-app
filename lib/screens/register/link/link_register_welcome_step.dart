import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:wa_blast/providers/link_register_provider.dart';

class LinkRegisterWelcomeStep extends StatelessWidget {
  const LinkRegisterWelcomeStep({super.key});

  @override
  Widget build(BuildContext context) {
    final p = context.watch<LinkRegisterProvider>();

    final businessName = p.displayBusinessName;
    final businessLogo = p.displayBusinessLogo ?? ''; // coerce ke String
    final inviteEmail = p.displayInviteEmail;
    final roleName = p.displayRoleName;

    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Color(0xFF42A5F5), // light blue
              Color(0xFF2DD4BF), // teal
            ],
          ),
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 40, 20, 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Top spacing & app logo
                const SizedBox(height: 50),
                Image.asset(
                  'assets/wave_logo_white.png',
                  width: 60,
                  fit: BoxFit.contain,
                ),
                const SizedBox(height: 30),

                // Friendly greeting + natural copy
                Text(
                  'Hi, $inviteEmail',
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'welcome to WaveUp',
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  // Jelaskan secara alami siapa yang mengundang & sebagai apa
                  '$businessName invited you to join their workspace as $roleName. '
                  'In the next steps, set your password and tell us your name so we can finish setting things up.',
                  style: const TextStyle(
                    fontSize: 15,
                    height: 1.5,
                    color: Colors.white70,
                  ),
                ),
                const SizedBox(height: 24),

                // ===== Invitation summary card =====
                _InviteSummaryCard(
                  businessName: businessName,
                  businessLogo: businessLogo,
                  inviteEmail: inviteEmail,
                  roleName: roleName,
                ),

                const Spacer(),

                // Next button
                Align(
                  alignment: Alignment.bottomRight,
                  child: SizedBox(
                    height: 56,
                    width: 56,
                    child: IconButton.filled(
                      style: const ButtonStyle(
                        backgroundColor: WidgetStatePropertyAll(Colors.white),
                        shape: WidgetStatePropertyAll(CircleBorder()),
                      ),
                      onPressed: () =>
                          context.read<LinkRegisterProvider>().dismissWelcome(),
                      icon: const Icon(
                        Icons.arrow_forward_rounded,
                        color: Color(0xFF42A5F5),
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
  }
}

class _InviteSummaryCard extends StatelessWidget {
  final String businessName;
  final String businessLogo;
  final String inviteEmail;
  final String roleName;

  const _InviteSummaryCard({
    required this.businessName,
    required this.businessLogo,
    required this.inviteEmail,
    required this.roleName,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.14),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withOpacity(0.22)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 10,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Business logo
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: _Logo(logoUrl: businessLogo),
          ),
          const SizedBox(width: 14),

          // Texts
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Flexible(
                      child: Text(
                        businessName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          height: 1.2,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),
                    const Icon(
                      Icons.verified_rounded,
                      color: Colors.white,
                      size: 18,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Logo extends StatelessWidget {
  final String logoUrl;
  const _Logo({required this.logoUrl});

  @override
  Widget build(BuildContext context) {
    const double size = 56;
    final fallback = Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.18),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withOpacity(0.25)),
      ),
      child: const Icon(
        Icons.store_mall_directory_rounded,
        color: Colors.white,
        size: 26,
      ),
    );

    if (logoUrl.isEmpty) return fallback;

    return Image.network(
      logoUrl,
      width: size,
      height: size,
      fit: BoxFit.cover,
      filterQuality: FilterQuality.medium,
      errorBuilder: (_, __, ___) => fallback,
      loadingBuilder: (context, child, progress) {
        if (progress == null) return child;
        return SizedBox(
          width: size,
          height: size,
          child: const Center(
            child: SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: Colors.white,
              ),
            ),
          ),
        );
      },
    );
  }
}
