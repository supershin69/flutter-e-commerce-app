import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/cart_item_model.dart';

class CartService {
  static const String _cartKey = 'cart_items';

  static final RegExp _uuidRegex = RegExp(
    r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[1-5][0-9a-fA-F]{3}-[89abAB][0-9a-fA-F]{3}-[0-9a-fA-F]{12}$',
  );

  static bool _isValidUuid(String value) {
    final v = value.trim();
    if (v.isEmpty) return false;
    return _uuidRegex.hasMatch(v);
  }

  Future<List<Map<String, dynamic>>> getRawCartItemMaps() async {
    final prefs = await SharedPreferences.getInstance();
    final cartJson = prefs.getString(_cartKey);

    if (cartJson == null || cartJson.isEmpty) return [];

    final decoded = json.decode(cartJson);
    if (decoded is! List) return [];

    return decoded
        .whereType<Map>()
        .map((e) => Map<String, dynamic>.from(e))
        .toList();
  }

  Future<int> cleanInvalidCartItems() async {
    final raw = await getRawCartItemMaps();
    if (raw.isEmpty) return 0;

    final validItems = <CartItem>[];
    var removed = 0;

    for (final map in raw) {
      try {
        final item = CartItem.fromMap(map);
        if (!_isValidUuid(item.variantId) || item.quantity <= 0) {
          removed++;
          continue;
        }
        validItems.add(item);
      } catch (_) {
        removed++;
      }
    }

    if (removed > 0) {
      await _saveCartItems(validItems);
    }

    return removed;
  }

  // Get all cart items
  Future<List<CartItem>> getCartItems() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final cartJson = prefs.getString(_cartKey);
      
      if (cartJson == null || cartJson.isEmpty) {
        return [];
      }

      final decoded = json.decode(cartJson);
      if (decoded is! List) return [];

      final validItems = <CartItem>[];
      var removed = 0;

      for (final raw in decoded) {
        try {
          if (raw is! Map) {
            removed++;
            continue;
          }
          final item = CartItem.fromMap(Map<String, dynamic>.from(raw));
          if (!_isValidUuid(item.variantId) || item.quantity <= 0) {
            removed++;
            continue;
          }
          validItems.add(item);
        } catch (_) {
          removed++;
        }
      }

      if (removed > 0) {
        await _saveCartItems(validItems);
      }

      return validItems;
    } catch (e) {
      return [];
    }
  }

  // Add item to cart
  Future<bool> addToCart(CartItem item) async {
    try {
      final cartItems = await getCartItems();
      
      // Check if item with same product and variant already exists
      final existingIndex = cartItems.indexWhere(
        (cartItem) => cartItem.productId == item.productId && cartItem.variantId == item.variantId,
      );

      if (existingIndex != -1) {
        // Update quantity if item exists
        final existingItem = cartItems[existingIndex];
        cartItems[existingIndex] = existingItem.copyWith(
          quantity: existingItem.quantity + item.quantity,
        );
      } else {
        // Add new item
        cartItems.add(item);
      }

      return await _saveCartItems(cartItems);
    } catch (e) {
      return false;
    }
  }

  // Update item quantity
  Future<bool> updateQuantity(String itemId, int quantity) async {
    try {
      final cartItems = await getCartItems();
      final index = cartItems.indexWhere((item) => item.id == itemId);

      if (index == -1) return false;

      if (quantity <= 0) {
        cartItems.removeAt(index);
      } else {
        cartItems[index] = cartItems[index].copyWith(quantity: quantity);
      }

      return await _saveCartItems(cartItems);
    } catch (e) {
      return false;
    }
  }

  // Remove item from cart
  Future<bool> removeFromCart(String itemId) async {
    try {
      final cartItems = await getCartItems();
      cartItems.removeWhere((item) => item.id == itemId);
      return await _saveCartItems(cartItems);
    } catch (e) {
      return false;
    }
  }

  // Clear cart
  Future<bool> clearCart() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return await prefs.remove(_cartKey);
    } catch (e) {
      return false;
    }
  }

  // Get cart count
  Future<int> getCartCount() async {
    final cartItems = await getCartItems();
    return cartItems.fold<int>(0, (sum, item) => sum + item.quantity);
  }

  // Get total price
  Future<int> getTotalPrice() async {
    final cartItems = await getCartItems();
    return cartItems.fold<int>(0, (sum, item) => sum + item.totalPrice);
  }

  // Save cart items to SharedPreferences
  Future<bool> _saveCartItems(List<CartItem> items) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final cartJson = json.encode(items.map((item) => item.toMap()).toList());
      return await prefs.setString(_cartKey, cartJson);
    } catch (e) {
      return false;
    }
  }
}
