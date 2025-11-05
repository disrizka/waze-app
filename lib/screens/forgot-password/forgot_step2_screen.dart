import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:wa_blast/providers/change_password_provider.dart';
import 'forgot_shared.dart';

class ForgotStep2Screen extends StatefulWidget {
  final String email;
  final String? initialOtp;
  final void Function(String otp) onNext;

  const ForgotStep2Screen({
    super.key,
    required this.email,
    required this.onNext,
    this.initialOtp,
  });

  @override
  State<ForgotStep2Screen> createState() => _ForgotStep2ScreenState();
}

class _ForgotStep2ScreenState extends State<ForgotStep2Screen> {
  final _otpC = TextEditingController();

  @override
  void initState() {
    super.initState();
    if ((widget.initialOtp ?? '').isNotEmpty) {
      _otpC.text = widget.initialOtp!;
    }
  }

  @override
  void dispose() {
    _otpC.dispose();
    super.dispose();
  }

  Future<void> _resend() async {
    final prov = context.read<ChangePasswordProvider>();
    final otp = await prov.forgotPasswordStep1(
      context,
      emailOrUser: widget.email,
    );
    if (otp != null) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('OTP resent. Check your email.')),
      );
      setState(() {
        _otpC.text = otp;
      });
    } else {
      if (!mounted) return;
      showErrorDialog(context, prov.lastError ?? 'Failed to resend OTP');
    }
  }

  void _next() {
    final otp = _otpC.text.trim();
    if (otp.isEmpty || otp.length < 4) {
      showErrorDialog(context, 'Please enter a valid OTP code.');
      return;
    }
    widget.onNext(otp);
  }

  @override
  Widget build(BuildContext context) {
    final loading = context.watch<ChangePasswordProvider>().loading;
    final blue = const Color(0xFF1565C0); // konsisten dengan step 1

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // === HEADER TITLE (rata kiri, biru, ukuran kecil) ===
          Text(
            'Verify OTP',
            style: TextStyle(
              color: blue,
              fontSize: 20,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),

          // === SUBTITLE (rata kiri) ===
          Text(
            'Enter the code sent to ${widget.email}',
            textAlign: TextAlign.left,
            style: const TextStyle(
              color: Colors.black87,
              fontSize: 14,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 24),

          // === OTP BOXES (komponen dari forgot_shared) ===
          OtpBoxes(controller: _otpC, length: 6),

          const SizedBox(height: 12),

          // === RESEND (rata kiri) ===
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton(
              onPressed: loading ? null : _resend,
              style: TextButton.styleFrom(
                padding: EdgeInsets.zero,
                minimumSize: const Size(0, 0),
              ),
              child: const Text(
                'Resend Code',
                style: TextStyle(
                  color: Colors.black54,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ),

          const Spacer(),

          // === CTA BUTTON (penuh, biru, radius konsisten) ===
          SizedBox(
            width: double.infinity,
            height: 48,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: blue,
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              onPressed: loading ? null : _next,
              child: loading
                  ? const SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text(
                      'Verify',
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 15,
                      ),
                    ),
            ),
          ),
        ],
      ),
    );
  }
}
