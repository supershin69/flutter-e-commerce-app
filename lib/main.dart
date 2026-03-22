import 'package:e_commerce_frontend/screens/flash_screen.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:get/get.dart';
import 'package:e_commerce_frontend/features/shop/controllers/product_controller.dart';
import 'package:e_commerce_frontend/services/notification_service.dart';
import 'package:e_commerce_frontend/features/personalization/screens/orders/order_detail_screen.dart';

final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

void handleNotificationInteraction(RemoteMessage message) {
  final data = message.data;
  final notification = message.notification;
  
  debugPrint('--- Firebase Notification Tapped ---');
  debugPrint('Message Data: $data');
  if (notification != null) {
    debugPrint('Notification Title: ${notification.title}');
    debugPrint('Notification Body: ${notification.body}');
  }
  debugPrint('------------------------------------');

  if (data['type'] == 'delivery_fee_set') {
    final orderId = data['order_id']?.toString();
    if (orderId == null || orderId.trim().isEmpty) {
      debugPrint('Error: order_id is missing or empty in notification data');
      return;
    }
    
    debugPrint('Navigating to OrderDetailScreen for orderId: $orderId');
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final nav = navigatorKey.currentState;
      if (nav != null) {
        debugPrint('Using navigatorKey for navigation');
        nav.push(MaterialPageRoute(builder: (_) => OrderDetailScreen.byId(orderId: orderId)));
      } else {
        debugPrint('navigatorKey.currentState is NULL, falling back to Get.to');
        Get.to(() => OrderDetailScreen.byId(orderId: orderId));
      }
    });
  } else if (data['type'] == 'price_drop') {
    final productId = data['product_id'];
    debugPrint("Price drop notification for product: $productId");
    // Add product navigation logic here if needed
  } else {
    debugPrint('Unknown notification type: ${data['type']}');
  }
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Firebase.initializeApp();

  await Supabase.initialize(
    url: 'https://mxngcloeolzkfnauioln.supabase.co',
    anonKey: 'sb_secret_-Rfkp-sQcn-cYWnb-p6drQ_MuTJzwrI',
    authOptions: const FlutterAuthClientOptions(
      authFlowType: AuthFlowType.pkce,
    ),
  );

  // Initialize Notification Service
  await NotificationService().initialize();
  
  // Handle notification tap when app is in background (opened from notification)
  FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
    debugPrint('🔥 onMessageOpenedApp triggered');
    handleNotificationInteraction(message);
  });

  // Handle notification tap when app is terminated
  FirebaseMessaging.instance.getInitialMessage().then((RemoteMessage? initialMessage) {
    if (initialMessage != null) {
      debugPrint('🔥 getInitialMessage triggered');
      handleNotificationInteraction(initialMessage);
    } else {
      debugPrint('No initial notification message found');
    }
  });

  Get.put(ProductController());

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  // This widget is the root of your application.
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
