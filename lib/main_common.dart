import 'dart:async';
import 'dart:io';

import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:provider/provider.dart';

// Firebase
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';

// App
import 'package:wa_blast/app_nav.dart';
import 'package:wa_blast/env.dart';
import 'package:wa_blast/firebase_options.dart';
import 'package:wa_blast/l10n/app_localizations.dart';
import 'package:wa_blast/models/product_models/product_model.dart';
import 'package:wa_blast/providers/adjustment_provider.dart';
import 'package:wa_blast/providers/auth_provider.dart';
import 'package:wa_blast/providers/change_password_provider.dart';
import 'package:wa_blast/providers/chat_detail_provider.dart';
import 'package:wa_blast/providers/chat_provider.dart';
import 'package:wa_blast/providers/edit_profile_provider.dart';
import 'package:wa_blast/providers/hr_provider.dart';
import 'package:wa_blast/providers/locale_provider.dart';
import 'package:wa_blast/providers/notification_provider.dart';
import 'package:wa_blast/providers/order_provider.dart';
import 'package:wa_blast/providers/product_provider.dart';
import 'package:wa_blast/providers/purchase_provider.dart';
import 'package:wa_blast/providers/report_provider.dart';
import 'package:wa_blast/providers/role_provider.dart';
import 'package:wa_blast/providers/sales_provider.dart';
import 'package:wa_blast/providers/splash_provider.dart';
import 'package:wa_blast/providers/stock_provider.dart';
import 'package:wa_blast/providers/store_provider.dart';
import 'package:wa_blast/providers/subscription_provider.dart';
import 'package:wa_blast/screens/adjustment/adjustment_list_screen.dart';
import 'package:wa_blast/screens/change_password_screen.dart';
import 'package:wa_blast/screens/detail_purchase_screen.dart';
import 'package:wa_blast/screens/edit_profile_screen.dart';
import 'package:wa_blast/screens/forgot-password/forgot_password_wrapper_screen.dart';
import 'package:wa_blast/screens/hr/employee_list_screen.dart';
import 'package:wa_blast/screens/hr/employee_detail_screen.dart';
import 'package:wa_blast/screens/hr/hr_screen.dart';
import 'package:wa_blast/screens/hr/manage_hr_screen.dart';
import 'package:wa_blast/screens/hr/role_screen.dart';
import 'package:wa_blast/screens/inventory/add_initial_stock_screen.dart';
import 'package:wa_blast/screens/inventory/initial_stock_detail_screen.dart';
import 'package:wa_blast/screens/inventory/initial_stock_screen.dart';
import 'package:wa_blast/screens/inventory/inventory_screen.dart';
import 'package:wa_blast/screens/inventory/manage_stock_screen.dart';
import 'package:wa_blast/screens/inventory/product_stock_history.dart';
import 'package:wa_blast/screens/login_screen.dart';
import 'package:wa_blast/screens/main_wrapper.dart';
import 'package:wa_blast/screens/notification_detail_list.dart';
import 'package:wa_blast/screens/notification_list_screen.dart';
import 'package:wa_blast/screens/order/order_list_screen.dart';
import 'package:wa_blast/screens/payment_history_base_screen.dart';
import 'package:wa_blast/screens/products/brand_list_screen.dart';
import 'package:wa_blast/screens/products/category_list_screen.dart';
import 'package:wa_blast/screens/products/create_edit_screen/add_product_screen.dart';
import 'package:wa_blast/screens/products/manage_product.dart';
import 'package:wa_blast/screens/products/product_detail_screen.dart';
import 'package:wa_blast/screens/products/product_screen.dart';
import 'package:wa_blast/screens/products/product_stock_inventory.dart';
import 'package:wa_blast/screens/purchase/add_purchase_screen.dart';
import 'package:wa_blast/screens/purchase/manage_purchase_screen.dart';
import 'package:wa_blast/screens/purchase/purchase_screen.dart';
import 'package:wa_blast/screens/purchase/supplier_detail_screen.dart';
import 'package:wa_blast/screens/purchase/supplier_list_screen.dart';
import 'package:wa_blast/screens/register/business_register_screen.dart';
import 'package:wa_blast/screens/register/register_screen_wrapper.dart';
import 'package:wa_blast/screens/report/manage_report_screen.dart';
import 'package:wa_blast/screens/report/report_purchase_screen.dart';
import 'package:wa_blast/screens/report/report_sales_screen.dart';
import 'package:wa_blast/screens/sales/costumer_screen.dart';
import 'package:wa_blast/screens/sales/manage_sales_screen.dart';
import 'package:wa_blast/screens/sales/sales_stepper_wrapper.dart';
import 'package:wa_blast/screens/sales_report_detail_screen.dart';
import 'package:wa_blast/screens/sales_report_screen.dart';
import 'package:wa_blast/screens/settings/business/business_edit_screen.dart';
import 'package:wa_blast/screens/settings/business/business_settings_screen.dart';
import 'package:wa_blast/screens/settings/thermal_printer_setting.dart';
import 'package:wa_blast/screens/splash_screen.dart';
import 'package:wa_blast/screens/stock-opname/stock_opname_create_screen.dart';
import 'package:wa_blast/screens/stock_opname_list_screen.dart';
import 'package:wa_blast/screens/store_list_screen.dart';
import 'package:wa_blast/screens/subscription/subscription_checkout_history_screen.dart';
import 'package:wa_blast/screens/subscription/subscription_screen.dart';
import 'package:wa_blast/screens/transaction_fee_detail_screen.dart';
import 'package:wa_blast/services/deep_link_service.dart';

Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
  } catch (_) {}
  debugPrint('BG notification: ${message.notification?.title}');
}

Future<void> startApp() async {
  WidgetsFlutterBinding.ensureInitialized();
  if (Env.isDev) {
    HttpOverrides.global = _DevHttpOverrides();
  }
  await _initEnvSafe();
  try {
    if (Firebase.apps.isEmpty) {
      await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform,
      );
    }
  } catch (e) {
    debugPrint('Firebase init error (startApp): $e');
  }

  Env.debugPrintEnv(' @startApp');
  BuildDiag.printSummary(' @startApp');
  runApp(const _AppShell());
}

class _DevHttpOverrides extends HttpOverrides {
  @override
  HttpClient createHttpClient(SecurityContext? context) {
    final client = super.createHttpClient(context);
    client.badCertificateCallback =
        (X509Certificate cert, String host, int port) => true;
    return client;
  }
}

Future<void> _initEnvSafe() async {
  final candidates = <String>[
    BuildDiag.isProd ? '.env.prod' : '.env.dev',
    '.env',
  ];

  var loaded = false;
  for (final file in candidates) {
    try {
      await dotenv.load(fileName: file);
      debugPrint('✅ dotenv loaded: $file');
      loaded = true;
      break;
    } on FileSystemException {
      debugPrint('⚠️ dotenv file "$file" tidak ditemukan, coba yang lain...');
    } catch (e) {
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
          create: (_) => ChangePasswordProvider(),
          lazy: true,
        ),
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
        ChangeNotifierProvider(create: (_) => ReportProviderV2(), lazy: true),
        ChangeNotifierProvider(
          create: (_) => SubscriptionProvider(),
          lazy: true,
        ),
        ChangeNotifierProvider(
          create: (_) => NotificationProvider(),
          lazy: true,
        ),
        ChangeNotifierProvider(create: (_) => StockProvider(), lazy: true),
        ChangeNotifierProvider(create: (_) => OrderProvider(), lazy: true),
        ChangeNotifierProvider(create: (_) => AdjustmentProvider(), lazy: true),
      ],
      child: const _Bootstrapper(child: MyApp()),
    );
  }
}

/// Bootstrapper: inisialisasi Firebase, FCM, deep link, dsb.
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
    WidgetsBinding.instance.addPostFrameCallback((_) => _bootstrap());
  }

  Future<void> _bootstrap() async {
    if (_inited) return;
    _inited = true;

    try {
      if (Firebase.apps.isEmpty) {
        await Future.any([
          Firebase.initializeApp(
            options: DefaultFirebaseOptions.currentPlatform,
          ),
          Future.delayed(const Duration(seconds: 5)),
        ]);
      }

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
      onGenerateRoute: _onGenerateRoute,
    );
  }

  Route<dynamic>? _onGenerateRoute(RouteSettings settings) {
    switch (settings.name) {
      case '/splash':
        return _platformRouteAnimated(
          settings,
          const SplashScreen(),
          android: AndroidTransition.none,
        );

      case '/login':
        return _platformRouteAnimated(
          settings,
          const LoginScreen(),
          android: AndroidTransition.none,
        );

      case '/register':
        return _platformRouteAnimated(
          settings,
          const RegisterWrapper(),
          android: AndroidTransition.slideRight,
        );

      case '/register/business':
        return _platformRouteAnimated(
          settings,
          const BusinessRegisterScreen(),
          android: AndroidTransition.slideRight,
        );

      case '/home':
        return _platformRouteAnimated(
          settings,
          const MainWrapper(),
          android: AndroidTransition.none,
        );

      // PRODUCT
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

      case '/product/add':
      case '/product/edit':
        return _platformRouteAnimated(
          settings,
          const AddProductScreen(),
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

      // STOCK
      case '/stock':
        return _platformRouteAnimated(
          settings,
          const ManageStockScreen(),
          android: AndroidTransition.slideRight,
        );
      case '/stock/opname':
        return _platformRouteAnimated(
          settings,
          const StockOpnameListScreen(),
          android: AndroidTransition.slideRight,
        );
      case '/stock/opname/create':
        return _platformRouteAnimated(
          settings,
          const StockOpnameCreateScreen(),
          android: AndroidTransition.slideRight,
        );

      case '/stock/initial-stock':
        return _platformRouteAnimated(
          settings,
          const StockScreen(),
          android: AndroidTransition.slideRight,
        );

      case '/stock/initial-stock/detail':
        return _platformRouteAnimated(
          settings,
          const InitialStockDetailScreen(),
          android: AndroidTransition.slideUp,
        );

      case '/stock/initial-stock/add':
        return _platformRouteAnimated(
          settings,
          const AddInitialStockPage(),
          android: AndroidTransition.slideRight,
        );

      case '/stock/inventory':
        return _platformRouteAnimated(
          settings,
          const InventoryScreen(),
          android: AndroidTransition.slideRight,
        );

      case '/stock/inventory/detail':
        {
          final args = settings.arguments as ProductStockHistoryArgs?;
          return _platformRouteAnimated(
            settings,
            ProductStockHistoryScreen(
              productName: args?.productName ?? '',
              skus: args?.skus ?? const <ProductSku>[],
              initialSkuId: args?.initialSkuId,
            ),
            android: AndroidTransition.slideRight,
          );
        }

      // PURCHASE
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

      // EDIT / REPORT / HR
      case '/edit-profile':
        return _platformRouteAnimated(
          settings,
          const EditProfileScreen(),
          android: AndroidTransition.slideRight,
        );

      case '/password/change':
        return _platformRouteAnimated(
          settings,
          const ChangePasswordScreen(),
          android: AndroidTransition.slideRight,
        );

      case '/password/forgot':
        return _platformRouteAnimated(
          settings,
          const ForgotPasswordWrapperScreen(),
          android: AndroidTransition.slideRight,
        );

      case '/report':
        return _platformRouteAnimated(
          settings,
          const ManageReportScreen(),
          android: AndroidTransition.slideRight,
        );

      case '/report/sales':
        return _platformRouteAnimated(
          settings,
          const ReportSalesScreen(),
          android: AndroidTransition.slideRight,
        );

      case '/report/purchase':
        return _platformRouteAnimated(
          settings,
          const PurchaseReportScreen(),
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

      case '/hr/employee/list':
        return _platformRouteAnimated(
          settings,
          const EmployeeListScreen(),
          android: AndroidTransition.slideRight,
        );

      case '/hr/employee/detail':
        {
          final args = settings.arguments;
          if (args is! EmployeeUser) {
            return _platformRouteAnimated(
              settings,
              const _RouteErrorScreen(
                message:
                    'EmployeeDetailScreen membutuhkan argumen EmployeeUser.',
              ),
              android: AndroidTransition.fade,
            );
          }
          return _platformRouteAnimated(
            settings,
            EmployeeDetailScreen(employee: args),
            android: AndroidTransition.slideRight,
          );
        }

      case '/hr/employee/invitation':
        return _platformRouteAnimated(
          settings,
          const HrScreen(),
          android: AndroidTransition.slideRight,
        );

      // SALES
      case '/sales':
        return _platformRouteAnimated(
          settings,
          const ManageSalesScreen(),
          android: AndroidTransition.slideRight,
        );
      case '/sales/order-external':
        return _platformRouteAnimated(
          settings,
          const StoreOrderListScreen(),
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

      // SUBSCRIPTION / BUSINESS / NOTIFICATION
      case '/subscription':
        return _platformRouteAnimated(
          settings,
          const SubscriptionScreen(),
          android: AndroidTransition.slideRight,
        );

      case '/subscription/history':
        return _platformRouteAnimated(
          settings,
          const SubscriptionCheckoutHistoryScreen(),
          android: AndroidTransition.slideRight,
        );

      case '/business':
        return _platformRouteAnimated(
          settings,
          const BusinessSettingsScreen(),
          android: AndroidTransition.slideUp,
        );

      case '/business/edit':
        return _platformRouteAnimated(
          settings,
          const BusinessEditScreen(),
          android: AndroidTransition.slideUp,
        );

      case '/business/fee/history':
        {
          final args = settings.arguments;

          // default: transaction fee
          String initialType = SubscriptionProvider.kHistoryTypeTransactionFee;

          if (args is Map) {
            final t = (args['type'] ?? '').toString().trim();
            if (t == SubscriptionProvider.kHistoryTypePremiumBusiness ||
                t == SubscriptionProvider.kHistoryTypeTransactionFee) {
              initialType = t;
            }
          } else if (args is String) {
            final t = args.trim();
            if (t == SubscriptionProvider.kHistoryTypePremiumBusiness ||
                t == SubscriptionProvider.kHistoryTypeTransactionFee) {
              initialType = t;
            }
          }

          return _platformRouteAnimated(
            settings,
            PlatformPaymentHistoryScreen(),
            android: AndroidTransition.slideUp,
          );
        }

      case '/business/transaction-fee/detail':
        final args =
            (settings.arguments as Map?)?.cast<String, dynamic>() ?? {};
        final id = (args['idTransactionFee'] ?? '').toString();

        return _platformRouteAnimated(
          settings,
          TransactionFeeDetailScreen(idTransactionFee: id),
          android: AndroidTransition.slideUp,
        );

      case '/notification/detail':
        {
          final id = settings.arguments as String?;
          if (id == null || id.isEmpty) {
            return _platformRouteAnimated(
              settings,
              const _RouteErrorScreen(
                message:
                    'Route /notification/detail butuh argument idNotification (String).',
              ),
              android: AndroidTransition.fade,
            );
          }
          return _platformRouteAnimated(
            settings,
            NotificationDetailScreen(idNotification: id),
            android: AndroidTransition.slideUp,
          );
        }
      case '/notification':
        return _platformRouteAnimated(
          settings,
          const NotificationListScreen(),
          android: AndroidTransition.slideUp,
        );

      case '/adjustment':
        return _platformRouteAnimated(
          settings,
          const AdjustmentListScreen(),
          android: AndroidTransition.slideUp,
        );

      default:
        return _platformRouteAnimated(
          settings,
          const SplashScreen(),
          android: AndroidTransition.fade,
        );
    }
  }
}

enum AndroidTransition { none, slideRight, slideUp, fade, scale }

Route<dynamic> _platformRouteAnimated(
  RouteSettings settings,
  Widget page, {
  AndroidTransition android = AndroidTransition.slideRight,
  Duration duration = const Duration(milliseconds: 280),
}) {
  if (android == AndroidTransition.none) {
    return PageRouteBuilder(
      settings: settings,
      transitionDuration: Duration.zero,
      reverseTransitionDuration: Duration.zero,
      pageBuilder: (context, animation, secondaryAnimation) => page,
      transitionsBuilder: (context, animation, secondaryAnimation, child) =>
          child,
    );
  }

  if (defaultTargetPlatform == TargetPlatform.iOS ||
      defaultTargetPlatform == TargetPlatform.macOS) {
    return CupertinoPageRoute(settings: settings, builder: (_) => page);
  }

  return PageRouteBuilder(
    settings: settings,
    transitionDuration: duration,
    reverseTransitionDuration: duration,
    pageBuilder: (context, animation, secondaryAnimation) => page,
    transitionsBuilder: (context, animation, secondary, child) {
      switch (android) {
        case AndroidTransition.none:
          return child;

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

class BuildDiag {
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
      '🔧 BuildDiag$where → flavor=$flavor (isDev=$isDev isProd=$isProd)  mode=$mode '
      '(isDebug=$isDebug isProfile=$isProfile isRelease=$isRelease)',
    );
  }
}
