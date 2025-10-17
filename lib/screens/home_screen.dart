// lib/screens/home_screen.dart
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:wa_blast/constants/app_colors.dart';
import 'package:wa_blast/providers/auth_provider.dart';
import 'package:wa_blast/providers/role_provider.dart';

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

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    // Key untuk me-reload header setelah refresh
    final headerKey = GlobalKey<_HeaderGradientState>();

    final green = AppColors.blue;
    final textPrimary = const Color(0xFF1E1E1E);
    const double _cardWidth = 206;

    final t = AppLocalizations.of(context)!;

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        // Bungkus dengan RefreshIndicator
        child: RefreshIndicator(
          color: AppColors.blue,
          onRefresh: () async {
            final auth = context.read<AuthProvider>();
            final ok = await auth.refreshCurrentUser(context);

            // Reload header dari prefs agar label/logo ikut update
            await headerKey.currentState?.reloadFromPrefs();

            if (context.mounted) {
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
            }
          },
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(
              parent: BouncingScrollPhysics(),
            ),
            padding: EdgeInsets.zero,
            child: Builder(
              builder: (context) {
                // iPad/tablet jika shortestSide >= 600
                final bool isTablet =
                    MediaQuery.of(context).size.shortestSide >= 600;

                // ======= iPhone (TETAP seperti semula) =======
                final Widget phoneBody = Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _HeaderGradient(
                      key: headerKey,
                      green: green,
                      textPrimary: textPrimary,
                    ),
                    const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 10),
                      child: _GridMenu(), // versi grid default (3 kolom)
                    ),
                    const SizedBox(height: 50),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 30),
                      child: Text(
                        t.previewReport_title,
                        style: const TextStyle(
                          color: Color(0xFF4B5563),
                          fontWeight: FontWeight.w700,
                          fontSize: 16,
                          letterSpacing: 0.2,
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),

                    // Kartu statistik horizontal (seperti semula)
                    SizedBox(
                      height: 86,
                      child: ListView.separated(
                        scrollDirection: Axis.horizontal,
                        padding: const EdgeInsets.symmetric(horizontal: 30),
                        physics: const BouncingScrollPhysics(),
                        itemCount: 3,
                        separatorBuilder: (_, __) => const SizedBox(width: 12),
                        itemBuilder: (_, i) {
                          switch (i) {
                            case 0:
                              return const SizedBox(
                                width: 206,
                                child: _StatCard(
                                  title: 'Income this day',
                                  amount: 'Rp. 200,000',
                                ),
                              );
                            case 1:
                              return const SizedBox(
                                width: 206,
                                child: _StatCard(
                                  title: 'Income this month',
                                  amount: 'Rp. 1,200,000,000',
                                ),
                              );
                            default:
                              return const SizedBox(
                                width: 206,
                                child: _StatCard(
                                  title: 'Income this year',
                                  amount: 'Rp. 14,500,000,000',
                                ),
                              );
                          }
                        },
                      ),
                    ),

                    const SizedBox(height: 24),
                  ],
                );

                if (!isTablet) return phoneBody;

                // ======= iPad (RESPONSIF) =======
                // - Konten dipusatkan & dibatasi lebarnya agar proporsional
                // - Grid otomatis 4–5 kolom (lihat _GridMenu di bawah)
                // - Stat cards ditampilkan dalam 1 baris (3 kolom) tanpa scroll
                return Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 1024),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _HeaderGradient(
                          key: headerKey,
                          green: green,
                          textPrimary: textPrimary,
                        ),
                        const Padding(
                          padding: EdgeInsets.symmetric(horizontal: 24),
                          child: _GridMenu(), // grid akan adaptif (4–5 kolom)
                        ),
                        const SizedBox(height: 64),

                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 24),
                          child: Text(
                            t.previewReport_title,
                            style: const TextStyle(
                              color: Color(0xFF4B5563),
                              fontWeight: FontWeight.w700,
                              fontSize: 18,
                              letterSpacing: 0.2,
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),

                        // Stat cards versi iPad: 3 kolom dalam satu baris (tanpa scroll)
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 24),
                          child: Row(
                            children: const [
                              Expanded(
                                child: _StatCard(
                                  title: 'Income this day',
                                  amount: 'Rp. 200,000',
                                ),
                              ),
                              SizedBox(width: 12),
                              Expanded(
                                child: _StatCard(
                                  title: 'Income this month',
                                  amount: 'Rp. 1,200,000,000',
                                ),
                              ),
                              SizedBox(width: 12),
                              Expanded(
                                child: _StatCard(
                                  title: 'Income this year',
                                  amount: 'Rp. 14,500,000,000',
                                ),
                              ),
                            ],
                          ),
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

    String businessName = prefs.getString('activeBizName') ?? '';
    String businessUsername = prefs.getString('activeBizUsername') ?? '';
    _photoPath = prefs.getString('photoPath') ?? '';
    _businessLogoPath =
        prefs.getString('activeBizLogoPath') ?? ''; // ambil logo

    if (businessName.isEmpty || businessUsername.isEmpty) {
      final businessJson = prefs.getString('business');
      if (businessJson != null && businessJson.isNotEmpty) {
        try {
          final decoded = jsonDecode(businessJson);
          if (decoded is List && decoded.isNotEmpty) {
            final first = Map<String, dynamic>.from(decoded.first as Map);
            businessName =
                (first['name'] ??
                        first['business_name'] ??
                        first['businessName'] ??
                        '')
                    .toString();
            businessUsername =
                (first['username'] ??
                        first['business_username'] ??
                        first['code'] ??
                        '')
                    .toString();
            _businessLogoPath = (first['logoPath'] ?? first['logo'] ?? '')
                .toString(); // fallback
          }
        } catch (_) {}
      }
    }

    if (!mounted) return;
    setState(() {
      _accountName = name;
      _accountUsername = accountUsername.isNotEmpty ? accountUsername : '—';
      _businessName = businessName.isNotEmpty ? businessName : '—';
      _businessUsername = businessUsername.isNotEmpty ? businessUsername : '—';
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

                  // BELL (tanpa IconButton bawaan supaya tidak ada padding internal)
                  SizedBox(
                    width: 36,
                    height: 36, // sama dengan logo
                    child: Padding(
                      padding: const EdgeInsets.only(top: 2),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(18),
                        onTap: () {},
                        child: const Center(
                          child: Icon(
                            LucideIcons.bell,
                            color: Colors.white,
                            size: 22,
                          ),
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
                        subtitle: '@$_accountUsername',
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
            size: 18,
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

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context)!;
    final role = context.watch<RoleProvider>();

    // (items) tetap sama persis seperti punyamu...
    final allItems = <_MenuItemData>[
      _MenuItemData(
        t.grid_hr,
        'assets/hr_icon.png',
        onTap: () => Navigator.pushNamed(context, '/hr'),
        pageKeys: const ['employee', 'role'],
        routeName: '/hr',
      ),
      _MenuItemData(
        t.grid_product,
        'assets/product_icon.png',
        onTap: () => Navigator.pushNamed(context, '/product'),
        pageKeys: const ['product'],
        routeName: '/product',
      ),
      _MenuItemData(
        t.grid_sales,
        'assets/sales_icon.png',
        onTap: () => Navigator.pushNamed(context, '/sales'),
        pageKeys: const ['sale'],
        routeName: '/sales',
      ),
      _MenuItemData(
        t.grid_purchase,
        'assets/purchase_icon.png',
        onTap: () => Navigator.pushNamed(context, '/purchase'),
        pageKeys: const ['purchase'],
        routeName: '/purchase',
      ),
      _MenuItemData(
        t.grid_report,
        'assets/report_icon.png',
        onTap: () => Navigator.pushNamed(context, '/report'),
        pageKeys: const ['report'],
        routeName: '/report',
      ),
      _MenuItemData(
        t.grid_setting,
        'assets/setting_icon.png',
        onTap: () => debugPrint("Setting tapped"),
        pageKeys: const [],
        routeName: null,
      ),
    ];

    final items = role.isReady
        ? allItems.where((it) {
            final allowByPage = it.pageKeys.any(role.canPage);
            final allowByRoute = (it.routeName != null)
                ? role.can(it.routeName!)
                : false;
            final isPublic = it.pageKeys.isEmpty && (it.routeName == null);
            return isPublic || allowByPage || allowByRoute;
          }).toList()
        : allItems;

    // RESPONSIF: iPhone tetap 3 kolom; iPad 4–5 kolom tergantung lebar
    final isTablet = MediaQuery.of(context).size.shortestSide >= 600;
    final width = MediaQuery.of(context).size.width;
    final int crossAxisCount = !isTablet
        ? 3
        : (width >= 1200 ? 5 : 4); // iPad besar = 5 kolom, iPad reguler = 4

    final double spacing = isTablet ? 28 : 30; // rasa iPad sedikit lebih rapat

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: items.length,
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: crossAxisCount,
        mainAxisSpacing: isTablet ? 24 : 19,
        crossAxisSpacing: spacing,
        childAspectRatio: isTablet ? 1.0 : 0.90, // iPad tile lebih kotak
      ),
      itemBuilder: (_, i) => _MenuTile(data: items[i]),
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
