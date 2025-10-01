import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:http/http.dart' as http;
import 'package:wa_blast/screens/register/link/link_register_stepper_wrapper.dart';
import 'auth_provider.dart';

class SplashProvider with ChangeNotifier {
  Future<void> handleAutoLogin(BuildContext context) async {
    final isConnected = await _checkRealInternetConnection();

    if (!isConnected) {
      _showNoConnectionDialog(context);
      return;
    }

    await Future.delayed(const Duration(seconds: 1));

    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    await authProvider.tryAutoLogin(context);

    final hasToken =
        authProvider.accessToken != null &&
        authProvider.accessToken!.isNotEmpty;
    final isActivated = authProvider.isActivated;

    if (hasToken && isActivated) {
      Navigator.pushReplacementNamed(context, '/home');
      //tambahin nama organisasi di welcome page, wave up penulisan digabung jadi WaveUp
      // harus ada pengchekan kalau belum login harus login masukkan password dulu
      // ada api untuk accept invitation di semua case

      // Navigator.push(
      //   context,
      //   MaterialPageRoute(
      //     builder: (_) => LinkRegisterStepperWrapper(
      //       inviteEmail: "userwave@mail.com",
      //       inviteToken: "BhbshbdhYS&SHUKE.JHAShjjdihiudgigd",
      //       businessName: "PT. Coffee Roasters",
      //       businessLogo:
      //           "https://images.unsplash.com/photo-1509042239860-f550ce710b93?w=200", // ✅ dummy logo internet
      //     ),
      //   ),
      // );
    } else {
      Navigator.pushReplacementNamed(context, '/login');
    }
  }

  Future<bool> _checkRealInternetConnection() async {
    try {
      final response = await http
          .get(Uri.parse('https://www.google.com'))
          .timeout(const Duration(seconds: 5));
      return response.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  void _showNoConnectionDialog(BuildContext context) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => AlertDialog(
        title: const Text('Tidak Ada Koneksi'),
        content: const Text('Periksa koneksi internet Anda dan coba lagi.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }
}
