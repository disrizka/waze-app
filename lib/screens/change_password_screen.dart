import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:wa_blast/constants/app_colors.dart';

import 'package:wa_blast/providers/change_password_provider.dart';

class ChangePasswordScreen extends StatefulWidget {
  const ChangePasswordScreen({super.key});

  @override
  State<ChangePasswordScreen> createState() => _ChangePasswordScreenState();
}

class _ChangePasswordScreenState extends State<ChangePasswordScreen> {
  final _formKey = GlobalKey<FormState>();

  final _oldC = TextEditingController();
  final _newC = TextEditingController();
  final _confirmC = TextEditingController();

  final _oldNode = FocusNode();
  final _newNode = FocusNode();
  final _confirmNode = FocusNode();

  bool _obscureOld = true;
  bool _obscureNew = true;
  bool _obscureConfirm = true;

  @override
  void dispose() {
    _oldC.dispose();
    _newC.dispose();
    _confirmC.dispose();
    _oldNode.dispose();
    _newNode.dispose();
    _confirmNode.dispose();
    super.dispose();
  }

  String? _req(String? v, String label) {
    if (v == null || v.trim().isEmpty) return '$label is required';
    return null;
  }

  Future<void> _submit() async {
    final prov = context.read<ChangePasswordProvider>();
    FocusScope.of(context).unfocus();

    if (!_formKey.currentState!.validate()) return;

    final ok = await prov.changePassword(
      context,
      oldPassword: _oldC.text.trim(),
      newPassword: _newC.text.trim(),
      confirmPassword: _confirmC.text.trim(),
    );

    if (!mounted) return;

    if (ok) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Password updated successfully'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      Navigator.of(context).maybePop();
    } else {
      final err = prov.lastError ?? 'Failed to change password';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(err), behavior: SnackBarBehavior.floating),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    // tema: putih bersih; aksen biru pada tombol / focus
    const primary = Color(0xFF1769E0);

    final inputBorder = OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: const BorderSide(color: Color(0xFFE5E7EB)), // abu soft
    );

    return ChangeNotifierProvider(
      create: (_) => ChangePasswordProvider(),
      child: Builder(
        builder: (context) {
          final loading = context.watch<ChangePasswordProvider>().loading;

          return Scaffold(
            backgroundColor: Colors.white,
            appBar: AppBar(
              backgroundColor: Colors.white,
              elevation: 0,
              leading: IconButton(
                icon: const Icon(
                  Icons.arrow_back_ios_new_rounded,
                  color: AppColors.black,
                ),
                onPressed: () => Navigator.pushReplacementNamed(
                  context,
                  '/home',
                  arguments: {'tab': 'settings'},
                ),
              ),
              title: const Text(
                'Change Password',
                style: TextStyle(
                  color: Colors.black87,
                  fontWeight: FontWeight.w600,
                ),
              ),
              centerTitle: true,
            ),
            body: SafeArea(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 8,
                ),
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 480),
                    child: Form(
                      key: _formKey,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          // Deskripsi kecil seperti di contoh
                          const Text(
                            'Choose a New Password',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                              color: Colors.black87,
                            ),
                          ),
                          const SizedBox(height: 4),
                          const Text(
                            'Enter and confirm your new password to regain access',
                            style: TextStyle(
                              fontSize: 13.5,
                              color: Color(0xFF6B7280), // abu-abu
                              height: 1.25,
                            ),
                          ),
                          const SizedBox(height: 18),

                          // Old password
                          _LabeledField(
                            label: 'Old Password',
                            child: TextFormField(
                              controller: _oldC,
                              focusNode: _oldNode,
                              obscureText: _obscureOld,
                              textInputAction: TextInputAction.next,
                              onFieldSubmitted: (_) => _newNode.requestFocus(),
                              validator: (v) => _req(v, 'Old password'),
                              decoration: InputDecoration(
                                hintText: '••••••••',
                                isDense: true,
                                contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 14,
                                  vertical: 14,
                                ),
                                prefixIcon: const Icon(Icons.lock_outline),
                                suffixIcon: IconButton(
                                  onPressed: () => setState(
                                    () => _obscureOld = !_obscureOld,
                                  ),
                                  icon: Icon(
                                    _obscureOld
                                        ? Icons.visibility
                                        : Icons.visibility_off,
                                  ),
                                ),
                                border: inputBorder,
                                enabledBorder: inputBorder,
                                focusedBorder: inputBorder.copyWith(
                                  borderSide: const BorderSide(color: primary),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 12),

                          // New password
                          _LabeledField(
                            label: 'New password',
                            child: TextFormField(
                              controller: _newC,
                              focusNode: _newNode,
                              obscureText: _obscureNew,
                              textInputAction: TextInputAction.next,
                              onFieldSubmitted: (_) =>
                                  _confirmNode.requestFocus(),
                              validator: (v) {
                                final e = _req(v, 'New password');
                                if (e != null) return e;
                                if ((v ?? '').length < 3) {
                                  return 'Minimum 6 characters';
                                }
                                return null;
                              },
                              decoration: InputDecoration(
                                hintText: '••••••••',
                                isDense: true,
                                contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 14,
                                  vertical: 14,
                                ),
                                prefixIcon: const Icon(Icons.password),
                                suffixIcon: IconButton(
                                  onPressed: () => setState(
                                    () => _obscureNew = !_obscureNew,
                                  ),
                                  icon: Icon(
                                    _obscureNew
                                        ? Icons.visibility
                                        : Icons.visibility_off,
                                  ),
                                ),
                                border: inputBorder,
                                enabledBorder: inputBorder,
                                focusedBorder: inputBorder.copyWith(
                                  borderSide: const BorderSide(color: primary),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 12),

                          // Confirm password
                          _LabeledField(
                            label: 'Confirm new password',
                            child: TextFormField(
                              controller: _confirmC,
                              focusNode: _confirmNode,
                              obscureText: _obscureConfirm,
                              textInputAction: TextInputAction.done,
                              onFieldSubmitted: (_) => _submit(),
                              validator: (v) {
                                final e = _req(v, 'Confirmation');
                                if (e != null) return e;
                                if (v != _newC.text) {
                                  return 'Confirmation does not match';
                                }
                                return null;
                              },
                              decoration: InputDecoration(
                                hintText: '••••••••',
                                isDense: true,
                                contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 14,
                                  vertical: 14,
                                ),
                                prefixIcon: const Icon(
                                  Icons.verified_user_outlined,
                                ),
                                suffixIcon: IconButton(
                                  onPressed: () => setState(
                                    () => _obscureConfirm = !_obscureConfirm,
                                  ),
                                  icon: Icon(
                                    _obscureConfirm
                                        ? Icons.visibility
                                        : Icons.visibility_off,
                                  ),
                                ),
                                border: inputBorder,
                                enabledBorder: inputBorder,
                                focusedBorder: inputBorder.copyWith(
                                  borderSide: const BorderSide(color: primary),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 22),

                          // Tombol biru
                          SizedBox(
                            height: 48,
                            child: ElevatedButton(
                              onPressed: loading ? null : _submit,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: primary,
                                foregroundColor: Colors.white,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                elevation: 0,
                              ),
                              child: loading
                                  ? const SizedBox(
                                      width: 20,
                                      height: 20,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2.4,
                                        valueColor: AlwaysStoppedAnimation(
                                          Colors.white,
                                        ),
                                      ),
                                    )
                                  : const Text(
                                      'Update Password',
                                      style: TextStyle(
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

/// Label kecil di atas field agar mirip contoh
class _LabeledField extends StatelessWidget {
  final String label;
  final Widget child;
  const _LabeledField({required this.label, required this.child});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 13.5,
            color: Color(0xFF374151),
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 8),
        child,
      ],
    );
  }
}
