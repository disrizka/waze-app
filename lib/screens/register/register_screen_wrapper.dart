import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:wa_blast/providers/auth_provider.dart';
import 'package:wa_blast/screens/register/register_step1_clean.dart';
import 'package:wa_blast/screens/register/register_step2_clean.dart';
import 'package:wa_blast/screens/register/register_welcome_step.dart';

class RegisterWrapper extends StatefulWidget {
  /// initialStep:
  /// 0 = Welcome
  /// 1 = Account
  /// 2 = Profile
  const RegisterWrapper({super.key, this.initialStep = 0});
  final int initialStep;

  @override
  State<RegisterWrapper> createState() => _RegisterWrapperState();
}

class _RegisterWrapperState extends State<RegisterWrapper> {
  late int _step; // 0..2

  /// progress sub-step di step "Account" (0..1)
  /// 4 sub-step → 0.25, 0.5, 0.75, 1.0
  double _accountSubProgress = 0.25;

  @override
  void initState() {
    super.initState();
    if (widget.initialStep <= 0) {
      _step = 0;
    } else if (widget.initialStep == 1) {
      _step = 1;
    } else {
      _step = 2;
      _accountSubProgress =
          1.0; // kalau langsung lompat ke Profile, anggap Account sudah full
    }
  }

  void _goStep1() {
    setState(() {
      _step = 1;
      _accountSubProgress = 0.25; // mulai dari sub-step pertama
    });
  }

  void _goStep2() {
    setState(() {
      _step = 2;
      _accountSubProgress =
          1.0; // begitu masuk Profile, step Account dianggap selesai
    });
  }

  /// dipanggil dari RegisterStep1Clean setiap kali sub-step berubah
  void _onAccountSubStepChanged(int current, int total) {
    if (total <= 0) return;
    setState(() {
      final clamped = current.clamp(1, total);
      _accountSubProgress = clamped / total; // 1/4, 2/4, 3/4, 4/4
    });
  }

  static const blue = Color(0xFF4069E6);
  static const textDark = Color(0xFF0F172A);

  @override
  Widget build(BuildContext context) {
    final loading = context.watch<AuthProvider>().isLoading;

    // === STEP 0: Welcome (tanpa appbar & stepper) ===
    if (_step == 0) {
      return RegisterWelcomeStep(onNext: _goStep1);
    }

    // === STEP 1..2: Tampilan dengan appbar + stepper ===
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 520),
            child: ListView(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              children: [
                // App bar minimal
                Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.arrow_back, color: Colors.black87),
                      onPressed: () => Navigator.of(
                        context,
                      ).popUntil((route) => route.settings.name == '/login'),
                      tooltip: 'Kembali',
                    ),
                    const SizedBox(width: 6),
                    const Expanded(
                      child: Text(
                        'Sign Up',
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                          color: textDark,
                        ),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 10),

                // Stepper: sekarang step "Account" bisa punya progress 0–1 berdasarkan sub-step
                _PrettyStepper2(
                  currentStep: _step, // 1..2
                  activeColor: blue,
                  inactiveColor: const Color(0xFFE6E9F2),
                  labels: const ['Account', 'Business'],
                  accountProgress: _accountSubProgress,
                ),

                const SizedBox(height: 30),

                // Konten step
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 250),
                  switchInCurve: Curves.easeOut,
                  switchOutCurve: Curves.easeIn,
                  child: _step == 1
                      ? RegisterStep1Clean(
                          key: const ValueKey('step1'),
                          onSuccessNext: _goStep2,
                          // kirim callback supaya sub-step bisa update progress line
                          onSubStepChanged: _onAccountSubStepChanged,
                        )
                      : const RegisterStep2Clean(key: ValueKey('step2')),
                ),

                if (loading) const SizedBox(height: 8),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// =============================
/// Stepper 2-segmen + sub-progress di step "Account"
/// =============================
class _PrettyStepper2 extends StatelessWidget {
  final int currentStep; // 1..2
  final Color activeColor;
  final Color inactiveColor;
  final List<String> labels;

  /// progress untuk step "Account" (0..1) – dibagi 4 di dalam RegisterStep1Clean
  final double accountProgress;

  const _PrettyStepper2({
    super.key,
    required this.currentStep,
    required this.activeColor,
    required this.inactiveColor,
    required this.labels,
    this.accountProgress = 0.25,
  }) : assert(labels.length == 2, 'labels harus 2 item');

  @override
  Widget build(BuildContext context) {
    final step = currentStep.clamp(1, 2);
    final double accountValue = step >= 2
        ? 1.0
        : accountProgress.clamp(0.0, 1.0);
    final double profileValue = step >= 2 ? 1.0 : 0.0;

    return Column(
      children: [
        // Track wrapper
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 6),
          child: Row(
            children: [
              // Segment "Account" – punya 4 sub bagian
              Expanded(
                child: _SegmentBar(
                  value: accountValue,
                  activeColor: activeColor,
                  inactiveColor: inactiveColor,
                  divisions: 4, // visual: 4 bagian kecil
                ),
              ),
              const SizedBox(width: 8),
              // Segment "Profile" – full/empty
              Expanded(
                child: _SegmentBar(
                  value: profileValue,
                  activeColor: activeColor,
                  inactiveColor: inactiveColor,
                  divisions: 1,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        // Labels kiri-kanan
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 6),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _StepTag(
                text: labels[0],
                active: step == 1,
                activeColor: activeColor,
              ),
              _StepTag(
                text: labels[1],
                active: step == 2,
                activeColor: activeColor,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// Bar dengan value 0..1, bisa dibagi jadi beberapa bagian visual (divisions)
class _SegmentBar extends StatelessWidget {
  final double value; // 0..1
  final Color activeColor;
  final Color inactiveColor;
  final int divisions;

  const _SegmentBar({
    required this.value,
    required this.activeColor,
    required this.inactiveColor,
    this.divisions = 1,
  });

  @override
  Widget build(BuildContext context) {
    final v = value.clamp(0.0, 1.0);

    return LayoutBuilder(
      builder: (context, constraints) {
        final fullWidth = constraints.maxWidth;
        final activeWidth = fullWidth * v;

        return SizedBox(
          height: 8,
          child: Stack(
            children: [
              // background (inactive)
              Container(
                width: fullWidth,
                height: 8,
                decoration: BoxDecoration(
                  color: inactiveColor,
                  borderRadius: BorderRadius.circular(999),
                ),
              ),

              // garis pembagi kecil (visual 4 bagian)
              if (divisions > 1)
                ...List.generate(divisions - 1, (index) {
                  final left = fullWidth * (index + 1) / divisions;
                  return Positioned(
                    left: left - 0.5,
                    top: 1.5,
                    bottom: 1.5,
                    child: Container(
                      width: 1,
                      color: Colors.white.withOpacity(0.7),
                    ),
                  );
                }),

              // bagian aktif (biru) – panjangnya sesuai value
              AnimatedContainer(
                duration: const Duration(milliseconds: 260),
                curve: Curves.easeOutCubic,
                width: activeWidth,
                height: 8,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(999),
                  gradient: LinearGradient(
                    begin: Alignment.centerLeft,
                    end: Alignment.centerRight,
                    colors: [
                      activeColor.withOpacity(.95),
                      activeColor.withOpacity(.85),
                    ],
                  ),
                  boxShadow: v > 0
                      ? [
                          BoxShadow(
                            color: activeColor.withOpacity(.18),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ]
                      : null,
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _StepTag extends StatelessWidget {
  final String text;
  final bool active;
  final Color activeColor;

  const _StepTag({
    required this.text,
    required this.active,
    required this.activeColor,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedDefaultTextStyle(
      duration: const Duration(milliseconds: 180),
      style: TextStyle(
        fontSize: 12,
        fontWeight: active ? FontWeight.w800 : FontWeight.w600,
        color: active ? activeColor : const Color(0xFF8A94A6),
        letterSpacing: .2,
      ),
      child: Text(text),
    );
  }
}
