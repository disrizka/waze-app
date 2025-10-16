// lib/screens/login_screen.dart
import 'dart:io';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:provider/provider.dart';
import 'package:shimmer/shimmer.dart';
import 'package:wa_blast/app_nav.dart';
import 'package:wa_blast/l10n/app_localizations.dart';
import 'package:wa_blast/providers/splash_provider.dart';
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

  // Status permission (opsional, bisa dipakai untuk logging/telemetri)
  PermissionStatus? _notifStatus;
  PermissionStatus? _cameraStatus;
  PermissionStatus? _photosStatus;
  PermissionStatus? _storageStatus;

  @override
  void initState() {
    super.initState();
    _requestInitialPermissions();
  }

  /// Minta izin: Notification, Camera, Photos/Media, Storage
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
          _notifStatus = authorized
              ? PermissionStatus.granted
              : PermissionStatus.denied;
        }
        // Android 13+ dan juga fallback umum
        final notif = await Permission.notification.request();
        _notifStatus = notif;
      } catch (_) {}

      // === Camera ===
      try {
        _cameraStatus = await Permission.camera.request();
      } catch (_) {
        _cameraStatus = PermissionStatus.denied;
      }

      // === Photos / Media Library ===
      // iOS: Photos; Android 13+: READ_MEDIA_IMAGES dipetakan ke Permission.photos oleh plugin
      try {
        _photosStatus = await Permission.photos.request();
      } catch (_) {
        _photosStatus = PermissionStatus.denied;
      }

      // === Storage (Android <= 12) ===
      if (Platform.isAndroid) {
        try {
          _storageStatus = await Permission.storage.request();
        } catch (_) {
          _storageStatus = PermissionStatus.denied;
        }
        // Jika butuh akses luas (opsional), bisa minta ini:
        // if (_storageStatus?.isDenied ?? true) {
        //   final mng = await Permission.manageExternalStorage.request();
        //   _storageStatus = mng;
        // }
      } else {
        _storageStatus = PermissionStatus.granted; // tidak relevan di iOS
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
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(t.login_empty_fields)));
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
    if (success) {
      final sp = appNavigatorKey.currentContext?.read<SplashProvider>();
      sp?.resetNavigationGuards();
      sp?.abortDeepLink();
      appNavigatorKey.currentState?.pushNamedAndRemoveUntil(
        '/splash',
        (r) => false,
      );
    } else {
      final errorMsg = authProvider.error ?? t.login_failed;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(errorMsg)));
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
                height: 156,
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [Color(0xFFDDE7FF), Color(0xFFCCF5DD)],
                  ),
                ),
                child: Center(
                  child: Image.asset(
                    "assets/wave_up_logo.png",
                    height: 38.42,
                    fit: BoxFit.contain,
                  ),
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
                          /* TODO: Forgot password */
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
