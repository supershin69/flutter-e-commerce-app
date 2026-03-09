import 'package:e_commerce_frontend/models/price_alert_model.dart';
import 'package:e_commerce_frontend/services/price_alert_service.dart';
import 'package:flutter/foundation.dart';
import 'package:get/get.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class PriceAlertController extends GetxController {
  final _service = PriceAlertService();
  final _supabase = Supabase.instance.client;

  // Map of productId -> PriceAlert
  final RxMap<String, PriceAlert> activeAlerts = <String, PriceAlert>{}.obs;
  final RxBool isLoading = false.obs;

  @override
  void onInit() {
    super.onInit();
    _loadAlerts();
  }

  Future<void> _loadAlerts() async {
    final user = _supabase.auth.currentUser;
    if (user == null) return;

    try {
      isLoading.value = true;
      final alerts = await _service.getAlertsForUser(user.id);
      
      // Update map: productId -> alert
      final Map<String, PriceAlert> alertMap = {};
      for (var alert in alerts) {
        alertMap[alert.productId] = alert;
      }
      activeAlerts.assignAll(alertMap);
    } catch (e) {
      debugPrint("Error loading price alerts: $e");
    } finally {
      isLoading.value = false;
    }
  }

  bool hasPriceAlert(String productId) {
    return activeAlerts.containsKey(productId);
  }

  PriceAlert? getAlert(String productId) {
    return activeAlerts[productId];
  }

  Future<void> createAlert(String productId, String productName, int targetPrice) async {
    final user = _supabase.auth.currentUser;
    if (user == null) {
      Get.snackbar("Error", "You must be logged in to set alerts");
      return;
    }

    try {
      await _service.createAlert(
        userId: user.id,
        productId: productId,
        productName: productName,
        targetPrice: targetPrice,
      );
      
      // Reload to update UI
      await _loadAlerts();
      Get.snackbar("Success", "Price alert set for $productName");
    } catch (e) {
      Get.snackbar("Error", "Failed to set price alert");
    }
  }

  Future<void> deleteAlert(String productId) async {
    final alert = activeAlerts[productId];
    if (alert == null) return;

    try {
      await _service.deleteAlert(alert.id);
      
      // Reload to update UI
      await _loadAlerts();
      Get.snackbar("Success", "Price alert removed");
    } catch (e) {
      Get.snackbar("Error", "Failed to remove price alert");
    }
  }
}
