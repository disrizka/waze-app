// lib/env.dart
enum Flavor { dev, prod }

class Env {
  static late final Flavor flavor;
  static late final String apiBaseUrl;

  static bool get isDev => flavor == Flavor.dev;
  static bool get isProd => flavor == Flavor.prod;

  static void setup({required Flavor flavor, required String apiBaseUrl}) {
    Env.flavor = flavor;
    Env.apiBaseUrl = apiBaseUrl;
  }
}
