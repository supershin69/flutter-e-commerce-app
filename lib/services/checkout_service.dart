import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';
import '../models/cart_item_model.dart';
import '../features/shop/models/order_model.dart';

class CheckoutService {
  final supabase = Supabase.instance.client;
  final _uuid = const Uuid();

  static final RegExp _uuidRegex = RegExp(
    r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[1-5][0-9a-fA-F]{3}-[89abAB][0-9a-fA-F]{3}-[0-9a-fA-F]{12}$',
  );

  static bool _isValidUuid(String value) {
    final v = value.trim();
    if (v.isEmpty) return false;
    return _uuidRegex.hasMatch(v);
  }

  /// Create a new order in "pending delivery fee" state.
  /// Stock is NOT decreased until the customer accepts the delivery fee.
  Future<OrderModel?> createOrder({
    String? orderId, // Optional UUID, will generate if not provided
    required String userId, // Required - user_id has NOT NULL constraint
    required List<CartItem> items,
    required int totalAmount, // Must be int to match int4 in database
    required String city, // City name (e.g., "Mandalay")
    required String street, // Street address (e.g., "73 x 74" or "MIIT")
    required String phoneNumber,
    required String customerName,
    String status = 'pending', // Should match order_status enum
    String paymentStatus = 'pending', // Should match payment_status enum
    String? paymentMethod,
    String? shippingMethod, // Note: database uses shipping_method, not delivery_method
    String? transactionId, // Transaction ID from mobile banking (last 6 digits)
    String? receiptUrl, // Public URL of uploaded payment receipt image
  }) async {
    // 1. Generate Order ID
    final finalOrderId = orderId ?? _uuid.v4();
    final normalizedPaymentStatus = paymentStatus.trim().isEmpty ? 'pending' : paymentStatus.trim();
    final normalizedPaymentMethod = (paymentMethod == null || paymentMethod.trim().isEmpty)
        ? 'cash-on-delivery'
        : paymentMethod.trim();
    final normalizedShippingMethod = (shippingMethod == null || shippingMethod.trim().isEmpty)
        ? 'standard'
        : shippingMethod.trim();

    // 2. Prepare order data
    final shippingAddressJson = {
      'city': city.trim(),
      'street': street.trim(),
      'phone': phoneNumber,
      'name': customerName,
      // We don't need to store items in JSON anymore since we use order_items table,
      // but keeping it for backward compatibility if needed by frontend
      'items': items.map((item) => item.toMap()).toList(),
    };

    if (receiptUrl != null && receiptUrl.isNotEmpty) {
      shippingAddressJson['receipt_url'] = receiptUrl;
    }

    if (items.isEmpty) {
      throw Exception('Your cart is empty.');
    }

    final invalidItems = <CartItem>[];
    for (final item in items) {
      if (!_isValidUuid(item.variantId)) {
        invalidItems.add(item);
      }
    }

    if (invalidItems.isNotEmpty) {
      for (final bad in invalidItems) {
        debugPrint(
          'Invalid cart item variant_id. product="${bad.productName}" '
          'variantId="${bad.variantId}" variantName="${bad.variantName}" '
          'quantity=${bad.quantity}',
        );
      }
      throw Exception('Some items in your cart are missing a valid variant. Please remove them and add again.');
    }

    // Prepare items JSON for RPC
    final itemsJson = items.map((item) {
      return {
        'variant_id': item.variantId,
        'quantity': item.quantity,
        'price': item.price,
        'product_name': item.productName,
        'attributes': {
          if (item.variantName != null) 'variant': item.variantName
        }
      };
    }).toList();

    try {
      debugPrint('create_order_pending_fee items payload: $itemsJson');
      final response = await supabase.rpc(
        'create_order_pending_fee',
        params: {
          'p_order_id': finalOrderId,
          'p_user_id': userId,
          'p_total_amount': totalAmount,
          'p_payment_status': normalizedPaymentStatus,
          'p_shipping_address': shippingAddressJson,
          'p_payment_method': normalizedPaymentMethod,
          'p_shipping_method': normalizedShippingMethod,
          'p_customer_name': customerName,
          'p_items': itemsJson,
          if (transactionId != null && transactionId.isNotEmpty) 'p_transaction_id': transactionId,
        },
      );

      debugPrint('Order created (pending_fee) via RPC: $response');

      // Fetch the created order to return OrderModel
      final orderData = await supabase
          .from('orders')
          .select()
          .eq('id', finalOrderId)
          .single();

      return OrderModel.fromDatabaseMap(orderData);

    } catch (e) {
      debugPrint('Checkout Error: $e');
      rethrow; // Pass error to UI
    }
  }

  Future<List<OrderModel>> getOrdersPendingDeliveryFeeForAdmin() async {
    final data = await supabase.rpc('admin_list_orders_pending_fee');
    return (data as List<dynamic>)
        .map((e) => OrderModel.fromDatabaseMap(Map<String, dynamic>.from(e as Map)))
        .toList();
  }

  Future<void> adminSetDeliveryFee({
    required String orderId,
    required int deliveryFee,
    bool force = false,
  }) async {
    await supabase.rpc(
      'admin_set_delivery_fee',
      params: {
        'p_order_id': orderId,
        'p_delivery_fee': deliveryFee,
        'p_force': force,
      },
    );
  }

  Future<void> customerAcceptDeliveryFee(String orderId) async {
    final user = supabase.auth.currentUser;
    if (user == null) {
      throw Exception('Please login to continue');
    }
    await supabase.rpc(
      'accept_delivery_fee',
      params: {'p_order_id': orderId, 'p_user_id': user.id},
    );
  }

  Future<void> customerRejectDeliveryFee(String orderId) async {
    final user = supabase.auth.currentUser;
    if (user == null) {
      throw Exception('Please login to continue');
    }
    await supabase.rpc(
      'reject_delivery_fee',
      params: {'p_order_id': orderId, 'p_user_id': user.id},
    );
  }

  /// Get all orders for a user
  Future<List<OrderModel>> getUserOrders(String userId) async {
    try {
      // We only fetch the orders table. Order items are currently stored in 
      // the shipping_address JSONB column which OrderModel uses.
      // If we need to fetch from order_items table in the future, we can add a join here.
      // But for now, to avoid "Could not find a relationship" error until schema is fixed,
      // we just fetch the orders.
      final data = await supabase
          .from('orders')
          .select()
          .eq('user_id', userId)
          .order('created_at', ascending: false);

      return (data as List).map<OrderModel>((order) => OrderModel.fromDatabaseMap(order)).toList();
    } catch (e) {
      debugPrint('Error fetching user orders: $e');
      return [];
    }
  }
}
