import 'package:flutter/foundation.dart';
import 'package:get/get.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:e_commerce_frontend/models/product_model.dart';
import 'package:e_commerce_frontend/models/price_alert_model.dart';

class ProductController extends GetxController {
  static ProductController get instance => Get.find();
  
  final supabase = Supabase.instance.client;
  
  // Reactive list of wishlisted product IDs
  final RxList<String> wishlistedProductIds = <String>[].obs;
  
  // Reactive list of full wishlisted products (for Wishlist Page)
  final RxList<Product> wishlistProducts = <Product>[].obs;
  final RxBool isLoadingWishlist = false.obs;
  
  // Real-time Price Updates
  // Map of productId -> current minPrice
  final RxMap<String, double> realTimePrices = <String, double>{}.obs;
  RealtimeChannel? _priceSubscription;

  // Price Alerts
  final RxMap<String, PriceAlert> priceAlerts = <String, PriceAlert>{}.obs;

  // Robust getter for wishlist products filtering
  List<Product> get filteredWishlistProducts {
    // If we have fetched full products, use those (filtered by current IDs)
    if (wishlistProducts.isNotEmpty) {
      return wishlistProducts.where((p) => wishlistedProductIds.contains(p.id.toString().trim())).toList();
    }
    return [];
  }

  @override
  void onInit() {
    super.onInit();
    fetchWishlistIds();
    fetchPriceAlerts();
    _subscribeToPriceChanges();
  }

  @override
  void onClose() {
    _priceSubscription?.unsubscribe();
    super.onClose();
  }

  void _subscribeToPriceChanges() {
    // Listen to UPDATE events on product_variants table
    _priceSubscription = supabase
        .channel('public:product_variants')
        .onPostgresChanges(
          event: PostgresChangeEvent.update,
          schema: 'public',
          table: 'product_variants',
          callback: (payload) {
            _handlePriceUpdate(payload);
          },
        )
        .subscribe();
  }

  void _handlePriceUpdate(PostgresChangePayload payload) {
    // Payload.newRecord contains the updated row
    final newRecord = payload.newRecord;
    if (newRecord.isEmpty) return;

    final String productId = newRecord['product_id'].toString();
    final double newPrice = (newRecord['price'] as num).toDouble();

    // Update our reactive map
    // Note: Since a product can have multiple variants, 'minPrice' logic is complex.
    // For simplicity, we trigger a refresh of the product data if we detect a change
    // or we can optimistically update if we know this is the base price.
    
    // Better approach: Since `minPrice` is an aggregate on the product, 
    // and we are listening to variants, we might need to re-fetch the product 
    // to get the correct new minPrice.
    _refreshProductPrice(productId);
  }

  Future<void> _refreshProductPrice(String productId) async {
    try {
      // Re-fetch product from 'product_catalog' view which likely calculates min_price
      final response = await supabase
          .from('product_catalog')
          .select('min_price')
          .eq('id', productId)
          .single();

      if (response != null && response['min_price'] != null) {
        final double newMinPrice = (response['min_price'] as num).toDouble();
        realTimePrices[productId] = newMinPrice;
        
        // Also update local wishlist products if present
        final index = wishlistProducts.indexWhere((p) => p.id == productId);
        if (index != -1) {
          // Clone and update to trigger reactivity
          final updatedProduct = wishlistProducts[index].copyWith(minPrice: newMinPrice);
          wishlistProducts[index] = updatedProduct;
        }
      }
    } catch (e) {
      debugPrint("Error refreshing product price: $e");
    }
  }

  double getPrice(String productId, double initialPrice) {
    // Return real-time price if available, otherwise initial
    return realTimePrices[productId] ?? initialPrice;
  }


  // Price Alert Logic
  Future<void> fetchPriceAlerts() async {
    final user = supabase.auth.currentUser;
    if (user == null) return;

    try {
      final data = await supabase
          .from('price_alerts')
          .select()
          .eq('user_id', user.id)
          .eq('is_active', true);

      final List<dynamic> alerts = data as List<dynamic>;
      for (final alert in alerts) {
        // Ensure product_id is treated as String
        final String productId = alert['product_id'].toString();
        priceAlerts[productId] = PriceAlert.fromJson(alert);
      }
    } catch (e) {
      debugPrint('Error fetching price alerts: $e');
    }
  }

  Future<void> setPriceAlert(String productId, int targetPrice, {String productName = ''}) async {
    final user = supabase.auth.currentUser;
    if (user == null) {
      Get.snackbar('Login Required', 'Please login to set price alerts');
      return;
    }

    try {
      // Check if we already have an alert for this product to update it
      String? existingId;
      if (priceAlerts.containsKey(productId)) {
        existingId = priceAlerts[productId]!.id;
      }

      final alert = {
        if (existingId != null) 'id': existingId,
        'user_id': user.id,
        'product_id': productId,
        'product_name': productName,
        'target_price': targetPrice,
        'is_active': true,
        // If updating, we might want to update created_at or have an updated_at column
        // But for now let's keep it simple
      };

      final response = await supabase
          .from('price_alerts')
          .upsert(alert)
          .select()
          .single();

      priceAlerts[productId] = PriceAlert.fromJson(response);

      Get.snackbar('Success', 'Price alert set! You\'ll be notified when price drops',
          snackPosition: SnackPosition.BOTTOM, duration: const Duration(seconds: 2));
    } catch (e) {
      debugPrint('Error setting price alert: $e');
      Get.snackbar('Error', 'Failed to set price alert');
    }
  }
  
  Future<void> deletePriceAlert(String productId) async {
    final user = supabase.auth.currentUser;
    if (user == null) return;
    
    if (!priceAlerts.containsKey(productId)) return;
    
    try {
      final alertId = priceAlerts[productId]!.id;
      
      await supabase
          .from('price_alerts')
          .delete()
          .eq('id', alertId);
          
      priceAlerts.remove(productId);
      
      Get.snackbar('Success', 'Price alert removed',
          snackPosition: SnackPosition.BOTTOM, duration: const Duration(seconds: 1));
    } catch (e) {
      debugPrint('Error deleting price alert: $e');
      Get.snackbar('Error', 'Failed to remove price alert');
    }
  }

  bool hasPriceAlert(String productId) {
    return priceAlerts.containsKey(productId);
  }
  
  PriceAlert? getPriceAlert(String productId) {
    return priceAlerts[productId];
  }

  // 1. Fetch Wishlist IDs on App Start
  Future<void> fetchWishlistIds() async {
    try {
      final user = supabase.auth.currentUser;
      if (user == null) {
        wishlistedProductIds.clear();
        return;
      }

      final response = await supabase
          .from('wishlist_items')
          .select('product_id')
          .eq('user_id', user.id);

      final ids = (response as List<dynamic>)
          .map((row) => row['product_id'].toString().trim())
          .toList();
      
      wishlistedProductIds.assignAll(ids);
      debugPrint("Wishlist IDs in memory: $wishlistedProductIds");
    } catch (e) {
      debugPrint('Error fetching wishlist IDs: $e');
    }
  }

  // 2. Toggle Wishlist Logic
  Future<void> toggleWishlist(Product product) async {
    final user = supabase.auth.currentUser;
    if (user == null) {
      Get.snackbar('Login Required', 'Please login to add items to wishlist');
      return;
    }

    final productId = product.id.toString().trim();
    
    // Optimistic Update
    if (wishlistedProductIds.contains(productId)) {
      wishlistedProductIds.remove(productId);
    } else {
      wishlistedProductIds.add(productId);
    }

    try {
      if (!wishlistedProductIds.contains(productId)) {
        // Was removed (so we delete from DB)
        // Also update the full product list if it's there
        wishlistProducts.removeWhere((p) => p.id.toString().trim() == productId);
        
        await supabase
            .from('wishlist_items')
            .delete()
            .eq('user_id', user.id)
            .eq('product_id', productId);
            
        Get.snackbar('Success', 'Removed from Wishlist', 
          snackPosition: SnackPosition.BOTTOM, duration: const Duration(seconds: 1));
      } else {
        // Was added (so we insert into DB)
        await supabase.from('wishlist_items').insert({
          'user_id': user.id,
          'product_id': productId,
          'created_at': DateTime.now().toIso8601String(),
        });
        
        Get.snackbar('Success', 'Added to Wishlist', 
          snackPosition: SnackPosition.BOTTOM, duration: const Duration(seconds: 1));
      }

      await fetchWishlistProducts();
    } catch (e) {
      debugPrint('Error toggling wishlist: $e');
      // Revert if error
      // If we removed it (so it's NOT in the list now), we add it back.
      // If we added it (so it IS in the list now), we remove it.
      if (!wishlistedProductIds.contains(productId)) {
        wishlistedProductIds.add(productId);
      } else {
        wishlistedProductIds.remove(productId);
      }
      Get.snackbar('Error', 'Failed to update wishlist');
    }
  }

  // 3. Fetch Full Wishlist Products (for Wishlist Page)
  Future<void> fetchWishlistProducts() async {
    try {
      isLoadingWishlist.value = true;
      final user = supabase.auth.currentUser;
      
      if (user == null || wishlistedProductIds.isEmpty) {
        wishlistProducts.clear();
        return;
      }

      // We use the already fetched IDs to get product details
      final productsResponse = await supabase
          .from('product_catalog')
          .select()
          .inFilter('id', wishlistedProductIds.toList());

      final products = (productsResponse as List<dynamic>)
          .map((e) => Product.fromMap(e as Map<String, dynamic>))
          .toList();
          
      wishlistProducts.assignAll(products);
    } catch (e) {
      debugPrint('Error fetching wishlist products: $e');
    } finally {
      isLoadingWishlist.value = false;
    }
  }
}
