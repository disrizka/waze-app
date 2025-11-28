import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:wa_blast/l10n/app_localizations.dart';

/// ============
/// COLOR STYLE
/// ============
class RegisterColors {
  static const Color blue = Color(0xFF4069E6);
  static const Color textDark = Color(0xFF0F172A);
  static const Color subText = Color(0xFF475569);
  static const Color mint = Color(0xFF00C389);
}

/// Halaman Welcome register yang menarik, proporsional, dan rata kiri.
/// - Tanpa AppBar bawaan (agar dekor bulat nyambung sampai tepi atas)
/// - Tombol back custom mengambang di kiri atas (ke /login)
/// - Logo kecil + judul + deskripsi di atas (rata kiri)
/// - Tombol panah di pojok kanan bawah
/// - Background dengan dekorasi lembut
class RegisterWelcomeStep extends StatelessWidget {
  const RegisterWelcomeStep({super.key, required this.onNext});

  final VoidCallback onNext;

  @override
  Widget build(BuildContext context) {
    final mq = MediaQuery.of(context);
    final w = mq.size.width;
    final isNarrow = w < 380;
    const contentMax = 560.0;

    final l10n = AppLocalizations.of(context)!;

    return Scaffold(
      backgroundColor: Colors.white,
      body: Stack(
        children: [
          // ===== Background lembut (nyambung ke atas layar) =====
          const _DecorBackground(),

          // ===== Konten utama =====
          Align(
            alignment: Alignment.topCenter,
            child: SafeArea(
              bottom: false,
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 720),
                child: Padding(
                  padding: EdgeInsets.fromLTRB(24, isNarrow ? 8 : 16, 24, 24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SizedBox(height: isNarrow ? 30 : 70),

                      // ===== Wordmark: logo + WaveUp =====
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Image.asset(
                            'assets/wave_up_logo_2.png',
                            height: isNarrow ? 26 : 30,
                            fit: BoxFit.contain,
                            errorBuilder: (_, __, ___) => const Icon(
                              Icons.waves,
                              size: 28,
                              color: RegisterColors.mint,
                            ),
                          ),
                        ],
                      ),

                      SizedBox(height: isNarrow ? 20 : 30),

                      // ===== Headline =====
                      ConstrainedBox(
                        constraints: const BoxConstraints.tightFor(
                          width: double.infinity,
                        ),
                        child: Text(
                          l10n.register_welcome_title,
                          textAlign: TextAlign.left,
                          style: const TextStyle(
                            fontSize: 28,
                            fontWeight: FontWeight.w800,
                            color: RegisterColors.blue,
                            height: 1.15,
                          ),
                        ),
                      ),

                      const SizedBox(height: 10),

                      // ===== Deskripsi =====
                      ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: contentMax),
                        child: Text(
                          l10n.register_welcome_description,
                          textAlign: TextAlign.left,
                          style: const TextStyle(
                            fontSize: 14.5,
                            height: 1.6,
                            color: RegisterColors.subText,
                          ),
                        ),
                      ),

                      SizedBox(height: isNarrow ? 22 : 28),

                      // ===== Hint Card (opsional) =====
                      _HintCard(
                        title: l10n.register_welcome_hint_title,
                        points: [
                          l10n.register_welcome_hint_point1,
                          l10n.register_welcome_hint_point2,
                          l10n.register_welcome_hint_point3,
                        ],
                      ),

                      const Spacer(),
                      const SizedBox(height: 80),
                    ],
                  ),
                ),
              ),
            ),
          ),

          // ===== Tombol back custom (glass button) =====
          Positioned(
            left: 12,
            top: mq.padding.top + 10,
            child: Container(
              margin: const EdgeInsets.only(bottom: 30),
              child: _GlassIconButton(
                tooltip: l10n.register_welcome_back_tooltip,
                icon: Icons.arrow_back_ios_new_rounded,
                onTap: () => Navigator.of(
                  context,
                ).popUntil((route) => route.settings.name == '/login'),
              ),
            ),
          ),

          // ===== Tombol panah lanjut =====
          Align(
            alignment: Alignment.bottomRight,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 28),
              child: _PulseFab(
                onTap: onNext,
                icon: Icons.arrow_forward_rounded,
                background: RegisterColors.blue,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// ===== Tombol icon kaca (glassmorphism) =====
class _GlassIconButton extends StatelessWidget {
  const _GlassIconButton({
    required this.icon,
    required this.onTap,
    this.tooltip,
  });

  final IconData icon;
  final VoidCallback onTap;
  final String? tooltip;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip ?? '',
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
          child: Material(
            color: Colors.white.withOpacity(0.35),
            child: InkWell(
              onTap: onTap,
              child: const SizedBox(
                width: 44,
                height: 44,
                child: Icon(
                  Icons.arrow_back_ios_new_rounded,
                  size: 20,
                  color: RegisterColors.textDark,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// ===== FAB animasi kecil =====
class _PulseFab extends StatefulWidget {
  const _PulseFab({
    required this.onTap,
    required this.icon,
    required this.background,
  });

  final VoidCallback onTap;
  final IconData icon;
  final Color background;

  @override
  State<_PulseFab> createState() => _PulseFabState();
}

class _PulseFabState extends State<_PulseFab>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 120),
    lowerBound: .96,
    upperBound: 1.0,
  )..value = 1.0;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ScaleTransition(
      scale: _controller,
      child: SizedBox(
        width: 60,
        height: 60,
        child: RawMaterialButton(
          onPressed: () async {
            await _controller.reverse();
            await _controller.forward();
            widget.onTap();
          },
          elevation: 3,
          fillColor: widget.background,
          shape: const CircleBorder(),
          child: Icon(widget.icon, color: Colors.white, size: 28),
        ),
      ),
    );
  }
}

/// ===== Kartu tips kecil =====
class _HintCard extends StatelessWidget {
  const _HintCard({required this.title, required this.points});

  final String title;
  final List<String> points;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFFF6F8FF),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE7ECFF)),
      ),
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 13.5,
              fontWeight: FontWeight.w700,
              color: RegisterColors.textDark,
            ),
          ),
          const SizedBox(height: 8),
          ...points.map(
            (p) => Padding(
              padding: const EdgeInsets.symmetric(vertical: 3),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Padding(
                    padding: EdgeInsets.only(top: 6),
                    child: _Dot(),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      p,
                      style: const TextStyle(
                        fontSize: 13,
                        height: 1.5,
                        color: RegisterColors.subText,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Dot extends StatelessWidget {
  const _Dot();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 6,
      height: 6,
      decoration: const BoxDecoration(
        shape: BoxShape.circle,
        color: RegisterColors.blue,
      ),
    );
  }
}

/// ===== Background dekoratif lembut =====
class _DecorBackground extends StatelessWidget {
  const _DecorBackground();

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        // Blob kanan atas
        const Positioned(
          right: -40,
          top: -20,
          child: _Blob(
            size: 180,
            colors: [Color(0xFF5E7CF0), Color(0xFF6CE8C2)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            opacity: .15,
          ),
        ),
        // Blob kiri bawah
        const Positioned(
          left: -60,
          bottom: -40,
          child: _Blob(
            size: 220,
            colors: [Color(0xFF6CE8C2), Color(0xFF5E7CF0)],
            begin: Alignment.topRight,
            end: Alignment.bottomLeft,
            opacity: .10,
          ),
        ),
        // Titik grid samar
        Positioned.fill(
          child: IgnorePointer(
            child: CustomPaint(
              painter: _DotGridPainter(
                color: const Color(0xFFCBD5E1).withOpacity(.25),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _Blob extends StatelessWidget {
  const _Blob({
    required this.size,
    required this.colors,
    required this.begin,
    required this.end,
    this.opacity = .12,
  });

  final double size;
  final List<Color> colors;
  final Alignment begin;
  final Alignment end;
  final double opacity;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(size),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 6, sigmaY: 6),
        child: Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            gradient: LinearGradient(begin: begin, end: end, colors: colors),
          ),
          child: Opacity(opacity: opacity, child: const SizedBox()),
        ),
      ),
    );
  }
}

class _DotGridPainter extends CustomPainter {
  _DotGridPainter({required this.color});
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = color;
    const gap = 24.0;
    const r = 1.2;
    for (double y = gap; y < size.height; y += gap) {
      for (double x = gap; x < size.width; x += gap) {
        canvas.drawCircle(Offset(x, y), r, paint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
