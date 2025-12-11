import 'package:wa_blast/env.dart';
import 'main_common.dart';

void main() {
  const flavorStr = String.fromEnvironment('FLAVOR', defaultValue: 'prod');
  final flavor = flavorStr.toLowerCase() == 'prod' ? Flavor.prod : Flavor.dev;

  final base = flavor == Flavor.prod
      ? 'https://wave-api.eon.id'
      : 'https://api.wave.id';

  Env.setup(flavor: flavor, apiBaseUrl: base);
  Env.debugPrintEnv(' @main');

  startApp();
}
