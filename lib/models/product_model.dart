import 'variant_attribute_model.dart';
class Product {
  final String id;
  final String name;
  final String description;
  final String categoryName;
  final String brandName;
  final int minPrice;
  final int maxPrice;
  final List<ProductVariant> variants;
  final List<ProductImage> images;

  Product({
    required this.id,
    required this.name,
    required this.description,
    required this.minPrice,
    required this.maxPrice,
    required this.variants,
    required this.images,
    required this.categoryName,
    required this.brandName,
  });

  factory Product.fromMap(Map<String, dynamic> map) {
  return Product(
    id: map['id']?.toString() ?? '',
    name: map['name']?.toString() ?? '',
    description: map['description'] ?? '',
    categoryName: map['category_name']?.toString() ?? '',
    brandName: map['brand_name']?.toString() ?? '',
    minPrice: map['min_price'] is int ? map['min_price'] : (int.tryParse(map['min_price']?.toString() ?? '0') ?? 0),
    maxPrice: map['max_price'] is int ? map['max_price'] : (int.tryParse(map['max_price']?.toString() ?? '0') ?? 0),
    variants: (map['variants'] as List<dynamic>?)
            ?.map((x) => ProductVariant.fromMap(x as Map<String, dynamic>))
            .toList() ?? [],
    images: (map['images'] as List<dynamic>?)
            ?.map((x) {
              // If x is a String (the old format), wrap it in a Map-like structure
              if (x is String) {
                return ProductImage(url: x, attributeValueId: null);
              }
              // If it's already a Map, use the normal factory
              return ProductImage.fromMap(x as Map<String, dynamic>);
            })
            .toList() ?? [],
  );
}
}

class ProductVariant {
  final String id;
  final int price;
  final int quantity;
  final List<VariantAttribute> attributes;

  ProductVariant({
    required this.id,
    required this.price,
    required this.quantity,
    required this.attributes,
  });

  factory ProductVariant.fromMap(Map<String, dynamic> map) {
    return ProductVariant(
      id: map['id'],
      price: map['price'],
      quantity: map['quantity'],
      attributes: (map['attributes'] as List<dynamic>?)
              ?.map((x) => VariantAttribute.fromMap(x as Map<String, dynamic>))
              .toList() ?? [],
    );
  }
}



class ProductImage {
  final String url;
  final String? attributeValueId;

  ProductImage({required this.url, this.attributeValueId});

  factory ProductImage.fromMap(Map<String, dynamic> map) {
    return ProductImage(
      // Safely access keys even if they aren't exactly what we expect
      url: map['url']?.toString() ?? '', 
      attributeValueId: map['attribute_value_id']?.toString(),
    );
  }
}