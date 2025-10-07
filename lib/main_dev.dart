import 'package:wa_blast/env.dart';
import 'main_common.dart';

void main() {
  Env.setup(
    flavor: Flavor.dev,
    apiBaseUrl: 'https://wave-api.eon.id', // <-- ganti sesuai dev
  );
  startApp();
}
