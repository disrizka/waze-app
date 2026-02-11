import 'package:wa_blast/env.dart';
import 'main_common.dart';

Future<void> main() async {
  const flavorStr = String.fromEnvironment('FLAVOR', defaultValue: 'prod');
  final flavor = flavorStr.toLowerCase() == 'prod' ? Flavor.prod : Flavor.dev;

  final base = flavor == Flavor.prod
      ? 'https://wave-api.eon.id'
      : 'https://wave-api.eon.id';

  Env.setup(flavor: flavor, apiBaseUrl: base);
  Env.debugPrintEnv(' @main');

  await startApp();
}
