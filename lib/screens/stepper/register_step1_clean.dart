import 'dart:io';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:wa_blast/providers/auth_provider.dart';

class RegisterStep1Clean extends StatefulWidget {
  const RegisterStep1Clean({
    super.key,
    required this.onSuccessNext,
    this.onTapLogin,
  });

  final VoidCallback onSuccessNext;
  final VoidCallback? onTapLogin;

  @override
  State<RegisterStep1Clean> createState() => _RegisterStep1CleanState();
}

class _RegisterStep1CleanState extends State<RegisterStep1Clean> {
  final _formKey = GlobalKey<FormState>();
  final _emailC = TextEditingController();
  final _passwordC = TextEditingController();
  bool _showPwd = false;

  // device & fcm
  String _deviceId = '';
  String _deviceName = '';
  String _fcmToken = '';
  bool _initDone = false;

  @override
  void initState() {
    super.initState();
    _initDeviceAndFcm();
  }

  Future<void> _initDeviceAndFcm() async {
    try {
      final info = DeviceInfoPlugin();
      if (Platform.isAndroid) {
        final a = await info.androidInfo;
        _deviceId = a.id ?? ''; // id bisa null pada sebagian device
        _deviceName = '${a.manufacturer} ${a.model}'.trim();
      } else if (Platform.isIOS) {
        final i = await info.iosInfo;
        _deviceId = i.identifierForVendor ?? '';
        _deviceName = '${i.name} (${i.systemName} ${i.systemVersion})';
      } else {
        _deviceId = 'unknown_device';
        _deviceName = 'unknown';
      }
    } catch (_) {
      _deviceId = 'unknown_device';
      _deviceName = 'unknown';
    }

    try {
      _fcmToken = (await FirebaseMessaging.instance.getToken()) ?? '';
    } catch (_) {
      _fcmToken = '';
    }

    if (mounted) setState(() => _initDone = true);
  }

  @override
  void dispose() {
    _emailC.dispose();
    _passwordC.dispose();
    super.dispose();
  }

  OutlineInputBorder _border(Color c) => OutlineInputBorder(
    borderRadius: BorderRadius.circular(10),
    borderSide: BorderSide(color: c, width: 1),
  );

  Future<void> _onNext() async {
    if (!_formKey.currentState!.validate()) return;

    // optional: cegah submit sebelum init selesai
    if (!_initDone) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Menyiapkan perangkat...')));
      return;
    }

    final auth = context.read<AuthProvider>();
    final ok = await auth.registerStep1(
      email: _emailC.text.trim(),
      password: _passwordC.text,
      referralCode: '', // jika ada field di UI, isi dari situ
      deviceId: _deviceId,
      deviceName: _deviceName,
      fcmToken: _fcmToken,
    );

    if (!mounted) return;

    if (ok) {
      // Step 1 sukses → token+data sudah dipersist → lanjut ke Step 2
      widget.onSuccessNext();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(auth.error ?? 'Register Step 1 gagal')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    const borderGray = Color(0xFFE5E7EB);
    const hintGray = Color(0xFF9CA3AF);
    const buttonBlue = Color(0xFF4069E6);

    final loading = context.watch<AuthProvider>().isLoading;

    return Form(
      key: _formKey,
      child: Column(
        key: const ValueKey('content-step1'),
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ===== Email =====
          const Text('Email', style: TextStyle(fontWeight: FontWeight.w600)),
          const SizedBox(height: 6),
          TextFormField(
            controller: _emailC,
            keyboardType: TextInputType.emailAddress,
            decoration: InputDecoration(
              hintText: 'E.g user0001@gmail.com',
              hintStyle: const TextStyle(color: hintGray),
              filled: true,
              fillColor: Colors.white,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 14,
                vertical: 14,
              ),
              enabledBorder: _border(borderGray),
              focusedBorder: _border(buttonBlue),
              border: _border(borderGray),
            ),
            validator: (v) {
              if (v == null || v.trim().isEmpty) return 'Email wajib diisi';
              final ok = RegExp(r'^\S+@\S+\.\S+$').hasMatch(v.trim());
              if (!ok) return 'Format email tidak valid';
              return null;
            },
          ),

          const SizedBox(height: 16),

          const Text('Password', style: TextStyle(fontWeight: FontWeight.w600)),
          const SizedBox(height: 6),
          TextFormField(
            controller: _passwordC,
            obscureText: !_showPwd,
            decoration: InputDecoration(
              hintText: '••••••••',
              hintStyle: const TextStyle(color: hintGray, fontSize: 18),
              filled: true,
              fillColor: Colors.white,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 14,
                vertical: 14,
              ),
              enabledBorder: _border(borderGray),
              focusedBorder: _border(buttonBlue),
              suffixIcon: IconButton(
                icon: Icon(
                  _showPwd ? Icons.visibility_off : Icons.visibility,
                  color: hintGray,
                ),
                onPressed: () => setState(() => _showPwd = !_showPwd),
              ),
            ),
            validator: (v) {
              if (v == null || v.isEmpty) return 'Password wajib diisi';
              if (v.length < 6) return 'Minimal 6 karakter';
              return null;
            },
          ),

          const SizedBox(height: 22),

          // ===== Next button =====
          SizedBox(
            width: double.infinity,
            height: 52,
            child: ElevatedButton(
              onPressed: loading ? null : _onNext,
              style: ElevatedButton.styleFrom(
                backgroundColor: buttonBlue,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                elevation: 0,
              ),
              child: loading
                  ? const SizedBox(
                      height: 22,
                      width: 22,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Text(
                      'Next',
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
                    ),
            ),
          ),

          const SizedBox(height: 16),

          // ===== Footer =====
          Center(
            child: Wrap(
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                const Text(
                  "Don’t have account? ",
                  style: TextStyle(color: Colors.black87, fontSize: 13),
                ),
                InkWell(
                  onTap: widget.onTapLogin,
                  borderRadius: BorderRadius.circular(4),
                  child: const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 2, vertical: 2),
                    child: Text(
                      'Login Now',
                      style: TextStyle(
                        color: buttonBlue,
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
