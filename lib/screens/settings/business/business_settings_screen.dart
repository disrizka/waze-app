import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:wa_blast/l10n/app_localizations.dart';

class BusinessSettingsScreen extends StatefulWidget {
  const BusinessSettingsScreen({super.key});

  @override
  State<BusinessSettingsScreen> createState() => _BusinessSettingsScreenState();
}

class _BusinessSettingsScreenState extends State<BusinessSettingsScreen> {
  bool _loading = true;
  String _businessName = '';
  String _businessUsername = '';
  String _businessLogoPath = '';

  @override
  void initState() {
    super.initState();
    _loadActiveBusiness();
  }

  Future<void> _loadActiveBusiness() async {
    final prefs = await SharedPreferences.getInstance();

    final activeId = (prefs.getString('activeBizId') ?? '').trim();
    String businessName = '';
    String businessUsername = '';
    String businessLogoPath = '';

    final businessJson = prefs.getString('business');
    if (businessJson != null && businessJson.isNotEmpty) {
      try {
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
          businessName = (match['name'] ?? '').toString();
          businessUsername = (match['username'] ?? '').toString();
          businessLogoPath = (match['logoPath'] ?? match['logo'] ?? '')
              .toString();
        } else {
          businessName = prefs.getString('activeBizName') ?? '';
          businessUsername = prefs.getString('activeBizUsername') ?? '';
          businessLogoPath = prefs.getString('activeBizLogoPath') ?? '';
        }
      } catch (_) {
        businessName = prefs.getString('activeBizName') ?? '';
        businessUsername = prefs.getString('activeBizUsername') ?? '';
        businessLogoPath = prefs.getString('activeBizLogoPath') ?? '';
      }
    } else {
      businessName = prefs.getString('activeBizName') ?? '';
      businessUsername = prefs.getString('activeBizUsername') ?? '';
      businessLogoPath = prefs.getString('activeBizLogoPath') ?? '';
    }

    if (!mounted) return;
    setState(() {
      _businessName = businessName.isNotEmpty ? businessName : '—';
      _businessUsername = businessUsername.isNotEmpty ? businessUsername : '—';
      _businessLogoPath = businessLogoPath;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final l10n = AppLocalizations.of(context)!;

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
        title: Text(l10n.businessSettingsTitle),
        centerTitle: false,
        elevation: 0,
      ),
      body: RefreshIndicator(
        onRefresh: _loadActiveBusiness,
        color: const Color(0xFF4C6EF5),
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
          physics: const AlwaysScrollableScrollPhysics(
            parent: BouncingScrollPhysics(),
          ),
          children: [
            // ===== Profile Header =====
            _ProfileHeader(
              loading: _loading,
              logoUrl: _businessLogoPath,
              name: _businessName,
              username: _businessUsername,
              planType: 'free', // TODO: ganti dari data API / prefs
              onPlanTap: () => Navigator.pushNamed(context, '/subscription'),
            ),

            const SizedBox(height: 28),

            // ===== Management section =====
            _SectionTitle(l10n.businessSettingsSectionManagement),
            const SizedBox(height: 8),
            _ListCard(
              children: [
                _MenuTile(
                  icon: Icons.payment,
                  title: 'Subscription',
                  subtitle: 'Manage your business subscription',
                  onTap: () => Navigator.pushNamed(context, '/subscription'),
                ),
              ],
            ),
            const SizedBox(height: 8),
            _ListCard(
              children: [
                _MenuTile(
                  icon: Icons.edit_document,
                  title: l10n.businessSettingsBusinessEditTitle,
                  subtitle: l10n.businessSettingsBusinessEditSubtitle,
                  onTap: () => Navigator.pushNamed(context, '/business/edit'),
                ),
              ],
            ),
            const SizedBox(height: 8),
            _ListCard(
              children: [
                _MenuTile(
                  icon: Icons.storefront_rounded,
                  title: l10n.businessSettingsStoreListTitle,
                  subtitle: l10n.businessSettingsStoreListSubtitle,
                  onTap: () => Navigator.pushNamed(context, '/purchase/store'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ================== PROFILE HEADER ==================

class _ProfileHeader extends StatelessWidget {
  const _ProfileHeader({
    required this.loading,
    required this.logoUrl,
    required this.name,
    required this.username,
    required this.planType, // "free" / "premium"
    required this.onPlanTap,
  });

  final bool loading;
  final String logoUrl;
  final String name;
  final String username;
  final String planType;
  final VoidCallback onPlanTap;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;

    if (loading) {
      return Container(
        decoration: _profileDecoration(),
        padding: const EdgeInsets.all(20),
        child: Row(
          children: const [
            _ShimmerBox(width: 64, height: 64, radius: 32),
            SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _ShimmerBox(width: 150, height: 18, radius: 6),
                  SizedBox(height: 8),
                  _ShimmerBox(width: 120, height: 14, radius: 6),
                  SizedBox(height: 8),
                  _ShimmerBox(width: 90, height: 16, radius: 999),
                ],
              ),
            ),
          ],
        ),
      );
    }

    return Container(
      decoration: _profileDecoration(),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Logo avatar
          CircleAvatar(
            radius: 36,
            backgroundColor: const Color(0xFFE9F0FF),
            child: logoUrl.isNotEmpty
                ? ClipOval(
                    child: Image.network(
                      logoUrl,
                      width: 72,
                      height: 72,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => _fallbackAvatar(name),
                    ),
                  )
                : _fallbackAvatar(name),
          ),
          const SizedBox(width: 18),

          // Text area kanan
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Baris 1: nama bisnis + badge plan di kanan
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Expanded(
                      child: Text(
                        name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: t.titleMedium?.copyWith(
                          fontWeight: FontWeight.w800,
                          fontSize: 18,
                          color: const Color(0xFF0F172A),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    _PlanStatusBadge(planType: planType, onTap: onPlanTap),
                  ],
                ),

                const SizedBox(height: 6),

                // Baris 2: username sebagai teks biasa
                Text(
                  '@$username',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: t.bodyMedium?.copyWith(
                    fontSize: 13,
                    color: const Color(0xFF6B7280),
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _fallbackAvatar(String name) {
    final initial = (name.isNotEmpty ? name.trim()[0].toUpperCase() : '?');
    return Text(
      initial,
      style: const TextStyle(
        fontWeight: FontWeight.w800,
        color: Color(0xFF4C6EF5),
        fontSize: 26,
      ),
    );
  }
}

// ================== LIST & TILE ==================

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.text);
  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: Theme.of(context).textTheme.labelLarge?.copyWith(
        color: const Color(0xFF6B7280),
        fontWeight: FontWeight.w700,
        letterSpacing: .3,
      ),
    );
  }
}

class _ListCard extends StatelessWidget {
  const _ListCard({required this.children});
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: _listDecoration(),
      child: Column(children: children),
    );
  }
}

class _MenuTile extends StatelessWidget {
  const _MenuTile({
    required this.icon,
    required this.title,
    this.subtitle,
    this.onTap,
  });

  final IconData icon;
  final String title;
  final String? subtitle;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: const BoxDecoration(
                  color: Color(0xFFEFF6FF),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: const Color(0xFF2563EB), size: 22),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: t.titleSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                        color: const Color(0xFF0F172A),
                      ),
                    ),
                    if (subtitle != null) ...[
                      const SizedBox(height: 2),
                      Text(
                        subtitle!,
                        style: t.bodySmall?.copyWith(
                          color: const Color(0xFF64748B),
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const Icon(Icons.chevron_right_rounded, size: 22),
            ],
          ),
        ),
      ),
    );
  }
}

// ================== DECORATIONS & SHIMMER ==================

BoxDecoration _profileDecoration() {
  return BoxDecoration(
    color: Colors.white,
    borderRadius: BorderRadius.circular(18),
    border: Border.all(color: const Color(0xFFE5E7EB)),
    boxShadow: [
      BoxShadow(
        color: Colors.black.withOpacity(0.04),
        blurRadius: 16,
        offset: const Offset(0, 8),
      ),
    ],
  );
}

BoxDecoration _listDecoration() {
  return BoxDecoration(
    color: Colors.white,
    borderRadius: BorderRadius.circular(14),
    border: Border.all(color: const Color(0xFFE5E7EB)),
  );
}

/// Badge kecil di header yang menunjukkan status plan (free / premium).
class _PlanStatusBadge extends StatelessWidget {
  final String planType; // "free" atau "premium"
  final VoidCallback onTap;

  const _PlanStatusBadge({required this.planType, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final String normalized = planType.trim().toLowerCase();
    final bool isPremium = normalized == 'premium';

    // Premium: gradient biru-hijau (tanpa ungu)
    const Gradient premiumGradient = LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [
        Color(0xFF22C55E), // green
        Color(0xFF3B82F6), // blue
      ],
    );

    // Free: silver/abu, lebih dull
    const Gradient freeGradient = LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [Color(0xFFEEEEEE), Color(0xFFD3D7DD)],
    );

    final Gradient badgeGradient = isPremium ? premiumGradient : freeGradient;
    final Color badgeTextColor = isPremium
        ? Colors.white
        : const Color(0xFF111827);
    final Color iconColor = isPremium ? Colors.white : const Color(0xFF4B5563);

    final String titleText = isPremium ? 'Premium plan' : 'Free plan';

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(999),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            gradient: badgeGradient,
            borderRadius: BorderRadius.circular(999),
            border: Border.all(
              color: Colors.white.withOpacity(isPremium ? 0.9 : 0.7),
              width: isPremium ? 1.2 : 1,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(isPremium ? 0.25 : 0.12),
                blurRadius: isPremium ? 12 : 6,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.workspace_premium_rounded, size: 16, color: iconColor),
              const SizedBox(width: 6),
              Text(
                titleText,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: badgeTextColor,
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.25,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ShimmerBox extends StatelessWidget {
  const _ShimmerBox({
    required this.width,
    required this.height,
    this.radius = 8,
  });

  final double width;
  final double height;
  final double radius;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: const Color(0xFFF3F4F6),
        borderRadius: BorderRadius.circular(radius),
      ),
    );
  }
}
