class PriceAlert {
  final String id;
  final String userId;
  final String productId;
  final String productName; // Optional: Store name for easier display without fetching product
  final int targetPrice;
  final bool isActive;
  final DateTime createdAt;

  PriceAlert({
    required this.id,
    required this.userId,
    required this.productId,
    required this.productName,
    required this.targetPrice,
    required this.isActive,
    required this.createdAt,
  });

  factory PriceAlert.fromMap(Map<String, dynamic> map) {
    return PriceAlert(
      id: map['id'] ?? '',
      userId: map['user_id'] ?? '',
      productId: map['product_id'] ?? '',
      productName: map['product_name'] ?? '', // Assuming we might store it or join it
      targetPrice: map['target_price']?.toInt() ?? 0,
      isActive: map['is_active'] ?? true,
      createdAt: DateTime.parse(map['created_at'] ?? DateTime.now().toIso8601String()),
    );
  }

  factory PriceAlert.fromJson(Map<String, dynamic> json) => PriceAlert.fromMap(json);

  Map<String, dynamic> toMap() {
    return {
      'user_id': userId,
      'product_id': productId,
      'product_name': productName,
      'target_price': targetPrice,
      'is_active': isActive,
      // created_at is usually handled by DB default
    };
  }
}
