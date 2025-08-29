import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:provider/provider.dart';
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
      ],
      child: const MyApp(),
    ),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Wave Upp',
      debugShowCheckedModeBanner: false,
      initialRoute: '/splash',
      routes: {
        '/splash': (ctx) => const SplashScreen(),
        '/login': (ctx) => const LoginScreen(),
        '/register': (ctx) => const RegisterWrapper(),
        '/home': (ctx) => const MainWrapper(),
      },
    );
  }
}
