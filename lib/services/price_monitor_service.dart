import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

class PriceMonitorService {
  final SupabaseClient _supabase = Supabase.instance.client;
  final FlutterLocalNotificationsPlugin _localNotificationsPlugin = FlutterLocalNotificationsPlugin();

  /// Call this periodically (every hour via cron job or Cloud Function)
  /// Note: Since this is client-side code, it will only run when the app is active
  /// or if triggered by a background task runner (e.g., workmanager).
  /// For true 24/7 monitoring without the app running, this logic should be moved
  /// to a Supabase Edge Function.
  Future<void> checkForPriceDrops() async {
    debugPrint("Checking for price drops...");
    try {
      // 1. Get all active price alerts with current prices
      // We use the `select` with a join. Ensure you have foreign key set up:
      // ALTER TABLE price_alerts ADD CONSTRAINT fk_product FOREIGN KEY (product_id) REFERENCES products(id);
      // Or if using product_catalog view which might not have FK directly on alerts, 
      // you might need to fetch alerts and then fetch products separately (like in PriceAlertService).
      // However, assuming the user has set up the relation as requested:
      final response = await _supabase
          .from('price_alerts')
          .select('*, products:product_id(name, min_price)')
          .eq('is_active', true);

      final List<dynamic> alerts = response as List<dynamic>;

      // 2. Check each alert
      for (final alert in alerts) {
        if (alert['products'] != null) {
          final productData = alert['products'];
          // Handle cases where product data might be a list or map depending on relation type (one-to-one vs one-to-many)
          // Usually it's a Map if it's a single product relation.
          final Map<String, dynamic> product = productData is List 
              ? (productData.isNotEmpty ? productData.first : {}) 
              : productData;
          
          if (product.isNotEmpty && product.containsKey('min_price')) {
            final currentPrice = (product['min_price'] as num).toDouble();
            final targetPrice = (alert['target_price'] as num).toDouble();

            if (currentPrice <= targetPrice) {
              // Prepare enriched alert map for notification functions
              final enrichedAlert = Map<String, dynamic>.from(alert);
              enrichedAlert['current_price'] = currentPrice;
              enrichedAlert['old_price'] = targetPrice; // Use target as reference for "old"
              
              await notifyPriceDrop(enrichedAlert);
            }
          }
        }
      }
    } catch (e) {
      debugPrint("Error checking for price drops: $e");
    }
  }

  Future<void> notifyPriceDrop(Map<String, dynamic> alert) async {
    final productName = alert['products']['name'];
    final currentPrice = alert['current_price'];
    
    debugPrint("Price drop detected for $productName! Now $currentPrice");
    
    // Create notification in DB
    await createPriceDropNotification(alert);

    // Send push notification (Local notification in this context)
    await sendPriceDropPush(alert);
  }

  Future<void> createPriceDropNotification(Map<String, dynamic> alert) async {
    try {
      final notification = {
        'user_id': alert['user_id'],
        'title': 'Price Drop Alert! 🏷️',
        'body': '${alert['products']['name']} is now ${alert['current_price']} MMK',
        'data': {
          'type': 'price_drop',
          'product_id': alert['product_id'],
          'old_price': alert['old_price'],
          'new_price': alert['current_price'],
        },
        'created_at': DateTime.now().toIso8601String(),
        'read': false, // Explicitly set read status if column has default false but we want to be sure
      };
      
      await _supabase.from('notifications').insert(notification);
    } catch (e) {
      debugPrint("Error creating notification record: $e");
    }
  }

  Future<void> sendPriceDropPush(Map<String, dynamic> alert) async {
    // In a client-side service, "sending a push" to the current user 
    // is effectively showing a local notification.
    
    final productName = alert['products']['name'];
    final currentPrice = alert['current_price'];
    
    const AndroidNotificationDetails androidPlatformChannelSpecifics =
        AndroidNotificationDetails(
      'price_alert_channel',
      'Price Alerts',
      channelDescription: 'Notifications for price drops',
      importance: Importance.max,
      priority: Priority.high,
    );
    
    const NotificationDetails platformChannelSpecifics =
        NotificationDetails(android: androidPlatformChannelSpecifics);

    await _localNotificationsPlugin.show(
      alert['id'].hashCode, // Use alert ID hash as notification ID
      'Price Drop Alert!',
      '$productName is now available for $currentPrice MMK',
      platformChannelSpecifics,
      payload: 'product_id:${alert['product_id']}',
    );
  }
}
