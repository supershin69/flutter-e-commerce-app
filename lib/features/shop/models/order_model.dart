import 'package:e_commerce_frontend/models/cart_item_model.dart';
import 'dart:convert';

/// Model representing a completed order/transaction
/// Matches Supabase schema: id (uuid), user_id (uuid), total_amount (int4),
/// status (order_status enum), payment_status (payment_status enum),
/// shipping_address (jsonb with required city and street),
/// payment_method, shipping_method, customer_name, created_at (timestamptz)
class OrderModel {
  final String id; // UUID from database
  final String? userId; // UUID of the user
  final int totalAmount; // Total amount as integer (int4 in database)
  final String status; // Order status enum value
  final String paymentStatus; // Payment status enum value
  final Map<String, dynamic> shippingAddress; // JSONB with required city and street
  final String? customerName; // Separate column in database
  final String? paymentMethod; // Separate column in database
  final String? shippingMethod; // Separate column in database (not delivery_method)
  final DateTime createdAt; // When order was created

  // Convenience getters for shipping_address JSONB fields
  // Database requires: city and street (required by check constraint)
  String get city => shippingAddress['city'] as String? ?? '';
  String get street => shippingAddress['street'] as String? ?? '';
  
  // Additional optional fields that may be stored in shipping_address
  String get address => '$street, $city'; // Combined for display
  String? get phoneNumber => shippingAddress['phone'] as String?;
  List<CartItem> get items {
    final itemsList = shippingAddress['items'] as List<dynamic>?;
    if (itemsList == null) return [];
    return itemsList
        .map((item) => CartItem.fromMap(item as Map<String, dynamic>))
        .toList();
  }
  String? get receiptUrl => shippingAddress['receipt_url'] as String?;

  // Computed properties for backward compatibility
  DateTime get orderDate => createdAt;
  double get totalAmountDouble => totalAmount.toDouble();

  OrderModel({
    required this.id,
    this.userId,
    required this.totalAmount,
    required this.status,
    required this.paymentStatus,
    required this.shippingAddress,
    this.customerName,
    this.paymentMethod,
    this.shippingMethod,
    required this.createdAt,
  });

  /// Convert OrderModel to JSON map (for display/logging purposes)
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'user_id': userId,
      'total_amount': totalAmount,
      'status': status,
      'payment_status': paymentStatus,
      'shipping_address': shippingAddress,
      'customer_name': customerName,
      'payment_method': paymentMethod,
      'shipping_method': shippingMethod,
      'created_at': createdAt.toIso8601String(),
    };
  }

  /// Create OrderModel from JSON map
  factory OrderModel.fromJson(Map<String, dynamic> json) {
    return OrderModel(
      id: json['id'] as String? ?? '',
      userId: json['user_id'] as String?,
      totalAmount: json['total_amount'] is int
          ? json['total_amount'] as int
          : (json['total_amount'] is double
              ? (json['total_amount'] as double).toInt()
              : int.tryParse(json['total_amount']?.toString() ?? '0') ?? 0),
      status: json['status'] as String? ?? 'processing',
      paymentStatus: json['payment_status'] as String? ?? 'pending',
      shippingAddress: json['shipping_address'] is Map<String, dynamic>
          ? Map<String, dynamic>.from(json['shipping_address'])
          : (json['shipping_address'] is String
              ? jsonDecode(json['shipping_address']) as Map<String, dynamic>
              : {}),
      customerName: json['customer_name'] as String?,
      paymentMethod: json['payment_method'] as String?,
      shippingMethod: json['shipping_method'] as String?,
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'] as String)
          : DateTime.now(),
    );
  }

  /// Create OrderModel from Supabase database row
  /// Matches the actual database schema
  factory OrderModel.fromDatabaseMap(Map<String, dynamic> map) {
    // Handle shipping_address JSONB - could be Map or String
    Map<String, dynamic> shippingData = {};
    if (map['shipping_address'] != null) {
      if (map['shipping_address'] is Map<String, dynamic>) {
        shippingData = Map<String, dynamic>.from(map['shipping_address']);
      } else if (map['shipping_address'] is String) {
        shippingData = jsonDecode(map['shipping_address']) as Map<String, dynamic>;
      }
    }

    return OrderModel(
      id: map['id'] as String? ?? '',
      userId: map['user_id'] as String?,
      totalAmount: map['total_amount'] is int
          ? map['total_amount'] as int
          : (map['total_amount'] is double
              ? (map['total_amount'] as double).toInt()
              : int.tryParse(map['total_amount']?.toString() ?? '0') ?? 0),
      status: map['status'] as String? ?? 'processing',
      paymentStatus: map['payment_status'] as String? ?? 'pending',
      shippingAddress: shippingData,
      customerName: map['customer_name'] as String?,
      paymentMethod: map['payment_method'] as String?,
      shippingMethod: map['shipping_method'] as String?,
      createdAt: map['created_at'] != null
          ? DateTime.parse(map['created_at'] as String)
          : DateTime.now(),
    );
  }

  /// Create a copy of OrderModel with updated fields
  OrderModel copyWith({
    String? id,
    String? userId,
    int? totalAmount,
    String? status,
    String? paymentStatus,
    Map<String, dynamic>? shippingAddress,
    String? customerName,
    String? paymentMethod,
    String? shippingMethod,
    DateTime? createdAt,
  }) {
    return OrderModel(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      totalAmount: totalAmount ?? this.totalAmount,
      status: status ?? this.status,
      paymentStatus: paymentStatus ?? this.paymentStatus,
      shippingAddress: shippingAddress ?? Map<String, dynamic>.from(this.shippingAddress),
      customerName: customerName ?? this.customerName,
      paymentMethod: paymentMethod ?? this.paymentMethod,
      shippingMethod: shippingMethod ?? this.shippingMethod,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  /// Get total number of items in the order
  int get totalItems => items.fold(0, (sum, item) => sum + item.quantity);

  /// Check if order is completed/delivered
  bool get isCompleted => status.toLowerCase() == 'delivered';

  /// Check if order is cancelled
  bool get isCancelled => status.toLowerCase() == 'cancelled';

  @override
  String toString() {
    return 'OrderModel(id: $id, userId: $userId, totalAmount: $totalAmount, status: $status, paymentStatus: $paymentStatus)';
  }
}
