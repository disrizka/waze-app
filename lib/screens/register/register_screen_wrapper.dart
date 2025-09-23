import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:wa_blast/providers/auth_provider.dart';
import 'package:wa_blast/screens/register/register_step1_clean.dart';
import 'package:wa_blast/screens/register/register_step2_clean.dart';

class RegisterWrapper extends StatefulWidget {
  const RegisterWrapper({super.key, this.initialStep = 1});
  final int initialStep;

  @override
  State<RegisterWrapper> createState() => _RegisterWrapperState();
}

class _RegisterWrapperState extends State<RegisterWrapper> {
  late int _step;

  @override
  void initState() {
    super.initState();
    _step = (widget.initialStep == 2) ? 2 : 1;
  }

  void _goStep2() => setState(() => _step = 2);

  @override
  Widget build(BuildContext context) {
    final loading = context.watch<AuthProvider>().isLoading;

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 520),
            child: ListView(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              children: [
                // ===== Back button =====
                Align(
                  alignment: Alignment.centerLeft,
                  child: IconButton(
                    icon: const Icon(Icons.arrow_back, color: Colors.black87),
                    onPressed: () {
                      Navigator.pushReplacementNamed(context, '/login');
                    },
                  ),
                ),

                const SizedBox(height: 20),

                // ===== Logo =====
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Image.asset(
                      'assets/wave_up_logo.png',
                      height: 28,
                      errorBuilder: (_, __, ___) => const Icon(
                        Icons.waves,
                        size: 28,
                        color: Color(0xFF00C389),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 70),

                // ======== STEP CONTENT ========
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 250),
                  switchInCurve: Curves.easeOut,
                  switchOutCurve: Curves.easeIn,
                  child: _step == 1
                      ? RegisterStep1Clean(
                          key: const ValueKey('step1'),
                          onSuccessNext: _goStep2,
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
