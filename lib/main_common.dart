import 'dart:async';
import 'dart:io';
import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

// Firebase
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:wa_blast/app_nav.dart';
import 'package:wa_blast/env.dart';
import 'package:wa_blast/l10n/app_localizations.dart';
import 'package:wa_blast/providers/locale_provider.dart';
import 'package:wa_blast/providers/role_provider.dart';
import 'package:wa_blast/providers/store_provider.dart';
import 'package:wa_blast/screens/edit_profile_screen.dart';
import 'package:wa_blast/screens/hr/manage_hr_screen.dart';
import 'package:wa_blast/screens/hr/role_screen.dart';
import 'package:wa_blast/screens/manage_report_screen.dart';
import 'package:wa_blast/screens/products/product_stock_inventory.dart';
import 'package:wa_blast/screens/purchase/add_purchase_screen.dart';
import 'package:wa_blast/screens/purchase/supplier_detail_screen.dart';
import 'package:wa_blast/screens/sales/costumer_screen.dart';
import 'package:wa_blast/screens/sales/manage_sales_screen.dart';
import 'package:wa_blast/screens/sales/sales_stepper_wrapper.dart';
import 'package:wa_blast/screens/sales_report_detail_screen.dart';
import 'package:wa_blast/screens/sales_report_screen.dart';
import 'package:wa_blast/screens/settings/business/business_settings_screen.dart';
import 'package:wa_blast/screens/settings/thermal_printer_setting.dart';
import 'package:wa_blast/screens/store_list_screen.dart';
import 'package:wa_blast/services/deep_link_service.dart';
import 'firebase_options.dart';

// providers
import 'package:wa_blast/providers/auth_provider.dart';
import 'package:wa_blast/providers/splash_provider.dart';
import 'package:wa_blast/providers/chat_provider.dart';
import 'package:wa_blast/providers/chat_detail_provider.dart';
import 'package:wa_blast/providers/product_provider.dart';
import 'package:wa_blast/providers/purchase_provider.dart';
import 'package:wa_blast/providers/edit_profile_provider.dart';
import 'package:wa_blast/providers/hr_provider.dart';
import 'package:wa_blast/providers/sales_provider.dart';

// screens
import 'package:wa_blast/screens/splash_screen.dart';
import 'package:wa_blast/screens/login_screen.dart';
import 'package:wa_blast/screens/register/register_screen_wrapper.dart';
import 'package:wa_blast/screens/main_wrapper.dart';
import 'package:wa_blast/screens/products/manage_product.dart';
import 'package:wa_blast/screens/products/product_screen.dart';
import 'package:wa_blast/screens/products/product_detail_screen.dart';
import 'package:wa_blast/screens/products/category_list_screen.dart';
import 'package:wa_blast/screens/products/brand_list_screen.dart';
import 'package:wa_blast/screens/purchase/manage_purchase_screen.dart';
import 'package:wa_blast/screens/purchase/purchase_screen.dart';
import 'package:wa_blast/screens/purchase/supplier_list_screen.dart';
import 'package:wa_blast/screens/detail_purchase_screen.dart';
import 'package:wa_blast/screens/hr/hr_screen.dart';

Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
  } catch (_) {}
  debugPrint('BG notification: ${message.notification?.title}');
}

void startApp() async {
  WidgetsFlutterBinding.ensureInitialized();

  await _initEnvSafe();

  Env.debugPrintEnv(' @startApp');

  BuildDiag.printSummary(' @startApp');

  runApp(const _AppShell());
}

Future<void> _initEnvSafe() async {
  final candidates = <String>[
    BuildDiag.isProd ? '.env.prod' : '.env.dev',
    '.env',
  ];

  bool loaded = false;

  for (final file in candidates) {
    try {
      await dotenv.load(fileName: file);
      debugPrint('✅ dotenv loaded: $file');
      loaded = true;
      break;
    } on FileSystemException catch (_) {
      // File tidak ditemukan → lanjut ke file berikut
      debugPrint('⚠️ dotenv file "$file" tidak ditemukan, coba yang lain...');
    } catch (e) {
      // Error lain (parse error, permission, dsb.)
      debugPrint('⚠️ dotenv gagal load ($file): $e');
    }
  }

  if (!loaded) {
    debugPrint(
      '⚠️ Tidak ada file .env ditemukan, lanjut dengan fallback default.',
    );
  }
}

class _AppShell extends StatelessWidget {
  const _AppShell();

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthProvider(), lazy: true),
        ChangeNotifierProvider(create: (_) => SplashProvider(), lazy: true),
        ChangeNotifierProvider(create: (_) => ChatProvider(), lazy: true),
        ChangeNotifierProvider(create: (_) => ChatDetailProvider(), lazy: true),
        ChangeNotifierProvider(create: (_) => ProductProvider(), lazy: true),
        ChangeNotifierProvider(create: (_) => PurchaseProvider(), lazy: true),
        ChangeNotifierProvider(
          create: (_) => EditProfileProvider(),
          lazy: true,
        ),
        ChangeNotifierProvider(create: (_) => HrProvider(), lazy: true),
        ChangeNotifierProvider(create: (_) => SalesProvider(), lazy: true),
        ChangeNotifierProvider(create: (_) => StoreProvider(), lazy: true),
        ChangeNotifierProvider(
          create: (_) => LocaleProvider()..loadSaved(),
          lazy: false,
        ),
        ChangeNotifierProvider(create: (_) => RoleProvider(), lazy: true),
      ],
      child: const _Bootstrapper(child: MyApp()),
    );
  }
}

/// (SEMUA KODE DI BAWAH INI TETAP SAMA persis DENGAN punyamu)
class _Bootstrapper extends StatefulWidget {
  final Widget child;
  const _Bootstrapper({required this.child});

  @override
  State<_Bootstrapper> createState() => _BootstrapperState();
}

class _BootstrapperState extends State<_Bootstrapper> {
  bool _inited = false;
  late final DeepLinkService _deepLinkService = DeepLinkService();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _bootstrap();
    });
  }

  Future<void> _bootstrap() async {
    if (_inited) return;
    _inited = true;

    try {
      await Future.any([
        Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform),
        Future.delayed(const Duration(seconds: 5)),
      ]);

      FirebaseMessaging.onBackgroundMessage(
        _firebaseMessagingBackgroundHandler,
      );

      FirebaseMessaging.onMessage.listen(
        (m) => debugPrint('🔔 FG notification: ${m.notification?.title}'),
      );
      FirebaseMessaging.onMessageOpenedApp.listen(
        (m) => debugPrint('🔔 Opened from notif: ${m.notification?.title}'),
      );

      unawaited(_askNotifPermissionAndToken());

      _deepLinkService.init();
    } catch (e) {
      debugPrint('Bootstrap error: $e');
    }
  }

  @override
  void dispose() {
    _deepLinkService.dispose();
    super.dispose();
  }

  Future<void> _askNotifPermissionAndToken() async {
    try {
      await Future.delayed(const Duration(milliseconds: 400));
      await FirebaseMessaging.instance.requestPermission(
        alert: true,
        badge: true,
        sound: true,
      );
    } catch (e) {
      debugPrint('Notif/token skipped: $e');
    }
  }

  @override
  Widget build(BuildContext context) => widget.child;
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    final localeProv = Provider.of<LocaleProvider>(context, listen: true);
    final Locale? appLocale = (() {
      try {
        return localeProv.locale;
      } catch (_) {
        return null;
      }
    })();

    return MaterialApp(
      navigatorKey: appNavigatorKey,
      title: 'Wave Up',
      debugShowCheckedModeBanner: false,
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ],
      supportedLocales: AppLocalizations.supportedLocales,
      locale: appLocale,
      theme: ThemeData(
        scaffoldBackgroundColor: Colors.white,
        inputDecorationTheme: const InputDecorationTheme(
          filled: true,
          fillColor: Colors.white,
          isDense: true,
          contentPadding: EdgeInsets.symmetric(horizontal: 14, vertical: 14),
          hintStyle: TextStyle(color: Color(0xFF6B7280), fontSize: 15),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.all(Radius.circular(10)),
            borderSide: BorderSide(color: Color(0xFFE5E7EB), width: 1.4),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.all(Radius.circular(10)),
            borderSide: BorderSide(color: Color(0xFFE5E7EB), width: 1.4),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.all(Radius.circular(10)),
            borderSide: BorderSide(color: Color(0xFF4C6EF5), width: 1.6),
          ),
        ),
        pageTransitionsTheme: const PageTransitionsTheme(
          builders: {
            TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
            TargetPlatform.macOS: CupertinoPageTransitionsBuilder(),
            TargetPlatform.android: FadeUpwardsPageTransitionsBuilder(),
            TargetPlatform.fuchsia: FadeUpwardsPageTransitionsBuilder(),
            TargetPlatform.linux: FadeUpwardsPageTransitionsBuilder(),
            TargetPlatform.windows: FadeUpwardsPageTransitionsBuilder(),
          },
        ),
      ),
      initialRoute: '/splash',
      // === onGenerateRoute lengkap ===
      onGenerateRoute: (settings) {
        switch (settings.name) {
          case '/splash':
            return _platformRouteAnimated(
              settings,
              const SplashScreen(),
              android: AndroidTransition.fade,
            );

          case '/login':
            return _platformRouteAnimated(
              settings,
              const LoginScreen(),
              android: AndroidTransition.fade,
            );

          case '/register':
            return _platformRouteAnimated(
              settings,
              const RegisterWrapper(),
              android: AndroidTransition.slideRight,
            );

          case '/home':
            return _platformRouteAnimated(
              settings,
              const MainWrapper(),
              android: AndroidTransition.fade,
            );

          // ===== PRODUCT =====
          case '/product':
            return _platformRouteAnimated(
              settings,
              const ManageProductScreen(),
              android: AndroidTransition.slideRight,
            );

          case '/product/list':
            return _platformRouteAnimated(
              settings,
              const ProductScreen(),
              android: AndroidTransition.slideRight,
            );

          case '/product/list/detail':
            {
              final id = settings.arguments as String?;
              if (id == null || id.isEmpty) {
                return _platformRouteAnimated(
                  settings,
                  const _RouteErrorScreen(
                    message:
                        'Route /product/list/detail membutuhkan argumen idProduct',
                  ),
                  android: AndroidTransition.fade,
                );
              }
              return _platformRouteAnimated(
                settings,
                ProductDetailScreen(idProduct: id),
                android: AndroidTransition.slideUp,
              );
            }

          case '/product/sku/inventory':
            {
              // Argumen yang diterima bisa:
              // - String  -> dianggap idProductSKU langsung
              // - Map     -> dukung beberapa key umum:
              //              id / idProductSKU / idProductSku / skuId
              //              skuCode / code
              //              initialPrice / price (num atau String)
              final args = settings.arguments;
              String? id;
              String? skuCode;
              num? initialPrice;

              if (args is String) {
                id = args;
              } else if (args is Map) {
                final m = args.cast<Object?, Object?>();

                id =
                    (m['id'] ??
                            m['idProductSKU'] ??
                            m['idProductSku'] ??
                            m['skuId'])
                        ?.toString();

                final codeRaw = m['skuCode'] ?? m['code'];
                if (codeRaw != null) skuCode = codeRaw.toString();

                final priceRaw = m['initialPrice'] ?? m['price'];
                if (priceRaw is num) {
                  initialPrice = priceRaw;
                } else if (priceRaw is String) {
                  initialPrice = num.tryParse(priceRaw);
                }
              }

              if (id == null || id.isEmpty) {
                return _platformRouteAnimated(
                  settings,
                  const _RouteErrorScreen(
                    message:
                        'Route /product/sku/inventory membutuhkan argumen idProductSKU.',
                  ),
                  android: AndroidTransition.fade,
                );
              }

              return _platformRouteAnimated(
                settings,
                StockSkuHistory(
                  idProductSKU: id,
                  skuCode: skuCode,
                  initialPrice: initialPrice,
                ),
                android: AndroidTransition.slideUp,
              );
            }

          case '/product/category':
            return _platformRouteAnimated(
              settings,
              const CategoryListScreen(),
              android: AndroidTransition.slideRight,
            );

          case '/product/brand':
            return _platformRouteAnimated(
              settings,
              const BrandListScreen(),
              android: AndroidTransition.slideRight,
            );

          // ===== PURCHASE =====
          case '/purchase':
            return _platformRouteAnimated(
              settings,
              const ManagePurchaseScreen(),
              android: AndroidTransition.slideRight,
            );

          case '/purchase/list':
            return _platformRouteAnimated(
              settings,
              const PurchaseScreen(),
              android: AndroidTransition.slideRight,
            );

          case '/purchase/list/detail':
            {
              final args = settings.arguments;
              String? id;
              if (args is String) {
                id = args;
              } else if (args is Map) {
                id = (args['id'] ?? args['idTransaction'])?.toString();
              }
              if (id == null || id.isEmpty) {
                return _platformRouteAnimated(
                  settings,
                  const _RouteErrorScreen(
                    message:
                        'DetailPurchaseScreen membutuhkan argumen "id" (idTransaction).',
                  ),
                  android: AndroidTransition.fade,
                );
              }
              return _platformRouteAnimated(
                settings,
                const DetailPurchaseScreen(),
                android: AndroidTransition.slideUp,
              );
            }

          case '/purchase/add':
            return _platformRouteAnimated(
              settings,
              const AddPurchasePage(),
              android: AndroidTransition.slideUp,
            );

          case '/purchase/supplier':
            return _platformRouteAnimated(
              settings,
              const SupplierScreen(),
              android: AndroidTransition.slideRight,
            );

          case '/purchase/supplier/detail':
            {
              final args = settings.arguments;
              String? id;
              if (args is String) {
                id = args;
              } else if (args is Map) {
                id = (args['id'] ?? args['supplierId']) as String?;
              }
              if (id == null || id.isEmpty) {
                return _platformRouteAnimated(
                  settings,
                  const _RouteErrorScreen(
                    message:
                        'SupplierDetailScreen membutuhkan argumen "id" (supplierId).',
                  ),
                  android: AndroidTransition.fade,
                );
              }
              return _platformRouteAnimated(
                settings,
                SupplierDetailScreen(supplierId: id),
                android: AndroidTransition.slideUp,
              );
            }

          case '/purchase/store':
            return _platformRouteAnimated(
              settings,
              const StoreListScreen(),
              android: AndroidTransition.slideRight,
            );

          // ===== EDIT/REPORT/HR =====
          case '/edit-profile':
            return _platformRouteAnimated(
              settings,
              const EditProfileScreen(),
              android: AndroidTransition.slideRight,
            );

          case '/report':
            return _platformRouteAnimated(
              settings,
              const ReportDashboardScreen(),
              android: AndroidTransition.slideRight,
            );

          case '/hr':
            return _platformRouteAnimated(
              settings,
              const ManageHRScreen(),
              android: AndroidTransition.slideRight,
            );

          case '/hr/role':
            return _platformRouteAnimated(
              settings,
              const RoleScreen(),
              android: AndroidTransition.slideRight,
            );

          case '/hr/employee/invitation':
            return _platformRouteAnimated(
              settings,
              const HrScreen(),
              android: AndroidTransition.slideRight,
            );

          // ===== SALES =====
          case '/sales':
            return _platformRouteAnimated(
              settings,
              const ManageSalesScreen(),
              android: AndroidTransition.slideRight,
            );

          case '/sales/list':
            return _platformRouteAnimated(
              settings,
              const SalesReportScreen(),
              android: AndroidTransition.slideRight,
            );

          case '/sales/list/detail':
            {
              final args = settings.arguments;
              String? id;
              if (args is String) {
                id = args;
              } else if (args is Map) {
                id = (args['id'] ?? args['idTransaction'])?.toString();
              }
              if (id == null || id.isEmpty) {
                return _platformRouteAnimated(
                  settings,
                  const _RouteErrorScreen(
                    message:
                        'SalesReportDetailScreen membutuhkan argumen "id" (idTransaction).',
                  ),
                  android: AndroidTransition.fade,
                );
              }
              return _platformRouteAnimated(
                settings,
                SalesReportDetailScreen(idTransaction: id),
                android: AndroidTransition.slideUp,
              );
            }

          case '/sales/add':
            return _platformRouteAnimated(
              settings,
              const SalesStepperWrapper(),
              android: AndroidTransition.slideUp,
            );

          case '/sales/customer':
            return _platformRouteAnimated(
              settings,
              const CustomerListScreen(),
              android: AndroidTransition.slideRight,
            );

          case '/printer':
            return _platformRouteAnimated(
              settings,
              const ThermalPrinterSettingsScreen(),
              android: AndroidTransition.slideUp,
            );

          case '/business':
            return _platformRouteAnimated(
              settings,
              const BusinessSettingsScreen(),
              android: AndroidTransition.slideUp,
            );

          default:
            return _platformRouteAnimated(
              settings,
              const SplashScreen(),
              android: AndroidTransition.fade,
            );
        }
      },
    );
  }
}

enum AndroidTransition {
  slideRight, // default: dari kanan ke kiri (mirip iOS)
  slideUp, // dari bawah ke atas (cocok untuk detail/sheet)
  fade,
  scale,
}

Route<dynamic> _platformRouteAnimated(
  RouteSettings settings,
  Widget page, {
  AndroidTransition android = AndroidTransition.slideRight,
  Duration duration = const Duration(milliseconds: 280),
}) {
  // iOS/macOS: gunakan CupertinoPageRoute supaya swipe-back tetap aktif
  if (defaultTargetPlatform == TargetPlatform.iOS ||
      defaultTargetPlatform == TargetPlatform.macOS) {
    return CupertinoPageRoute(settings: settings, builder: (_) => page);
  }

  // Android/desktop: PageRouteBuilder dengan animasi kustom
  return PageRouteBuilder(
    settings: settings,
    transitionDuration: duration,
    reverseTransitionDuration: duration,
    pageBuilder: (_, __, ___) => page,
    transitionsBuilder: (_, animation, secondary, child) {
      switch (android) {
        case AndroidTransition.fade:
          return FadeTransition(opacity: animation, child: child);

        case AndroidTransition.scale:
          return ScaleTransition(
            scale: Tween<double>(begin: 0.96, end: 1).animate(
              CurvedAnimation(parent: animation, curve: Curves.easeOutCubic),
            ),
            child: FadeTransition(
              opacity: CurvedAnimation(
                parent: animation,
                curve: Curves.easeOutQuad,
              ),
              child: child,
            ),
          );

        case AndroidTransition.slideUp:
          return SlideTransition(
            position: Tween<Offset>(
              begin: const Offset(0, 0.08),
              end: Offset.zero,
            ).chain(CurveTween(curve: Curves.easeOutCubic)).animate(animation),
            child: FadeTransition(
              opacity: CurvedAnimation(
                parent: animation,
                curve: Curves.easeOut,
              ),
              child: child,
            ),
          );

        case AndroidTransition.slideRight:
        default:
          return SlideTransition(
            position: Tween<Offset>(
              begin: const Offset(1, 0),
              end: Offset.zero,
            ).chain(CurveTween(curve: Curves.easeOutCubic)).animate(animation),
            child: child,
          );
      }
    },
  );
}

class _RouteErrorScreen extends StatelessWidget {
  final String message;
  const _RouteErrorScreen({required this.message});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Route Error')),
      body: Center(child: Text(message)),
    );
  }
}

// ===== Build/Flavor diagnostics =====
class BuildDiag {
  // Kirim via --dart-define=FLAVOR=dev|prod (lihat bagian 4 di bawah)
  static const String flavor = String.fromEnvironment(
    'FLAVOR',
    defaultValue: 'unknown',
  );

  static bool get isDev => flavor.toLowerCase() == 'dev';
  static bool get isProd => flavor.toLowerCase() == 'prod';

  static bool get isDebug => kDebugMode;
  static bool get isProfile => kProfileMode;
  static bool get isRelease => kReleaseMode;

  static void printSummary([String where = '']) {
    final mode = isDebug
        ? 'DEBUG'
        : isProfile
        ? 'PROFILE'
        : isRelease
        ? 'RELEASE'
        : 'UNKNOWN';
    debugPrint(
      '🔧 BuildDiag$where → flavor=$flavor '
      '(isDev=$isDev isProd=$isProd)  mode=$mode '
      '(isDebug=$isDebug isProfile=$isProfile isRelease=$isRelease)',
    );
  }
}
