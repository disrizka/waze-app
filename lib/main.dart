import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:provider/provider.dart';
import 'package:wa_blast/providers/edit_profile_provider.dart';
import 'package:wa_blast/screens/edit_profile_screen.dart';
import 'package:wa_blast/screens/edit_purchase_screen.dart';

import 'firebase_options.dart';

// providers
import 'package:wa_blast/providers/auth_provider.dart';
import 'package:wa_blast/providers/splash_provider.dart';
import 'package:wa_blast/providers/chat_provider.dart';
import 'package:wa_blast/providers/chat_detail_provider.dart';
import 'package:wa_blast/providers/product_provider.dart';
import 'package:wa_blast/providers/purchase_provider.dart';

// screens
import 'package:wa_blast/screens/splash_screen.dart';
import 'package:wa_blast/screens/login_screen.dart';
import 'package:wa_blast/screens/register_screen_wrapper.dart';
import 'package:wa_blast/screens/main_wrapper.dart';
import 'package:wa_blast/screens/manage_product.dart';
import 'package:wa_blast/screens/product_screen.dart';
import 'package:wa_blast/screens/purchase_screen.dart';
import 'package:wa_blast/screens/detail_purchase_screen.dart';

Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();
  debugPrint('📩 Background notification: ${message.notification?.title}');
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

  await FirebaseMessaging.instance.requestPermission(
    alert: true,
    badge: true,
    sound: true,
  );

  final fcmToken = await FirebaseMessaging.instance.getToken();
  debugPrint('FCM Token: $fcmToken');

  FirebaseMessaging.onMessage.listen((RemoteMessage message) {
    debugPrint('Foreground notification: ${message.notification?.title}');
  });

  FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
    debugPrint('Opened notification: ${message.notification?.title}');
  });

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthProvider()),
        ChangeNotifierProvider(create: (_) => SplashProvider()),
        ChangeNotifierProvider(create: (_) => ChatProvider()),
        ChangeNotifierProvider(create: (_) => ChatDetailProvider()),
        ChangeNotifierProvider(create: (_) => ProductProvider()),
        ChangeNotifierProvider(create: (_) => PurchaseProvider()),
        ChangeNotifierProvider(create: (_) => EditProfileProvider()),
      ],
      child: const MyApp(),
    ),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  Route<dynamic> _fadeRoute(RouteSettings settings, Widget page) {
    return PageRouteBuilder(
      settings: settings,
      transitionDuration: const Duration(milliseconds: 300),
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
          case '/purchase':
            return _fadeRoute(settings, const PurchaseScreen());

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
          case '/edit_purchase':
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
          default:
            return _fadeRoute(settings, const SplashScreen());
        }
      },
    );
  }
}

/// layar kecil untuk error route (opsional, biar gak crash)
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
