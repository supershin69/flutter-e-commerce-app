class Brand {
  final String id;
  final String name;
  final String logoUrl;
  final int? productCount; // Optional product count

  Brand({
    required this.id,
    required this.name,
    required this.logoUrl,
    this.productCount,
  });

  factory Brand.fromMap(Map<String, dynamic> map) {
      return Brand(
        id: map['id'] as String,
        name: map['name'] as String,
        logoUrl: map['logo_url'] as String,
        productCount: map['product_count'] as int?,
      );
  }
}