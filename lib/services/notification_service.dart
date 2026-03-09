import 'dart:async';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter/foundation.dart';

// Background message handler must be a top-level function
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();
  debugPrint("Handling a background message: ${message.messageId}");
  debugPrint("Background Notification Data: ${message.data}");
}

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final FirebaseMessaging _firebaseMessaging = FirebaseMessaging.instance;
  final FlutterLocalNotificationsPlugin _localNotificationsPlugin = FlutterLocalNotificationsPlugin();
  final SupabaseClient _supabase = Supabase.instance.client;

  bool _isInitialized = false;

  Future<void> initialize() async {
    if (_isInitialized) return;

    // 1. Request Permission
    await _requestPermission();

    // 2. Initialize Local Notifications
    await _initLocalNotifications();

    // 3. Setup Background Handler
    FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

    // 4. Setup Foreground Handler
    FirebaseMessaging.onMessage.listen(_handleForegroundMessage);

    // 5. Get and Save Token
    await _setupTokenManagement();

    // 6. Handle interactions (optional, but good practice)
    await _setupInteractions();

    _isInitialized = true;
    debugPrint("NotificationService initialized");
  }

  Future<void> _requestPermission() async {
    NotificationSettings settings = await _firebaseMessaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
      provisional: false,
    );
    debugPrint('User granted permission: ${settings.authorizationStatus}');
  }

  Future<void> _initLocalNotifications() async {
    const AndroidInitializationSettings initializationSettingsAndroid =
        AndroidInitializationSettings('@mipmap/ic_launcher');
    
    // Note: Add requestSoundPermission: false, requestBadgePermission: false, requestAlertPermission: false 
    // for iOS if you want to request permissions later or manually.
    const DarwinInitializationSettings initializationSettingsDarwin =
        DarwinInitializationSettings();

    const InitializationSettings initializationSettings = InitializationSettings(
      android: initializationSettingsAndroid,
      iOS: initializationSettingsDarwin,
    );

    await _localNotificationsPlugin.initialize(
      initializationSettings,
      onDidReceiveNotificationResponse: (NotificationResponse response) {
        debugPrint('Notification clicked: ${response.payload}');
        // Handle notification tap logic here
      },
    );

    // Create channel for Android
    const AndroidNotificationChannel channel = AndroidNotificationChannel(
      'high_importance_channel', // id
      'High Importance Notifications', // title
      description: 'This channel is used for important notifications.', // description
      importance: Importance.max,
    );

    await _localNotificationsPlugin
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(channel);
  }

  Future<void> _handleForegroundMessage(RemoteMessage message) async {
    debugPrint('Got a message whilst in the foreground!');
    debugPrint('Message data: ${message.data}');

    if (message.notification != null) {
      debugPrint('Message also contained a notification: ${message.notification}');
      
      // Show local notification
      _showLocalNotification(message);
    }
  }

  Future<void> _showLocalNotification(RemoteMessage message) async {
    RemoteNotification? notification = message.notification;
    AndroidNotification? android = message.notification?.android;

    if (notification != null && android != null) {
      await _localNotificationsPlugin.show(
        notification.hashCode,
        notification.title,
        notification.body,
        const NotificationDetails(
          android: AndroidNotificationDetails(
            'high_importance_channel',
            'High Importance Notifications',
            channelDescription: 'This channel is used for important notifications.',
            icon: '@mipmap/ic_launcher',
            importance: Importance.max,
            priority: Priority.high,
          ),
          iOS: DarwinNotificationDetails(),
        ),
        payload: message.data.toString(),
      );
    }
  }

  Future<void> _setupTokenManagement() async {
    // Get initial token
    String? token = await _firebaseMessaging.getToken();
    if (token != null) {
      debugPrint("FCM Token: $token");
      await _saveTokenToSupabase(token);
    }

    // Listen for token refresh
    _firebaseMessaging.onTokenRefresh.listen((newToken) async {
      debugPrint("FCM Token Refreshed: $newToken");
      await _saveTokenToSupabase(newToken);
    });

    // Listen for Auth Changes to save token when user logs in
    _supabase.auth.onAuthStateChange.listen((data) async {
      final AuthChangeEvent event = data.event;
      if (event == AuthChangeEvent.signedIn) {
        String? token = await _firebaseMessaging.getToken();
        if (token != null) {
          await _saveTokenToSupabase(token);
        }
      }
    });
  }

  Future<void> _saveTokenToSupabase(String token) async {
    final user = _supabase.auth.currentUser;
    if (user == null) {
      debugPrint("User not logged in, skipping token save.");
      return;
    }

    try {
      // Upsert the token into user_tokens table
      await _supabase.from('user_tokens').upsert({
        'user_id': user.id,
        'fcm_token': token,
        'created_at': DateTime.now().toIso8601String(),
      }, onConflict: 'user_id');

      // Also update profiles table as Edge Function relies on it for joins
      // We update fcm_token in profiles if it exists
      await _supabase.from('profiles').update({
        'fcm_token': token,
      }).eq('user_id', user.id);
      
      debugPrint("FCM Token saved to Supabase (user_tokens & profiles) for user ${user.id}");
    } catch (e) {
      debugPrint("Error saving FCM token to Supabase: $e");
    }
  }

  Future<void> _setupInteractions() async {
    // Get any messages which caused the application to open from
    // a terminated state.
    RemoteMessage? initialMessage =
        await _firebaseMessaging.getInitialMessage();

    if (initialMessage != null) {
      _handleMessageInteraction(initialMessage);
    }

    // Also handle any interaction when the app is in the background via a
    // Stream listener
    FirebaseMessaging.onMessageOpenedApp.listen(_handleMessageInteraction);
  }

  void _handleMessageInteraction(RemoteMessage message) {
    debugPrint("User tapped on notification: ${message.data}");
    
    if (message.data['type'] == 'price_drop') {
      final productId = message.data['product_id'];
      if (productId != null) {
        // Use Get.toNamed if you have named routes, or Get.to()
        // Since we don't know if product object is fully available, 
        // we might need to fetch it or navigate to a wrapper page.
        // For now, let's assume we can navigate to home or product page.
        // Ideally: Get.to(() => ProductDetailPage(productId: productId));
        // But ProductDetails takes a Product object.
        // We can navigate to a "ProductLoaderPage" or handle it in main navigation.
        debugPrint("Navigate to product: $productId");
      }
    }
  }
}
