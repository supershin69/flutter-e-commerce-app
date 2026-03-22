
import 'dart:convert';

class Product {
  final String id;
  final String name;
  final String description;
  final double minPrice;
  final double maxPrice;
  final String brandName;
  final String categoryName;
  final DateTime? createdAt;
  final bool? isArchived;
  final List<ProductImage> images;
  final List<ProductVariant> variants;
  final double discount;
  final double displayPrice;

  Product({
    required this.id,
    required this.name,
    required this.description,
    required this.minPrice,
    required this.maxPrice,
    required this.brandName,
    required this.categoryName,
    this.createdAt,
    this.isArchived,
    required this.images,
    required this.variants,
    required this.discount,
    required this.displayPrice,
  }) {
    // Constructor body can be empty or contain initialization logic
  }

  String get imageUrl {
    for (final image in images) {
      if (image.url.isNotEmpty) {
        return image.url;
      }
    }
    return '';
  }

  bool get archived => isArchived ?? false;

  bool get hasStock => variants.any((v) => v.stock > 0);

  bool get isAvailable => !archived && (variants.isEmpty || hasStock);

  static List<dynamic> _asJsonList(dynamic value) {
    if (value == null) return const [];
    if (value is List) return value;
    if (value is String) {
      final trimmed = value.trim();
      if (trimmed.isEmpty) return const [];
      final decoded = jsonDecode(trimmed);
      return decoded is List ? decoded : const [];
    }
    return const [];
  }

  static String _firstNonEmptyString(Map<String, dynamic> map, List<String> keys) {
    for (final key in keys) {
      final value = map[key];
      if (value != null) {
        if (value is String) {
          if (value.isNotEmpty) return value;
        } else {
          final strValue = value.toString();
          if (strValue.isNotEmpty) return strValue;
        }
      }
    }
    return '';
  }

  static String _extractImageUrlFromImagesColumn(dynamic value) {
    final list = _asJsonList(value);
    if (list.isEmpty) {
      return '';
    }
    final firstItem = list.first;
    if (firstItem is String) {
      return firstItem;
    }
    if (firstItem is Map) {
      final firstMap = Map<String, dynamic>.from(firstItem);
      return _firstNonEmptyString(firstMap, ['url', 'image_url', 'image', 'img_url']);
    }
    return firstItem.toString();
  }

  static List<ProductImage> _parseImages(Map<String, dynamic> map) {
    final imagesRaw = map['images'] ?? map['product_images'];
    final parsedImages = _asJsonList(imagesRaw)
        .map((e) {
          if (e is Map) {
            return ProductImage.fromMap(Map<String, dynamic>.from(e));
          }
          return ProductImage(url: e?.toString() ?? '');
        })
        .where((image) => image.url.isNotEmpty)
        .toList();

    if (parsedImages.isNotEmpty) {
      return parsedImages;
    }

    final singleImageUrl = _firstNonEmptyString(
      map,
      ['image_url', 'image', 'img_url', 'thumbnail_url'],
    );

    if (singleImageUrl.isNotEmpty) {
      return [ProductImage(url: singleImageUrl)];
    }

    return [];
  }

  factory Product.fromJson(Map<String, dynamic> json) {
    final minPrice = (json['min_price'] as num?)?.toDouble() ?? 0.0;
    final maxPrice = (json['max_price'] as num?)?.toDouble() ?? 0.0;
    DateTime? createdAt;
    final createdAtRaw = json['created_at'];
    if (createdAtRaw is String && createdAtRaw.isNotEmpty) {
      createdAt = DateTime.tryParse(createdAtRaw);
    }
    final imageUrlFromImages = _extractImageUrlFromImagesColumn(json['images']);
    final fallbackImageUrl = _firstNonEmptyString(
      json,
      ['image_url', 'image', 'img_url', 'thumbnail_url'],
    );
    final resolvedImageUrl = imageUrlFromImages.isNotEmpty ? imageUrlFromImages : fallbackImageUrl;
    final parsedImages = _parseImages(json);
    final images = parsedImages.isNotEmpty
        ? parsedImages
        : (resolvedImageUrl.isNotEmpty ? [ProductImage(url: resolvedImageUrl)] : <ProductImage>[]);

    return Product(
      id: json['id']?.toString() ?? '',
      name: json['name']?.toString() ?? 'Unknown Product',
      description: json['description']?.toString() ?? '',
      minPrice: minPrice,
      maxPrice: maxPrice,
      brandName: json['brand_name']?.toString() ?? 'Unknown Brand',
      categoryName: json['category_name']?.toString() ?? 'Unknown Category',
      createdAt: createdAt,
      isArchived: json['is_archived'] as bool?,
      images: images,
      variants: _asJsonList(json['variants'])
          .whereType<Map>()
          .map((e) => ProductVariant.fromMap(Map<String, dynamic>.from(e)))
          .toList(),
      discount: (json['discount'] as num?)?.toDouble() ?? 0.0,
      displayPrice: minPrice,
    );
  }

  factory Product.fromMap(Map<String, dynamic> map) {
    return Product.fromJson(map);
  }

  Product copyWith({
    String? id,
    String? name,
    String? description,
    double? minPrice,
    double? maxPrice,
    String? brandName,
    String? categoryName,
    DateTime? createdAt,
    bool? isArchived,
    List<ProductImage>? images,
    List<ProductVariant>? variants,
    double? discount,
    double? displayPrice,
  }) {
    return Product(
      id: id ?? this.id,
      name: name ?? this.name,
      description: description ?? this.description,
      minPrice: minPrice ?? this.minPrice,
      maxPrice: maxPrice ?? this.maxPrice,
      brandName: brandName ?? this.brandName,
      categoryName: categoryName ?? this.categoryName,
      createdAt: createdAt ?? this.createdAt,
      isArchived: isArchived ?? this.isArchived,
      images: images ?? this.images,
      variants: variants ?? this.variants,
      discount: discount ?? this.discount,
      displayPrice: displayPrice ?? this.displayPrice,
    );
  }
}

class ProductImage {
  final String url;
  final String? attributeValueId;

  ProductImage({required this.url, this.attributeValueId});

  factory ProductImage.fromMap(Map<String, dynamic> map) {
    return ProductImage(
      url: Product._firstNonEmptyString(
        map,
        ['url', 'image_url', 'image', 'img_url'],
      ),
      attributeValueId: map['attribute_value_id']?.toString(),
    );
  }
}

class ProductVariant {
  final String id;
  final double price;
  final int stock;
  final List<VariantAttribute> attributes;

  ProductVariant({
    required this.id,
    required this.price,
    required this.stock,
    required this.attributes,
  });

  factory ProductVariant.fromMap(Map<String, dynamic> map) {
    return ProductVariant(
      id: map['id']?.toString() ?? '',
      price: (map['price'] as num?)?.toDouble() ?? 0.0,
      stock: (map['stock'] as num?)?.toInt() ?? 0,
      attributes: Product._asJsonList(map['attributes'])
          .whereType<Map>()
          .map((e) => VariantAttribute.fromMap(Map<String, dynamic>.from(e)))
          .toList(),
    );
  }
}

class VariantAttribute {
  final String id;
  final String type;
  final String value;
  final String displayValue;

  VariantAttribute({
    required this.id,
    required this.type,
    required this.value,
    required this.displayValue,
  });

  factory VariantAttribute.fromMap(Map<String, dynamic> map) {
    return VariantAttribute(
      id: map['id']?.toString() ?? '',
      type: map['type']?.toString() ?? '',
      value: map['value']?.toString() ?? '',
      displayValue: map['display_value']?.toString() ?? '',
    );
  }
}
