class Product {
  final String id;
  final String name;
  final int minPrice;
  final int maxPrice;
  final List<dynamic> images;

  Product ({
    required this.id,
    required this.name,
    required this.minPrice,
    required this.maxPrice,
    required this.images
  });

  factory Product.fromMap(Map<String, dynamic> map) {
    return Product(
      id: map['id'] as String, 
      name: map['name'] as String, 
      minPrice: map['min_price'],
      maxPrice: map['max_price'],
      images: (map['images'] as List<dynamic>).map((e) => e as String).toList()
    );
  }
}