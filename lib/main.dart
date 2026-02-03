import 'package:e_commerce_frontend/screens/flash_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';

final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin = FlutterLocalNotificationsPlugin();

const AndroidNotificationChannel channel = AndroidNotificationChannel(
  'high_importance_channel', 
  'High Importance Notifications',
  description: 'This channel is used for important notifications',
  importance: Importance.max
);

@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  // If you want to use other Firebase services here, you must call initializeApp
  await Firebase.initializeApp();
  print("Handling a background message: ${message.messageId}");
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

  const AndroidInitializationSettings androidInitializationSettings = AndroidInitializationSettings('@mipmap/ic_launcher');

  const InitializationSettings initializationSettings = InitializationSettings(android: androidInitializationSettings);

  await flutterLocalNotificationsPlugin.initialize(initializationSettings);

  FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

  await flutterLocalNotificationsPlugin.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()?.createNotificationChannel(channel);

  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  // This widget is the root of your application.
  @override
  State<StatefulWidget> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {

  @override
  void initState() {
    // TODO: implement initState
    super.initState();
    _setupPushNotifications();
  }

  void _setupPushNotifications() async {
  final messaging = FirebaseMessaging.instance;

  await messaging.requestPermission(
    alert: true,
    badge: true,
    sound: true,
  );

  final token = await messaging.getToken();
  debugPrint("FCM TOKEN: $token");

  final user = Supabase.instance.client.auth.currentUser;

  if (user != null && token != null) {
    await Supabase.instance.client.from('profiles').update({
      'fcm_token': token,
      'updated_at': DateTime.now().toIso8601String(),
    }).eq('user_id', user.id);
  }

  // handle token refresh
  FirebaseMessaging.instance.onTokenRefresh.listen((newToken) async {
    if (user != null) {
      await Supabase.instance.client.from('profiles').update({
        'fcm_token': newToken,
      }).eq('user_id', user.id);
    }
  });

  // foreground listener
  FirebaseMessaging.onMessage.listen((RemoteMessage message) {
    debugPrint('FOREGROUND message: ${message.notification?.title}');
    final notification = message.notification;

    if (notification != null) {
      flutterLocalNotificationsPlugin.show(
        notification.hashCode,
        notification.title,
        notification.body,
        const NotificationDetails(
          android: AndroidNotificationDetails(
            'high_importance_channel', 
            'High Importance Notifications',
            priority: Priority.max,
            importance: Importance.max
          )
        )
      );
    }
  });
}

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Flutter Demo',
      theme: ThemeData(
        colorScheme: .fromSeed(seedColor: Colors.deepPurple),
      ),
      home: const SplashScreen() 
    ); 
  }
}