import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/product_model.dart';

class WishlistService {
  static final WishlistService _instance = WishlistService._internal();
  factory WishlistService() => _instance;
  WishlistService._internal();

  final supabase = Supabase.instance.client;
  
  // Real-time updates using ValueNotifier
  final ValueNotifier<Set<String>> wishlistIds = ValueNotifier({});
  
  bool _isInitialized = false;

  // Initialize and fetch wishlist
  Future<void> init() async {
    if (_isInitialized) return;
    await fetchWishlist();
    _isInitialized = true;
  }

  // Fetch all wishlist product IDs for the current user
  Future<void> fetchWishlist() async {
    try {
      final user = supabase.auth.currentUser;
      if (user == null) {
        wishlistIds.value = {};
        return;
      }

      final response = await supabase
          .from('wishlist_items')
          .select('product_id')
          .eq('user_id', user.id);

      final ids = (response as List<dynamic>)
          .map((row) => row['product_id'] as String)
          .toSet();
      
      wishlistIds.value = ids;
    } catch (e) {
      debugPrint('Error fetching wishlist: $e');
    }
  }

  // Check if a product is in wishlist
  bool isWishlisted(String productId) {
    return wishlistIds.value.contains(productId);
  }

  // Toggle wishlist state
  Future<bool> toggleWishlist(String productId) async {
    final user = supabase.auth.currentUser;
    if (user == null) return false;

    final isCurrentlyWishlisted = isWishlisted(productId);
    
    // Optimistic update
    final newSet = Set<String>.from(wishlistIds.value);
    if (isCurrentlyWishlisted) {
      newSet.remove(productId);
    } else {
      newSet.add(productId);
    }
    wishlistIds.value = newSet;

    try {
      if (isCurrentlyWishlisted) {
        await supabase
            .from('wishlist_items')
            .delete()
            .eq('user_id', user.id)
            .eq('product_id', productId);
      } else {
        await supabase.from('wishlist_items').insert({
          'user_id': user.id,
          'product_id': productId,
          'created_at': DateTime.now().toIso8601String(),
        });
      }
      return !isCurrentlyWishlisted; // Return new state (true = added, false = removed)
    } catch (e) {
      debugPrint('Error toggling wishlist: $e');
      // Revert on error
      wishlistIds.value = isCurrentlyWishlisted 
          ? (Set.from(newSet)..add(productId)) 
          : (Set.from(newSet)..remove(productId));
      return isCurrentlyWishlisted; // Return original state
    }
  }

  // Fetch full product details for wishlist page
  Future<List<Product>> fetchWishlistProducts() async {
    try {
      final user = supabase.auth.currentUser;
      if (user == null) return [];

      // Get product IDs from wishlist table
      final wishlistResponse = await supabase
          .from('wishlist_items')
          .select('product_id')
          .eq('user_id', user.id);

      if (wishlistResponse.isEmpty) return [];

      final productIds = (wishlistResponse as List<dynamic>)
          .map((row) => row['product_id'] as String)
          .toList();

      if (productIds.isEmpty) return [];

      // Fetch products from product_catalog using the IDs
      final productsResponse = await supabase
          .from('product_catalog')
          .select()
          .filter('id', 'in', '(${productIds.map((e) => '"$e"').join(',')})');

      return (productsResponse as List<dynamic>)
          .map((e) => Product.fromMap(e as Map<String, dynamic>))
          .toList();
    } catch (e) {
      debugPrint('Error fetching wishlist products: $e');
      return [];
    }
  }
}
