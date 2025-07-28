import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../constants/app_colors.dart';
import '../providers/auth_provider.dart';

void showAddAccountModal(BuildContext context) {
  final emailController = TextEditingController();
  final passwordController = TextEditingController();
  bool isPasswordHidden = true;
  bool isLoading = false;

  showDialog(
    context: context,
    barrierDismissible: false,
    builder: (context) {
      return StatefulBuilder(
        builder: (context, setState) {
          return Dialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
            backgroundColor: Colors.white,
            insetPadding: const EdgeInsets.symmetric(horizontal: 24),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(24, 16, 24, 20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Align(
                    alignment: Alignment.topRight,
                    child: IconButton(
                      onPressed: isLoading
                          ? null
                          : () => Navigator.pop(context),
                      icon: const Icon(LucideIcons.x),
                      color: Colors.grey,
                      tooltip: 'Cancel',
                    ),
                  ),
                  const Icon(
                    LucideIcons.userPlus,
                    size: 50,
                    color: AppColors.primary,
                  ),
                  const SizedBox(height: 10),
                  const Text(
                    'Tambah Akun Lainnya',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: AppColors.primaryText,
                    ),
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'Masukkan email dan password akun lain yang ingin kamu tambahkan.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 14,
                      color: AppColors.secondaryText,
                    ),
                  ),
                  const SizedBox(height: 24),
                  TextField(
                    controller: emailController,
                    enabled: !isLoading,
                    keyboardType: TextInputType.emailAddress,
                    decoration: InputDecoration(
                      hintText: 'Email',
                      prefixIcon: const Icon(LucideIcons.mail),
                      filled: true,
                      fillColor: AppColors.greyBackground,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  TextField(
                    controller: passwordController,
                    enabled: !isLoading,
                    obscureText: isPasswordHidden,
                    decoration: InputDecoration(
                      hintText: 'Password',
                      prefixIcon: const Icon(LucideIcons.lock),
                      suffixIcon: IconButton(
                        icon: Icon(
                          isPasswordHidden
                              ? LucideIcons.eyeOff
                              : LucideIcons.eye,
                          size: 20,
                          color: Colors.grey,
                        ),
                        onPressed: isLoading
                            ? null
                            : () {
                                setState(() {
                                  isPasswordHidden = !isPasswordHidden;
                                });
                              },
                      ),
                      filled: true,
                      fillColor: AppColors.greyBackground,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                  const SizedBox(height: 28),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      icon: isLoading
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(
                                color: Colors.white,
                                strokeWidth: 2,
                              ),
                            )
                          : const Icon(LucideIcons.logIn),
                      label: Text(isLoading ? 'Memproses...' : 'Login'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 20,
                          vertical: 14,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      onPressed: isLoading
                          ? null
                          : () async {
                              final email = emailController.text.trim();
                              final password = passwordController.text.trim();
                              if (email.isEmpty || password.isEmpty) return;

                              setState(() => isLoading = true);

                              final auth = Provider.of<AuthProvider>(
                                context,
                                listen: false,
                              );

                              final success = await auth.login(email, password);

                              if (context.mounted) {
                                if (success) {
                                  Navigator.pop(context);
                                  Navigator.pushReplacementNamed(
                                    context,
                                    '/splash',
                                  );
                                } else {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text(
                                        auth.error ?? 'Login gagal',
                                      ),
                                    ),
                                  );
                                }
                              }

                              setState(() => isLoading = false);
                            },
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      );
    },
  );
}
