import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

// Firebase
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:wa_blast/app_nav.dart';
import 'package:wa_blast/env.dart';
import 'package:wa_blast/providers/store_provider.dart';
import 'package:wa_blast/screens/edit_profile_screen.dart';
import 'package:wa_blast/screens/hr/manage_hr_screen.dart';
import 'package:wa_blast/screens/hr/role_screen.dart';
import 'package:wa_blast/screens/manage_report_screen.dart';
import 'package:wa_blast/screens/purchase/add_purchase_screen.dart';
import 'package:wa_blast/screens/purchase/supplier_detail_screen.dart';
import 'package:wa_blast/screens/sales/costumer_screen.dart';
import 'package:wa_blast/screens/sales/manage_sales_screen.dart';
import 'package:wa_blast/screens/sales/sales_stepper_wrapper.dart';
import 'package:wa_blast/screens/sales_report_detail_screen.dart';
import 'package:wa_blast/screens/sales_report_screen.dart';
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
import 'package:wa_blast/screens/manage_product.dart';
import 'package:wa_blast/screens/products/product_screen.dart';
import 'package:wa_blast/screens/products/product_detail_screen.dart';
import 'package:wa_blast/screens/products/category_list_screen.dart';
import 'package:wa_blast/screens/products/brand_list_screen.dart';
import 'package:wa_blast/screens/purchase/manage_purchase_screen.dart';
import 'package:wa_blast/screens/purchase/purchase_screen.dart';
import 'package:wa_blast/screens/purchase/supplier_list_screen.dart';
import 'package:wa_blast/screens/detail_purchase_screen.dart';
import 'package:wa_blast/screens/edit_purchase_screen.dart';
import 'package:wa_blast/screens/hr/hr_screen.dart';
import 'package:wa_blast/screens/detail_employee_screen.dart';
import 'package:wa_blast/screens/leave_days_screen.dart';
import 'package:wa_blast/screens/request_leave_days_screen.dart';
import 'package:wa_blast/screens/reimbursement_screen.dart';
import 'package:wa_blast/screens/request_reimbursement_screen.dart';

/// === FCM background handler (WAJIB top-level) ===
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
  } catch (_) {}
  debugPrint('📩 BG notification: ${message.notification?.title}');
}

// 🔹 fungsi baru untuk dipanggil dari main_dev/main_prod
void startApp() {
  WidgetsFlutterBinding.ensureInitialized();

  // Harus sudah DEV di sini, kalau tidak: pasti ada yang nge-set sebelumnya
  Env.debugPrintEnv(' @startApp');

  BuildDiag.printSummary(' @startApp'); // biar cocok dengan Env

  runApp(const _AppShell());
}

/// Shell ringan: provider dibuat lazy, init berat dijadwalkan setelah frame pertama.
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
      final token = await FirebaseMessaging.instance.getToken().timeout(
        const Duration(seconds: 3),
        onTimeout: () => null,
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

  Route<dynamic> _fadeRoute(RouteSettings settings, Widget page) {
    return PageRouteBuilder(
      settings: settings,
      transitionDuration: const Duration(milliseconds: 250),
      pageBuilder: (_, __, ___) => page,
      transitionsBuilder: (_, animation, __, child) =>
          FadeTransition(opacity: animation, child: child),
    );
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      navigatorKey: appNavigatorKey,
      title: 'Wave Up',
      debugShowCheckedModeBanner: false,
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
      ),
      initialRoute: '/splash',
      onGenerateRoute: (settings) {
        // ... semua route PERSIS seperti punyamu ...
        switch (settings.name) {
          case '/splash':
            return _fadeRoute(settings, const SplashScreen());
          case '/login':
            return _fadeRoute(settings, const LoginScreen());
          case '/register':
            return _fadeRoute(settings, const RegisterWrapper());
          case '/home':
            return _fadeRoute(settings, const MainWrapper());
          case '/manage-product':
            return _fadeRoute(settings, const ManageProductScreen());
          case '/product':
            return _fadeRoute(settings, const ProductScreen());
          case '/product/detail-product':
            {
              final id = settings.arguments as String?;
              if (id == null || id.isEmpty) {
                return _fadeRoute(
                  settings,
                  const _RouteErrorScreen(
                    message:
                        'Route /product/detail-product membutuhkan argumen idProduct',
                  ),
                );
              }
              return _fadeRoute(settings, ProductDetailScreen(idProduct: id));
            }
          case '/category':
            return _fadeRoute(settings, const CategoryListScreen());
          case '/brand':
            return _fadeRoute(settings, const BrandListScreen());
          case '/store':
            return _fadeRoute(settings, const StoreListScreen());
          case '/purchase':
            return _fadeRoute(settings, const ManagePurchaseScreen());
          case '/purchase/list':
            return _fadeRoute(settings, const PurchaseScreen());
          case '/purchase/add':
            return _fadeRoute(settings, const AddPurchasePage());
          case '/purchase/supplier':
            return _fadeRoute(settings, const SupplierScreen());
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
                return _fadeRoute(
                  settings,
                  const _RouteErrorScreen(
                    message:
                        'SupplierDetailScreen membutuhkan argumen "id" (supplierId).',
                  ),
                );
              }
              return _fadeRoute(settings, SupplierDetailScreen(supplierId: id));
            }
          case '/detail-purchase':
            {
              final args = settings.arguments;
              String? id;
              if (args is String) {
                id = args;
              } else if (args is Map) {
                id = (args['id'] ?? args['idTransaction'])?.toString();
              }
              if (id == null || id.isEmpty) {
                return _fadeRoute(
                  settings,
                  const _RouteErrorScreen(
                    message:
                        'DetailPurchaseScreen membutuhkan argumen "id" (idTransaction).',
                  ),
                );
              }
              return _fadeRoute(settings, const DetailPurchaseScreen());
            }
          case '/edit-profile':
            return _fadeRoute(settings, const EditProfileScreen());
          case '/report':
            return _fadeRoute(settings, const ManageReportScreen());
          case '/report/sales':
            return _fadeRoute(settings, const SalesReportScreen());
          case '/report/purchase':
            return _fadeRoute(settings, const PurchaseScreen());
          case '/report/detail':
            {
              final args = settings.arguments;
              String? id;
              if (args is String) {
                id = args;
              } else if (args is Map) {
                id = (args['id'] ?? args['idTransaction'])?.toString();
              }
              if (id == null || id.isEmpty) {
                return _fadeRoute(
                  settings,
                  const _RouteErrorScreen(
                    message:
                        'SalesReportDetailScreen membutuhkan argumen "id" (idTransaction).',
                  ),
                );
              }
              return _fadeRoute(
                settings,
                SalesReportDetailScreen(idTransaction: id),
              );
            }
          case '/hr':
            return _fadeRoute(settings, const ManageHRScreen());
          case '/hr/role':
            return _fadeRoute(settings, const RoleScreen());
          case '/hr/employee/invitation':
            return _fadeRoute(settings, const HrScreen());
          case '/sales':
            return _fadeRoute(settings, const ManageSalesScreen());
          case '/sales/add':
            return _fadeRoute(settings, const SalesStepperWrapper());
          case '/sales/customer':
            return _fadeRoute(settings, const CustomerListScreen());
          default:
            return _fadeRoute(settings, const SplashScreen());
        }
      },
    );
  }
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
