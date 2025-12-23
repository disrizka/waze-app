// lib/screens/login_screen.dart
import 'dart:io';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:provider/provider.dart';
import 'package:shimmer/shimmer.dart';
import 'package:wa_blast/constants/app_colors.dart';
import 'package:wa_blast/l10n/app_localizations.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:wa_blast/widgets/app_snackbar.dart';

// HAPUS: import 'package:wa_blast/utils/core_permission.dart';
import '../providers/auth_provider.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isPasswordVisible = false;
  bool _isRequestingPermissions = false;

  @override
  void initState() {
    super.initState();
    _requestInitialPermissions();
  }

  /// === PERMISSIONS ===
  /// Sesuai kebijakan Play Store:
  /// - ANDROID: Jangan minta Photos/Storage → gunakan Android Photo Picker.
  /// - iOS: Boleh minta Photos.
  Future<void> _requestInitialPermissions() async {
    if (!mounted || _isRequestingPermissions) return;
    setState(() => _isRequestingPermissions = true);

    try {
      // === Notifications ===
      try {
        if (Platform.isIOS) {
          final fcm = await FirebaseMessaging.instance.requestPermission(
            alert: true,
            announcement: false,
            badge: true,
            carPlay: false,
            criticalAlert: false,
            provisional: false,
            sound: true,
          );
          final authorized =
              fcm.authorizationStatus == AuthorizationStatus.authorized ||
              fcm.authorizationStatus == AuthorizationStatus.provisional;
        }
        // Android 13+; di versi lama akan diabaikan oleh OS/plugin
        final notif = await Permission.notification.request();
      } catch (_) {}

      // === Camera ===
      try {} catch (_) {}

      // === Photos (iOS saja) ===
      if (Platform.isIOS) {
        try {} catch (_) {}
      } else {
        // ANDROID → JANGAN minta photos/storage. Gunakan Android Photo Picker saat memilih gambar.
      }
    } finally {
      if (mounted) setState(() => _isRequestingPermissions = false);
    }
  }

  // ====== END PERMISSIONS ======

  Future<void> _handleLogin() async {
    final t = AppLocalizations.of(context)!;

    final email = _emailController.text.trim();
    final password = _passwordController.text;

    if (email.isEmpty || password.isEmpty) {
      AppSnackbar.show(
        context,
        type: AppSnackType.warning,
        title: 'Missing info',
        message: t.login_empty_fields,
      );

      return;
    }

    // FCM token
    String fcmToken = 'unknown_fcm_token';
    try {
      fcmToken =
          (await FirebaseMessaging.instance.getToken()) ?? 'unknown_fcm_token';
    } catch (_) {}

    // Device info
    String deviceId = 'unknown_device_id';
    String deviceName = 'unknown_device';
    try {
      final deviceInfo = DeviceInfoPlugin();
      if (Platform.isAndroid) {
        final info = await deviceInfo.androidInfo;
        deviceId = info.id ?? info.model ?? 'android_device';
        deviceName = '${info.manufacturer} ${info.model}';
      } else if (Platform.isIOS) {
        final info = await deviceInfo.iosInfo;
        deviceId = info.identifierForVendor ?? 'ios_device';
        deviceName = info.utsname.machine ?? info.name ?? 'iPhone';
      }
    } catch (_) {}

    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final success = await authProvider.login(
      context: context,
      email: email,
      password: password,
      fcmToken: fcmToken,
      deviceId: deviceId,
      deviceName: deviceName,
    );

    if (!mounted) return;
    if (!success) {
      final errorMsg = authProvider.error ?? t.login_failed;
      AppSnackbar.show(
        context,
        type: AppSnackType.error,
        title: 'Login failed',
        message: errorMsg,
      );
    }
  }

  /// === LOGIN DENGAN GOOGLE ===
  Future<void> _handleLoginWithGoogle() async {
    final t = AppLocalizations.of(context)!;

    // FCM token
    String fcmToken = 'unknown_fcm_token';
    try {
      fcmToken =
          (await FirebaseMessaging.instance.getToken()) ?? 'unknown_fcm_token';
    } catch (_) {}

    // Device info
    String deviceId = 'unknown_device_id';
    String deviceName = 'unknown_device';
    try {
      final deviceInfo = DeviceInfoPlugin();
      if (Platform.isAndroid) {
        final info = await deviceInfo.androidInfo;
        deviceId = info.id ?? info.model ?? 'android_device';
        deviceName = '${info.manufacturer} ${info.model}';
      } else if (Platform.isIOS) {
        // Secara requirement kamu Google login hanya Android,
        // tapi kalau suatu saat dipakai di iOS, ini tetap aman.
        final info = await deviceInfo.iosInfo;
        deviceId = info.identifierForVendor ?? 'ios_device';
        deviceName = info.utsname.machine ?? info.name ?? 'iPhone';
      }
    } catch (_) {}

    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final success = await authProvider.loginWithGoogle(
      context: context,
      deviceId: deviceId,
      deviceName: deviceName,
      fcmToken: fcmToken,
    );

    if (!mounted) return;
    if (!success) {
      final errorMsg = authProvider.error ?? t.login_failed;
      AppSnackbar.show(
        context,
        type: AppSnackType.error,
        title: 'Login failed',
        message: errorMsg,
      );
    }
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context)!;
    final isLoading = context.watch<AuthProvider>().isLoading;

    return Scaffold(
      resizeToAvoidBottomInset: true,
      backgroundColor: Colors.white,
      body: SafeArea(
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Banner
              Container(
                width: double.infinity,
                height: 180,
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Color(0xFFDDE7FF), // biru muda
                      Color(0xFFCCF5DD), // hijau mint
                    ],
                  ),
                ),
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    // Gradient soft background (lebih halus)
                    Container(
                      decoration: const BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [Color(0xFFE6EEFF), Color(0xFFD5F7E8)],
                        ),
                      ),
                    ),

                    // Logo baru
                    Padding(
                      padding: const EdgeInsets.only(top: 16.0),
                      child: Image.asset(
                        "assets/wave_up_logo_2.png",
                        height: 48,
                        fit: BoxFit.contain,
                      ),
                    ),
                  ],
                ),
              ),

              // Form
              Padding(
                padding: EdgeInsets.only(
                  left: 24,
                  right: 24,
                  top: 40,
                  bottom: MediaQuery.of(context).viewInsets.bottom + 24,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      t.login_username, // "Username"
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: _emailController,
                      decoration: InputDecoration(
                        hintText:
                            t.login_username_hint, // "E.g user0001@gmail.com"
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(6),
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                    Text(
                      t.login_password, // "Password"
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: _passwordController,
                      obscureText: !_isPasswordVisible,
                      decoration: InputDecoration(
                        hintText:
                            t.login_password_hint, // "Fill your password here"
                        suffixIcon: IconButton(
                          icon: Icon(
                            _isPasswordVisible
                                ? Icons.visibility_off
                                : Icons.visibility,
                          ),
                          onPressed: () => setState(
                            () => _isPasswordVisible = !_isPasswordVisible,
                          ),
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(6),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: GestureDetector(
                        onTap: () {
                          Navigator.pushNamed(context, '/password/forgot');
                        },
                        child: Text(
                          t.login_forgot_password, // "Forgot password?"
                          style: const TextStyle(
                            color: Colors.blue,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Tombol login biasa
                    isLoading
                        ? const _LoginShimmerButton()
                        : SizedBox(
                            width: double.infinity,
                            height: 48,
                            child: ElevatedButton(
                              onPressed: _handleLogin,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.blue,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                              ),
                              child: Text(
                                t.login_button, // "Login"
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                          ),

                    const SizedBox(height: 16),

                    if (Platform.isAndroid) ...[
                      Row(
                        children: [
                          Expanded(
                            child: Container(
                              height: 1,
                              color: Colors.grey.shade300,
                            ),
                          ),
                          const Padding(
                            padding: EdgeInsets.symmetric(horizontal: 8.0),
                            child: Text(
                              'or',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey,
                              ),
                            ),
                          ),
                          Expanded(
                            child: Container(
                              height: 1,
                              color: Colors.grey.shade300,
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 16),

                      SizedBox(
                        width: double.infinity,
                        height: 48,
                        child: OutlinedButton(
                          onPressed: isLoading ? null : _handleLoginWithGoogle,
                          style: OutlinedButton.styleFrom(
                            backgroundColor: Colors.white,
                            foregroundColor: Colors.black87,
                            side: BorderSide(color: Colors.grey.shade300),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            mainAxisSize: MainAxisSize.max,
                            children: [
                              const FaIcon(
                                FontAwesomeIcons.google, // icon Google resmi
                                size: 20,
                                color: AppColors.black,
                              ),
                              const SizedBox(width: 10),
                              const Text(
                                'Continue with Google',
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.black87,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],

                    const SizedBox(height: 24),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(t.login_no_account), // "Don’t have account? "
                        GestureDetector(
                          onTap: () =>
                              Navigator.pushNamed(context, '/register'),
                          child: Text(
                            t.login_register_now, // "Register Now"
                            style: const TextStyle(
                              color: Colors.blue,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _LoginShimmerButton extends StatelessWidget {
  const _LoginShimmerButton();

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context)!;

    return AbsorbPointer(
      absorbing: true,
      child: SizedBox(
        width: double.infinity,
        height: 48,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: Shimmer.fromColors(
            baseColor: Colors.grey.shade300,
            highlightColor: Colors.grey.shade100,
            period: const Duration(milliseconds: 1200),
            child: Container(
              color: Colors.grey.shade300,
              alignment: Alignment.center,
              child: Text(
                t.login_button_loading, // "Logging in…"
                style: const TextStyle(
                  color: Colors.black54,
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _PermRow extends StatelessWidget {
  const _PermRow({required this.icon, required this.label});
  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 20),
        const SizedBox(width: 10),
        Expanded(child: Text(label)),
      ],
    );
  }
}

class _PermissionPoint extends StatelessWidget {
  const _PermissionPoint({
    required this.icon,
    required this.title,
    required this.desc,
    required this.accentBg,
    required this.accentIcon,
  });

  final IconData icon;
  final String title;
  final String desc;
  final Color accentBg;
  final Color accentIcon;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: accentBg,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, color: accentIcon),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 14.5,
                  color: Color(0xFF0F172A),
                ),
              ),
              const SizedBox(height: 2),
              Text(
                desc,
                style: const TextStyle(
                  fontSize: 12.5,
                  color: Color(0xFF64748B),
                  height: 1.35,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
