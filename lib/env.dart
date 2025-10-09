// lib/env.dart
import 'package:flutter/foundation.dart';

enum Flavor { dev, prod }

class Env {
  static Flavor? _flavor;
  static String? _apiBaseUrl;

  static bool get isInitialized => _flavor != null && _apiBaseUrl != null;
  static bool get isDev => flavor == Flavor.dev;
  static bool get isProd => flavor == Flavor.prod;

  static Flavor get flavor {
    _ensureInitialized('Env.flavor');
    return _flavor!;
  }

  static String get apiBaseUrl {
    _ensureInitialized('Env.apiBaseUrl');
    return _apiBaseUrl!;
  }

  static void _ensureInitialized(String who) {
    if (!isInitialized) {
      final st = StackTrace.current.toString();
      debugPrintSynchronously('❌ [$who] Env belum di-setup!\n$st');
      throw StateError('Env digunakan sebelum Env.setup()');
    }
  }

  static void setup({required Flavor flavor, required String apiBaseUrl}) {
    final st = StackTrace.current.toString();

    // === Enforce dart-define (kalau kamu pakai launch.json yg pakai FLAVOR=dev/prod) ===
    const define = String.fromEnvironment('FLAVOR', defaultValue: '');
    if (define.isNotEmpty) {
      final expected = define.toLowerCase();
      final incoming = flavor.name.toLowerCase();
      if (expected != incoming) {
        debugPrintSynchronously(
          '❌ [Env.setup] MISMATCH dengan --dart-define FLAVOR=$define '
          '(incoming=${flavor.name})\n$st',
        );
        throw StateError('Env.setup mismatch dengan --dart-define');
      }
    }

    if (isInitialized) {
      if (_flavor == flavor && _apiBaseUrl == apiBaseUrl) {
        debugPrintSynchronously(
          'ℹ️ [Env.setup] duplikat (nilai sama) → diabaikan',
        );
        return;
      }
      debugPrintSynchronously(
        '❌ [Env.setup] SETUP GANDA dengan NILAI BERBEDA!\n'
        'existing=${_flavor?.name} $_apiBaseUrl\n'
        'incoming=${flavor.name} $apiBaseUrl\n$st',
      );
      throw StateError('Env.setup dipanggil ulang dengan nilai berbeda.');
    }

    // 🚨 LOG PANGGILAN + STACKTRACE, SUPAYA TAU PELAKU
    debugPrintSynchronously(
      '🌐 [Env.setup] incoming=${flavor.name} $apiBaseUrl\n$st',
    );

    _flavor = flavor;
    _apiBaseUrl = apiBaseUrl;
    debugPrintSynchronously('✅ [Env] setup → ${flavor.name} $apiBaseUrl');
  }

  static void debugPrintEnv([String where = '']) {
    if (!isInitialized) {
      debugPrintSynchronously('⚠️ [Env$where] belum initialized');
      return;
    }
    debugPrintSynchronously(
      '🔧 [Env$where] flavor=${_flavor!.name} api=$_apiBaseUrl',
    );
  }
}
