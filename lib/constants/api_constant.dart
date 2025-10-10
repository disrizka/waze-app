import 'package:flutter/material.dart';
import 'package:wa_blast/env.dart';

class ApiConstant {
  static String get baseUrl {
    // Log sekali setiap akses (boleh hapus setelah root cause ketemu)
    debugPrint(
      '[ApiConstant] baseUrl dibaca → ${Env.isInitialized ? Env.apiBaseUrl : '(ENV BELUM SET)'}',
    );
    return Env.apiBaseUrl;
  }

  static const String basicAuth =
      'Basic bWFudWFsX2FwcDpkZGY0YjY1OTE2NTc2N2E2Mjc4NGY5NGM0ZWU1NmQwNzVkYjEwYzk0NTBkYTVjZjgxYjZhZjdiOWY1NmYxZWY3';
}
