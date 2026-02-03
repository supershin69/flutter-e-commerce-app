import 'product_model.dart';

class CartItem {
  final String id; // cart item id
  final String productId;
  final String productName;
  final String variantId;
  final String? variantName; // e.g., "Red, 128GB"
  final int price;
  final int quantity;
  final String imageUrl;
  final String brandName;
  final String categoryName;

  CartItem({
    required this.id,
    required this.productId,
    required this.productName,
    required this.variantId,
    required this.variantName,
    required this.price,
    required this.quantity,
    required this.imageUrl,
    required this.brandName,
    required this.categoryName,
  });

  int get totalPrice => price * quantity;

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'product_id': productId,
      'product_name': productName,
      'variant_id': variantId,
      'variant_name': variantName,
      'price': price,
      'quantity': quantity,
      'image_url': imageUrl,
      'brand_name': brandName,
      'category_name': categoryName,
    };
  }

  factory CartItem.fromMap(Map<String, dynamic> map) {
    return CartItem(
      id: map['id'] as String,
      productId: map['product_id'] as String,
      productName: map['product_name'] as String,
      variantId: map['variant_id'] as String,
      variantName: map['variant_name'] as String?,
      price: map['price'] as int,
      quantity: map['quantity'] as int,
      imageUrl: map['image_url'] as String,
      brandName: map['brand_name'] as String,
      categoryName: map['category_name'] as String,
    );
  }

  CartItem copyWith({
    String? id,
    String? productId,
    String? productName,
    String? variantId,
    String? variantName,
    int? price,
    int? quantity,
    String? imageUrl,
    String? brandName,
    String? categoryName,
  }) {
    return CartItem(
      id: id ?? this.id,
      productId: productId ?? this.productId,
      productName: productName ?? this.productName,
      variantId: variantId ?? this.variantId,
      variantName: variantName ?? this.variantName,
      price: price ?? this.price,
      quantity: quantity ?? this.quantity,
      imageUrl: imageUrl ?? this.imageUrl,
      brandName: brandName ?? this.brandName,
      categoryName: categoryName ?? this.categoryName,
    );
  }
}
