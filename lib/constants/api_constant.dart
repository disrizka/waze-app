import 'package:wa_blast/env.dart';

class ApiConstant {
  static String get baseUrl {
    if (Env.isDev) {
      return 'https://wave-api.eon.id';
    } else {
      return 'https://api.wave.id';
    }
  }

  static const String basicAuth =
      'Basic bWFudWFsX2FwcDpkZGY0YjY1OTE2NTc2N2E2Mjc4NGY5NGM0ZWU1NmQwNzVkYjEwYzk0NTBkYTVjZjgxYjZhZjdiOWY1NmYxZWY3';
}
