// lib/main.dart
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

// Firebase
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:wa_blast/screens/edit_profile_screen.dart';
import 'package:wa_blast/screens/sales/sales_stepper_wrapper.dart';
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
import 'package:wa_blast/screens/hr_screen.dart';
import 'package:wa_blast/screens/detail_employee_screen.dart';
import 'package:wa_blast/screens/leave_days_screen.dart';
import 'package:wa_blast/screens/request_leave_days_screen.dart';
import 'package:wa_blast/screens/reimbursement_screen.dart';
import 'package:wa_blast/screens/request_reimbursement_screen.dart';

/// === FCM background handler (WAJIB top-level) ===
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  try {
    // Init di background isolate (aman & cepat)
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
  } catch (_) {}
  debugPrint('📩 BG notification: ${message.notification?.title}');
}

void main() {
  WidgetsFlutterBinding.ensureInitialized();

  // Jangan inisialisasi berat di sini. Jalankan app dulu:
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
      ],
      child: const _Bootstrapper(child: MyApp()),
    );
  }
}

/// Widget kecil untuk menjalankan init berat secara non-blocking.
class _Bootstrapper extends StatefulWidget {
  final Widget child;
  const _Bootstrapper({required this.child});

  @override
  State<_Bootstrapper> createState() => _BootstrapperState();
}

class _BootstrapperState extends State<_Bootstrapper> {
  bool _inited = false;

  @override
  void initState() {
    super.initState();
    // Jalankan setelah first frame: UI muncul dulu
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _bootstrap();
    });
  }

  Future<void> _bootstrap() async {
    if (_inited) return;
    _inited = true;

    try {
      // 1) Init Firebase cepat + timeout supaya gak pernah ngegantung
      await Future.any([
        Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform),
        Future.delayed(const Duration(seconds: 5)),
      ]);

      // 2) Daftarkan background handler (aman walau init di atas timeout)
      FirebaseMessaging.onBackgroundMessage(
        _firebaseMessagingBackgroundHandler,
      );

      // 3) Listener foreground — ringan, non-blocking
      FirebaseMessaging.onMessage.listen(
        (m) => debugPrint('🔔 FG notification: ${m.notification?.title}'),
      );
      FirebaseMessaging.onMessageOpenedApp.listen(
        (m) => debugPrint('🔔 Opened from notif: ${m.notification?.title}'),
      );

      // 4) Minta permission & ambil token TANPA mengganggu UI
      unawaited(_askNotifPermissionAndToken());
    } catch (e) {
      // Jangan ganggu UI kalau gagal init
      debugPrint('Bootstrap error: $e');
    }
  }

  Future<void> _askNotifPermissionAndToken() async {
    try {
      // Tunggu UI settle dikit biar lebih smooth
      await Future.delayed(const Duration(milliseconds: 400));

      // Request permission (iOS / Android 13+) — ini non-blocking terhadap UI
      await FirebaseMessaging.instance.requestPermission(
        alert: true,
        badge: true,
        sound: true,
      );

      final token = await FirebaseMessaging.instance.getToken().timeout(
        const Duration(seconds: 3),
        onTimeout: () => null,
      );
      if (token != null) debugPrint('FCM Token: $token');
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
      transitionDuration: const Duration(
        milliseconds: 250,
      ), // sedikit lebih cepat
      pageBuilder: (_, __, ___) => page,
      transitionsBuilder: (_, animation, __, child) =>
          FadeTransition(opacity: animation, child: child),
    );
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
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
          case '/purchase':
            return _fadeRoute(settings, const ManagePurchaseScreen());
          case '/purchase/list':
            return _fadeRoute(settings, const PurchaseScreen());
          case '/purchase/supplier':
            return _fadeRoute(settings, const SupplierScreen());
          case '/detail-purchase':
            {
              final args = settings.arguments;
              String? code;
              if (args is Map) code = args['code'] as String?;
              if (code == null || code.isEmpty) {
                return _fadeRoute(
                  settings,
                  const _RouteErrorScreen(
                    message: 'DetailPurchaseScreen membutuhkan argumen "code"',
                  ),
                );
              }
              return _fadeRoute(settings, DetailPurchaseScreen(code: code));
            }
          case '/edit-purchase':
            {
              final args = settings.arguments;
              final code = (args is Map) ? args['code'] as String? : null;
              if (code == null || code.isEmpty) {
                return _fadeRoute(
                  settings,
                  const _RouteErrorScreen(message: 'Butuh code'),
                );
              }
              return _fadeRoute(settings, EditPurchaseScreen(code: code));
            }
          case '/edit-profile':
            return _fadeRoute(settings, const EditProfileScreen());
          case '/hr':
            return _fadeRoute(settings, const HrScreen());
          case '/hr/detail':
            {
              final args = settings.arguments;
              final index = (args is Map) ? args['index'] as int? : null;
              if (index == null) {
                return _fadeRoute(
                  settings,
                  const _RouteErrorScreen(
                    message: 'Butuh argumen index employee',
                  ),
                );
              }
              return _fadeRoute(settings, DetailEmployeeScreen(index: index));
            }
          case '/hr/leave-days':
            {
              final args = settings.arguments;
              final index = (args is Map) ? args['index'] as int? : null;
              if (index == null) {
                return _fadeRoute(
                  settings,
                  const _RouteErrorScreen(
                    message: 'Butuh argumen index employee',
                  ),
                );
              }
              return _fadeRoute(settings, LeaveDaysScreen(index: index));
            }
          case '/hr/leave-days/request':
            {
              final args = settings.arguments;
              final index = (args is Map) ? args['index'] as int? : null;
              if (index == null) {
                return _fadeRoute(
                  settings,
                  const _RouteErrorScreen(
                    message: 'Butuh argumen index employee',
                  ),
                );
              }
              return _fadeRoute(settings, RequestLeaveDayScreen(index: index));
            }
          case '/hr/reimbursement':
            {
              final args = settings.arguments;
              final index = (args is Map) ? args['index'] as int? : null;
              if (index == null) {
                return _fadeRoute(
                  settings,
                  const _RouteErrorScreen(
                    message: 'Butuh argumen index employee',
                  ),
                );
              }
              return _fadeRoute(settings, ReimbursementScreen(index: index));
            }
          case '/hr/reimbursement/request':
            {
              final args = settings.arguments;
              final index = (args is Map) ? args['index'] as int? : null;
              if (index == null) {
                return _fadeRoute(
                  settings,
                  const _RouteErrorScreen(
                    message: 'Butuh argumen index employee',
                  ),
                );
              }
              return _fadeRoute(
                settings,
                RequestReimbursementScreen(index: index),
              );
            }
          case '/sales':
            return _fadeRoute(settings, const SalesStepperWrapper());
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
