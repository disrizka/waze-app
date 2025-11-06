import 'dart:io';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';

bool _askingInProgress = false;
bool _askedOnceThisRun = false;
bool? _dialogShownCache;

bool get _shouldAskNotification {
  if (Platform.isAndroid) return true; // Android 13+ pakai POST_NOTIFICATIONS
  return Platform.isIOS;
}

/// Cek izin inti — tanpa izin foto/video untuk Android
Future<bool> _areCorePermissionsGrantedFast({
  Duration timeout = const Duration(milliseconds: 800),
}) async {
  Future<PermissionStatus> safeStatus(Permission p) async {
    try {
      return await p.status;
    } catch (_) {
      return PermissionStatus.denied;
    }
  }

  final futures = <Future>[];

  if (_shouldAskNotification) futures.add(safeStatus(Permission.notification));
  futures.add(safeStatus(Permission.camera));

  // hanya iOS yang cek photos
  if (Platform.isIOS) futures.add(safeStatus(Permission.photos));

  List results;
  try {
    results = await Future.wait(futures).timeout(timeout);
  } on TimeoutException {
    return false;
  }

  int i = 0;
  PermissionStatus? notif, cam, photos;

  if (_shouldAskNotification) notif = results[i++] as PermissionStatus;
  cam = results[i++] as PermissionStatus;
  if (Platform.isIOS) photos = results[i++] as PermissionStatus;

  final notifOK =
      !_shouldAskNotification || (notif!.isGranted || notif.isLimited);
  final camOK = cam!.isGranted;
  final photosOK = Platform.isIOS
      ? (photos!.isGranted || photos.isLimited)
      : true; // Android otomatis true karena pakai photo picker

  return notifOK && camOK && photosOK;
}

/// Minta izin — tanpa photos/storage di Android
Future<void> _requestAllCorePermissionsLight({
  Duration gap = const Duration(milliseconds: 250),
  Duration watchdog = const Duration(seconds: 6),
}) async {
  Future<void> pause() => Future.delayed(gap);

  Future<void> doRequests() async {
    if (_shouldAskNotification &&
        !await Permission.notification.isPermanentlyDenied) {
      await Permission.notification.request();
      await pause();
    }

    if (!await Permission.camera.isPermanentlyDenied) {
      await Permission.camera.request();
      await pause();
    }

    // hanya iOS yang minta photos
    if (Platform.isIOS) {
      if (!await Permission.photos.isPermanentlyDenied) {
        await Permission.photos.request();
        await pause();
      }
    }
  }

  await Future.any([doRequests(), Future.delayed(watchdog)]);
}

void scheduleAskCorePermissions(BuildContext context) {
  if (_askedOnceThisRun || _askingInProgress) return;
  _askingInProgress = true;

  WidgetsBinding.instance.addPostFrameCallback((_) async {
    await Future.delayed(const Duration(milliseconds: 300));
    if (!context.mounted) {
      _askingInProgress = false;
      return;
    }

    try {
      _dialogShownCache ??= await _readDialogShownFlagSafe();

      if (await _areCorePermissionsGrantedFast()) {
        _askedOnceThisRun = true;
        _askingInProgress = false;
        return;
      }

      if ((_dialogShownCache ?? false) == false) {
        final ok = await showCorePermissionsDialog(context);
        unawaited(_writeDialogShownFlagSafe(true));

        if (ok == true) {
          await WidgetsBinding.instance.endOfFrame;
          await Future.delayed(const Duration(milliseconds: 80));
          await _requestAllCorePermissionsLight();

          if (!await _areCorePermissionsGrantedFast() && context.mounted) {
            await showOpenSettingsSheet(context);
          }
        }
      }
    } catch (_) {
      // abaikan error
    } finally {
      _askedOnceThisRun = true;
      _askingInProgress = false;
    }
  });
}

Future<bool?> _readDialogShownFlagSafe() async {
  try {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool('corePermDialogShown') ?? false;
  } catch (_) {
    return false;
  }
}

Future<void> _writeDialogShownFlagSafe(bool v) async {
  try {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('corePermDialogShown', v);
  } catch (_) {}
}

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
    barrierDismissible: true,
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
                'Receive updates and messages.',
              ),
              const SizedBox(height: 10),
              point(
                Icons.photo_camera_rounded,
                'Camera',
                'Take photos directly for logo/check-in.',
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
              'Buka Pengaturan untuk mengizinkan akses Notifikasi atau Kamera.',
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
