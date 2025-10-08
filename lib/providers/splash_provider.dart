import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:http/http.dart' as http;

import 'auth_provider.dart';

class SplashProvider with ChangeNotifier {
  bool _deeplinkInProgress = false;
  bool get deeplinkInProgress => _deeplinkInProgress;
  set deeplinkInProgress(bool v) {
    if (_deeplinkInProgress == v) return;
    _deeplinkInProgress = v;
    notifyListeners();
  }

  bool _didNavigate = false;

  Future<void> handleAutoLogin(BuildContext context) async {
    // Kalau Splash bukan yang paling atas, jangan apa-apa.
    final route = ModalRoute.of(context);
    if (route?.isCurrent != true) return;

    // Kalau deeplink sedang bekerja atau sudah navigasi, stop.
    if (_deeplinkInProgress || _didNavigate) return;

    final auth = Provider.of<AuthProvider>(context, listen: false);

    // Kita jalankan 2 hal paralel: autoLogin & cek koneksi super-cepat (opsional)
    Future<void> autoLoginFut() async {
      // Batasi waktu tryAutoLogin agar tidak ngegantung.
      // Misal 2 detik (atur sesuai kebutuhan).
      await auth
          .tryAutoLogin(context)
          .timeout(const Duration(seconds: 2), onTimeout: () {});
    }

    Future<bool> quickOnlineCheck() async {
      // Opsional: ping super ringan dg timeout 800–1200ms,
      // atau skip total dan andalkan error dari tryAutoLogin.
      try {
        final resp = await http
            .head(Uri.parse('https://www.google.com'))
            .timeout(const Duration(milliseconds: 1200));
        return resp.statusCode < 500;
      } catch (_) {
        return false;
      }
    }

    // Mulai paralel tanpa saling menunggu
    final autoLogin = autoLoginFut();
    final online = quickOnlineCheck();

    // Tunggu autoLogin selesai atau 1.5 detik max supaya Splash tidak lama
    await Future.any([
      autoLogin,
      Future.delayed(const Duration(milliseconds: 1500)),
    ]);

    // Jika selama menunggu, deeplink masuk / sudah navigasi / route berubah, stop.
    if (ModalRoute.of(context)?.isCurrent != true ||
        _deeplinkInProgress ||
        _didNavigate) {
      return;
    }

    // Keputusan navigasi
    final hasToken = (auth.accessToken != null && auth.accessToken!.isNotEmpty);
    final isActivated = auth.isActivated;

    // Kalau tidak ada token dan juga terdeteksi offline cepat, baru tampilkan dialog.
    // (Kalau ada token, kita langsung coba masuk; kalau online tidak pasti, tetap lanjut.)
    if (!hasToken && !(await online)) {
      final rootNav = Navigator.of(context, rootNavigator: true);
      await showDialog(
        context: rootNav.context,
        barrierDismissible: false,
        builder: (dCtx) => const AlertDialog(
          title: Text('Tidak Ada Koneksi'),
          content: Text('Periksa koneksi internet Anda dan coba lagi.'),
        ),
      );
      // Setelah dialog, cek lagi guard
      if (ModalRoute.of(context)?.isCurrent != true ||
          _deeplinkInProgress ||
          _didNavigate) {
        return;
      }
    }

    // Final guard
    if (ModalRoute.of(context)?.isCurrent != true ||
        _deeplinkInProgress ||
        _didNavigate) {
      return;
    }

    _didNavigate = true;
    final rootNav = Navigator.of(context, rootNavigator: true);
    if (hasToken && isActivated) {
      rootNav.pushNamedAndRemoveUntil('/home', (r) => false);
    } else {
      rootNav.pushNamedAndRemoveUntil('/login', (r) => false);
    }
  }

  void resetNavigationGuards() {
    _didNavigate = false;
  }
}
