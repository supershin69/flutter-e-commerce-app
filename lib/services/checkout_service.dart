import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';
import '../models/cart_item_model.dart';
import '../features/shop/models/order_model.dart';

class CheckoutService {
  final supabase = Supabase.instance.client;
  final _uuid = const Uuid();

  /// Create a new order and save it to the database
  /// Requires authenticated user (user_id is NOT NULL in database)
  /// Matches Supabase schema: id (uuid), user_id (uuid), total_amount (int4),
  /// status (order_status enum), payment_status (payment_status enum),
  /// shipping_address (jsonb with required city and street),
  /// payment_method, shipping_method, customer_name, created_at (timestamptz)
  Future<OrderModel?> createOrder({
    String? orderId, // Optional UUID, will generate if not provided
    required String userId, // Required - user_id has NOT NULL constraint
    required List<CartItem> items,
    required int totalAmount, // Must be int to match int4 in database
    required String city, // City name (e.g., "Mandalay")
    required String street, // Street address (e.g., "73 x 74" or "MIIT")
    required String phoneNumber,
    required String customerName,
    String status = 'processing', // Should match order_status enum
    String paymentStatus = 'pending', // Should match payment_status enum
    String? paymentMethod,
    String? shippingMethod, // Note: database uses shipping_method, not delivery_method
    String? transactionId, // Transaction ID from mobile banking (last 6 digits)
    String? receiptUrl, // Public URL of uploaded payment receipt image
  }) async {
    try {
      // Generate UUID if not provided
      final finalOrderId = orderId ?? _uuid.v4();

      // Build shipping_address JSONB object with required fields
      // Database constraint requires: {"city": "...", "street": "..."}
      final shippingAddressJson = {
        'city': city.trim(),
        'street': street.trim(),
        // Optional additional fields
        'phone': phoneNumber,
        'name': customerName,
        'items': items.map((item) => item.toMap()).toList(),
      };

      // Attach receipt URL to shipping_address JSONB if available so it can be
      // accessed via OrderModel.receiptUrl for display in the UI.
      if (receiptUrl != null && receiptUrl.isNotEmpty) {
        shippingAddressJson['receipt_url'] = receiptUrl;
      }

      // Create order data matching the exact Supabase schema
      final orderData = {
        'id': finalOrderId,
        'user_id': userId,
        'total_amount': totalAmount, // int4 in database
        'status': status, // order_status enum
        'payment_status': paymentStatus, // payment_status enum
        'shipping_address': shippingAddressJson, // JSONB with required city and street
        'payment_method': paymentMethod ?? 'cash-on-delivery',
        'shipping_method': shippingMethod ?? 'standard',
        'customer_name': customerName,
        if (transactionId != null && transactionId.isNotEmpty) 'transaction_id': transactionId,
        // created_at will be set automatically by database default
      };

      debugPrint('Creating order with data: $orderData');

      // Insert order into orders table
      final response = await supabase
          .from('orders')
          .insert(orderData)
          .select()
          .single();

      debugPrint('Order created successfully: $response');

      // Create OrderModel from response
      return OrderModel.fromDatabaseMap(response);
    } catch (e, stackTrace) {
      debugPrint('Error creating order: $e');
      debugPrint('Stack trace: $stackTrace');
      // Re-throw with more details for better error handling
      throw Exception('Failed to create order: $e');
    }
  }

  /// Get all orders for a user
  /// Returns empty list if userId is null (guest orders can't be retrieved by user)
  Future<List<OrderModel>> getUserOrders(String userId) async {
    try {
      final data = await supabase
          .from('orders')
          .select()
          .eq('user_id', userId)
          .order('created_at', ascending: false);

      return data
          .map<OrderModel>((order) => OrderModel.fromDatabaseMap(order))
          .toList();
    } catch (e) {
      debugPrint('Error fetching user orders: $e');
      return [];
    }
  }

  /// Get a single order by ID
  Future<OrderModel?> getOrderById(String orderId) async {
    try {
      final data = await supabase
          .from('orders')
          .select()
          .eq('id', orderId)
          .maybeSingle();

      if (data == null) return null;

      return OrderModel.fromDatabaseMap(data);
    } catch (e) {
      debugPrint('Error fetching order: $e');
      return null;
    }
  }
}
