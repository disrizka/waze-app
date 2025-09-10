import 'dart:io';
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';

bool _askedCorePermsOnce = false;

/// Cek semua izin yang kita butuh (notifikasi, kamera, galeri/storage).
Future<bool> _areCorePermissionsGranted() async {
  final notif = await Permission.notification.status;
  final cam = await Permission.camera.status;
  final photos = await Permission.photos.status; // iOS & Android 13+
  final store = await Permission.storage.status; // Android ≤12

  final notiOK = notif.isGranted || notif.isLimited;
  final camOK = cam.isGranted;
  // anggap OK jika photos granted/limited (A13+/iOS), atau storage granted (legacy)
  final galOK = photos.isGranted || photos.isLimited || store.isGranted;

  return notiOK && camOK && galOK;
}

/// Minta semua izin inti, dengan jeda kecil antar sheet OS biar mulus.
Future<void> _requestAllCorePermissions({
  Duration gap = const Duration(milliseconds: 500),
}) async {
  Future<void> pause() => Future.delayed(gap);

  // 1) Notifikasi
  if (!await Permission.notification.isPermanentlyDenied) {
    await Permission.notification.request();
    await pause();
  }

  // 2) Kamera
  if (!await Permission.camera.isPermanentlyDenied) {
    await Permission.camera.request();
    await pause();
  }

  // 3) Galeri / Storage
  if (Platform.isIOS) {
    if (!await Permission.photos.isPermanentlyDenied) {
      await Permission.photos.request();
      await pause();
    }
  } else {
    // Android 13+: READ_MEDIA_IMAGES → photos
    if (!await Permission.photos.isPermanentlyDenied) {
      await Permission.photos.request();
      await pause();
    }
    // Android ≤12: storage legacy
    if (!await Permission.storage.isPermanentlyDenied) {
      await Permission.storage.request();
      await pause();
    }
  }
}

/// Panggil dari initState: tampilkan dialog sekali, lalu minta izin SETELAH dialog ditutup.
Future<void> maybeAskCorePermissions(BuildContext context) async {
  debugPrint('[perm] maybeAskCorePermissions called');
  if (_askedCorePermsOnce) return;
  _askedCorePermsOnce = true;

  final prefs = await SharedPreferences.getInstance();
  final shown = prefs.getBool('corePermDialogShown') ?? false;

  if (await _areCorePermissionsGranted()) return;

  if (!shown && context.mounted) {
    final ok = await showCorePermissionsDialog(
      context,
    ); // dialog pop true/false
    debugPrint('[perm] dialog result = $ok');
    await prefs.setBool('corePermDialogShown', true);

    if (ok == true) {
      // Pastikan frame pop selesai, baru minta izin (hindari nabrak animasi dialog)
      await WidgetsBinding.instance.endOfFrame;
      await Future.delayed(const Duration(milliseconds: 80));

      debugPrint('[perm] requesting…');
      await _requestAllCorePermissions();
      debugPrint('[perm] request finished');

      // Jika masih ada yang permanen ditolak, arahkan ke Settings
      if (!await _areCorePermissionsGranted() && context.mounted) {
        await showOpenSettingsSheet(context);
      }
    }
  }
}

/// ==== DIALOG TEMA BIRU (seperti versi sebelumnya) ====
Future<bool?> showCorePermissionsDialog(BuildContext context) {
  const brandBlue = Color(0xFF4069E6);
  const brandBlueSoft = Color(0xFFEFF4FF);
  const textMain = Color(0xFF0F172A);
  const textSub = Color(0xFF64748B);

  Widget point(IconData icon, String title, String desc) {
    return Row(
      children: [
        Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: brandBlueSoft,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, color: brandBlue),
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
                  color: textMain,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                desc,
                style: const TextStyle(
                  fontSize: 12.5,
                  color: textSub,
                  height: 1.35,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  return showDialog<bool>(
    context: context,
    barrierDismissible: true, // boleh ditutup di luar
    useRootNavigator: true, // konsisten dengan pop
    builder: (ctx) {
      return Dialog(
        backgroundColor: Colors.white,
        insetPadding: const EdgeInsets.symmetric(horizontal: 32, vertical: 24),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 28, 20, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Pakai logo/ilustrasi kamu kalau ada
              Image.asset(
                'assets/wave_up_logo.png',
                height: 20,
                fit: BoxFit.contain,
              ),
              const SizedBox(height: 4),
              const Text(
                'Allow Access',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: textMain,
                ),
              ),
              const SizedBox(height: 6),
              const Text(
                'To provide the best experience, we need access to:',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 13.5,
                  height: 1.4,
                  color: textSub,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 16),
              point(
                Icons.notifications_active_rounded,
                'Notifications',
                'Receive updates and important messages.',
              ),
              const SizedBox(height: 10),
              point(
                Icons.photo_camera_rounded,
                'Camera',
                'Take photos directly for your logo/check-in.',
              ),
              const SizedBox(height: 10),
              point(
                Icons.photo_library_rounded,
                'Gallery/Photos',
                'Choose or save images from your device.',
              ),
              const SizedBox(height: 22),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () =>
                          Navigator.of(ctx, rootNavigator: true).pop(false),
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: brandBlue),
                        foregroundColor: brandBlue,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: const Text(
                        'Not now',
                        style: TextStyle(fontWeight: FontWeight.w700),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () =>
                          Navigator.of(ctx, rootNavigator: true).pop(true),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: brandBlue,
                        foregroundColor: Colors.white,
                        elevation: 0,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: const Text(
                        'Allow now',
                        style: TextStyle(fontWeight: FontWeight.w700),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      );
    },
  );
}

/// Bottom sheet untuk arahkan user buka Settings jika ada izin yang ditolak permanen.
Future<void> showOpenSettingsSheet(BuildContext context) {
  const brandBlue = Color(0xFF4069E6);

  return showModalBottomSheet(
    context: context,
    useRootNavigator: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
    ),
    builder: (ctx) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 48,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.black12,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 12),
            const Text(
              'Beberapa izin ditolak permanen',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            const Text(
              'Buka Pengaturan untuk mengizinkan akses Notifikasi, Kamera, atau Galeri.',
              style: TextStyle(fontSize: 13),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: brandBlue),
                      minimumSize: const Size.fromHeight(44),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    onPressed: () =>
                        Navigator.of(ctx, rootNavigator: true).pop(),
                    child: const Text('Tutup'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: brandBlue,
                      foregroundColor: Colors.white,
                      minimumSize: const Size.fromHeight(44),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    onPressed: () async {
                      await openAppSettings();
                      if (ctx.mounted)
                        Navigator.of(ctx, rootNavigator: true).pop();
                    },
                    child: const Text('Buka Pengaturan'),
                  ),
                ),
              ],
            ),
          ],
        ),
      );
    },
  );
}
