import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:wa_blast/app_nav.dart';

import '../constants/app_colors.dart';
import '../providers/auth_provider.dart';

/// Show an "Add Account" login modal (beautiful, branded, and keyboard-safe).
void showAddAccountModal(BuildContext context) {
  final emailController = TextEditingController();
  final passwordController = TextEditingController();
  final formKey = GlobalKey<FormState>();

  bool isPasswordHidden = true;
  bool isLoading = false;

  // Helpers
  Future<String> _getFcmToken() async {
    try {
      final token = await FirebaseMessaging.instance.getToken();
      return token ?? 'unknown_fcm_token';
    } catch (_) {
      return 'unknown_fcm_token';
    }
  }

  Future<({String deviceId, String deviceName, String os})>
  _getDeviceInfo() async {
    final deviceInfo = DeviceInfoPlugin();
    try {
      if (Platform.isAndroid) {
        final info = await deviceInfo.androidInfo;
        return (
          deviceId: info.id ?? 'unknown_device_id',
          deviceName: '${info.manufacturer} ${info.model}',
          os: 'android',
        );
      } else if (Platform.isIOS) {
        final info = await deviceInfo.iosInfo;
        return (
          deviceId: info.identifierForVendor ?? 'unknown_device_id',
          deviceName: info.utsname.machine ?? info.name ?? 'iPhone',
          os: 'ios',
        );
      }
    } catch (_) {}
    return (
      deviceId: 'unknown_device_id',
      deviceName: 'unknown_device',
      os: Platform.isIOS ? 'ios' : 'android',
    );
  }

  void _attemptSubmit(StateSetter setState) async {
    // validate inputs
    final ok = formKey.currentState?.validate() ?? false;
    if (!ok) return;

    FocusScope.of(context).unfocus();
    setState(() => isLoading = true);

    final auth = Provider.of<AuthProvider>(context, listen: false);
    final fcm = await _getFcmToken();
    final di = await _getDeviceInfo();

    final success = await auth.login(
      context: context,
      email: emailController.text.trim(),
      password: passwordController.text,
      fcmToken: fcm,
      deviceId: di.deviceId,
      deviceName: di.deviceName,
    );

    if (context.mounted) {
      if (success) {
        Navigator.pop(context); // close modal
        appNavigatorKey.currentState?.pushNamedAndRemoveUntil(
          '/splash',
          (r) => false,
        );
      }
    }

    setState(() => isLoading = false);
  }

  showDialog(
    context: context,
    barrierDismissible:
        false, // ← always false; we'll control closing ourselves
    builder: (context) {
      return StatefulBuilder(
        builder: (context, setState) {
          // recompute enable-state each rebuild
          final canSubmit =
              !isLoading && emailController.text.trim().isNotEmpty;

          return WillPopScope(
            onWillPop: () async => !isLoading, // ← block back when loading
            child: Dialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
              backgroundColor: Colors.white,
              insetPadding: const EdgeInsets.symmetric(
                horizontal: 20,
                vertical: 24,
              ),
              child: SafeArea(
                top: false,
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
                  child: Form(
                    key: formKey,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // header row (same as your current)
                        Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.center,
                                children: [
                                  Padding(
                                    padding: const EdgeInsets.only(
                                      top: 6,
                                      bottom: 30,
                                    ),
                                    child: Image.asset(
                                      'assets/wave_up_logo.png',
                                      height: 20,
                                    ),
                                  ),
                                  const Text(
                                    'Add Account',
                                    style: TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.w800,
                                      color: AppColors.primaryText,
                                    ),
                                  ),
                                  const SizedBox(height: 6),
                                  const Text(
                                    'Sign in to add another account. You can switch anytime.',
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
                                      fontSize: 13.5,
                                      height: 1.35,
                                      color: AppColors.secondaryText,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 8),
                          ],
                        ),

                        const SizedBox(height: 16),

                        // Email
                        TextFormField(
                          controller: emailController,
                          enabled: !isLoading,
                          keyboardType: TextInputType.emailAddress,
                          textInputAction: TextInputAction.next,
                          onChanged: (_) => setState(
                            () {},
                          ), // ← trigger rebuild for canSubmit
                          decoration: InputDecoration(
                            labelText: 'Email or Username',
                            hintText: 'e.g. user@mail.com',
                            prefixIcon: const Icon(LucideIcons.mail),
                            filled: true,
                            fillColor: AppColors.greyBackground,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide.none,
                            ),
                          ),
                          validator: (v) => (v == null || v.trim().isEmpty)
                              ? 'Email/username is required'
                              : null,
                        ),

                        const SizedBox(height: 14),

                        // Password
                        TextFormField(
                          controller: passwordController,
                          enabled: !isLoading,
                          obscureText: isPasswordHidden,
                          textInputAction: TextInputAction.done,
                          onChanged: (_) => setState(
                            () {},
                          ), // ← trigger rebuild for canSubmit
                          onFieldSubmitted: (_) =>
                              canSubmit ? _attemptSubmit(setState) : null,
                          decoration: InputDecoration(
                            labelText: 'Password',
                            hintText: 'Your password',
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
                                  : () => setState(
                                      () =>
                                          isPasswordHidden = !isPasswordHidden,
                                    ),
                            ),
                            filled: true,
                            fillColor: AppColors.greyBackground,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide.none,
                            ),
                          ),
                          validator: (v) {
                            if (v == null || v.isEmpty)
                              return 'Password is required';
                            return null;
                          },
                        ),

                        const SizedBox(height: 22),

                        Row(
                          children: const [
                            Icon(
                              LucideIcons.info,
                              size: 16,
                              color: AppColors.secondaryText,
                            ),
                            SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'We’ll use your device and notification token to keep you signed in.',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: AppColors.secondaryText,
                                ),
                              ),
                            ),
                          ],
                        ),

                        const SizedBox(height: 22),

                        // CTA
                        SizedBox(
                          width: double.infinity,
                          height: 48,
                          child: ElevatedButton.icon(
                            icon: isLoading
                                ? const SizedBox(
                                    width: 18,
                                    height: 18,
                                    child: CircularProgressIndicator(
                                      color: Colors.white,
                                      strokeWidth: 2,
                                    ),
                                  )
                                : const Icon(LucideIcons.logIn),
                            label: Text(
                              isLoading ? 'Signing in…' : 'Sign in',
                              style: const TextStyle(
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.primary,
                              foregroundColor: Colors.white,
                              elevation:
                                  2, // ← soft shadow like in your screenshot
                              shadowColor: AppColors.primary.withOpacity(0.35),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            onPressed: canSubmit
                                ? () => _attemptSubmit(setState)
                                : null, // ← enabled only when valid
                          ),
                        ),

                        const SizedBox(height: 6),

                        TextButton.icon(
                          onPressed: isLoading
                              ? null
                              : () => Navigator.pop(context),
                          icon: const Icon(LucideIcons.arrowLeft),
                          label: const Text('Cancel'),
                          style: TextButton.styleFrom(
                            foregroundColor: AppColors.primary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          );
        },
      );
    },
  );
}
