import 'package:e_commerce_frontend/screens/flash_screen.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:get/get.dart';
import 'package:e_commerce_frontend/features/shop/controllers/product_controller.dart';
import 'package:e_commerce_frontend/features/personalization/screens/orders/order_detail_screen.dart';
import 'package:onesignal_flutter/onesignal_flutter.dart';

final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Supabase Initialization
  await Supabase.initialize(
    url: 'https://mxngcloeolzkfnauioln.supabase.co',
    anonKey: 'sb_publishable_ia5D5O1Eh0kRIoNyuz5iXQ_9pY7zIWX',
    authOptions: const FlutterAuthClientOptions(
      authFlowType: AuthFlowType.pkce,
    ),
  );

  // ==================== OneSignal Setup ====================
  if (kDebugMode) {
    OneSignal.Debug.setLogLevel(OSLogLevel.verbose);
  }

  OneSignal.initialize("711d1435-53f7-49eb-8d5f-6609f7bcd77a");

  debugPrint("✅ OneSignal initialized successfully");

  // Request notification permission
  final granted = await OneSignal.Notifications.requestPermission(true);
  debugPrint("🔔 Notification permission granted: $granted");

  // Listen for push subscription changes (for debugging)
  OneSignal.User.pushSubscription.addObserver((state) {
    debugPrint(
      "🔄 Push Subscription → ID: ${state.current.id ?? 'null'}, OptedIn: ${state.current.optedIn ?? false}",
    );
  });

  // Foreground notification handler
  OneSignal.Notifications.addForegroundWillDisplayListener((event) {
    debugPrint("🔔 Foreground Notification: ${event.notification.title}");

    // This forces the notification to show as heads-up banner
    event.notification.display();

    // Optional: You can also prevent default if you want full control later
    // event.preventDefault();
  });

  // Notification click handler
  OneSignal.Notifications.addClickListener((event) {
    final data = event.notification.additionalData;
    debugPrint('🔔 OneSignal Notification Clicked with data: $data');

    if (data != null && data['type'] == 'delivery_fee_set') {
      final orderId = data['order_id']?.toString();
      if (orderId != null && orderId.isNotEmpty) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          navigatorKey.currentState?.push(
            MaterialPageRoute(
              builder: (_) => OrderDetailScreen.byId(orderId: orderId),
            ),
          );
        });
      }
    }
  });

  // Auth state listener - Link user to OneSignal
  Supabase.instance.client.auth.onAuthStateChange.listen((data) async {
    final session = data.session;

    if (session != null) {
      OneSignal.logout(); // ← First logout old user
      OneSignal.login(session.user.id); // ← Then login new user
      debugPrint("🔗 OneSignal: Switched to user ${session.user.id}");

      // Step 2: Force Re-subscription
      OneSignal.User.pushSubscription.optOut();
      await Future.delayed(const Duration(milliseconds: 500));
      OneSignal.User.pushSubscription.optIn();
    } else {
      OneSignal.logout();
      debugPrint("🔐 OneSignal: Logged out");
    }
  });

  Get.put(ProductController());

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return GetMaterialApp(
      title: 'E-Commerce App',
      debugShowCheckedModeBanner: false,
      navigatorKey: navigatorKey,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        useMaterial3: true,
      ),
      home: const SplashScreen(),
    );
  }
}