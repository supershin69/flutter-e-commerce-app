class Brand {
  final String id;
  final String name;
  final String logoUrl;

  Brand({
    required this.id,
    required this.name,
    required this.logoUrl
  });

  factory Brand.fromMap(Map<String, dynamic> map) {
      final brand = map['brands'];
      return Brand(
        id: brand['id'],
        name: brand['name'],
        logoUrl: brand['logo_url'],
      );
  }
}