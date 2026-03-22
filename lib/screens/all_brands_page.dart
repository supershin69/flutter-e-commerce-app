import 'package:e_commerce_frontend/models/brand_model.dart';
import 'package:e_commerce_frontend/models/product_model.dart';
import 'package:e_commerce_frontend/widgets/product_card.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class AllBrandsPage extends StatefulWidget {
  const AllBrandsPage({super.key});

  @override
  State<AllBrandsPage> createState() => _AllBrandsPageState();
}

class _AllBrandsPageState extends State<AllBrandsPage> {
  final supabase = Supabase.instance.client;
  late Future<List<BrandWithCount>> _brandsFuture;

  @override
  void initState() {
    super.initState();
    _brandsFuture = fetchAllBrands();
  }

  Future<List<BrandWithCount>> fetchAllBrands() async {
    try {
      // Fetch all brands directly from brands table
      final brandsData = await supabase.from('brands').select('id, name, logo_url');
      
      final brands = brandsData.map<Brand>((e) {
        return Brand(
          id: e['id'] as String,
          name: e['name'] as String,
          logoUrl: (e['logo_url'] as String?) ?? '',
        );
      }).toList();
      
      // Get product counts for each brand
      final brandsWithCounts = <BrandWithCount>[];
      
      for (final brand in brands) {
        try {
          final productData = await supabase
              .from('product_catalog')
              .select('id')
              .eq('brand_name', brand.name);
          
          final count = productData.length;
          
          brandsWithCounts.add(BrandWithCount(
            brand: brand,
            productCount: count,
          ));
        } catch (e) {
          debugPrint('Error counting products for ${brand.name}: $e');
          brandsWithCounts.add(BrandWithCount(
            brand: brand,
            productCount: 0,
          ));
        }
      }
      
      return brandsWithCounts;
    } catch (e) {
      debugPrint('Error fetching all brands: $e');
      return [];
    }
  }

  Future<void> _onRefresh() async {
    final future = fetchAllBrands();
    setState(() {
      _brandsFuture = future;
    });
    await future;
  }

  @override
  Widget build(BuildContext context) {
    const bg = Color(0xFF0F0F10);
    const card = Color(0xFF1B1C1F);
    const border = Color(0xFF2B2C30);
    const muted = Color(0xFF9AA0A6);
    const accent = Color(0xFF6C7BFF);

    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        backgroundColor: Colors.brown.shade300,
        foregroundColor: Colors.white,
        title: const Text(
          'All Brands',
          style: TextStyle(
            fontWeight: FontWeight.w700,
          ),
        ),
        elevation: 0,
      ),
      body: RefreshIndicator(
        onRefresh: _onRefresh,
        color: accent,
        child: FutureBuilder<List<BrandWithCount>>(
          future: _brandsFuture,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(
                child: CircularProgressIndicator(),
              );
            }

            if (snapshot.hasError) {
              return SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                child: SizedBox(
                  height: MediaQuery.of(context).size.height - 200,
                  child: Center(
                    child: Padding(
                      padding: const EdgeInsets.all(20.0),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.error_outline,
                            size: 64,
                            color: Colors.grey[400],
                          ),
                          const SizedBox(height: 16),
                          const Text(
                            'Error loading brands',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            snapshot.error.toString(),
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: Colors.grey[400],
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              );
            }

            final brands = snapshot.data ?? [];

            if (brands.isEmpty) {
              return SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                child: SizedBox(
                  height: MediaQuery.of(context).size.height - 200,
                  child: Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.store_outlined,
                          size: 64,
                          color: Colors.grey[400],
                        ),
                        const SizedBox(height: 16),
                        const Text(
                          'No brands available',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            }

            return GridView.builder(
              padding: const EdgeInsets.all(16),
              physics: const AlwaysScrollableScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                mainAxisSpacing: 12,
                crossAxisSpacing: 12,
                childAspectRatio: 2.25,
              ),
              itemCount: brands.length,
              itemBuilder: (context, index) {
                final brandData = brands[index];
                return _BrandCard(
                  brand: brandData.brand,
                  productCount: brandData.productCount,
                  bg: card,
                  border: border,
                  muted: muted,
                  accent: accent,
                  onTap: () {
                    // Navigate to a page showing all products from this brand
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (context) => BrandProductsPage(
                          brandId: brandData.brand.id,
                          brandName: brandData.brand.name,
                        ),
                      ),
                    );
                  },
                );
              },
            );
          },
        ),
      ),
    );
  }
}

class _BrandCard extends StatelessWidget {
  final Brand brand;
  final int productCount;
  final Color bg;
  final Color border;
  final Color muted;
  final Color accent;
  final VoidCallback onTap;

  const _BrandCard({
    required this.brand,
    required this.productCount,
    required this.bg,
    required this.border,
    required this.muted,
    required this.accent,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Ink(
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: border),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            child: Row(
              children: [
                Container(
                  width: 34,
                  height: 34,
                  decoration: BoxDecoration(
                    color: Colors.black26,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: border),
                  ),
                  child: brand.logoUrl.isNotEmpty
                      ? ClipRRect(
                          borderRadius: BorderRadius.circular(10),
                          child: Image.network(
                            brand.logoUrl,
                            fit: BoxFit.cover,
                            errorBuilder: (context, error, stackTrace) {
                              return const Icon(Icons.storefront, color: Colors.white, size: 18);
                            },
                          ),
                        )
                      : const Icon(Icons.storefront, color: Colors.white, size: 18),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              brand.name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w700,
                                fontSize: 13,
                              ),
                            ),
                          ),
                          const SizedBox(width: 6),
                          const Icon(Icons.verified, size: 14, color: Color(0xFF6C7BFF)),
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '$productCount products',
                        style: TextStyle(
                          color: muted,
                          fontSize: 11,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// Page to show all products from a brand
class BrandProductsPage extends StatefulWidget {
  final String brandId;
  final String brandName;

  const BrandProductsPage({
    super.key,
    required this.brandId,
    required this.brandName,
  });

  @override
  State<BrandProductsPage> createState() => _BrandProductsPageState();
}

class _BrandProductsPageState extends State<BrandProductsPage> {
  final supabase = Supabase.instance.client;
  late Future<List<Product>> _productsFuture;

  @override
  void initState() {
    super.initState();
    debugPrint('🟢 BrandProductsPage initState() for: ${widget.brandName}');
    _productsFuture = fetchBrandProducts();
    // Also print immediately to see if initState is called
    _productsFuture.then((products) {
      debugPrint('🟢 Future completed with ${products.length} products');
    }).catchError((error) {
      debugPrint('🔴 Future failed with error: $error');
    });
  }

  Future<List<Product>> fetchBrandProducts() async {
    try {
      debugPrint('=== Fetching products for brand: "${widget.brandName}" ===');
      
      // Fetch all products from this brand using product_catalog
      final data = await supabase
          .from('product_catalog')
          .select()
          .eq('brand_name', widget.brandName);
      
      debugPrint('Raw data fetched: ${data.length} items');
      if (data.isNotEmpty) {
        debugPrint('First item keys: ${data.first.keys}');
        debugPrint('First item brand_name: ${data.first['brand_name']}');
      }
      
      if (data.isEmpty) {
        debugPrint('No products found for brand: "${widget.brandName}"');
        // Try case-insensitive search as fallback
        debugPrint('Attempting case-insensitive search...');
        final allData = await supabase
            .from('product_catalog')
            .select('brand_name');
        
        final uniqueBrands = allData.map((e) => e['brand_name']?.toString().toLowerCase()).toSet();
        debugPrint('Available brands in database: $uniqueBrands');
        
        return [];
      }
      
      final products = <Product>[];
      for (var item in data) {
        try {
          final product = Product.fromMap(item);
          products.add(product);
          debugPrint('✓ Parsed: ${product.name}');
        } catch (e) {
          debugPrint('✗ Error parsing product: $e');
          debugPrint('  Product data keys: ${item.keys}');
        }
      }
      
      debugPrint('=== Successfully parsed ${products.length}/${data.length} products ===');
      return products;
    } catch (e, stackTrace) {
      debugPrint('=== ERROR fetching brand products ===');
      debugPrint('Error: $e');
      debugPrint('Stack trace: $stackTrace');
      // Re-throw the error so FutureBuilder can catch it
      rethrow;
    }
  }

  Future<void> _onRefresh() async {
    final future = fetchBrandProducts();
    setState(() {
      _productsFuture = future;
    });
    await future;
  }

  @override
  Widget build(BuildContext context) {
    const bg = Color(0xFF0F0F10);
    
    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        backgroundColor: Colors.brown.shade300,
        foregroundColor: Colors.white,
        title: Text(widget.brandName),
        elevation: 0,
      ),
      body: Container(
        color: bg,
        child: RefreshIndicator(
          onRefresh: _onRefresh,
          color: Colors.brown.shade300,
          child: FutureBuilder<List<Product>>(
            future: _productsFuture,
            builder: (context, snapshot) {
              // Force print to terminal (not debug console)
              print('🔵 BrandProductsPage FutureBuilder - State: ${snapshot.connectionState}, HasData: ${snapshot.hasData}, HasError: ${snapshot.hasError}');
              
              // Always show something, even if there's an issue
              if (snapshot.connectionState == ConnectionState.waiting) {
                print('🟡 Showing loading indicator');
                return Container(
                  color: bg,
                  child: const Center(
                    child: CircularProgressIndicator(
                      color: Colors.brown,
                    ),
                  ),
                );
              }

            if (snapshot.hasError) {
              return SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                child: SizedBox(
                  height: MediaQuery.of(context).size.height - 200,
                  child: Center(
                    child: Padding(
                      padding: const EdgeInsets.all(20.0),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(
                            Icons.error_outline,
                            size: 64,
                            color: Colors.red,
                          ),
                          const SizedBox(height: 16),
                          const Text(
                            'Error loading products',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            snapshot.error.toString(),
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              color: Colors.grey,
                              fontSize: 12,
                            ),
                          ),
                          const SizedBox(height: 16),
                          ElevatedButton(
                            onPressed: _onRefresh,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.brown.shade300,
                            ),
                            child: const Text('Retry'),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                );
              }

              final products = snapshot.data ?? [];
              debugPrint('🟢 Products count: ${products.length}');

            if (products.isEmpty) {
              debugPrint('🟡 Showing empty state');
              return SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                child: Container(
                  color: bg,
                  height: MediaQuery.of(context).size.height - 200,
                  child: Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(
                          Icons.inventory_2_outlined,
                          size: 64,
                          color: Colors.grey,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'No products from ${widget.brandName}',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          'Try checking back later',
                          style: TextStyle(
                            color: Colors.grey,
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            }

              print('🟢 Building GridView with ${products.length} products');
              return GridView.builder(
                padding: const EdgeInsets.all(16),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  mainAxisSpacing: 16,
                  crossAxisSpacing: 16,
                  childAspectRatio: 0.6,
                ),
                itemCount: products.length,
                itemBuilder: (context, index) {
                  return ProductCard(product: products[index]);
                },
              );
            },
          ),
        ),
      ),
    );
  }
}

// BrandWithCount class (same as in store_page.dart)
class BrandWithCount {
  final Brand brand;
  final int productCount;
  BrandWithCount({required this.brand, required this.productCount});
}
