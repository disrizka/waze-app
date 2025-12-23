import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:wa_blast/providers/change_password_provider.dart';
import 'package:wa_blast/widgets/app_snackbar.dart';
import 'forgot_shared.dart';

class ForgotStep1Screen extends StatefulWidget {
  final String? initialEmail;
  final void Function(String email, {String? otpFromServer}) onNext;

  const ForgotStep1Screen({super.key, required this.onNext, this.initialEmail});

  @override
  State<ForgotStep1Screen> createState() => _ForgotStep1ScreenState();
}

class _ForgotStep1ScreenState extends State<ForgotStep1Screen> {
  final _formKey = GlobalKey<FormState>();
  final _emailC = TextEditingController();

  @override
  void initState() {
    super.initState();
    if ((widget.initialEmail ?? '').isNotEmpty) {
      _emailC.text = widget.initialEmail!;
    }
  }

  @override
  void dispose() {
    _emailC.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    final prov = context.read<ChangePasswordProvider>();
    final email = _emailC.text.trim();

    if (!mounted) return;

    if (mounted) {
      AppSnackbar.show(
        context,
        type: AppSnackType.success,
        title: 'Success',
        message: 'OTP sent! Please check your email.',
        duration: const Duration(seconds: 3),
      );
      widget.onNext(email);
    } else {
      showErrorDialog(context, prov.lastError ?? 'Failed to request OTP');
    }
  }

  @override
  Widget build(BuildContext context) {
    final loading = context.watch<ChangePasswordProvider>().loading;
    final blue = const Color(0xFF1565C0); // Warna biru utama (Google blue tone)

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // === HEADER TITLE ===
          Text(
            'Send OTP',
            textAlign: TextAlign.left,
            style: TextStyle(
              color: blue,
              fontSize: 20,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Enter your email address to receive a verification code.',
            textAlign: TextAlign.left,
            style: TextStyle(color: Colors.black87, fontSize: 14, height: 1.4),
          ),
          const SizedBox(height: 32),

          // === INPUT FIELD ===
          Form(
            key: _formKey,
            child: TextFormField(
              controller: _emailC,
              keyboardType: TextInputType.emailAddress,
              textInputAction: TextInputAction.done,
              decoration: InputDecoration(
                labelText: 'Email Address',
                alignLabelWithHint: true,
                labelStyle: const TextStyle(color: Colors.black54),
                filled: true,
                fillColor: Colors.grey.shade100,
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide(color: Colors.grey.shade300),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide(color: blue, width: 1.5),
                ),
              ),
              validator: (v) {
                final s = (v ?? '').trim();
                if (s.isEmpty) return 'Email is required';
                if (!s.contains('@')) return 'Invalid email';
                return null;
              },
              onFieldSubmitted: (_) => _submit(),
            ),
          ),

          const Spacer(),

          // === BUTTON ===
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
              onPressed: loading ? null : _submit,
              child: loading
                  ? const SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text(
                      'Send Code',
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
