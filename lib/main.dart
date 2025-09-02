import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:provider/provider.dart';
import 'package:wa_blast/providers/product_provider.dart';
import 'package:wa_blast/screens/product_screen.dart';
import 'package:wa_blast/screens/register_screen_wrapper.dart';

import 'firebase_options.dart';

import 'package:wa_blast/providers/chat_detail_provider.dart';
import 'package:wa_blast/providers/chat_provider.dart';
import 'package:wa_blast/providers/splash_provider.dart';
import 'package:wa_blast/providers/auth_provider.dart';
import 'package:wa_blast/screens/main_wrapper.dart';
import 'package:wa_blast/screens/login_screen.dart';
import 'package:wa_blast/screens/splash_screen.dart';

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
      ],
      child: const MyApp(),
    ),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  Route _fadeRoute(RouteSettings settings, Widget page) {
    return PageRouteBuilder(
      settings: settings,
      transitionDuration: const Duration(milliseconds: 300),
      pageBuilder: (_, __, ___) => page,
      transitionsBuilder: (_, animation, __, child) {
        return FadeTransition(opacity: animation, child: child);
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Wave Up',
      debugShowCheckedModeBanner: false,
      initialRoute: '/splash',
      onGenerateRoute: (settings) {
        switch (settings.name) {
          case '/splash':
            return _fadeRoute(settings, const SplashScreen());
          case '/login':
            return _fadeRoute(settings, const LoginScreen());
          case '/register':
            return _fadeRoute(settings, RegisterWrapper());
          case '/home':
            return _fadeRoute(settings, const MainWrapper());
          case '/product':
            return _fadeRoute(settings, const ProductScreen());
          default:
            return _fadeRoute(settings, const SplashScreen());
        }
      },
    );
  }
}
