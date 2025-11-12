// lib/screens/home_screen.dart
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:wa_blast/constants/app_colors.dart';
import 'package:wa_blast/providers/auth_provider.dart';
import 'package:wa_blast/providers/notification_provider.dart';
import 'package:wa_blast/providers/report_provider.dart';
import 'package:wa_blast/providers/role_provider.dart';
import 'package:wa_blast/screens/notification_detail_list.dart';

import '../l10n/app_localizations.dart';

class _MenuItemData {
  final String label;
  final String assetPath;
  final VoidCallback? onTap;

  /// Daftar "page" API yang mewakili tile ini (boleh kosong).
  /// Contoh: tile HR bisa diwakili oleh page 'employee' ATAU 'role'.
  final List<String> pageKeys;

  /// Route utama tile ini (dipakai untuk cek via RoleProvider.can()).
  final String? routeName;

  const _MenuItemData(
    this.label,
    this.assetPath, {
    this.onTap,
    this.pageKeys = const [],
    this.routeName,
  });
}

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  bool _didKickRoleLoad = false;

  final GlobalKey<_HeaderGradientState> _headerKey =
      GlobalKey<_HeaderGradientState>();

  Future<void> _kickDailyFetch() async {
    final rp = context.read<ReportProvider>();

    // Pastikan tab/kind yang dipakai adalah SALES
    rp.setKind(ReportKind.sales, notify: false);

    // Set period = daily khusus untuk SALES
    if (rp.periodOf(ReportKind.sales) != SalesPeriod.daily) {
      rp.setPeriod(SalesPeriod.daily, forKind: ReportKind.sales, notify: false);
    }

    // Fetch endpoint: /report/sales?period=daily
    await rp.fetch(context, kind: ReportKind.sales);
  }

  @override
  void initState() {
    super.initState();
    Future.microtask(() async {
      if (!mounted || _didKickRoleLoad) return;
      _didKickRoleLoad = true;

      await context.read<RoleProvider>().refreshActiveRoleFromPrefs(context);

      // 🔹 di sini kita pastikan report = daily & fetch
      await _kickDailyFetch();
    });
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
            final auth = context.read<AuthProvider>();
            final prefs = await SharedPreferences.getInstance();

            // 1) Kunci active id saat ini
            final lockedId = (prefs.getString('activeBizId') ?? '').trim();

            // 2) Jalankan refresh
            final ok = await auth.refreshCurrentUser(context);

            // 3) Validasi apakah pilihan user berubah “diam-diam”
            String? currentId = (prefs.getString('activeBizId') ?? '').trim();

            if (lockedId.isNotEmpty && lockedId != currentId) {
              // cek apakah lockedId masih valid di daftar business terbaru
              final raw = prefs.getString('business');
              if (raw != null && raw.isNotEmpty) {
                try {
                  final list = (jsonDecode(raw) as List)
                      .cast<Map<String, dynamic>>();
                  final ids = list
                      .map((e) => (e['idBusiness'] ?? '').toString())
                      .where((s) => s.isNotEmpty)
                      .toList();

                  if (ids.contains(lockedId)) {
                    // 4) Paksa balik ke pilihan user
                    await auth.switchActiveBusiness(lockedId);
                    currentId = lockedId; // sinkron
                  }
                } catch (_) {}
              }
            }

            // 5) Update header dari prefs (label/logo)
            await _headerKey.currentState?.reloadFromPrefs();

            if (!mounted) return;
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Row(
                  children: [
                    Icon(
                      ok ? Icons.check_circle_outline : Icons.error_outline,
                      color: Colors.white,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(ok ? t.refresh_success : t.refresh_failed),
                    ),
                  ],
                ),
                backgroundColor: ok
                    ? Colors.green.shade600
                    : Colors.red.shade600,
                behavior: SnackBarBehavior.floating,
                margin: const EdgeInsets.only(top: 16, left: 12, right: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                duration: const Duration(seconds: 2),
              ),
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

  @override
  void initState() {
    super.initState();
    _loadPrefs();
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
      // reload label/logo setelah switch
      await _loadPrefs();
      final rp = context.read<ReportProvider>();
      rp.setKind(ReportKind.sales, notify: false);
      rp.setPeriod(SalesPeriod.daily, forKind: ReportKind.sales, notify: false);
      await rp.fetch(context, kind: ReportKind.sales);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.check_circle_outline, color: Colors.white),
              const SizedBox(width: 12),
              Expanded(child: Text(t.snackbar_business_switch_success)),
            ],
          ),
          backgroundColor: Colors.green.shade600,
          behavior: SnackBarBehavior.floating,
          margin: const EdgeInsets.only(top: 16, left: 12, right: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          duration: const Duration(seconds: 2),
        ),
      );
    }
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
          // Tidak ada activeId atau tidak ketemu di list:
          // → JANGAN fallback ke item pertama (biar tidak "terlihat" pindah).
          // Tetap coba pakai cache 'activeBiz*' kalau ada, else tampilkan '—'.
          businessName = prefs.getString('activeBizName') ?? '';
          businessUsername = prefs.getString('activeBizUsername') ?? '';
          businessLogoPath = prefs.getString('activeBizLogoPath') ?? '';
        }
      } catch (_) {
        // JSON rusak → pakai cache 'activeBiz*' sebisanya
        businessName = prefs.getString('activeBizName') ?? '';
        businessUsername = prefs.getString('activeBizUsername') ?? '';
        businessLogoPath = prefs.getString('activeBizLogoPath') ?? '';
      }
    } else {
      // Tidak ada daftar business tersimpan → pakai cache 'activeBiz*' sebisanya
      businessName = prefs.getString('activeBizName') ?? '';
      businessUsername = prefs.getString('activeBizUsername') ?? '';
      businessLogoPath = prefs.getString('activeBizLogoPath') ?? '';
    }

    _photoPath = prefs.getString('photoPath') ?? '';
    _businessLogoPath = businessLogoPath;

    if (!mounted) return;
    setState(() {
      _accountName = name;
      _accountUsername = accountUsername.isNotEmpty ? accountUsername : '—';
      _businessName = businessName.isNotEmpty ? businessName : '—';
      _businessUsername = businessUsername.isNotEmpty ? businessUsername : '—';
    });
  }

  Future<void> _openNotificationPopup(BuildContext context) async {
    await context.read<NotificationProvider>().fetchUnreadCount(context);
    // ignore: use_build_context_synchronously
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (_) => const _NotificationPopupSheet(),
    );
    // ignore: use_build_context_synchronously
    await context.read<NotificationProvider>().fetchUnreadCount(context);
  }

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context)!;

    // ukuran & posisi agar menimpa 3/4 dari gradient
    const double headerHeight = 150; // tinggi area gradient
    const double cardHeight = 96; // tinggi kartu
    final double overlapTop =
        headerHeight - cardHeight * 0.79; // 1/4 di dalam gradient, 3/4 di luar

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
                crossAxisAlignment:
                    CrossAxisAlignment.start, // tetap start (nempel atas)
                children: [
                  // LOGO
                  const SizedBox(
                    width: 36,
                    height: 36, // tinggi slot sama
                    child: Padding(
                      padding: EdgeInsets.only(top: 2), // optik
                      child: Image(
                        image: AssetImage('assets/wave_logo_white.png'),
                        fit: BoxFit.contain,
                      ),
                    ),
                  ),

                  const Spacer(),

                  SizedBox(
                    width: 36,
                    height: 36,
                    child: Padding(
                      padding: const EdgeInsets.only(top: 2),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(18),
                        onTap: () => _openNotificationPopup(
                          context,
                        ), // buka popup list (sudah kamu tambah)
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
                                  if (c <= 0) return const SizedBox.shrink();
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

            // KARTU MENGAMBANG
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
                                      // fallback ke inisial user
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

                    // Business
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

        // Spacer agar konten di bawah tidak ketimpa kartu
        const SizedBox(height: cardHeight * 0.70 + 3),
      ],
    );
  }
}

String _shortId(String raw) {
  if (raw.isEmpty) return '';
  // ambil 9 karakter pertama, lalu tambahkan "..."
  final short = raw.length > 9 ? raw.substring(0, 9) : raw;
  return '$short...';
}

class _InfoBlock extends StatelessWidget {
  final String caption;
  final Widget leading;
  final String title;
  final String subtitle;
  final VoidCallback? onTap; // optional

  const _InfoBlock({
    required this.caption,
    required this.leading,
    required this.title,
    required this.subtitle,
    this.onTap,
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

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
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
          ],
        ),
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
                padding: const EdgeInsets.only(right: 4), // ruang untuk chevron
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

  // ===== Ikon & route mapping (tanpa Store & WA Business)
  static const Map<String, String> _iconByMenuName = {
    'Data User': 'assets/hr_icon.png',
    'Product': 'assets/product_icon.png',
    'Purchase': 'assets/purchase_icon.png',
    'Sale': 'assets/sales_icon.png',
    // (Store & WA Business DIHAPUS)
  };

  static const Map<String, String> _pageToRoute = {
    'employee': '/hr',
    'user': '/hr',
    'role': '/hr',
    'product': '/product',
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

    // Settings bisa /setting (non-owner) atau /business (owner)
    if (r == '/product') return 0;
    if (r == '/sales') return 1;
    if (r == '/purchase') return 2;
    if (r == '/report') return 3;
    if (r == '/hr') return 4;
    if (r == '/setting' || r == '/business') return 5;

    // Kalau routeName null, coba deteksi dari pageKeys
    final pages = it.pageKeys.map((e) => e.toLowerCase()).toList();
    if (pages.contains('product')) return 0;
    if (pages.contains('sale')) return 1;
    if (pages.contains('purchase')) return 2;
    if (pages.contains('report')) return 3;
    if (pages.contains('employee') ||
        pages.contains('user') ||
        pages.contains('role')) {
      return 4;
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

    return FutureBuilder<String?>(
      future: SharedPreferences.getInstance().then(
        (p) => p.getString('activeBizRoleName'),
      ),
      builder: (ctx, snap) {
        final prefsRoleName = (snap.data ?? '').trim().toLowerCase();
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
            // Purchase
            _MenuItemData(
              t.grid_purchase,
              'assets/purchase_icon.png',
              pageKeys: const ['purchase'],
              routeName: '/purchase',
              onTap: () => Navigator.pushNamed(context, '/purchase'),
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
            // Settings (owner masih ke /business sesuai implementasi awal)
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

// ===============================
// POPUP LIST NOTIFIKASI (bottom sheet)
// ===============================

class _NotificationPopupSheet extends StatefulWidget {
  const _NotificationPopupSheet();

  @override
  State<_NotificationPopupSheet> createState() =>
      _NotificationPopupSheetState();
}

class _NotificationPopupSheetState extends State<_NotificationPopupSheet> {
  final ScrollController _scroll = ScrollController();
  bool _pagingBusy = false;

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
    // Ambil navigator SEKALI, supaya tidak bergantung ke context setelah pop
    final navigator = Navigator.of(context);

    // 1) Tandai read (masih aman pakai context karena sheet belum ditutup)
    if (!n.isRead) {
      await context.read<NotificationProvider>().markAsRead(
        context,
        n.idNotification,
      );
      // update badge sementara sheet masih hidup
      await context.read<NotificationProvider>().fetchUnreadCount(context);
    }

    // 2) Tutup bottom sheet
    navigator.pop();

    // 3) Buka halaman detail memakai navigator yg sudah dicapture
    await navigator.pushNamed(
      '/notification/detail',
      arguments: n.idNotification,
    );

    // 4) JANGAN panggil apa pun yang butuh `context` sheet di sini.
    //    Sheet sudah ditutup → state unmounted. Refresh badge/list
    //    sudah dihandle oleh _HeaderGradient._openNotificationPopup()
    //    setelah modal ditutup.
  }

  @override
  Widget build(BuildContext context) {
    final radius = const Radius.circular(16);
    return SafeArea(
      top: false,
      child: DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.88,
        minChildSize: 0.40,
        maxChildSize: 0.95,
        builder: (ctx, controller) {
          return ClipRRect(
            borderRadius: BorderRadius.vertical(top: radius),
            child: Material(
              color: Colors.white,
              child: Column(
                children: [
                  const SizedBox(height: 8),
                  Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: const Color(0xFFE5E7EB),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  const SizedBox(height: 8),

                  // HEADER
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Row(
                      children: [
                        const Text(
                          'Notifications',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const Spacer(),
                        Consumer<NotificationProvider>(
                          builder: (_, np, __) {
                            final c = np.unreadCount;
                            return Text(
                              '$c unread',
                              style: const TextStyle(
                                color: Color(0xFF6B7280),
                                fontWeight: FontWeight.w700,
                              ),
                            );
                          },
                        ),
                        const SizedBox(width: 8),
                      ],
                    ),
                  ),
                  const SizedBox(height: 6),
                  const Divider(height: 1),

                  // LIST
                  Expanded(
                    child: Consumer<NotificationProvider>(
                      builder: (_, np, __) {
                        if (np.loadingList && np.notifications.isEmpty) {
                          return const Center(
                            child: CircularProgressIndicator(),
                          );
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
                            padding: const EdgeInsets.fromLTRB(8, 10, 8, 16),
                            itemCount: np.notifications.length + 1,
                            separatorBuilder: (_, __) =>
                                const SizedBox(height: 6),
                            itemBuilder: (_, i) {
                              if (i == np.notifications.length) {
                                final show =
                                    np.page != null &&
                                    (np.page!.currentPage <
                                        np.page!.totalPages);
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

                              // UI tile lebih simple, tidak ada tombol Mark read
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

                  // NOTE: Footer "Mark all as read" DIHAPUS sesuai permintaan
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

class _NotifTile extends StatelessWidget {
  final NotificationItem item;
  final VoidCallback onTap;

  const _NotifTile({required this.item, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final isRead = item.isRead;

    // Warna simpel & clean
    final bg = isRead
        ? Colors.white
        : const Color(0xFFF5FAFF); // subtle biru utk unread
    final border = isRead ? const Color(0xFFE5E7EB) : const Color(0xFFDDEAFE);
    final titleColor = isRead
        ? const Color(0xFF1F2937)
        : const Color(0xFF0F172A);
    final msgColor = isRead ? const Color(0xFF6B7280) : const Color(0xFF374151);

    return Material(
      color: bg,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: border, width: 1),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Indikator bulat untuk status unread
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: isRead
                        ? const Color(0xFFCBD5E1)
                        : const Color(0xFF2563EB),
                    shape: BoxShape.circle,
                  ),
                ),
              ),
              const SizedBox(width: 10),

              // Thumbnail / icon (opsional)
              ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: (item.imageUrl != null && item.imageUrl!.isNotEmpty)
                    ? Image.network(
                        item.imageUrl!,
                        width: 32,
                        height: 32,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => _thumbFallback(),
                      )
                    : _thumbFallback(),
              ),
              const SizedBox(width: 10),

              // Teks
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Judul (1 baris, tegas)
                    Text(
                      item.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontWeight: isRead ? FontWeight.w700 : FontWeight.w800,
                        color: titleColor,
                      ),
                    ),
                    const SizedBox(height: 4),

                    // Deskripsi (2 baris)
                    Text(
                      item.message,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(color: msgColor, height: 1.25),
                    ),
                    const SizedBox(height: 8),

                    // Waktu (kecil & abu-abu)
                    Text(
                      _fmtTimeAgo(item),
                      style: const TextStyle(
                        color: Color(0xFF9CA3AF),
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(width: 6),

              // Chevron kecil sebagai affordance "tap untuk detail"
              const Icon(
                Icons.chevron_right_rounded,
                size: 18,
                color: Color(0xFF94A3B8),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _thumbFallback() => Container(
    width: 32,
    height: 32,
    decoration: BoxDecoration(
      color: const Color(0xFFF3F4F6),
      borderRadius: BorderRadius.circular(6),
    ),
    child: const Icon(Icons.notifications, size: 18, color: Color(0xFF9CA3AF)),
  );

  // Format waktu relatif: Now, 1h ago, 4h ago, 05 May 2019
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
// EMPTY STATE untuk list notifikasi
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
            Icon(
              Icons.notifications_off_outlined,
              size: 48,
              color: Color(0xFF9CA3AF),
            ),
            SizedBox(height: 10),
            Text(
              'No notifications',
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
    return Column(
      children: [
        InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: data.onTap,
          child: SizedBox(
            width: 78,
            height: 78,
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
        const SizedBox(height: 10),
        Text(
          data.label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
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
                              .switchActiveBusiness(b.idBusiness);
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
  }

  @override
  Widget build(BuildContext context) {
    return Consumer2<RoleProvider, ReportProvider>(
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

  @override
  Widget build(BuildContext context) {
    final bool isTablet = MediaQuery.of(context).size.shortestSide >= 600;

    return Consumer<ReportProvider>(
      builder: (context, rp, _) {
        // BACA STATE PER-KIND: SALES
        const kind = ReportKind.sales;
        final isLoading = rp.isLoadingOf(kind);
        final summary = rp.summaryOf(kind);
        final err = rp.lastErrorOf(kind);

        // Jika summary belum ada, fallback hitung dari items
        final items = rp.itemsOf(kind);
        final num revenueComputed = items.fold<num>(
          0,
          (acc, e) => acc + e.totalRevenue,
        );
        final int qtyComputed = items.fold<int>(
          0,
          (acc, e) => acc + e.totalQty,
        );

        final String salesToday = isLoading
            ? '—'
            : _formatRpCompact2Digits(
                (summary?.totalRevenue ?? revenueComputed),
              );

        final String productsToday = isLoading
            ? '—'
            : '${summary?.totalQty ?? qtyComputed} product';

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
                    const Text(
                      'Tracking Report',
                      style: TextStyle(
                        color: Color(0xFF374151),
                        fontWeight: FontWeight.w700,
                        fontSize: 16,
                        letterSpacing: 0.2,
                      ),
                    ),
                    const SizedBox(height: 18),

                    const Text(
                      'Sales Today',
                      style: TextStyle(
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

                    const Text(
                      'Products Sold Today',
                      style: TextStyle(
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

              // kanan
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

String _formatRp(num v) {
  final s = v.floor().toString();
  final re = RegExp(r'\B(?=(\d{3})+(?!\d))');
  final withDots = s.replaceAllMapped(re, (m) => '.');
  return 'Rp $withDots';
}

String _formatRpCompact2Digits(num v) {
  final n = v is int ? v.toDouble() : (v.toDouble());
  if (n < 1_000_000) return _formatRp(n);

  String unit;
  double base;
  if (n < 1_000_000_000) {
    unit = 'juta';
    base = n / 1_000_000;
  } else if (n < 1_000_000_000_000) {
    unit = 'miliar';
    base = n / 1_000_000_000;
  } else {
    unit = 'triliun';
    base = n / 1_000_000_000_000;
  }

  String head;
  if (base >= 10) {
    head = base.round().toString();
  } else {
    head = base.toStringAsFixed(1);
    if (head.endsWith('.0')) head = head.substring(0, head.length - 2);
  }
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
    s = (n / 1e12).toStringAsFixed((n % 1e12 == 0) ? 0 : 2) + 'T';
  } else if (n >= 1e9) {
    s = (n / 1e9).toStringAsFixed((n % 1e9 == 0) ? 0 : 2) + 'B';
  } else if (n >= 1e6) {
    s = (n / 1e6).toStringAsFixed((n % 1e6 == 0) ? 0 : 2) + 'M';
  } else if (n >= 1e3) {
    s = (n / 1e3).toStringAsFixed((n % 1e3 == 0) ? 0 : 1) + 'K';
  } else {
    s = n.toStringAsFixed(0);
  }

  // hapus trailing .0
  s = s.replaceAll(RegExp(r'\.0(?=[KMBT])'), '');
  return hasRp ? 'Rp. $s' : s;
}
