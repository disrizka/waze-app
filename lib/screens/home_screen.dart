// lib/screens/home_screen.dart
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shimmer/shimmer.dart';
import 'package:wa_blast/constants/app_colors.dart';
import 'package:wa_blast/helper/route_observer.dart';
import 'package:wa_blast/providers/auth_provider.dart';
import 'package:wa_blast/providers/notification_provider.dart';
import 'package:wa_blast/providers/report_provider.dart';
import 'package:wa_blast/providers/role_provider.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:intl/intl.dart';
import 'package:wa_blast/providers/subscription_provider.dart';
import 'package:wa_blast/models/subscription_models/premium_plan_model.dart';
import 'package:wa_blast/widgets/app_snackbar.dart';
import '../l10n/app_localizations.dart';

// Key untuk menyimpan waktu terakhir modal subscription ditampilkan
const String kLastSubscriptionShownAtKey = 'lastSubscriptionShownAt';

class _MenuItemData {
  final String label;
  final String assetPath;
  final VoidCallback? onTap;

  /// Daftar "page" API yang mewakili tile ini (boleh kosong).
  final List<String> pageKeys;

  /// Route utama tile ini (dipakai untuk cek via RoleProvider.can()).
  final String? routeName;

  /// Kalau true → tile dikunci (abu & ada label "Premium")
  final bool isPremiumLocked;

  const _MenuItemData(
    this.label,
    this.assetPath, {
    this.onTap,
    this.pageKeys = const [],
    this.routeName,
    this.isPremiumLocked = false,
  });
}

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen>
    with RouteAware, WidgetsBindingObserver {
  bool _didKickRoleLoad = false;
  bool _didSubscribeRouteObserver = false;

  final GlobalKey<_HeaderGradientState> _headerKey =
      GlobalKey<_HeaderGradientState>();

  /// Refresh report harian
  Future<void> _kickDailyFetch() async {
    if (!mounted) return;

    final rp = context.read<ReportProviderV2>();

    await rp.fetchSales(
      context,
      target: ReportTarget.period,
      period: ReportPeriod.day,
      force: true, // paksa refresh supaya home selalu fresh
    );
  }

  /// Refresh user + sinkron active business + update header.
  /// Mengembalikan true kalau refresh user sukses.
  Future<bool> _refreshCurrentUserAndHeader() async {
    final auth = context.read<AuthProvider>();
    final prefs = await SharedPreferences.getInstance();

    final lockedId = (prefs.getString('activeBizId') ?? '').trim();
    final lockedName = prefs.getString('activeBizName') ?? '';
    final lockedUsername = prefs.getString('activeBizUsername') ?? '';
    final lockedLogoPath = prefs.getString('activeBizLogoPath') ?? '';
    final lockedRoleId = (prefs.getString('activeBizRoleId') ?? '').trim();
    final lockedRoleName = prefs.getString('activeBizRoleName') ?? '';
    final lockedRoleIsPrimary = prefs.getBool('activeBizRoleIsPrimary') ?? false;
    final ok = await auth.refreshCurrentUser(context);

    final currentId = (prefs.getString('activeBizId') ?? '').trim();

    // Pertahankan bisnis aktif sebelumnya bila masih valid di daftar terbaru.
    if (lockedId.isNotEmpty && lockedId != currentId) {
      final switched = lockedUsername.trim().isNotEmpty
          ? await auth.switchActiveBusinessByUsername(lockedUsername)
          : await auth.switchActiveBusiness(lockedId);
      if (!switched) {
        await auth.restoreActiveBusinessFromCache(
          idBusiness: lockedId,
          name: lockedName,
          username: lockedUsername,
          logoPath: lockedLogoPath,
          roleId: lockedRoleId,
          roleName: lockedRoleName,
          roleIsPrimary: lockedRoleIsPrimary,
        );
      }
      debugPrint(
        '[HomeScreen] restore activeBiz locked=$lockedId current=$currentId switched=$switched',
      );
    }

    // 🔁 Tambahan: refresh role setelah user refresh
    await context.read<RoleProvider>().refreshActiveRoleFromPrefs(context);

    await _headerKey.currentState?.reloadFromPrefs();

    return ok;
  }

  /// Cek apakah waktunya menampilkan subscription modal (minimal tiap 1 jam sekali)
  Future<void> _maybeShowSubscriptionModal() async {
    final prefs = await SharedPreferences.getInstance();

    // ✅ Jangan tampilkan modal kalau sudah premium
    final bool isPremium = _readActiveBizIsPremium(prefs);
    if (isPremium) return;

    // baca waktu terakhir modal muncul
    final lastStr = prefs.getString(kLastSubscriptionShownAtKey);
    if (lastStr != null) {
      final last = DateTime.tryParse(lastStr);
      if (last != null) {
        final diff = DateTime.now().difference(last);

        // kalau belum 1 jam, jangan tampilkan lagi
        if (diff < const Duration(hours: 1)) {
          return;
        }
      }
    }

    if (!mounted) return;

    // tampilkan modal subscription
    await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black.withOpacity(0.35),
      builder: (_) => const _SubscriptionSheet(),
    );

    // apapun hasilnya, simpan waktu terakhir muncul
    await prefs.setString(
      kLastSubscriptionShownAtKey,
      DateTime.now().toIso8601String(),
    );
  }

  bool _readActiveBizIsPremium(SharedPreferences prefs) {
    bool parsePremium(dynamic v) {
      if (v is bool) return v;
      if (v is num) return v != 0;
      final s = v?.toString().trim().toLowerCase() ?? '';
      if (s.isEmpty) return false;
      return s == '1' || s == 'true' || s == 'yes' || s == 'premium';
    }

    final activeId = (prefs.getString('activeBizId') ?? '').trim();
    final rawBusiness = prefs.getString('business');
    if (rawBusiness != null && rawBusiness.isNotEmpty) {
      try {
        final list = (jsonDecode(rawBusiness) as List)
            .cast<Map<String, dynamic>>();
        final match = list.firstWhere(
          (e) => (e['idBusiness'] ?? '').toString() == activeId,
          orElse: () => <String, dynamic>{},
        );
        if (match.isNotEmpty) {
          return parsePremium(match['isPremium'] ?? match['is_premium']);
        }
      } catch (_) {}
    }

    return prefs.getBool('activeBizIsPremium') ?? false;
  }

  @override
  void initState() {
    super.initState();
    Future.microtask(() async {
      // guard awal
      if (!mounted || _didKickRoleLoad) return;
      _didKickRoleLoad = true;

      // 1) refresh data user + header (SETIAP HOME DIBUKA)
      // Method ini sudah me-refresh role setelah /user sinkron.
      await _refreshCurrentUserAndHeader();

      if (!mounted) return;

      // 2) fetch report harian
      await _kickDailyFetch();

      await _refreshNotificationsOnHomeOpen();

      if (!mounted) return;

      // 3) cek apakah perlu tampilkan modal subscription
      // await _maybeShowSubscriptionModal();
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    // Subscribe sekali supaya callback route tidak terdaftar ganda.
    final route = ModalRoute.of(context);
    if (!_didSubscribeRouteObserver && route is PageRoute) {
      routeObserver.subscribe(this, route);
      _didSubscribeRouteObserver = true;
    }
  }

  @override
  void dispose() {
    routeObserver.unsubscribe(this);
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didPush() {
    _refreshNotificationsOnHomeOpen();
  }

  @override
  void didPopNext() {
    _refreshNotificationsOnHomeOpen();
  }

  // ✅ Tambahan: helper refresh notif
  Future<void> _refreshNotificationsOnHomeOpen() async {
    if (!mounted) return;
    final np = context.read<NotificationProvider>();

    // 1) badge unread biar selalu update
    await np.fetchUnreadCount(context);

    // 2) optional: reload list notif juga (biar dropdown isinya fresh)
    await np.fetchNotifications(context);
  }

  @override
  Widget build(BuildContext context) {
    final green = AppColors.blue;
    final textPrimary = const Color(0xFF1E1E1E);
    final t = AppLocalizations.of(context)!;

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: RefreshIndicator(
          color: AppColors.blue,
          onRefresh: () async {
            // 1) refresh user + header
            final ok = await _refreshCurrentUserAndHeader();

            // 2) refresh report harian biar panel tracking ikut update
            await _kickDailyFetch();

            // 3) cek & tampilkan modal subscription (kalau sudah lewat 1 jam)
            await _maybeShowSubscriptionModal();

            if (!mounted) return;

            AppSnackbar.show(
              context,
              type: ok ? AppSnackType.success : AppSnackType.error,
              title: ok ? 'Success' : 'Failed',
              message: ok ? t.refresh_success : t.refresh_failed,
              duration: const Duration(seconds: 2),
            );
          },
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(
              parent: BouncingScrollPhysics(),
            ),
            padding: EdgeInsets.zero,
            child: Builder(
              builder: (context) {
                final bool isTablet =
                    MediaQuery.of(context).size.shortestSide >= 600;

                final Widget phoneBody = Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _HeaderGradient(
                      key: _headerKey,
                      green: green,
                      textPrimary: textPrimary,
                    ),
                    const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 10),
                      child: _GridMenu(),
                    ),
                    const SizedBox(height: 24),
                    const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 20),
                      child: _TrackingReportGate(),
                    ),
                    const SizedBox(height: 24),
                  ],
                );

                if (!isTablet) return phoneBody;

                return Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 1024),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _HeaderGradient(
                          key: _headerKey,
                          green: green,
                          textPrimary: textPrimary,
                        ),
                        const Padding(
                          padding: EdgeInsets.symmetric(horizontal: 24),
                          child: _GridMenu(),
                        ),
                        const SizedBox(height: 24),
                        const Padding(
                          padding: EdgeInsets.symmetric(horizontal: 20),
                          child: _TrackingReportPanel(),
                        ),
                        const SizedBox(height: 32),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}

// ===================================================================
// SUBSCRIPTION SHEET (PAKAI DATA DARI SubscriptionProvider)
// ===================================================================

class _SubscriptionSheet extends StatefulWidget {
  const _SubscriptionSheet();

  // Blue theme (sesuai app)
  static const Color _primaryBlue = Color(0xFF4C6EF5);
  static const Color _softBlue = Color(0xFFE4EDFF);
  static const Color _borderGray = Color(0xFFE5E7EB);
  static const Color _textDark = Color(0xFF0F172A);
  static const Color _textMuted = Color(0xFF6B7280);

  @override
  State<_SubscriptionSheet> createState() => _SubscriptionSheetState();
}

class _SubscriptionSheetState extends State<_SubscriptionSheet> {
  String _formatRp(num v) {
    final f = NumberFormat.currency(
      locale: 'id_ID',
      symbol: 'Rp. ',
      decimalDigits: 0,
    );
    return f.format(v);
  }

  String _buildPriceLabel(PremiumPlan plan) {
    final price = _formatRp(plan.price);
    final months = plan.months;
    String period;
    if (months == null || months <= 0) {
      period = 'period';
    } else if (months == 1) {
      period = 'month';
    } else if (months == 12) {
      period = 'year';
    } else {
      period = '$months months';
    }
    return '$price / $period';
  }

  @override
  void initState() {
    super.initState();
    // Saat sheet dibuka, langsung fetch premium plan
    Future.microtask(() async {
      if (!mounted) return;
      await context.read<SubscriptionProvider>().fetchPremiumPlans(context);
    });
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final bool isTablet = size.shortestSide >= 600;
    final double maxWidth = isTablet ? 420 : size.width;

    final sub = context.watch<SubscriptionProvider>();
    final bool loading = sub.isLoadingPlans;
    PremiumPlan? firstPlan = sub.plans.isNotEmpty ? sub.plans.first : null;

    final String premiumPriceText = loading
        ? 'Loading...'
        : (firstPlan != null
              ? _buildPriceLabel(firstPlan)
              : 'Plan not available');

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
              children: [
                // top bar (back icon)
                Row(
                  children: [
                    InkWell(
                      borderRadius: BorderRadius.circular(999),
                      onTap: () => Navigator.of(context).pop(false),
                      child: const Padding(
                        padding: EdgeInsets.all(4),
                        child: Icon(
                          Icons.arrow_back_ios_new_rounded,
                          size: 18,
                          color: _SubscriptionSheet._textMuted,
                        ),
                      ),
                    ),
                    const Spacer(),
                  ],
                ),
                const SizedBox(height: 8),

                // 👇 Logo WaveUp
                SvgPicture.asset(
                  'assets/subscription-promotion.svg',
                  width: 250,
                ),

                const SizedBox(height: 30),

                // Title & subtitle
                const Text(
                  'Choose the perfect plan',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: _SubscriptionSheet._textDark,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 6),
                const Text(
                  'Unlock the full power of WaveUp and grow your business with confidence.',
                  style: TextStyle(
                    fontSize: 13,
                    color: _SubscriptionSheet._textMuted,
                    height: 1.35,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 20),

                if (sub.errorMessage != null && !loading) ...[
                  Container(
                    padding: const EdgeInsets.all(10),
                    margin: const EdgeInsets.only(bottom: 8),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFEE2E2),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFFFCA5A5)),
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.error_outline,
                          size: 16,
                          color: Color(0xFFB91C1C),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            sub.errorMessage!,
                            style: const TextStyle(
                              fontSize: 12,
                              color: Color(0xFFB91C1C),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],

                // Plan cards (FREE & PREMIUM)
                Row(
                  children: [
                    const Expanded(
                      child: _SubscriptionPlanCard(
                        title: 'Basic Plan',
                        priceText: 'Rp. 500 / transaction',
                        badgeText: 'Current plan',
                        isHighlighted: false,
                        isCurrent: true,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _SubscriptionPlanCard(
                        title: 'Premium',
                        priceText: premiumPriceText,
                        badgeText: firstPlan != null ? 'Best value' : 'Premium',
                        isHighlighted: true,
                        isCurrent: false,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 18),

                // Short explanation under the plans
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: _SubscriptionSheet._softBlue,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: _SubscriptionSheet._borderGray),
                  ),
                  child: const Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Basic plan',
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 13,
                          color: _SubscriptionSheet._textDark,
                        ),
                      ),
                      SizedBox(height: 4),
                      Text(
                        'This is your current plan. You have to pay Rp. 500 for every sales transaction',
                        style: TextStyle(
                          fontSize: 12,
                          color: _SubscriptionSheet._textMuted,
                          height: 1.35,
                        ),
                      ),
                      SizedBox(height: 10),
                      Text(
                        'Premium plan',
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 13,
                          color: _SubscriptionSheet._textDark,
                        ),
                      ),
                      SizedBox(height: 4),
                      Text(
                        'Upgrade to unlock unlimited products, unlimited transactions, and full access to tools designed to scale your business.',
                        style: TextStyle(
                          fontSize: 12,
                          color: _SubscriptionSheet._textMuted,
                          height: 1.35,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),

                // CTA button
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _SubscriptionSheet._primaryBlue,
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    onPressed: () {
                      // Tetap arahkan ke halaman subscription utama
                      Navigator.pushNamed(context, '/subscription');
                    },
                    child: const Text(
                      'Upgrade to Premium',
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 15,
                        color: Colors.white,
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

class _BusinessPlanBadge extends StatelessWidget {
  final bool isPremium;
  final VoidCallback onTap;

  const _BusinessPlanBadge({required this.isPremium, required this.onTap});

  @override
  Widget build(BuildContext context) {
    if (isPremium) {
      // PREMIUM BADGE
      return InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(999),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xFF4C6EF5), Color(0xFF22C55E)],
            ),
            borderRadius: BorderRadius.circular(999),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: const [
              Icon(LucideIcons.crown, size: 13, color: Colors.white),
              SizedBox(width: 6),
              Text(
                'Premium business',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                ),
              ),
            ],
          ),
        ),
      );
    }

    // BASIC + UPGRADE BADGE (semua dalam 1 badge)
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(999),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: const Color(0xFFF3F4FF),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: const Color(0xFFCBD5FF)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: const [
            Icon(LucideIcons.store, size: 13, color: Color(0xFF4C6EF5)),
            SizedBox(width: 6),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Basic business',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF1D4ED8),
                  ),
                ),
                Text(
                  'Tap to upgrade',
                  style: TextStyle(
                    fontSize: 9,
                    fontWeight: FontWeight.w500,
                    color: Color(0xFF2563EB),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _SubscriptionPlanCard extends StatelessWidget {
  final String title;
  final String priceText;
  final String badgeText;
  final bool isHighlighted;
  final bool isCurrent;

  const _SubscriptionPlanCard({
    required this.title,
    required this.priceText,
    required this.badgeText,
    required this.isHighlighted,
    required this.isCurrent,
  });

  @override
  Widget build(BuildContext context) {
    final Color borderColor = isHighlighted
        ? _SubscriptionSheet._primaryBlue
        : _SubscriptionSheet._borderGray;
    final Color bgColor = isHighlighted
        ? _SubscriptionSheet._softBlue
        : Colors.white;

    final Color titleColor = isHighlighted
        ? _SubscriptionSheet._primaryBlue
        : _SubscriptionSheet._textDark;

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 10),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: borderColor, width: isHighlighted ? 2 : 1),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (badgeText.isNotEmpty)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: isHighlighted
                    ? _SubscriptionSheet._primaryBlue
                    : const Color(0xFFE5E7EB),
                borderRadius: BorderRadius.circular(999),
              ),
              child: Text(
                badgeText.toUpperCase(),
                style: TextStyle(
                  fontSize: 9,
                  fontWeight: FontWeight.w800,
                  color: isHighlighted
                      ? Colors.white
                      : _SubscriptionSheet._textDark,
                  letterSpacing: 0.4,
                ),
              ),
            )
          else
            const SizedBox(height: 18),
          const SizedBox(height: 6),
          Text(
            title,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 16,
              fontWeight: isHighlighted ? FontWeight.w800 : FontWeight.w700,
              color: titleColor,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            priceText,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 12,
              color: _SubscriptionSheet._textMuted,
            ),
          ),
          const SizedBox(height: 8),
          if (isCurrent)
            const Text(
              'You are currently on this plan',
              style: TextStyle(
                fontSize: 11,
                color: _SubscriptionSheet._textMuted,
                height: 1.3,
              ),
              textAlign: TextAlign.center,
            )
          else
            const Text(
              'Perfect for growing and scaling your store.',
              style: TextStyle(
                fontSize: 11,
                color: _SubscriptionSheet._textMuted,
                height: 1.3,
              ),
              textAlign: TextAlign.center,
            ),
        ],
      ),
    );
  }
}

class _HeaderGradient extends StatefulWidget {
  final Color green;
  final Color textPrimary;

  const _HeaderGradient({
    super.key,
    required this.green,
    required this.textPrimary,
  });

  @override
  State<_HeaderGradient> createState() => _HeaderGradientState();
}

class _HeaderGradientState extends State<_HeaderGradient> {
  String _accountName = '';
  String _accountUsername = '';
  String _businessName = '';
  String _businessUsername = '';
  String _photoPath = '';
  String _businessLogoPath = '';
  bool _isPremium = false;

  String _bannedStatus = ''; // '', 'semi-ban', 'ban'

  @override
  void initState() {
    super.initState();
    _loadPrefs();
  }

  bool _parsePremiumFlag(dynamic v) {
    if (v is bool) return v;
    if (v is num) return v != 0;
    final s = v?.toString().trim().toLowerCase() ?? '';
    if (s.isEmpty) return false;
    return s == '1' || s == 'true' || s == 'yes' || s == 'premium';
  }

  // Public wrapper supaya bisa dipanggil dari RefreshIndicator
  Future<void> reloadFromPrefs() => _loadPrefs();

  Future<void> _openBusinessSwitcher() async {
    final t = AppLocalizations.of(context)!;
    final changed = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (_) => const _BusinessSwitcherSheet(),
    );

    if (changed == true && mounted) {
      // 1️⃣ Reload header + info bisnis aktif (nama, username, logo, isPremium)
      await _loadPrefs();

      // 2️⃣ Refresh role & permission untuk bisnis baru
      //    → ini yang akan memicu _GridMenu rebuild dan load menu terbaru
      await context.read<RoleProvider>().refreshActiveRoleFromPrefs(context);

      // 3️⃣ Refresh report harian (tracking panel)
      final rp = context.read<ReportProviderV2>();
      await rp.fetchSales(
        context,
        target: ReportTarget.customer,
        period: ReportPeriod.day,
        force: true,
      );

      if (!mounted) return;

      // 4️⃣ Snackbar sukses switch
      AppSnackbar.show(
        context,
        type: AppSnackType.success,
        title: 'Success',
        message: t.snackbar_business_switch_success,
        duration: const Duration(seconds: 2),
      );
    }
  }

  /// Buka subscription sheet ketika user tekan badge plan.
  Future<void> _openSubscriptionSheet() async {
    await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black.withOpacity(0.35),
      builder: (_) => const _SubscriptionSheet(),
    );
  }

  Future<void> _openTransactionFeeModal() async {
    if (!mounted) return;

    // fetch dulu biar modal kebuka dengan state terbaru
    await context.read<SubscriptionProvider>().fetchTransactionFees(context);

    if (!mounted) return;

    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const _TransactionFeeDialog(),
    );
  }

  Future<void> _loadPrefs() async {
    final prefs = await SharedPreferences.getInstance();

    final name = prefs.getString('name') ?? '';
    final userUsername = prefs.getString('username')?.trim();
    final email = prefs.getString('email')?.trim();
    final accountUsername = (userUsername != null && userUsername.isNotEmpty)
        ? userUsername
        : (email ?? '');

    // ——— utamakan baca via activeBizId
    final activeId = (prefs.getString('activeBizId') ?? '').trim();

    String businessName = '';
    String businessUsername = '';
    String businessLogoPath = '';
    bool isPremium = false;
    String bannedStatus = '';

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
          isPremium = _parsePremiumFlag(
            match['isPremium'] ?? match['is_premium'],
          );

          // ✅ NEW
          bannedStatus = (match['banned'] as String?)?.trim() ?? '';
        } else {
          businessName = prefs.getString('activeBizName') ?? '';
          businessUsername = prefs.getString('activeBizUsername') ?? '';
          businessLogoPath = prefs.getString('activeBizLogoPath') ?? '';
          isPremium = prefs.getBool('activeBizIsPremium') ?? false;

          // ✅ NEW
          bannedStatus = (prefs.getString('activeBizBanned') ?? '').trim();
        }
      } catch (_) {
        businessName = prefs.getString('activeBizName') ?? '';
        businessUsername = prefs.getString('activeBizUsername') ?? '';
        businessLogoPath = prefs.getString('activeBizLogoPath') ?? '';
        isPremium = (prefs.getBool('activeBizIsPremium') ?? false);
      }
    } else {
      businessName = prefs.getString('activeBizName') ?? '';
      businessUsername = prefs.getString('activeBizUsername') ?? '';
      businessLogoPath = prefs.getString('activeBizLogoPath') ?? '';
      isPremium = prefs.getBool('activeBizIsPremium') ?? false;
    }

    _photoPath = prefs.getString('photoPath') ?? '';
    _businessLogoPath = businessLogoPath;
    await prefs.setBool('activeBizIsPremium', isPremium);

    if (!mounted) return;
    setState(() {
      _accountName = name;
      _accountUsername = accountUsername.isNotEmpty ? accountUsername : '—';
      _businessName = businessName.isNotEmpty ? businessName : '—';
      _businessUsername = businessUsername.isNotEmpty ? businessUsername : '—';
      _isPremium = isPremium;
      _bannedStatus = bannedStatus; // ✅
    });
  }

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context)!;

    // ukuran & posisi agar menimpa 3/4 dari gradient
    const double headerHeight = 150; // tinggi area gradient
    const double cardHeight = 96; // tinggi kartu
    final double overlapTop =
        headerHeight - cardHeight * 0.79; // 1/4 di dalam gradient, 3/4 di luar

    final String ban = _bannedStatus.trim().toLowerCase();

    return Column(
      children: [
        Stack(
          clipBehavior: Clip.none,
          children: [
            // GRADIENT HEADER (rounded bottom)
            Container(
              height: headerHeight,
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    Color(0xFF1FB4FF), // biru terang
                    Color(0xFF23D38E), // hijau
                  ],
                  stops: [0.0, 1.0],
                ),
                borderRadius: BorderRadius.vertical(
                  bottom: Radius.circular(28),
                ),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // LOGO KIRI
                  const SizedBox(
                    width: 36,
                    height: 36,
                    child: Padding(
                      padding: EdgeInsets.only(top: 2),
                      child: Image(
                        image: AssetImage('assets/wave_logo_white.png'),
                        fit: BoxFit.contain,
                      ),
                    ),
                  ),

                  const Spacer(),

                  // 🔷 GET PREMIUM badge – hanya muncul kalau BELUM premium
                  // 🔷 BADGE PLAN
                  // - kalau belum premium: Get premium (bisa dipencet)
                  // - kalau premium: Premium badge (tidak bisa dipencet)
                  if (!_isPremium)
                    Padding(
                      padding: const EdgeInsets.only(top: 2),
                      child: Material(
                        color: Colors.transparent,
                        child: InkWell(
                          borderRadius: BorderRadius.circular(999),
                          onTap: _openSubscriptionSheet,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(
                                colors: [
                                  Color(0xFF6366F1), // indigo
                                  Color(0xFFEC4899), // pink
                                ],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              ),
                              borderRadius: BorderRadius.circular(999),
                            ),
                            child: const Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  LucideIcons.gem,
                                  size: 16,
                                  color: Colors.white,
                                ),
                                SizedBox(width: 6),
                                Text(
                                  'Get premium',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w800,
                                    letterSpacing: 0.2,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    )
                  else
                    const Padding(
                      padding: EdgeInsets.only(top: 2),
                      child: _PremiumStaticBadge(), // 👑 non-clickable
                    ),

                  const SizedBox(width: 6),

                  // ICON LONCENG NOTIFIKASI
                  SizedBox(
                    width: 36,
                    height: 36,
                    child: Padding(
                      padding: const EdgeInsets.only(top: 2),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(18),
                        onTap: () => Navigator.of(context).pushNamed(
                          '/notification',
                        ),
                        child: Stack(
                          clipBehavior: Clip.none,
                          children: [
                            const Center(
                              child: Icon(
                                LucideIcons.bell,
                                color: Colors.white,
                                size: 22,
                              ),
                            ),
                            // 🔴 Badge unread
                            Positioned(
                              right: -2,
                              top: -2,
                              child: Consumer<NotificationProvider>(
                                builder: (_, np, __) {
                                  final c = np.unreadCount;
                                  if (c <= 0) {
                                    return const SizedBox.shrink();
                                  }
                                  final text = c > 99 ? '99+' : '$c';
                                  return Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 5,
                                      vertical: 1.5,
                                    ),
                                    decoration: BoxDecoration(
                                      color: Colors.redAccent,
                                      borderRadius: BorderRadius.circular(10),
                                      border: Border.all(
                                        color: Colors.white,
                                        width: 1,
                                      ),
                                    ),
                                    child: Text(
                                      text,
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 10,
                                        fontWeight: FontWeight.w800,
                                      ),
                                    ),
                                  );
                                },
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // KARTU MENGAMBANG (akun + bisnis)
            Positioned(
              top: overlapTop,
              left: 20,
              right: 20,
              child: Container(
                height: cardHeight,
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 12,
                ),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(18),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.10),
                      blurRadius: 20,
                      offset: const Offset(0, 14),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: _InfoBlock(
                        caption: t.header_account_caption,
                        leading: CircleAvatar(
                          radius: 18,
                          backgroundColor: const Color(0xFFE9F6EE),
                          child: _photoPath.isNotEmpty
                              ? ClipOval(
                                  child: Image.network(
                                    _photoPath,
                                    fit: BoxFit.cover,
                                    width: 36,
                                    height: 36,
                                    errorBuilder: (ctx, error, stack) {
                                      final initial = (_accountName.isNotEmpty)
                                          ? _accountName.trim()[0].toUpperCase()
                                          : '?';
                                      return Center(
                                        child: Text(
                                          initial,
                                          style: const TextStyle(
                                            fontWeight: FontWeight.w700,
                                            color: Colors.green,
                                          ),
                                        ),
                                      );
                                    },
                                  ),
                                )
                              : Center(
                                  child: Text(
                                    (_accountName.isNotEmpty)
                                        ? _accountName.trim()[0].toUpperCase()
                                        : '?',
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w700,
                                      color: Colors.green,
                                    ),
                                  ),
                                ),
                        ),
                        title: _accountName,
                        subtitle: '@${_shortId(_accountUsername)}',
                      ),
                    ),

                    // divider tipis
                    Container(
                      width: 1,
                      height: 42,
                      margin: const EdgeInsets.symmetric(horizontal: 12),
                      color: const Color(0xFFEAEAEA),
                    ),

                    // Business + badge
                    Expanded(
                      child: _InfoBlock(
                        caption: t.header_business_caption,
                        leading: CircleAvatar(
                          radius: 18,
                          backgroundColor: const Color(0xFFE9F0FF),
                          child: _businessLogoPath.isNotEmpty
                              ? ClipOval(
                                  child: Image.network(
                                    _businessLogoPath,
                                    fit: BoxFit.cover,
                                    width: 36,
                                    height: 36,
                                    errorBuilder: (ctx, error, stack) {
                                      final initial = (_businessName.isNotEmpty)
                                          ? _businessName
                                                .trim()[0]
                                                .toUpperCase()
                                          : '?';
                                      return Center(
                                        child: Text(
                                          initial,
                                          style: const TextStyle(
                                            fontWeight: FontWeight.w700,
                                            color: Colors.blue,
                                          ),
                                        ),
                                      );
                                    },
                                  ),
                                )
                              : Center(
                                  child: Text(
                                    (_businessName.isNotEmpty)
                                        ? _businessName.trim()[0].toUpperCase()
                                        : '?',
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w700,
                                      color: Colors.blue,
                                    ),
                                  ),
                                ),
                        ),
                        title: _businessName,
                        subtitle: '@${_shortId(_businessUsername)}',
                        onTap: _openBusinessSwitcher,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),

        // ✅ Kalau null/kosong/selain itu -> seperti biasa (hanya spacer)
        // Spacer + banner (dynamic spacing biar gak mepet & gak kejauhan)
        Builder(
          builder: (_) {
            final bool showBanner = ban == 'semi-ban' || ban == 'ban';

            // ✅ Default (tanpa banner): seperti biasa
            if (!showBanner) {
              return const SizedBox(height: cardHeight * 0.70 + 3);
            }

            // ✅ Dengan banner:
            // - spacer diperkecil supaya grid gak turun jauh
            // - banner kasih jarak dari kartu (top) & jarak kecil ke grid (bottom)
            return Column(
              children: [
                const SizedBox(
                  height: 10,
                ), // jarak dari kartu (biar gak mepet atas)

                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 30, 20, 0),
                  child: _SalesAccessWarningBanner(
                    type: ban == 'ban'
                        ? _SalesBanType.ban
                        : _SalesBanType.semiBan,
                    onPay: () => _openTransactionFeeModal(),
                  ),
                ),

                const SizedBox(
                  height: 30,
                ), // jarak banner ke grid (biar gak kejauhan)
              ],
            );
          },
        ),
      ],
    );
  }
}

enum _SalesBanType { semiBan, ban }

class _SalesAccessWarningBanner extends StatelessWidget {
  final _SalesBanType type;
  final VoidCallback? onPay;

  const _SalesAccessWarningBanner({required this.type, this.onPay});

  static const _primaryBlue = Color(0xFF4C6EF5);

  @override
  Widget build(BuildContext context) {
    final bool isBan = type == _SalesBanType.ban;

    final Color bg = isBan ? const Color(0xFFFEF2F2) : const Color(0xFFFFFBEB);
    final Color border = isBan
        ? const Color(0xFFFECACA)
        : const Color(0xFFFDE68A);
    final Color iconBg = isBan
        ? const Color(0xFFFEE2E2)
        : const Color(0xFFFEF3C7);
    final Color iconColor = isBan
        ? const Color(0xFFDC2626)
        : const Color(0xFFD97706);
    final Color titleColor = isBan
        ? const Color(0xFF991B1B)
        : const Color(0xFF92400E);
    final Color textColor = isBan
        ? const Color(0xFF7F1D1D)
        : const Color(0xFF78350F);

    final String title = isBan ? 'Payment required' : 'Payment reminder';
    final String message = isBan
        ? 'Please pay your monthly bill to access Sales features.'
        : 'Please pay your monthly bill before your Sales access is limited.';

    final Color btnBg = isBan
        ? const Color(0xFFDC2626)
        : const Color(0xFFD97706);
    final Color btnBgPressed = isBan
        ? const Color(0xFFB91C1C)
        : const Color(0xFFB45309);

    void goPay() {
      if (onPay != null) return onPay!();
      Navigator.pushNamed(context, '/subscription'); // ✅ default
    }

    return Container(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: border),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: iconBg,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              Icons.warning_amber_rounded,
              color: iconColor,
              size: 20,
            ),
          ),
          const SizedBox(width: 10),

          // text
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 14,
                    color: titleColor,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  message,
                  style: TextStyle(
                    fontSize: 12.5,
                    height: 1.25,
                    color: textColor,
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(width: 10),

          // ✅ Pay button
          SizedBox(
            height: 34,
            child: ElevatedButton(
              style: ButtonStyle(
                backgroundColor: MaterialStateProperty.resolveWith<Color>((s) {
                  if (s.contains(MaterialState.pressed)) return btnBgPressed;
                  return btnBg;
                }),
                elevation: const MaterialStatePropertyAll(0),
                padding: const MaterialStatePropertyAll(
                  EdgeInsets.symmetric(horizontal: 14),
                ),
                shape: MaterialStatePropertyAll(
                  RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
              onPressed: goPay,
              child: const Text(
                'Pay',
                style: TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 12,
                  color: Colors.white,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

String _shortId(String raw) {
  if (raw.isEmpty) return '';
  // ambil 9 karakter pertama, lalu tambahkan "..."
  final short = raw.length > 9 ? raw.substring(0, 9) : raw;
  return '$short...';
}

class _PremiumStaticBadge extends StatelessWidget {
  const _PremiumStaticBadge();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [
            Color(0xFF22C55E), // green
            Color(0xFF4C6EF5), // blue
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(
          color: Colors.white, // 👈 border putih
          width: 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.12),
            blurRadius: 10,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: const Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(LucideIcons.crown, size: 16, color: Colors.white),
          SizedBox(width: 6),
          Text(
            'Premium',
            style: TextStyle(
              color: Colors.white,
              fontSize: 12,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.2,
            ),
          ),
        ],
      ),
    );
  }
}

class _TransactionFeeDialog extends StatelessWidget {
  const _TransactionFeeDialog();

  static const Color _primaryBlue = Color(0xFF4C6EF5);
  static const Color _textDark = Color(0xFF0F172A);
  static const Color _textMuted = Color(0xFF6B7280);
  static const Color _border = Color(0xFFE5E7EB);
  static const Color _paper = Color(0xFFFFFFFF);
  static const Color _paperSoft = Color(0xFFF8FAFF);

  String _formatRp(int v) {
    final f = NumberFormat.currency(
      locale: 'id_ID',
      symbol: 'Rp ',
      decimalDigits: 0,
    );
    return f.format(v);
  }

  String _monthLabel(int m, int y) {
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
    final mm = (m >= 1 && m <= 12) ? months[m - 1] : '—';
    return '$mm $y';
  }

  Widget _kv(String k, String v) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          k,
          style: const TextStyle(
            fontSize: 12,
            color: _textMuted,
            fontWeight: FontWeight.w600,
          ),
        ),
        Flexible(
          child: Text(
            v,
            textAlign: TextAlign.right,
            style: const TextStyle(
              fontSize: 12,
              color: _textDark,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
      ],
    );
  }

  Widget _dashedLine() {
    return LayoutBuilder(
      builder: (_, c) {
        final dashCount = (c.maxWidth / 10).floor();
        return Row(
          children: List.generate(dashCount, (_) {
            return Expanded(
              child: Container(
                height: 1,
                margin: const EdgeInsets.symmetric(horizontal: 2),
                color: _border,
              ),
            );
          }),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final bool isTablet = size.shortestSide >= 600;

    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 18),
      backgroundColor: Colors.transparent,
      child: Center(
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: isTablet ? 520 : 560),
          child: Material(
            color: Colors.transparent,
            child: Container(
              decoration: BoxDecoration(
                color: _paper,
                borderRadius: BorderRadius.circular(22),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.18),
                    blurRadius: 26,
                    offset: const Offset(0, 18),
                  ),
                ],
              ),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(18, 16, 18, 16),
                child: Consumer<SubscriptionProvider>(
                  builder: (_, sp, __) {
                    final loading = sp.isLoadingTransactionFees;
                    final err = sp.transactionFeeError;
                    final items = sp.transactionFees;
                    final totalUnpaid = sp.totalUnpaidTransactionFee;

                    // Ambil "billing period" utama dari item pertama (kalau ada)
                    final periodLabel = items.isNotEmpty
                        ? _monthLabel(items.first.month, items.first.year)
                        : '—';

                    return Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // ===== Top Header (bill style) =====
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              width: 42,
                              height: 42,
                              decoration: BoxDecoration(
                                color: const Color(0xFFEFF6FF),
                                borderRadius: BorderRadius.circular(14),
                              ),
                              child: const Icon(
                                Icons.receipt_long_rounded,
                                color: _primaryBlue,
                                size: 22,
                              ),
                            ),
                            const SizedBox(width: 10),
                            const Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Payment required',
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w900,
                                      color: _textDark,
                                    ),
                                  ),
                                  SizedBox(height: 2),
                                  Text(
                                    'Please settle your monthly transaction fee to unlock Sales access.',
                                    style: TextStyle(
                                      fontSize: 12,
                                      height: 1.25,
                                      color: _textMuted,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            InkWell(
                              borderRadius: BorderRadius.circular(999),
                              onTap: () {
                                context
                                    .read<SubscriptionProvider>()
                                    .resetTransactionFeeState();
                                Navigator.of(context).pop();
                              },
                              child: const Padding(
                                padding: EdgeInsets.all(6),
                                child: Icon(
                                  Icons.close_rounded,
                                  size: 20,
                                  color: Color(0xFF9CA3AF),
                                ),
                              ),
                            ),
                          ],
                        ),

                        const SizedBox(height: 14),
                        const Divider(height: 1, color: _border),
                        const SizedBox(height: 12),

                        if (loading) ...[
                          const SizedBox(height: 14),
                          const CircularProgressIndicator(strokeWidth: 2),
                          const SizedBox(height: 14),
                        ] else if (err != null && err.trim().isNotEmpty) ...[
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: const Color(0xFFFEE2E2),
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(
                                color: const Color(0xFFFCA5A5),
                              ),
                            ),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Icon(
                                  Icons.error_outline,
                                  size: 18,
                                  color: Color(0xFFB91C1C),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Text(
                                    err,
                                    style: const TextStyle(
                                      fontSize: 12.5,
                                      color: Color(0xFF991B1B),
                                      height: 1.3,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 12),
                        ] else ...[
                          // ===== Bill / Invoice Body =====
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
                            decoration: BoxDecoration(
                              color: _paperSoft,
                              borderRadius: BorderRadius.circular(18),
                              border: Border.all(color: _border),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                // Bill summary header row
                                Row(
                                  children: [
                                    const Text(
                                      'Bill summary',
                                      style: TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w900,
                                        color: _textDark,
                                      ),
                                    ),
                                    const Spacer(),
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 10,
                                        vertical: 5,
                                      ),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFFEFF6FF),
                                        borderRadius: BorderRadius.circular(
                                          999,
                                        ),
                                        border: Border.all(
                                          color: const Color(0xFFD7E6FF),
                                        ),
                                      ),
                                      child: Text(
                                        totalUnpaid > 0 ? 'DUE' : 'SETTLED',
                                        style: const TextStyle(
                                          fontSize: 11,
                                          fontWeight: FontWeight.w900,
                                          color: _primaryBlue,
                                          letterSpacing: 0.4,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),

                                const SizedBox(height: 10),
                                _kv('Billing period', periodLabel),
                                const SizedBox(height: 6),
                                _kv('Service', 'WaveUp Transaction Fee'),

                                const SizedBox(height: 12),
                                _dashedLine(),
                                const SizedBox(height: 12),

                                const Text(
                                  'Line items',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w900,
                                    color: _textDark,
                                  ),
                                ),
                                const SizedBox(height: 10),

                                if (items.isEmpty)
                                  const Padding(
                                    padding: EdgeInsets.symmetric(vertical: 8),
                                    child: Text(
                                      'No outstanding fee found.',
                                      style: TextStyle(
                                        fontSize: 12.5,
                                        color: _textMuted,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  )
                                else
                                  ...items.map((it) {
                                    final status = it.status
                                        .toLowerCase()
                                        .trim();
                                    final bool isPending =
                                        status == 'pending' ||
                                        status == 'unpaid' ||
                                        status == 'due';

                                    final Color badgeBg = isPending
                                        ? const Color(0xFFFFFBEB)
                                        : const Color(0xFFECFDF5);
                                    final Color badgeBorder = isPending
                                        ? const Color(0xFFFDE68A)
                                        : const Color(0xFFBBF7D0);
                                    final Color badgeText = isPending
                                        ? const Color(0xFF92400E)
                                        : const Color(0xFF166534);

                                    return Container(
                                      margin: const EdgeInsets.only(bottom: 10),
                                      padding: const EdgeInsets.fromLTRB(
                                        12,
                                        10,
                                        12,
                                        10,
                                      ),
                                      decoration: BoxDecoration(
                                        color: Colors.white,
                                        borderRadius: BorderRadius.circular(14),
                                        border: Border.all(color: _border),
                                      ),
                                      child: Column(
                                        children: [
                                          Row(
                                            children: [
                                              Expanded(
                                                child: Text(
                                                  _monthLabel(
                                                    it.month,
                                                    it.year,
                                                  ),
                                                  style: const TextStyle(
                                                    fontSize: 13,
                                                    fontWeight: FontWeight.w900,
                                                    color: _textDark,
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ),
                                          const SizedBox(height: 8),
                                          Row(
                                            mainAxisAlignment:
                                                MainAxisAlignment.spaceBetween,
                                            children: [
                                              Text(
                                                '${it.transactionCount} transaction(s)',
                                                style: const TextStyle(
                                                  fontSize: 12,
                                                  color: _textMuted,
                                                  fontWeight: FontWeight.w700,
                                                ),
                                              ),
                                              Text(
                                                _formatRp(it.totalFee),
                                                style: const TextStyle(
                                                  fontSize: 13,
                                                  color: _textDark,
                                                  fontWeight: FontWeight.w900,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ],
                                      ),
                                    );
                                  }).toList(),

                                const SizedBox(height: 6),
                                _dashedLine(),
                                const SizedBox(height: 12),

                                // Totals
                                _kv('Subtotal', _formatRp(totalUnpaid)),
                                const SizedBox(height: 8),
                                Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    const Text(
                                      'Total due',
                                      style: TextStyle(
                                        fontSize: 13,
                                        color: _textDark,
                                        fontWeight: FontWeight.w900,
                                      ),
                                    ),
                                    Text(
                                      _formatRp(totalUnpaid),
                                      style: const TextStyle(
                                        fontSize: 16,
                                        color: _primaryBlue,
                                        fontWeight: FontWeight.w900,
                                      ),
                                    ),
                                  ],
                                ),

                                const SizedBox(height: 10),
                                const Text(
                                  'This bill is generated automatically by WaveUp.',
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: _textMuted,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],

                        const SizedBox(height: 16),

                        Consumer<SubscriptionProvider>(
                          builder: (context, sp, _) {
                            final bool isUnpaid = totalUnpaid > 0;

                            // shimmer ketika belum bayar & (lagi fetch fee atau lagi proses bayar)
                            final bool shimmerButtons =
                                isUnpaid &&
                                (sp.isLoadingTransactionFees ||
                                    sp.isProcessingTransactionFee);

                            final radius = BorderRadius.circular(14);

                            // saat shimmer, semua tombol di-disable biar ga bisa diklik
                            final bool disableButtons =
                                !isUnpaid || shimmerButtons;

                            Widget shimmerOverlay(Color baseColor) {
                              return Positioned.fill(
                                child: IgnorePointer(
                                  child: ClipRRect(
                                    borderRadius: radius,
                                    child: Shimmer.fromColors(
                                      baseColor: baseColor,
                                      highlightColor: const Color(0xFFFFFFFF),
                                      child: Container(color: baseColor),
                                    ),
                                  ),
                                ),
                              );
                            }

                            return Row(
                              children: [
                                Expanded(
                                  child: Stack(
                                    children: [
                                      SizedBox(
                                        height: 46,
                                        width: double.infinity,
                                        child: OutlinedButton(
                                          style: OutlinedButton.styleFrom(
                                            foregroundColor: const Color(
                                              0xFF6B7280,
                                            ),
                                            side: const BorderSide(
                                              color: _border,
                                            ),
                                            padding: const EdgeInsets.symmetric(
                                              vertical: 13,
                                            ),
                                            shape: RoundedRectangleBorder(
                                              borderRadius: radius,
                                            ),
                                          ),
                                          onPressed: disableButtons
                                              ? null
                                              : () =>
                                                    Navigator.of(context).pop(),
                                          child: const Text(
                                            'Not now',
                                            style: TextStyle(
                                              fontWeight: FontWeight.w900,
                                              fontSize: 13,
                                            ),
                                          ),
                                        ),
                                      ),

                                      // shimmer untuk Not now
                                      if (shimmerButtons)
                                        shimmerOverlay(
                                          const Color(0xFFF3F4F6),
                                        ), // skeleton gray
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Stack(
                                    children: [
                                      SizedBox(
                                        height: 46,
                                        width: double.infinity,
                                        child: ElevatedButton(
                                          style: ElevatedButton.styleFrom(
                                            backgroundColor: _primaryBlue,
                                            foregroundColor: Colors.white,
                                            elevation: 0,
                                            padding: const EdgeInsets.symmetric(
                                              vertical: 13,
                                            ),
                                            shape: RoundedRectangleBorder(
                                              borderRadius: radius,
                                            ),
                                          ),
                                          onPressed: disableButtons
                                              ? null
                                              : () async {
                                                  await sp
                                                      .goToTransactionFeePayment(
                                                        context: context,
                                                      );
                                                },
                                          child: const Text(
                                            'Pay now',
                                            style: TextStyle(
                                              fontWeight: FontWeight.w900,
                                              fontSize: 13,
                                            ),
                                          ),
                                        ),
                                      ),

                                      // shimmer untuk Pay now
                                      if (shimmerButtons)
                                        shimmerOverlay(
                                          const Color(0xFFDBEAFE),
                                        ), // skeleton blue-ish
                                    ],
                                  ),
                                ),
                              ],
                            );
                          },
                        ),
                      ],
                    );
                  },
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _Shimmer extends StatefulWidget {
  final Widget child;
  final BorderRadius borderRadius;

  const _Shimmer({required this.child, required this.borderRadius});

  @override
  State<_Shimmer> createState() => _ShimmerState();
}

class _ShimmerState extends State<_Shimmer>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c;

  @override
  void initState() {
    super.initState();
    _c = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1100),
    )..repeat();
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _c,
      builder: (_, __) {
        final t = _c.value; // 0..1
        return ClipRRect(
          borderRadius: widget.borderRadius,
          child: Stack(
            fit: StackFit.passthrough,
            children: [
              widget.child,
              Positioned.fill(
                child: ShaderMask(
                  blendMode: BlendMode.srcATop,
                  shaderCallback: (rect) {
                    return LinearGradient(
                      begin: Alignment(-1.0 - 2.0 * (1 - t), 0),
                      end: Alignment(1.0 + 2.0 * t, 0),
                      colors: const [
                        Color(0x00FFFFFF),
                        Color(0x66FFFFFF),
                        Color(0x00FFFFFF),
                      ],
                      stops: const [0.35, 0.5, 0.65],
                    ).createShader(rect);
                  },
                  child: Container(color: Colors.white),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _ButtonShimmerSkeleton extends StatelessWidget {
  final double height;
  final BorderRadius radius;
  final Color baseColor;

  const _ButtonShimmerSkeleton({
    required this.height,
    required this.radius,
    required this.baseColor,
  });

  @override
  Widget build(BuildContext context) {
    return _Shimmer(
      borderRadius: radius,
      child: Container(
        height: height,
        decoration: BoxDecoration(color: baseColor, borderRadius: radius),
      ),
    );
  }
}

class _InfoBlock extends StatelessWidget {
  final String caption;
  final Widget leading;
  final String title;
  final String subtitle;
  final VoidCallback? onTap; // optional
  final Widget? trailingBadge;

  const _InfoBlock({
    required this.caption,
    required this.leading,
    required this.title,
    required this.subtitle,
    this.onTap,
    this.trailingBadge,
  });

  @override
  Widget build(BuildContext context) {
    final captionColor = const Color(0xFF8A8A8A);
    final titleColor = const Color(0xFF222222);
    final subColor = const Color(0xFF9A9A9A);

    final content = Row(
      children: [
        leading,
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: titleColor,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 2),
              Text(subtitle, style: TextStyle(color: subColor, fontSize: 12)),
            ],
          ),
        ),
        if (onTap != null)
          const Icon(
            Icons.keyboard_arrow_down_rounded,
            size: 12,
            color: Color(0xFF9A9A9A),
          ),
      ],
    );

    // 🔵 Header di atas avatar:
    // - Kalau caption kosong & ada trailingBadge → pakai badge saja (business case)
    // - Kalau tidak, pakai caption + icon info (default)
    Widget headerRow;
    if (trailingBadge != null && caption.isEmpty) {
      headerRow = Align(alignment: Alignment.centerLeft, child: trailingBadge!);
    } else {
      headerRow = Row(
        children: [
          Text(
            caption,
            style: TextStyle(
              color: captionColor,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(width: 6),
          const Icon(LucideIcons.info, size: 14, color: Color(0xFFB0B0B0)),
          if (trailingBadge != null) ...[
            const SizedBox(width: 8),
            trailingBadge!,
          ],
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        headerRow,
        const SizedBox(height: 8),
        if (onTap == null)
          content
        else
          Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: onTap,
              borderRadius: BorderRadius.circular(10),
              child: Padding(
                padding: const EdgeInsets.only(right: 4),
                child: content,
              ),
            ),
          ),
      ],
    );
  }
}

class _GridMenu extends StatelessWidget {
  const _GridMenu();

  Future<void> _showStockLockedModal(BuildContext context) async {
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
                    const SizedBox(height: 8),
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
                            'Premium Stock Management',
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.w800,
                              color: Color(0xFF0F172A),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    const Text(
                      'Get full control over your inventory with real-time stock levels and detailed movement history for every SKU.',
                      style: TextStyle(
                        fontSize: 13,
                        height: 1.4,
                        color: Color(0xFF6B7280),
                      ),
                    ),
                    const SizedBox(height: 18),

                    // 🎠 Carousel poin-poin fitur stock
                    _PremiumFeatureCarousel(
                      items: const [
                        _PremiumFeatureItem(
                          icon: LucideIcons.box,
                          title: 'See live stock per SKU',
                          description:
                              'Monitor current stock for every variant so you always know what is ready to sell.',
                        ),
                        _PremiumFeatureItem(
                          icon: LucideIcons.activity,
                          title: 'Track in & out movement',
                          description:
                              'Understand exactly when stock goes in from purchases and out from sales.',
                        ),
                        _PremiumFeatureItem(
                          icon: LucideIcons.clipboardList,
                          title: 'Clean stock history',
                          description:
                              'Review stock change history per product to investigate issues or corrections.',
                        ),
                        _PremiumFeatureItem(
                          icon: LucideIcons.alertTriangle,
                          title: 'Reduce overselling risk',
                          description:
                              'Avoid selling products you do not have in stock with better visibility.',
                        ),
                      ],
                    ),

                    const SizedBox(height: 22),
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

  Future<void> _showPurchaseLockedModal(BuildContext context) async {
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
                    const SizedBox(height: 8),
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
                            'Premium Purchase Module',
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.w800,
                              color: Color(0xFF0F172A),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    const Text(
                      'Unlock a smarter way to manage purchases from your suppliers and keep your incoming stock perfectly organized.',
                      style: TextStyle(
                        fontSize: 13,
                        height: 1.4,
                        color: Color(0xFF6B7280),
                      ),
                    ),
                    const SizedBox(height: 18),

                    // 🎠 Carousel poin-poin fitur
                    _PremiumFeatureCarousel(
                      items: const [
                        _PremiumFeatureItem(
                          icon: LucideIcons.shoppingBag,
                          title: 'Record every supplier purchase',
                          description:
                              'Create purchase orders and log what you buy from each supplier in one place.',
                        ),
                        _PremiumFeatureItem(
                          icon: LucideIcons.database,
                          title: 'Automatic stock-in',
                          description:
                              'Incoming purchases will automatically increase relevant SKU stock quantities.',
                        ),
                        _PremiumFeatureItem(
                          icon: LucideIcons.history,
                          title: 'Clear incoming stock history',
                          description:
                              'See exactly when and from which purchase each batch of stock arrived.',
                        ),
                        _PremiumFeatureItem(
                          icon: LucideIcons.barChart2,
                          title: 'Better cost visibility',
                          description:
                              'Understand how much you spend per product, per supplier, or per period.',
                        ),
                      ],
                    ),

                    const SizedBox(height: 22),
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

  // ===== Ikon & route mapping (tanpa Store & WA Business)
  static const Map<String, String> _iconByMenuName = {
    'Data User': 'assets/hr_icon.png',
    'Product': 'assets/product_icon.png',
    'Purchase': 'assets/purchase_icon.png',
    'Sale': 'assets/sales_icon.png',
    'Stock': 'assets/stock_icon.png', // ⬅️ NEW
    // (Store & WA Business DIHAPUS)
  };

  static const Map<String, String> _pageToRoute = {
    'employee': '/hr',
    'user': '/hr',
    'role': '/hr',
    'product': '/product',
    'stock': '/stock',
    'product/brand': '/product/brand',
    'product/category': '/product/category',
    'purchase': '/purchase',
    'supplier': '/supplier',
    'sale': '/sales',
    'customer': '/customer',
    'report': '/report',
    // (store/* & waba DIHAPUS)
  };

  // 🚫 Banlist menu / page yang wajib disembunyikan
  static const Set<String> _banNames = {'store', 'wa business', 'waba'};
  static const Set<String> _banPages = {
    'store/location',
    'store/external',
    'waba',
  };

  // ===== helper
  List<String> _pagesFromMenu(dynamic menu) {
    final pages = <String>[];
    final p = (menu.page ?? '').toString().trim();
    if (p.isNotEmpty) pages.add(p);
    final subs = (menu.submenu as List?) ?? const [];
    for (final s in subs) {
      final sp = (s.page ?? '').toString().trim();
      if (sp.isNotEmpty) pages.add(sp);
    }
    return pages;
  }

  String? _primaryRouteForPages(List<String> pages) {
    for (final p in pages) {
      final r = _pageToRoute[p];
      if (r != null && r.isNotEmpty) return r;
    }
    return null;
  }

  /// Pemetaan prioritas urutan target:
  /// product, sales, purchase, report, hr, settings
  int _priorityFor(_MenuItemData it) {
    // Prefer routeName kalau ada
    final r = (it.routeName ?? '').toLowerCase();

    // urutan: product, sales, stock, purchase, report, hr, settings
    if (r == '/product') return 0;
    if (r == '/sales') return 1;
    if (r == '/stock') return 2; // ⬅️ NEW
    if (r == '/purchase') return 3;
    if (r == '/report') return 4;
    if (r == '/hr') return 5;
    if (r == '/setting' || r == '/business') return 6;

    // Kalau routeName null, coba deteksi dari pageKeys
    final pages = it.pageKeys.map((e) => e.toLowerCase()).toList();
    if (pages.contains('product')) return 0;
    if (pages.contains('sale')) return 1;
    if (pages.contains('stock')) return 2; // ⬅️ NEW
    if (pages.contains('purchase')) return 3;
    if (pages.contains('report')) return 4;
    if (pages.contains('employee') ||
        pages.contains('user') ||
        pages.contains('role')) {
      return 5;
    }

    // fallback: taruh di belakang settings
    return 999;
  }

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context)!;
    final role = context.watch<RoleProvider>();

    // Responsif
    final isTablet = MediaQuery.of(context).size.shortestSide >= 600;
    final width = MediaQuery.of(context).size.width;
    final int crossAxisCount = !isTablet ? 3 : (width >= 1200 ? 5 : 4);

    // Loading → shimmer
    if (!role.isReady) {
      return GridView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: crossAxisCount * 2,
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: crossAxisCount,
          mainAxisSpacing: isTablet ? 24 : 19,
          crossAxisSpacing: isTablet ? 28 : 30,
          childAspectRatio: isTablet ? 1.0 : 0.90,
        ),
        itemBuilder: (_, __) => Column(
          children: [
            Container(
              width: 78,
              height: 78,
              decoration: BoxDecoration(
                color: const Color(0xFFF3F4F6),
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            const SizedBox(height: 10),
            Container(
              height: 16,
              width: 64,
              decoration: BoxDecoration(
                color: const Color(0xFFF3F4F6),
                borderRadius: BorderRadius.circular(6),
              ),
            ),
          ],
        ),
      );
    }

    return FutureBuilder<Map<String, dynamic>>(
      future: SharedPreferences.getInstance().then((p) {
        final roleName = (p.getString('activeBizRoleName') ?? '')
            .trim()
            .toLowerCase();
        final isPremiumBiz = (p.getBool('activeBizIsPremium') ?? false);
        return {'roleName': roleName, 'isPremium': isPremiumBiz};
      }),
      builder: (ctx, snap) {
        if (!snap.hasData) return const SizedBox.shrink();

        final data = snap.data!;
        final prefsRoleName = (data['roleName'] as String?) ?? '';
        final bool isBizPremium = (data['isPremium'] as bool?) ?? false;
        debugPrint('isBizPremium: $isBizPremium');

        final providerRoleName = (role.role?.name ?? '').trim().toLowerCase();
        final bool isOwner =
            (prefsRoleName == 'owner') || (providerRoleName == 'owner');

        // ===== OWNER MODE: urutan FIX (Product, Sales, Purchase, Report, HR, Settings)
        if (isOwner) {
          final allItems = <_MenuItemData>[
            // Product
            _MenuItemData(
              t.grid_product,
              'assets/product_icon.png',
              pageKeys: const ['product'],
              routeName: '/product',
              onTap: () => Navigator.pushNamed(context, '/product'),
            ),

            // Sales
            _MenuItemData(
              t.grid_sales,
              'assets/sales_icon.png',
              pageKeys: const ['sale'],
              routeName: '/sales',
              onTap: () => Navigator.pushNamed(context, '/sales'),
            ),

            // ✅ Stock (SETELAH Sales)
            _MenuItemData(
              'Stock',
              'assets/stock_icon.png',
              pageKeys: const ['stock'],
              routeName: '/stock',
              onTap: isBizPremium
                  ? () => Navigator.pushNamed(context, '/stock')
                  : () => _showStockLockedModal(context),
              isPremiumLocked: !isBizPremium,
            ),

            // Purchase
            _MenuItemData(
              t.grid_purchase,
              'assets/purchase_icon.png',
              pageKeys: const ['purchase'],
              routeName: '/purchase',
              onTap: isBizPremium
                  ? () => Navigator.pushNamed(context, '/purchase')
                  : () => _showPurchaseLockedModal(context),
              isPremiumLocked: !isBizPremium,
            ),

            // Report
            _MenuItemData(
              t.grid_report,
              'assets/report_icon.png',
              pageKeys: const ['report'],
              routeName: '/report',
              onTap: () => Navigator.pushNamed(context, '/report'),
            ),

            // HR
            _MenuItemData(
              t.grid_hr,
              'assets/hr_icon.png',
              pageKeys: const ['employee', 'user', 'role'],
              routeName: '/hr',
              onTap: () => Navigator.pushNamed(context, '/hr'),
            ),

            // Settings (owner masih ke /business)
            _MenuItemData(
              t.grid_setting,
              'assets/setting_icon.png',
              routeName: '/business',
              onTap: () => Navigator.pushNamed(context, '/business'),
            ),
          ];

          return GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: allItems.length,
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: crossAxisCount,
              mainAxisSpacing: isTablet ? 24 : 19,
              crossAxisSpacing: isTablet ? 28 : 30,
              childAspectRatio: isTablet ? 1.0 : 0.90,
            ),
            itemBuilder: (_, i) => _MenuTile(data: allItems[i]),
          );
        }

        // ===== NON-OWNER MODE: dari backend + filter izin + banlist → lalu sort ke urutan target
        final menus = role.role?.menus ?? const [];
        final items = <_MenuItemData>[];

        for (final m in menus) {
          final name = (m.name ?? '').toString().trim();
          if (name.isEmpty) continue;

          // Ban by name
          final nameL = name.toLowerCase();
          if (_banNames.contains(nameL)) continue;

          // Pages
          final pages = _pagesFromMenu(m);
          if (pages.any((p) => _banPages.contains(p.toLowerCase()))) continue;

          // Konsolidasi HR
          final isDataUser = nameL == 'data user';
          final hasHrPages = pages.any((p) {
            final lp = p.toLowerCase();
            return lp == 'employee' || lp == 'user' || lp == 'role';
          });
          if (isDataUser || hasHrPages) {
            final alreadyAdded = items.any((it) => it.routeName == '/hr');
            if (!alreadyAdded) {
              items.add(
                _MenuItemData(
                  t.grid_hr,
                  'assets/hr_icon.png',
                  pageKeys: const ['employee', 'user', 'role'],
                  routeName: '/hr',
                  onTap: () => Navigator.pushNamed(context, '/hr'),
                ),
              );
            }
            continue;
          }

          final routeName = _primaryRouteForPages(pages);
          final asset = _iconByMenuName[name] ?? 'assets/product_icon.png';

          final allowByPage = pages.any(role.canPage);
          final allowByRoute = (routeName != null)
              ? role.can(routeName)
              : false;
          if (!allowByPage && !allowByRoute) continue;

          // STOCK: kalau bisnis belum premium → tampil, tapi dikunci
          final hasStockPage = pages.any((p) => p.toLowerCase() == 'stock');
          if (!isBizPremium && hasStockPage) {
            final alreadyAdded = items.any(
              (it) => (it.routeName ?? '').toLowerCase() == '/stock',
            );
            if (!alreadyAdded) {
              items.add(
                _MenuItemData(
                  'Stock',
                  'assets/stock_icon.png',
                  pageKeys: pages,
                  routeName: '/stock',
                  onTap: () => _showStockLockedModal(context),
                  isPremiumLocked: true,
                ),
              );
            }
            continue;
          }

          // PURCHASE: kalau bisnis belum premium → tampil, tapi dikunci
          final hasPurchasePage = pages.any(
            (p) => p.toLowerCase() == 'purchase',
          );
          if (!isBizPremium && hasPurchasePage) {
            final alreadyAdded = items.any(
              (it) => (it.routeName ?? '').toLowerCase() == '/purchase',
            );
            if (!alreadyAdded) {
              items.add(
                _MenuItemData(
                  t.grid_purchase,
                  'assets/purchase_icon.png',
                  pageKeys: pages,
                  routeName: '/purchase',
                  onTap: () => _showPurchaseLockedModal(context),
                  isPremiumLocked: true,
                ),
              );
            }
            continue;
          }

          // default: tile normal
          items.add(
            _MenuItemData(
              name,
              asset,
              pageKeys: pages,
              routeName: routeName,
              onTap: (routeName != null)
                  ? () => Navigator.pushNamed(context, routeName)
                  : null,
            ),
          );
        }

        // Setting publik (non-owner)
        items.add(
          _MenuItemData(
            t.grid_setting,
            'assets/setting_icon.png',
            routeName: '/setting',
            onTap: () => Navigator.pushNamed(context, '/setting'),
          ),
        );

        // ==== SORT ke urutan target (product, sales, purchase, report, hr, settings)
        // agar tidak "lompat-lompat" antar item dengan prioritas sama, pakai indeks awal sebagai tie-breaker
        final indexed = items
            .asMap()
            .entries
            .map((e) => (index: e.key, item: e.value))
            .toList();
        indexed.sort((a, b) {
          final pa = _priorityFor(a.item);
          final pb = _priorityFor(b.item);
          if (pa != pb) return pa.compareTo(pb);
          // tie-break dengan index awal → efeknya mirip stable sort
          return a.index.compareTo(b.index);
        });
        final sortedItems = indexed.map((e) => e.item).toList();

        return GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: sortedItems.length,
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: crossAxisCount,
            mainAxisSpacing: isTablet ? 24 : 19,
            crossAxisSpacing: isTablet ? 28 : 30,
            childAspectRatio: isTablet ? 1.0 : 0.90,
          ),
          itemBuilder: (_, i) => _MenuTile(data: sortedItems[i]),
        );
      },
    );
  }
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

class _PremiumFeatureItem {
  final IconData icon;
  final String title;
  final String description;

  const _PremiumFeatureItem({
    required this.icon,
    required this.title,
    required this.description,
  });
}

class _PremiumFeatureCard extends StatelessWidget {
  final _PremiumFeatureItem item;
  final double scale;
  final double opacity;

  const _PremiumFeatureCard({
    required this.item,
    required this.scale,
    required this.opacity,
  });

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: opacity,
      child: Transform.scale(
        scale: scale,
        child: Container(
          margin: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(24),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.10),
                blurRadius: 18,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(18, 18, 18, 20),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Icon bulat di atas
                Container(
                  width: 52,
                  height: 52,
                  decoration: BoxDecoration(
                    color: const Color(0xFFE0ECFF),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Icon(
                    item.icon,
                    size: 26,
                    color: const Color(0xFF4C6EF5),
                  ),
                ),
                const SizedBox(height: 14),

                // Title
                Text(
                  item.title,
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF111827),
                  ),
                ),
                const SizedBox(height: 8),

                // Description
                Text(
                  item.description,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 12,
                    height: 1.35,
                    color: Color(0xFF4B5563),
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

class _PremiumFeatureCarousel extends StatefulWidget {
  final List<_PremiumFeatureItem> items;

  const _PremiumFeatureCarousel({required this.items});

  @override
  State<_PremiumFeatureCarousel> createState() =>
      _PremiumFeatureCarouselState();
}

class _PremiumFeatureCarouselState extends State<_PremiumFeatureCarousel> {
  late final PageController _controller;
  double _currentPage = 0.0;

  @override
  void initState() {
    super.initState();
    _controller = PageController(viewportFraction: 0.72);
    _controller.addListener(() {
      setState(() {
        _currentPage = _controller.page ?? 0.0;
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    if (widget.items.isEmpty) return const SizedBox.shrink();

    final int currentIndex = _currentPage.round().clamp(
      0,
      widget.items.length - 1,
    );

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          height: 240,
          child: PageView.builder(
            controller: _controller,
            itemCount: widget.items.length,
            physics: const BouncingScrollPhysics(),
            itemBuilder: (context, index) {
              final item = widget.items[index];

              // Hitung jarak dari center page
              final double distance = (index - _currentPage).abs();

              // scale: center = 1.0, samping ≈ 0.88
              final double scale = (1 - (distance * 0.14)).clamp(0.86, 1.0);

              // opacity: center = 1, samping ≈ 0.6
              final double opacity = (1 - (distance * 0.35)).clamp(0.55, 1.0);

              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: _PremiumFeatureCard(
                  item: item,
                  scale: scale,
                  opacity: opacity,
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 12),

        // DOT indicator
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(widget.items.length, (i) {
            final bool active = i == currentIndex;
            return AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              margin: const EdgeInsets.symmetric(horizontal: 3),
              width: active ? 16 : 6,
              height: 6,
              decoration: BoxDecoration(
                color: active
                    ? const Color(0xFF4C6EF5)
                    : const Color(0xFFD1D5DB),
                borderRadius: BorderRadius.circular(99),
              ),
            );
          }),
        ),
        const SizedBox(height: 4),
        const Text(
          'Swipe to see more features',
          style: TextStyle(fontSize: 11, color: Color(0xFF9CA3AF)),
        ),
      ],
    );
  }
}

Future<void> _openNotificationPopup(BuildContext context) async {
  // refresh badge sebelum popup dibuka
  await context.read<NotificationProvider>().fetchUnreadCount(context);

  await showGeneralDialog(
    context: context,
    barrierLabel: 'Notifications',
    barrierDismissible: true,
    barrierColor: Colors.black.withOpacity(0.20),
    transitionDuration: const Duration(milliseconds: 220),
    pageBuilder: (ctx, anim, secondaryAnim) {
      return const SizedBox.shrink();
    },
    transitionBuilder: (ctx, animation, secondaryAnimation, child) {
      final fade = CurvedAnimation(
        parent: animation,
        curve: Curves.easeOutQuad,
      );
      final slide = Tween<Offset>(
        begin: const Offset(0, -0.05),
        end: Offset.zero,
      ).animate(CurvedAnimation(parent: animation, curve: Curves.easeOutCubic));

      final media = MediaQuery.of(ctx);
      // posisi kira-kira tepat di bawah lonceng
      final double topOffset = media.padding.top + 52;

      // LEBAR KARTU DIPERKECIL DI SINI 👇
      // di HP kecil: layar - 32px
      // di layar lebar: fix 320px
      final double cardWidth = media.size.width <= 360
          ? media.size.width - 32
          : 320;

      final double maxHeight = media.size.height * 0.7;

      return FadeTransition(
        opacity: fade,
        child: SlideTransition(
          position: slide,
          child: Stack(
            children: [
              // tap di area gelap untuk menutup
              Positioned.fill(
                child: GestureDetector(
                  behavior: HitTestBehavior.translucent,
                  onTap: () => Navigator.of(ctx).pop(),
                ),
              ),
              Align(
                alignment: Alignment.topRight,
                child: Padding(
                  padding: EdgeInsets.only(
                    top: topOffset,
                    right: 8,
                    left: 8, // sedikit diperkecil juga
                  ),
                  child: ConstrainedBox(
                    constraints: BoxConstraints(
                      maxWidth: cardWidth,
                      maxHeight: maxHeight,
                    ),
                    child: const _NotificationDropdownCard(),
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    },
  );

  // refresh badge lagi setelah popup ditutup
  await context.read<NotificationProvider>().fetchUnreadCount(context);
}

// ===============================
// DROPDOWN NOTIFIKASI DI BAWAH LONCENG
// ===============================

class _NotificationDropdownCard extends StatefulWidget {
  const _NotificationDropdownCard();

  @override
  State<_NotificationDropdownCard> createState() =>
      _NotificationDropdownCardState();
}

class _NotificationDropdownCardState extends State<_NotificationDropdownCard> {
  final ScrollController _scroll = ScrollController();
  bool _pagingBusy = false;

  static const _primaryBlue = Color(0xFF2563EB);

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
    if (pos.pixels > pos.maxScrollExtent - 280) {
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
    final navigator = Navigator.of(context);

    if (!n.isRead) {
      await context.read<NotificationProvider>().markAsRead(
        context,
        n.idNotification,
      );
      await context.read<NotificationProvider>().fetchUnreadCount(context);
    }

    // tutup dropdown dulu
    navigator.pop();

    // lalu buka detail
    await navigator.pushNamed(
      '/notification/detail',
      arguments: n.idNotification,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.18),
              blurRadius: 22,
              offset: const Offset(0, 14),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // HEADER
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(
                children: [
                  Container(
                    width: 28,
                    height: 28,
                    decoration: BoxDecoration(
                      color: const Color(0xFFE0ECFF),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: const Icon(
                      Icons.notifications_rounded,
                      size: 18,
                      color: _primaryBlue,
                    ),
                  ),
                  const SizedBox(width: 10),
                  const Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Notifications',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFF0F172A),
                        ),
                      ),
                      SizedBox(height: 2),
                      Text(
                        'Updates & announcements',
                        style: TextStyle(
                          fontSize: 11,
                          color: Color(0xFF6B7280),
                        ),
                      ),
                    ],
                  ),
                  const Spacer(),
                  Consumer<NotificationProvider>(
                    builder: (_, np, __) {
                      final c = np.unreadCount;
                      final label = c <= 0 ? 'All read' : '$c unread';
                      return Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFFE0ECFF),
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Text(
                          label,
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: _primaryBlue,
                          ),
                        ),
                      );
                    },
                  ),
                  const SizedBox(width: 4),
                  // tombol close kecil
                  InkWell(
                    borderRadius: BorderRadius.circular(999),
                    onTap: () => Navigator.of(context).pop(),
                    child: const Padding(
                      padding: EdgeInsets.all(4),
                      child: Icon(
                        Icons.close_rounded,
                        size: 18,
                        color: Color(0xFF9CA3AF),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const Divider(height: 1, color: Color(0xFFE5E7EB)),

            // LIST (tinggi dinamis: max 3 notifikasi)
            Consumer<NotificationProvider>(
              builder: (_, np, __) {
                if (np.loadingList && np.notifications.isEmpty) {
                  // loading pertama -> tinggi kecil
                  return const SizedBox(
                    height: 120,
                    child: Center(child: CircularProgressIndicator()),
                  );
                }

                if (np.notifications.isEmpty) {
                  // kosong -> tinggi kecil
                  return const SizedBox(height: 160, child: _NotifEmptyState());
                }

                // === Hitung tinggi untuk 3 notifikasi teratas ===
                final total = np.notifications.length;
                final int visibleCount = total >= 3
                    ? 3
                    : total; // min(total, 3)

                const double itemHeightEstimate = 96; // kira-kira tinggi tile
                const double separator = 8;
                const double verticalPadding = 24; // padding list (12+12)

                final double listHeight =
                    visibleCount * itemHeightEstimate +
                    (visibleCount - 1) * separator +
                    verticalPadding;

                return SizedBox(
                  height: listHeight,
                  child: RefreshIndicator(
                    color: AppColors.blue,
                    onRefresh: _onRefresh,
                    child: ListView.separated(
                      controller: _scroll,
                      physics: const AlwaysScrollableScrollPhysics(
                        parent: BouncingScrollPhysics(),
                      ),
                      padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
                      // tetap gunakan seluruh list, tapi tinggi cuma cukup utk 3 item → sisanya di-scroll
                      itemCount: np.notifications.length + 1,
                      separatorBuilder: (_, __) => const SizedBox(height: 8),
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

// ===============================
// SIDEBAR NOTIFIKASI DARI KANAN
// ===============================

class _NotificationSidebar extends StatefulWidget {
  const _NotificationSidebar();

  @override
  State<_NotificationSidebar> createState() => _NotificationSidebarState();
}

class _NotificationSidebarState extends State<_NotificationSidebar> {
  final ScrollController _scroll = ScrollController();
  bool _pagingBusy = false;

  static const _primaryBlue = Color(0xFF2563EB);

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
    if (pos.pixels > pos.maxScrollExtent - 280) {
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
    final navigator = Navigator.of(context);

    if (!n.isRead) {
      await context.read<NotificationProvider>().markAsRead(
        context,
        n.idNotification,
      );
      await context.read<NotificationProvider>().fetchUnreadCount(context);
    }

    navigator.pop(); // tutup sidebar

    await navigator.pushNamed(
      '/notification/detail',
      arguments: n.idNotification,
    );
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final bool isTablet = size.shortestSide >= 600;

    // Lebar panel: Hp hampir full, tablet/desktop lebih kecil
    final double panelWidth = isTablet ? 420 : size.width * 0.92;

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.only(top: 8, bottom: 8, right: 8),
        child: Material(
          color: Colors.transparent,
          child: Container(
            width: panelWidth,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(18),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.14),
                  blurRadius: 20,
                  offset: const Offset(-8, 10),
                ),
              ],
            ),
            child: Column(
              children: [
                // HEADER
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 14,
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 28,
                        height: 28,
                        decoration: BoxDecoration(
                          color: const Color(0xFFE0ECFF),
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: const Icon(
                          Icons.notifications_rounded,
                          size: 18,
                          color: _primaryBlue,
                        ),
                      ),
                      const SizedBox(width: 10),
                      const Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Notifications',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w800,
                              color: Color(0xFF0F172A),
                            ),
                          ),
                          SizedBox(height: 2),
                          Text(
                            'Updates & announcements',
                            style: TextStyle(
                              fontSize: 12,
                              color: Color(0xFF6B7280),
                            ),
                          ),
                        ],
                      ),
                      const Spacer(),
                      Consumer<NotificationProvider>(
                        builder: (_, np, __) {
                          final c = np.unreadCount;
                          final label = c <= 0 ? 'All read' : '$c unread';
                          return Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(0xFFE0ECFF),
                              borderRadius: BorderRadius.circular(999),
                            ),
                            child: Text(
                              label,
                              style: const TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: _primaryBlue,
                              ),
                            ),
                          );
                        },
                      ),
                      const SizedBox(width: 6),
                      InkWell(
                        borderRadius: BorderRadius.circular(999),
                        onTap: () => Navigator.of(context).pop(),
                        child: const Padding(
                          padding: EdgeInsets.all(4),
                          child: Icon(
                            Icons.close_rounded,
                            size: 20,
                            color: Color(0xFF9CA3AF),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const Divider(height: 1, color: Color(0xFFE5E7EB)),

                // LIST
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
                          padding: const EdgeInsets.fromLTRB(12, 12, 12, 16),
                          itemCount: np.notifications.length + 1,
                          separatorBuilder: (_, __) =>
                              const SizedBox(height: 8),
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
                            return _NotifTile(
                              item: n,
                              onTap: () => _handleTap(n),
                            );
                          },
                        ),
                      );
                    },
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

// ===============================
// TILE NOTIFICATION – MODERN BIRU PUTIH
// ===============================

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
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: border, width: 1),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Icon / thumbnail kiri
              Container(
                width: 34,
                height: 34,
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
              const SizedBox(width: 10),

              // TEKS
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Title
                    Text(
                      item.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontWeight: isRead ? FontWeight.w700 : FontWeight.w800,
                        color: titleColor,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 4),

                    // Message (2 baris)
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
                    const SizedBox(height: 8),

                    // Waktu
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

              const SizedBox(width: 6),

              // Kolom kecil kanan: dot unread + chevron
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
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

  // Format waktu relatif: Just now, 1h ago, 4h ago, 05 May 2019
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

// ===============================
// EMPTY STATE – TEMA BIRU PUTIH
// ===============================

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

class _MenuTile extends StatelessWidget {
  final _MenuItemData data;
  const _MenuTile({required this.data});

  @override
  Widget build(BuildContext context) {
    final bool isLocked = data.isPremiumLocked;

    final String route = (data.routeName ?? '').toLowerCase();
    // 💎 Diamond untuk PURCHASE dan STOCK
    final bool hasDiamond = route == '/purchase' || route == '/stock';

    return Column(
      children: [
        SizedBox(
          width: 78,
          height: 78,
          child: Stack(
            clipBehavior: Clip.hardEdge,
            children: [
              InkWell(
                borderRadius: BorderRadius.circular(12),
                onTap: data.onTap, // non-premium: modal, premium: ke route
                child: Opacity(
                  opacity: isLocked ? 0.4 : 1.0,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Image.asset(
                      data.assetPath,
                      fit: BoxFit.contain,
                      errorBuilder: (_, __, ___) {
                        return const Icon(
                          Icons.image_not_supported_outlined,
                          size: 34,
                          color: Color(0xFF4E5D78),
                        );
                      },
                    ),
                  ),
                ),
              ),

              // 💎 DIAMOND SELALU ADA UNTUK PURCHASE & STOCK
              if (hasDiamond)
                Positioned(
                  top: 6,
                  left: 6,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        begin: Alignment.centerLeft,
                        end: Alignment.centerRight,
                        colors: [Color(0xFF6366F1), Color(0xFF22C55E)],
                      ),
                      borderRadius: BorderRadius.circular(999),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.16),
                          blurRadius: 4,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: const Icon(
                      LucideIcons.gem,
                      size: 12,
                      color: Colors.white,
                    ),
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 10),
        Text(
          data.label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            fontWeight: FontWeight.w700,
            fontSize: 16,
            color: isLocked ? const Color(0xFF9CA3AF) : null,
          ),
        ),
      ],
    );
  }
}

class _StatItem {
  final String title;
  final String amount;
  const _StatItem(this.title, this.amount);
}

class _StatCarousel extends StatefulWidget {
  final List<_StatItem> items;
  const _StatCarousel({required this.items});

  @override
  State<_StatCarousel> createState() => _StatCarouselState();
}

class _StatCarouselState extends State<_StatCarousel> {
  late final PageController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = PageController(
      viewportFraction: 0.88,
    ); // sedikit “peek” kartu sebelahnya
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // tinggi diset agar PageView punya ruang; kartu akan menyesuaikan tinggi minimum
        SizedBox(
          height: 100, // aman untuk 2 baris teks + icon
          child: PageView.builder(
            controller: _ctrl,
            itemCount: widget.items.length,
            physics: const BouncingScrollPhysics(),
            padEnds: false,
            itemBuilder: (_, i) {
              final it = widget.items[i];
              return Padding(
                padding: EdgeInsets.only(
                  left: i == 0 ? 20 : 10,
                  right: i == widget.items.length - 1 ? 20 : 10,
                ),
                child: _StatCard(title: it.title, amount: it.amount),
              );
            },
          ),
        ),
        const SizedBox(height: 10),
        // indikator slider sederhana
        SizedBox(
          height: 6,
          child: StatefulBuilder(
            builder: (context, setSB) {
              _ctrl.addListener(() => setSB(() {}));
              final page = _ctrl.hasClients ? _ctrl.page ?? 0.0 : 0.0;
              return Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(widget.items.length, (i) {
                  final active = (page - i).abs() < 0.5;
                  return AnimatedContainer(
                    duration: const Duration(milliseconds: 220),
                    margin: const EdgeInsets.symmetric(horizontal: 4),
                    width: active ? 16 : 6,
                    height: 6,
                    decoration: BoxDecoration(
                      color: active
                          ? const Color(0xFF4E5D78)
                          : const Color(0xFFCBD5E1),
                      borderRadius: BorderRadius.circular(20),
                    ),
                  );
                }),
              );
            },
          ),
        ),
      ],
    );
  }
}

class _StatCard extends StatelessWidget {
  final String title;
  final String amount;

  const _StatCard({required this.title, required this.amount});

  @override
  Widget build(BuildContext context) {
    final displayAmount = _shortenCurrency(amount);

    return Container(
      constraints: const BoxConstraints(minHeight: 72), // lebih ramping
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE0E0E0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 28,
            height: 28,
            decoration: const BoxDecoration(
              color: Color(0xFFEFF4FF),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              LucideIcons.file,
              size: 14,
              color: Color(0xFF4E5D78),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Color(0xFF6B7280),
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  displayAmount,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Color(0xFF16A34A),
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
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

@immutable
class _BusinessInfo {
  final String idBusiness;
  final String name;
  final String username;
  final String logoPath;
  final bool isActive;

  const _BusinessInfo({
    required this.idBusiness,
    required this.name,
    required this.username,
    required this.logoPath,
    this.isActive = false,
  });

  factory _BusinessInfo.fromJson(Map<String, dynamic> j, {String? activeId}) {
    final id = (j['idBusiness'] ?? '').toString();
    return _BusinessInfo(
      idBusiness: id,
      name: (j['name'] ?? '').toString(),
      username: (j['username'] ?? '').toString(),
      logoPath: (j['logoPath'] ?? j['logo'] ?? '').toString(),
      isActive: activeId != null && activeId == id,
    );
  }
}

class _BusinessSwitcherSheet extends StatefulWidget {
  const _BusinessSwitcherSheet();

  @override
  State<_BusinessSwitcherSheet> createState() => _BusinessSwitcherSheetState();
}

class _BusinessSwitcherSheetState extends State<_BusinessSwitcherSheet> {
  late Future<List<_BusinessInfo>> _future;

  @override
  void initState() {
    super.initState();
    _future = _loadBusinesses();
  }

  Future<List<_BusinessInfo>> _loadBusinesses() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString('business');
    final activeId = prefs.getString('activeBizId');
    if (raw == null || raw.isEmpty) return [];

    try {
      final list = (jsonDecode(raw) as List).cast<Map<String, dynamic>>();
      return list
          .map((e) => _BusinessInfo.fromJson(e, activeId: activeId))
          .toList();
    } catch (e) {
      debugPrint('parse business error: $e');
      return [];
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context)!;
    final textColor = const Color(0xFF111827);
    final subColor = const Color(0xFF6B7280);

    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
          top: 12,
          left: 16,
          right: 16,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.only(bottom: 12),
              decoration: BoxDecoration(
                color: const Color(0xFFE5E7EB),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Text(
              t.sheet_switch_business_title,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 12),
            FutureBuilder<List<_BusinessInfo>>(
              future: _future,
              builder: (context, snap) {
                if (!snap.hasData) {
                  return const Padding(
                    padding: EdgeInsets.all(24),
                    child: Center(child: CircularProgressIndicator()),
                  );
                }
                final items = snap.data!;
                if (items.isEmpty) {
                  return Padding(
                    padding: const EdgeInsets.all(24),
                    child: Text(t.sheet_no_business),
                  );
                }

                return Flexible(
                  child: ListView.separated(
                    shrinkWrap: true,
                    itemCount: items.length,
                    separatorBuilder: (_, __) => const Divider(height: 1),
                    itemBuilder: (_, i) {
                      final b = items[i];
                      return ListTile(
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 4,
                        ),
                        leading: CircleAvatar(
                          radius: 18,
                          backgroundColor: const Color(0xFFE9F0FF),
                          child: (b.logoPath.isNotEmpty)
                              ? ClipOval(
                                  child: Image.network(
                                    b.logoPath,
                                    width: 36,
                                    height: 36,
                                    fit: BoxFit.cover,
                                    errorBuilder: (_, __, ___) => Text(
                                      b.name.isNotEmpty
                                          ? b.name[0].toUpperCase()
                                          : '?',
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w700,
                                        color: Colors.blue,
                                      ),
                                    ),
                                  ),
                                )
                              : Text(
                                  b.name.isNotEmpty
                                      ? b.name[0].toUpperCase()
                                      : '?',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w700,
                                    color: Colors.blue,
                                  ),
                                ),
                        ),
                        title: Text(
                          b.name,
                          style: TextStyle(
                            color: textColor,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        subtitle: Text(
                          t.sheet_business_id_label(b.username),
                          style: TextStyle(color: subColor),
                        ),
                        trailing: b.isActive
                            ? const Icon(
                                Icons.check_circle,
                                color: Color(0xFF16A34A),
                              )
                            : const Icon(
                                Icons.radio_button_unchecked,
                                color: Color(0xFFCBD5E1),
                              ),
                        onTap: () async {
                          if (b.isActive) {
                            Navigator.pop(context, false);
                            return;
                          }
                          final ok = await context
                              .read<AuthProvider>()
                              .switchActiveBusinessByUsername(b.username);
                          if (ok && mounted) {
                            Navigator.pop(context, true);
                          }
                        },
                      );
                    },
                  ),
                );
              },
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }
}

class _TrackingReportGate extends StatelessWidget {
  const _TrackingReportGate();

  Future<bool> _hasActiveBusiness() async {
    final prefs = await SharedPreferences.getInstance();
    final id = (prefs.getString('activeBizId') ?? '').trim();
    return id.isNotEmpty;
  }

  Future<String> _getPrefsRoleName() async {
    final prefs = await SharedPreferences.getInstance();
    return (prefs.getString('activeBizRoleName') ?? '').trim().toLowerCase();
  }

  bool _allowByPage(RoleProvider role) {
    if (!role.isReady) return false;
    final canSale = role.canPage('sale');
    final canReport = role.canPage('report');
    return canSale || canReport; // ← pakai OR
    // NOTE: method ini disimpan bila nanti diperlukan
  }

  @override
  Widget build(BuildContext context) {
    return Consumer2<RoleProvider, ReportProviderV2>(
      builder: (context, role, _, __) {
        return FutureBuilder(
          future: Future.wait([_hasActiveBusiness(), _getPrefsRoleName()]),
          builder: (context, snap) {
            if (!snap.hasData) return const SizedBox.shrink();

            final hasActiveBiz = snap.data![0] as bool;
            final prefsRoleName = snap.data![1] as String;
            final canSale = role.canPage('sale');
            final canReport = role.canPage('report');
            final isOwner = prefsRoleName == 'owner';

            if (kDebugMode) {
              debugPrint(
                '[TrackingReportGate] prefsRoleName="$prefsRoleName", '
                'canPage(sale)=$canSale, canPage(report)=$canReport, '
                'hasActiveBiz=$hasActiveBiz',
              );
            }

            // guard utama (pakai OR)
            if (!hasActiveBiz) return const SizedBox.shrink();
            if (!(canSale || canReport || isOwner)) {
              return const SizedBox.shrink();
            }

            // lolos → tampilkan panel
            return const _TrackingReportPanel();
          },
        );
      },
    );
  }
}

class _TrackingReportPanel extends StatelessWidget {
  const _TrackingReportPanel();

  // Ambil lastError secara aman (provider-mu tidak punya properti ini secara eksplisit)
  String? _getLastErrorSafe(ReportProviderV2 rp) {
    try {
      final dyn = rp as dynamic;
      final v = dyn.lastError;
      if (v is String && v.trim().isNotEmpty) return v;
    } catch (_) {
      // provider tidak expose lastError → abaikan
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final bool isTablet = MediaQuery.of(context).size.shortestSide >= 600;
    final l10n = AppLocalizations.of(context)!;

    return Consumer<ReportProviderV2>(
      builder: (context, rp, _) {
        // State dari LAST FETCH (dipastikan _kickDailyFetch() sudah memanggil SALES/CUSTOMER/DAY)
        final isLoading = rp.isLoading;
        final err = _getLastErrorSafe(rp); // aman
        final summary = rp.summary; // nullable
        final items = rp.items;

        // Fallback jika summary null → hitung dari items
        num revenueComputed = 0;
        int qtyComputed = 0;
        int txComputed = 0;

        for (final e in items) {
          revenueComputed += (e.totalRevenue as num);
          qtyComputed += (e.totalQty as int);
          txComputed += (e.totalTransactions as int? ?? 0);
        }

        final num totalRevenue = (summary?.totalRevenue ?? revenueComputed);
        final int totalQty = (summary?.totalQty ?? qtyComputed);
        final int totalTx = (summary?.totalTransactions ?? txComputed);

        final String salesToday = isLoading
            ? '—'
            : _formatRpCompact2Digits(totalRevenue, l10n);

        // Supaya tidak ada kata Inggris "product" di value, value-nya hanya angka.
        final String productsToday = isLoading ? '—' : '$totalQty';

        return Container(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.04),
                blurRadius: 14,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // kiri
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      l10n.trackingReportTitle,
                      style: const TextStyle(
                        color: Color(0xFF374151),
                        fontWeight: FontWeight.w700,
                        fontSize: 16,
                        letterSpacing: 0.2,
                      ),
                    ),
                    const SizedBox(height: 18),

                    Text(
                      l10n.trackingReportSalesToday,
                      style: const TextStyle(
                        color: Color(0xFF6B7280),
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                      ),
                    ),
                    const SizedBox(height: 6),
                    _MetricText.loadingAware(
                      isLoading: isLoading,
                      text: salesToday,
                      color: const Color(0xFF16A34A),
                    ),

                    const SizedBox(height: 18),

                    Text(
                      l10n.trackingReportProductsSoldToday,
                      style: const TextStyle(
                        color: Color(0xFF6B7280),
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                      ),
                    ),
                    const SizedBox(height: 6),
                    _MetricText.loadingAware(
                      isLoading: isLoading,
                      text: productsToday,
                      color: const Color(0xFF16A34A),
                    ),

                    // (Opsional) tampilkan total transaksi harian jika kamu punya slot lain:
                    // const SizedBox(height: 18),
                    // _MetricText.loadingAware(
                    //   isLoading: isLoading,
                    //   text: 'Transactions Today: $totalTx',
                    //   color: Color(0xFF111827),
                    // ),
                    if (!isLoading && err != null) ...[
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          const Icon(
                            Icons.error_outline,
                            size: 16,
                            color: Color(0xFFDC2626),
                          ),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              err,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: Color(0xFFDC2626),
                                fontSize: 12,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),

              const SizedBox(width: 12),

              // kanan (gambar tetap)
              SizedBox(
                width: isTablet ? 180 : 140,
                height: isTablet ? 180 : 140,
                child: Image.asset(
                  'assets/tracking_report_image.png',
                  fit: BoxFit.contain,
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

// Catatan:
// - _MetricText dan _formatRpCompact2Digits diasumsikan sudah didefinisikan di file yang sama
//   atau di-import dari helper lain.
// - ReportProviderV2 dan AppLocalizations sudah diimport di bagian atas.

String _formatRp(num v) {
  final s = v.floor().toString();
  final re = RegExp(r'\B(?=(\d{3})+(?!\d))');
  final withDots = s.replaceAllMapped(re, (m) => '.');
  return 'Rp $withDots';
}

String _formatRpCompact2Digits(num v, AppLocalizations l10n) {
  final n = v is int ? v.toDouble() : v.toDouble();
  if (n < 1_000_000) {
    // < 1 juta masih pakai format penuh
    return _formatRp(n);
  }

  String unit;
  double base;

  if (n < 1_000_000_000) {
    unit = l10n.currencyUnitMillion; // "juta" / "million"
    base = n / 1_000_000;
  } else if (n < 1_000_000_000_000) {
    unit = l10n.currencyUnitBillion; // "miliar" / "billion"
    base = n / 1_000_000_000;
  } else {
    unit = l10n.currencyUnitTrillion; // "triliun" / "trillion"
    base = n / 1_000_000_000_000;
  }

  String head;
  if (base >= 10) {
    head = base.round().toString();
  } else {
    head = base.toStringAsFixed(1);
    if (head.endsWith('.0')) {
      head = head.substring(0, head.length - 2);
    }
  }

  // Kalau nanti mau full multi-currency, bagian "Rp" bisa juga dipindah ke ARB
  return 'Rp $head $unit';
}

class _MetricText extends StatelessWidget {
  final bool isLoading;
  final String text;
  final Color color;

  const _MetricText({
    required this.isLoading,
    required this.text,
    required this.color,
  });

  factory _MetricText.loadingAware({
    required bool isLoading,
    required String text,
    required Color color,
  }) => _MetricText(isLoading: isLoading, text: text, color: color);

  @override
  Widget build(BuildContext context) {
    if (!isLoading) {
      return Text(
        text,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          color: color,
          fontWeight: FontWeight.w800,
          fontSize: 20, // angka diperkecil
        ),
      );
    }
    return Container(
      height: 24,
      width: 160,
      decoration: BoxDecoration(
        color: const Color(0xFFF3F4F6),
        borderRadius: BorderRadius.circular(6),
      ),
    );
  }
}

String _shortenCurrency(String raw) {
  // deteksi prefix "Rp"
  final hasRp = raw.trim().toLowerCase().startsWith('rp');
  // ambil hanya digit
  final digits = raw.replaceAll(RegExp(r'[^0-9]'), '');
  if (digits.isEmpty) return raw;

  final n = double.tryParse(digits) ?? 0;
  String s;
  if (n >= 1e12) {
    s = '${(n / 1e12).toStringAsFixed((n % 1e12 == 0) ? 0 : 2)}T';
  } else if (n >= 1e9) {
    s = '${(n / 1e9).toStringAsFixed((n % 1e9 == 0) ? 0 : 2)}B';
  } else if (n >= 1e6) {
    s = '${(n / 1e6).toStringAsFixed((n % 1e6 == 0) ? 0 : 2)}M';
  } else if (n >= 1e3) {
    s = '${(n / 1e3).toStringAsFixed((n % 1e3 == 0) ? 0 : 1)}K';
  } else {
    s = n.toStringAsFixed(0);
  }

  // hapus trailing .0
  s = s.replaceAll(RegExp(r'\.0(?=[KMBT])'), '');
  return hasRp ? 'Rp. $s' : s;
}
