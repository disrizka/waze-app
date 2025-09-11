// lib/screens/home_screen.dart
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:wa_blast/constants/app_colors.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final green = AppColors.blue;
    final textPrimary = const Color(0xFF1E1E1E);
    final subText = const Color(0xFF7A7A7A);
    final cardBorder = const Color(0xFFE6E6E6);

    const double _cardWidth = 206;

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: EdgeInsets.zero,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // HEADER GRADIENT
              _HeaderGradient(green: green, textPrimary: textPrimary),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 10),
                child: _GridMenu(),
              ),

              const SizedBox(height: 50),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 30),
                child: Text(
                  'Preview Report',
                  style: TextStyle(
                    color: const Color(0xFF4B5563),
                    fontWeight: FontWeight.w700,
                    fontSize: 16,
                    letterSpacing: 0.2,
                  ),
                ),
              ),
              const SizedBox(height: 12),

              // seragam, tidak terlalu panjang/pendek
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
                          width: _cardWidth,
                          child: _StatCard(
                            title: 'Income this day',
                            amount: 'Rp. 200,000',
                          ),
                        );
                      case 1:
                        return const SizedBox(
                          width: _cardWidth,
                          child: _StatCard(
                            title: 'Income this month',
                            amount: 'Rp. 1,200,000,000',
                          ),
                        );
                      default:
                        return const SizedBox(
                          width: _cardWidth,
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
          ),
        ),
      ),
    );
  }
}

class _HeaderGradient extends StatefulWidget {
  final Color green;
  final Color textPrimary;

  const _HeaderGradient({required this.green, required this.textPrimary});

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
        prefs.getString('activeBizLogoPath') ?? ''; // ⬅️ ambil logo

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
                .toString(); // ⬅️ fallback
          }
        } catch (_) {}
      }
    }

    setState(() {
      _accountName = name;
      _accountUsername = accountUsername.isNotEmpty ? accountUsername : '—';
      _businessName = businessName.isNotEmpty ? businessName : '—';
      _businessUsername = businessUsername.isNotEmpty ? businessUsername : '—';
    });
  }

  @override
  Widget build(BuildContext context) {
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
                  SizedBox(
                    width: 36,
                    height: 36, // tinggi slot sama
                    child: Padding(
                      padding: const EdgeInsets.only(
                        top: 2,
                      ), // sedikit turun agar optik sejajar
                      child: Image.asset(
                        'assets/wave_logo_white.png',
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
                      padding: const EdgeInsets.only(
                        top: 2,
                      ), // samakan dengan logo
                      child: InkWell(
                        borderRadius: BorderRadius.circular(18),
                        onTap: () {},
                        child: const Center(
                          // pusatkan di slot 36x36, tapi slot-nya nempel atas
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

            // KARTU MENGAMBANG: menimpa 3/4 tinggi di luar gradient
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
                    // Account User
                    Expanded(
                      child: _InfoBlock(
                        caption: 'Account User',
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
                        subtitle: 'id: $_accountUsername',
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
                        caption: 'Business',
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
                        subtitle: 'id: $_businessUsername',
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),

        // Spacer agar konten di bawah tidak ketimpa kartu
        SizedBox(height: cardHeight * 0.70 + 3),
      ],
    );
  }
}

class _InfoBlock extends StatelessWidget {
  final String caption;
  final Widget leading;
  final String title;
  final String subtitle;

  const _InfoBlock({
    required this.caption,
    required this.leading,
    required this.title,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    final captionColor = const Color(0xFF8A8A8A);
    final titleColor = const Color(0xFF222222);
    final subColor = const Color(0xFF9A9A9A);

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
        Row(
          children: [
            leading,
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
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
                  Text(
                    subtitle,
                    style: TextStyle(color: subColor, fontSize: 12),
                  ),
                ],
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _MenuItemData {
  final String label;
  final String assetPath;
  final VoidCallback? onTap;

  const _MenuItemData(this.label, this.assetPath, {this.onTap});
}

class _GridMenu extends StatelessWidget {
  const _GridMenu();

  @override
  Widget build(BuildContext context) {
    final items = <_MenuItemData>[
      _MenuItemData(
        'HR',
        'assets/hr_icon.png',
        onTap: () {
          Navigator.pushNamed(context, '/hr');
        },
      ),
      _MenuItemData(
        'Product',
        'assets/product_icon.png',
        onTap: () {
          Navigator.pushReplacementNamed(context, '/manage-product');
        },
      ),
      _MenuItemData(
        'Sales',
        'assets/sales_icon.png',
        onTap: () {
          Navigator.of(context).pushNamed('/purchase-stepper');
        },
      ),
      _MenuItemData(
        'Purchase',
        'assets/purchase_icon.png',
        onTap: () {
          Navigator.pushReplacementNamed(context, '/purchase');
        },
      ),
      _MenuItemData(
        'Report',
        'assets/report_icon.png',
        onTap: () {
          print("Report tapped");
        },
      ),
      _MenuItemData(
        'Setting',
        'assets/setting_icon.png',
        onTap: () {
          print("Setting tapped");
        },
      ),
    ];

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: items.length,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        mainAxisSpacing: 19,
        crossAxisSpacing: 30,
        childAspectRatio: 0.90,
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
      padding: const EdgeInsets.symmetric(
        horizontal: 12,
        vertical: 10,
      ), // lebih kecil
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12), // sedikit lebih kecil radius
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
            height: 28, // avatar lebih kecil
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
                    fontSize: 12, // sedikit lebih kecil
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
                    fontSize: 14, // lebih kecil
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
