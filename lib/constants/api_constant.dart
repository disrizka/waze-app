import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:wa_blast/env.dart';

class ApiConstant {
  /// Ambil Base URL dari Env (dimuat lewat startApp)
  static String get baseUrl {
    debugPrint(
      '[ApiConstant] baseUrl dibaca → ${Env.isInitialized ? Env.apiBaseUrl : '(ENV BELUM SET)'}',
    );
    return Env.apiBaseUrl;
  }

  /// Ambil Basic Auth dari .env (fallback otomatis)
  static String get basicAuth {
    final direct = dotenv.env['BASIC_AUTH']?.trim();

    // Jika BASIC_AUTH langsung tersedia (sudah mengandung "Basic ...")
    if (direct != null && direct.isNotEmpty) {
      // Kalau user hanya isi raw base64 tanpa "Basic ", tambahkan prefix
      debugPrint('[ApiConstant] $direct');
      return 'Basic $direct';
    }

    // Fallback terakhir — supaya tidak null
    debugPrint('[ApiConstant] ⚠️ BASIC_AUTH tidak ditemukan di .env');
    return 'Basic REPLACE_ME';
  }
}
