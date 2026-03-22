import 'package:e_commerce_frontend/models/price_alert_model.dart';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

class PriceAlertService {
  final SupabaseClient _supabase = Supabase.instance.client;
  final FlutterLocalNotificationsPlugin _localNotificationsPlugin = FlutterLocalNotificationsPlugin();

  /// Create a new price alert for a product
  Future<void> createAlert({
    required String userId,
    required String productId,
    required String productName,
    required int targetPrice,
  }) async {
    try {
      await _supabase.from('price_alerts').insert({
        'user_id': userId,
        'product_id': productId,
        'product_name': productName,
        'target_price': targetPrice,
        'is_active': true,
      });
      debugPrint("Price alert created for product: $productName");
    } catch (e) {
      debugPrint("Error creating price alert: $e");
      rethrow;
    }
  }

  /// Delete an existing price alert
  Future<void> deleteAlert(String alertId) async {
    try {
      await _supabase.from('price_alerts').delete().eq('id', alertId);
      debugPrint("Price alert deleted: $alertId");
    } catch (e) {
      debugPrint("Error deleting price alert: $e");
      rethrow;
    }
  }

  /// Get all active price alerts for a specific user
  Future<List<PriceAlert>> getAlertsForUser(String userId) async {
    try {
      final response = await _supabase
          .from('price_alerts')
          .select()
          .eq('user_id', userId)
          .eq('is_active', true)
          .order('created_at', ascending: false);

      final List<dynamic> data = response as List<dynamic>;
      return data.map((e) => PriceAlert.fromMap(e)).toList();
    } catch (e) {
      debugPrint("Error fetching price alerts: $e");
      return [];
    }
  }

  /// Check for price changes against active alerts
  /// This function should be called periodically (e.g., via a background task or timer)
  Future<void> checkPriceChanges() async {
    final user = _supabase.auth.currentUser;
    if (user == null) return;

    try {
      // 1. Get all active alerts for the current user
      final alerts = await getAlertsForUser(user.id);
      if (alerts.isEmpty) return;

      // 2. Extract product IDs
      final productIds = alerts.map((e) => e.productId).toList();

      // 3. Fetch current product prices from Supabase
      // Using 'product_catalog' view as it aggregates product data including min_price
      final response = await _supabase
          .from('product_catalog')
          .select('id, name, min_price') 
          .filter('id', 'in', productIds);

      final List<dynamic> productsData = response as List<dynamic>;
      
      // 4. Compare prices and trigger notifications
      for (final alert in alerts) {
        final product = productsData.firstWhere(
          (p) => p['id'] == alert.productId,
          orElse: () => null,
        );

        if (product != null) {
          final double currentPrice = (product['min_price'] as num).toDouble();
          
          if (currentPrice <= alert.targetPrice) {
            // Trigger notification
            await _showPriceDropNotification(alert, currentPrice);
            
            // Optional: Update alert to prevent repeated notifications for the same price?
            // For now, we keep it active as requested.
          }
        }
      }
    } catch (e) {
      debugPrint("Error checking price changes: $e");
    }
  }

  Future<void> _showPriceDropNotification(PriceAlert alert, double currentPrice) async {
    const AndroidNotificationDetails androidPlatformChannelSpecifics =
        AndroidNotificationDetails(
      'high_importance_channel', // Reuse existing channel
      'High Importance Notifications',
      channelDescription: 'This channel is used for important notifications.',
      importance: Importance.max,
      priority: Priority.high,
      showWhen: true,
    );
    const NotificationDetails platformChannelSpecifics =
        NotificationDetails(android: androidPlatformChannelSpecifics);

    await _localNotificationsPlugin.show(
      alert.hashCode,
      'Price Drop Alert!',
      '${alert.productName} is now available for \$${currentPrice.toStringAsFixed(2)} (Target: \$${alert.targetPrice})',
      platformChannelSpecifics,
      payload: 'product_id:${alert.productId}',
    );
  }
}
