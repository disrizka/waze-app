import 'dart:io';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shimmer/shimmer.dart';

import 'package:wa_blast/app_nav.dart';
import 'package:wa_blast/providers/splash_provider.dart';
import 'package:wa_blast/providers/hr_provider.dart';
import 'package:wa_blast/providers/auth_provider.dart';

class LinkRegisterLoginStep extends StatefulWidget {
  const LinkRegisterLoginStep({
    super.key,
    required this.inviteEmail,
    required this.inviteToken,
  });

  final String inviteEmail;
  final String inviteToken;

  @override
  State<LinkRegisterLoginStep> createState() => _LinkRegisterLoginStepState();
}

class _LinkRegisterLoginStepState extends State<LinkRegisterLoginStep> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isPasswordVisible = false;

  @override
  void initState() {
    super.initState();
    // Prefill email dari undangan
    _emailController.text = widget.inviteEmail;
  }

  Future<void> _handleLoginThenAccept() async {
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

    final authProvider = context.read<AuthProvider>();
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
      final errorMsg = authProvider.error ?? 'Login gagal';
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(errorMsg)));
      return;
    }

    // ====== Sudah login → langsung accept undangan (firstname/last_name = null) ======
    final hr = context.read<HrProvider>();
    final accepted = await hr.acceptInviteAfterLoginWithDevice(
      context: context,
      token: widget.inviteToken,
    );

    if (!mounted) return;

    if (accepted) {
      final sp = appNavigatorKey.currentContext?.read<SplashProvider>();
      sp?.resetNavigationGuards();
      sp?.abortDeepLink();

      appNavigatorKey.currentState?.pushNamedAndRemoveUntil(
        '/splash',
        (r) => false,
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
    final isLoading = context.watch<AuthProvider>().isLoading;

    return Padding(
      padding: EdgeInsets.only(
        top: 20,
        left: 24,
        right: 24,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            "Username",
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
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
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _passwordController,
            obscureText: !_isPasswordVisible,
            decoration: InputDecoration(
              hintText: "Fill your password here",
              suffixIcon: IconButton(
                icon: Icon(
                  _isPasswordVisible ? Icons.visibility_off : Icons.visibility,
                ),
                onPressed: () =>
                    setState(() => _isPasswordVisible = !_isPasswordVisible),
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
                // TODO: Forgot password (optional)
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
                    onPressed: _handleLoginThenAccept,
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
        ],
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
