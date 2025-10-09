import 'dart:io';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shimmer/shimmer.dart';
import 'package:wa_blast/app_nav.dart';
import 'package:wa_blast/providers/splash_provider.dart';
import 'package:wa_blast/utils/core_permission.dart';
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

  static const _kPermFlag = 'permissionsPromptShown';

  @override
  void initState() {
    super.initState();
    scheduleAskCorePermissions(context);
  }

  // ====== END PERMISSIONS ======

  Future<void> _handleLogin() async {
    final email = _emailController.text.trim();
    final password = _passwordController.text;

    if (email.isEmpty || password.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Username dan password tidak boleh kosong'),
        ),
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
    if (success) {
      final sp = appNavigatorKey.currentContext?.read<SplashProvider>();
      sp?.resetNavigationGuards();
      sp?.abortDeepLink();
      appNavigatorKey.currentState?.pushNamedAndRemoveUntil(
        '/splash',
        (r) => false,
      );
    } else {
      final errorMsg = authProvider.error ?? 'Login gagal';
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
                    const Text(
                      "Username",
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: _emailController,
                      decoration: InputDecoration(
                        hintText: "E.g user0001@gmail.com",
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(6),
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                    const Text(
                      "Password",
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: _passwordController,
                      obscureText: !_isPasswordVisible,
                      decoration: InputDecoration(
                        hintText: "Fill your password here",
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
                        child: const Text(
                          "Forgot password?",
                          style: TextStyle(
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
                              child: const Text(
                                "Login",
                                style: TextStyle(
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
                        const Text("Don’t have account? "),
                        GestureDetector(
                          onTap: () =>
                              Navigator.pushNamed(context, '/register'),
                          child: const Text(
                            "Register Now",
                            style: TextStyle(
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
              child: const Text(
                "Logging in…",
                style: TextStyle(
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
