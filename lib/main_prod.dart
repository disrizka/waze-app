import 'package:wa_blast/env.dart';
import 'main_common.dart';

void main() {
  Env.setup(
    flavor: Flavor.prod,
    apiBaseUrl: 'https://api.wave-up.example', // <-- ganti sesuai prod
  );
  startApp();
}
