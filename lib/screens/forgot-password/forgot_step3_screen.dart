import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:wa_blast/providers/change_password_provider.dart';
import 'forgot_shared.dart';

class ForgotStep3Screen extends StatefulWidget {
  final String email;
  final String otp;
  final VoidCallback onDone;

  const ForgotStep3Screen({
    super.key,
    required this.email,
    required this.otp,
    required this.onDone,
  });

  @override
  State<ForgotStep3Screen> createState() => _ForgotStep3ScreenState();
}

class _ForgotStep3ScreenState extends State<ForgotStep3Screen> {
  final _formKey = GlobalKey<FormState>();
  final _passNewC = TextEditingController();
  final _passConfC = TextEditingController();

  bool _obscureNew = true;
  bool _obscureConf = true;

  @override
  void dispose() {
    _passNewC.dispose();
    _passConfC.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    final prov = context.read<ChangePasswordProvider>();
    final ok = await prov.forgotPasswordStep3(
      context,
      emailOrUser: widget.email,
      otp: widget.otp,
      newPassword: _passNewC.text,
      confirmPassword: _passConfC.text,
    );

    if (ok) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Password changed successfully')),
      );
      widget.onDone();
    } else {
      if (!mounted) return;
      showErrorDialog(context, prov.lastError ?? 'Failed to change password');
    }
  }

  @override
  Widget build(BuildContext context) {
    final loading = context.watch<ChangePasswordProvider>().loading;
    final blue = const Color(0xFF1565C0); // sama dengan step 1 & 2

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // === HEADER TITLE ===
          Text(
            'Enter New Password',
            textAlign: TextAlign.left,
            style: TextStyle(
              color: blue,
              fontSize: 20,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),

          const Text(
            'Your new password must be different from the previous one.',
            textAlign: TextAlign.left,
            style: TextStyle(color: Colors.black87, fontSize: 14, height: 1.4),
          ),

          const SizedBox(height: 32),

          // === FORM ===
          Form(
            key: _formKey,
            child: Column(
              children: [
                // New Password
                TextFormField(
                  controller: _passNewC,
                  obscureText: _obscureNew,
                  textInputAction: TextInputAction.next,
                  decoration: InputDecoration(
                    labelText: 'New Password',
                    filled: true,
                    fillColor: Colors.grey.shade100,
                    labelStyle: const TextStyle(color: Colors.black54),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: BorderSide(color: Colors.grey.shade300),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: BorderSide(color: blue, width: 1.5),
                    ),
                    suffixIcon: IconButton(
                      icon: Icon(
                        _obscureNew ? Icons.visibility : Icons.visibility_off,
                        color: Colors.black54,
                      ),
                      onPressed: () =>
                          setState(() => _obscureNew = !_obscureNew),
                    ),
                  ),
                  validator: (v) {
                    final s = (v ?? '');
                    if (s.isEmpty) return 'New password is required';
                    if (s.length < 6) return 'Minimum 6 characters';
                    return null;
                  },
                ),
                const SizedBox(height: 16),

                // Confirm Password
                TextFormField(
                  controller: _passConfC,
                  obscureText: _obscureConf,
                  textInputAction: TextInputAction.done,
                  onFieldSubmitted: (_) => _submit(),
                  decoration: InputDecoration(
                    labelText: 'Confirm Password',
                    filled: true,
                    fillColor: Colors.grey.shade100,
                    labelStyle: const TextStyle(color: Colors.black54),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: BorderSide(color: Colors.grey.shade300),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: BorderSide(color: blue, width: 1.5),
                    ),
                    suffixIcon: IconButton(
                      icon: Icon(
                        _obscureConf ? Icons.visibility : Icons.visibility_off,
                        color: Colors.black54,
                      ),
                      onPressed: () =>
                          setState(() => _obscureConf = !_obscureConf),
                    ),
                  ),
                  validator: (v) {
                    final s = (v ?? '');
                    if (s.isEmpty) return 'Please confirm the password';
                    if (s != _passNewC.text) return 'Passwords do not match';
                    return null;
                  },
                ),
              ],
            ),
          ),

          const Spacer(),

          // === BUTTON SAVE ===
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
                      'Save',
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
