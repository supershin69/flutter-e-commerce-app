import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:e_commerce_frontend/features/personalization/screens/orders/order_detail_screen.dart';
import 'package:onesignal_flutter/onesignal_flutter.dart';
import 'package:e_commerce_frontend/main.dart'; // for navigatorKey

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  bool _isInitialized = false;

  Future<void> initialize() async {
    if (_isInitialized) return;

    // OneSignal click listener (in case you want extra handling)
    OneSignal.Notifications.addClickListener((event) {
      final data = event.notification.additionalData;
      debugPrint('🔔 NotificationService: Notification clicked - Data: $data');

      if (data != null && data['type'] == 'delivery_fee_set') {
        final orderId = data['order_id']?.toString();
        if (orderId != null && orderId.isNotEmpty) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            final nav = navigatorKey.currentState;
            if (nav != null) {
              nav.push(MaterialPageRoute(
                builder: (_) => OrderDetailScreen.byId(orderId: orderId),
              ));
            } else {
              Get.to(() => OrderDetailScreen.byId(orderId: orderId));
            }
          });
        }
      }
    });

    _isInitialized = true;
    debugPrint("✅ NotificationService initialized (OneSignal only mode)");
  }

  // Optional: You can call this from UI if you want to send a test from the app
  Future<void> sendTestNotification() async {
    debugPrint("📤 Use OneSignal Dashboard to send test notifications.");
  }
}