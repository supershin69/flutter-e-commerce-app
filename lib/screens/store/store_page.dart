import 'dart:async';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../models/category_model.dart';
import '../../models/brand_model.dart';
import '../../models/product_model.dart';
import '../products_page.dart';
import '../all_brands_page.dart';
import '../cart_page.dart';
import '../../services/cart_service.dart';
import '../../utils/colors.dart';
import 'package:e_commerce_frontend/features/shop/screens/store/store_search_bar.dart';

class StorePage extends StatefulWidget {
  const StorePage({super.key});

  @override
  State<StorePage> createState() => _StorePageState();
}

class _StorePageState extends State<StorePage> {
  final supabase = Supabase.instance.client;
  final CartService _cartService = CartService();

  late Future<List<Category>> _categoriesFuture;
  late Future<List<BrandWithCount>> _featuredBrandsFuture;
  late Future<Map<String, BrandProductsData>> _brandProductsFuture;
  late Future<int> _cartCountFuture;

  List<Category> _categories = [];
  int _activeTabIndex = 0;
  String? _selectedCategoryId;
  Timer? _cartRefreshTimer;

  @override
  void initState() {
    super.initState();
    // Initialize futures with empty values to prevent late initialization errors
    _categoriesFuture = Future.value(<Category>[]);
    _featuredBrandsFuture = Future.value(<BrandWithCount>[]);
    _brandProductsFuture = Future.value(<String, BrandProductsData>{});
    _loadData();
    _loadCartCount();
    
    // Refresh cart count periodically (every 2 seconds) to catch real-time changes
    _cartRefreshTimer = Timer.periodic(const Duration(seconds: 2), (timer) {
      if (mounted) {
        _loadCartCount();
      }
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Refresh cart count when page becomes visible again (but only if mounted)
    if (mounted) {
      _loadCartCount();
    }
  }

  void _loadCartCount() {
    setState(() {
      _cartCountFuture = _cartService.getCartCount();
    });
  }

  Future<void> _loadData() async {
    setState(() {
      _categoriesFuture = _fetchCategories();
      // Load static featured brands once (not category-dependent)
      _featuredBrandsFuture = _fetchAllFeaturedBrands();
    });

    final categories = await _categoriesFuture;
    if (categories.isNotEmpty) {
      // Find phone-related category (look for "Phone" or "Phones" in name)
      final phoneCategory = categories.firstWhere(
        (cat) => cat.name.toLowerCase().contains('phone'),
        orElse: () => categories.first,
      );
      
      setState(() {
        _selectedCategoryId = phoneCategory.id;
        _brandProductsFuture = _fetchBrandProducts(phoneCategory.id);
      });
    }
  }

  Future<List<Category>> _fetchCategories() async {
    try {
      final data = await supabase.from('categories').select();
      return data.map<Category>((e) => Category.fromMap(e)).toList();
    } catch (e) {
      debugPrint('Error fetching categories: $e');
      return [];
    }
  }



  Future<List<BrandWithCount>> _fetchAllFeaturedBrands() async {
    try {
      // Fetch brands from product_catalog (same source as products)
      final catalogData = await supabase
          .from('product_catalog')
          .select('brand_name');

      if (catalogData.isEmpty) {
        debugPrint('No products found in product_catalog');
        return [];
      }

      // Count products per brand
      final brandCounts = <String, int>{};
      for (final item in catalogData) {
        final brandName = item['brand_name'] as String?;
        if (brandName != null && brandName.isNotEmpty) {
          brandCounts[brandName] = (brandCounts[brandName] ?? 0) + 1;
        }
      }

      if (brandCounts.isEmpty) {
        debugPrint('No brands found in product_catalog');
        return [];
      }

      // Fetch all brand details from brands table at once
      final brandNames = brandCounts.keys.toList();
      final brandsList = <BrandWithCount>[];
      
      try {
        // Fetch all brands, then match by name in Dart (avoids .in_ API issues)
        final allBrandsData = await supabase
            .from('brands')
            .select('id, name, logo_url');

        // Create a map of brand name to brand data for quick lookup
        final brandMap = <String, Brand>{};
        for (final brandData in allBrandsData) {
          final brand = Brand.fromMap(Map<String, dynamic>.from(brandData));
          brandMap[brand.name] = brand;
        }

        // Create BrandWithCount for each brand that appears in product_catalog
        for (final brandName in brandNames) {
          final brand = brandMap[brandName];
          if (brand != null) {
            brandsList.add(BrandWithCount(
              brand: brand,
              productCount: brandCounts[brandName] ?? 0,
            ));
          } else {
            // If brand doesn't exist in brands table, create a placeholder
            debugPrint('Brand "$brandName" not found in brands table, creating placeholder');
            brandsList.add(BrandWithCount(
              brand: Brand(
                id: brandName, // Use name as ID fallback
                name: brandName,
                logoUrl: '',
              ),
              productCount: brandCounts[brandName] ?? 0,
            ));
          }
        }
      } catch (e) {
        debugPrint('Error fetching brands from brands table: $e');
        // Fallback: create brands from names only
        for (final brandName in brandNames) {
          brandsList.add(BrandWithCount(
            brand: Brand(
              id: brandName,
              name: brandName,
              logoUrl: '',
            ),
            productCount: brandCounts[brandName] ?? 0,
          ));
        }
      }

      // Sort by product count descending to get top brands
      brandsList.sort((a, b) => b.productCount.compareTo(a.productCount));
      
      return brandsList.take(4).toList();
    } catch (e) {
      debugPrint('Error fetching all featured brands: $e');
      debugPrint('Stack trace: ${StackTrace.current}');
      return [];
    }
  }

  Future<Map<String, BrandProductsData>> _fetchBrandProducts(String categoryId) async {
    try {
      // First get category name
      final categoryData = await supabase
          .from('categories')
          .select('name')
          .eq('id', categoryId)
          .single();
      
      final categoryName = categoryData['name'] as String;

      // Fetch products from product_catalog (this is the working approach)
      final catalogData = await supabase
          .from('product_catalog')
          .select()
          .eq('category_name', categoryName);

      if (catalogData.isNotEmpty) {
        final first = catalogData.first;
        debugPrint('product_catalog columns: ${first.keys.toList()}');
      }

      final products = catalogData.map<Product>((e) => Product.fromMap(e)).toList();
      
      // Group by brand and fetch brand IDs
      final brandNames = products.map((p) => p.brandName).where((n) => n.isNotEmpty).toSet();
      final grouped = <String, BrandProductsData>{};
      
      for (final brandName in brandNames) {
        // Fetch brand ID by name
        try {
          final brandData = await supabase
              .from('brands')
              .select('id')
              .eq('name', brandName)
              .maybeSingle();
          
          final brandId = brandData?['id'] as String? ?? '';
          final brandProducts = products.where((p) => p.brandName == brandName).toList();
          
          grouped[brandName] = BrandProductsData(
            brandId: brandId,
            brandName: brandName,
            products: brandProducts,
          );
        } catch (e) {
          debugPrint('Error fetching brand ID for $brandName: $e');
          // Still add products even without brand ID
          final brandProducts = products.where((p) => p.brandName == brandName).toList();
          grouped[brandName] = BrandProductsData(
            brandId: '',
            brandName: brandName,
            products: brandProducts,
          );
        }
      }

      return grouped;
    } catch (e) {
      debugPrint('Error details: $e');
      return {};
    }
  }

  Future<void> _onCategoryChanged(int index) async {
    if (index < _categories.length) {
      final category = _categories[index];
      setState(() {
        _activeTabIndex = index;
        _selectedCategoryId = category.id;
        // Featured brands remain static - only update brand products for the selected category
        _brandProductsFuture = _fetchBrandProducts(category.id);
      });
    }
  }

  Future<void> _onRefresh() async {
    // Reload all data
    _loadData();
    _loadCartCount();
    
    // Wait for futures to complete (optional, as _loadData sets state immediately, 
    // but better for RefreshIndicator to wait)
    await Future.wait([
      _categoriesFuture,
      _featuredBrandsFuture,
      _brandProductsFuture,
    ]);
  }

  @override
  void dispose() {
    _cartRefreshTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    const bg = Colors.white;
    const card = Colors.white;
    const border = Color(0xFFE0E0E0);
    const muted = Color(0xFF9AA0A6);

    return Scaffold(
      backgroundColor: bg,
      body: RefreshIndicator(
        onRefresh: _onRefresh,
        color: Colors.brown.shade300,
        child: SafeArea(
          bottom: false,
          child: CustomScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            slivers: [
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
              sliver: SliverToBoxAdapter(
                child: Row(
                  children: [
                    Text(
                      'Store',
                      style: TextStyle(
                        color: Colors.brown.shade300,
                        fontSize: 22,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const Spacer(),
                    FutureBuilder<int>(
                      future: _cartCountFuture,
                      builder: (context, snapshot) {
                        final count = snapshot.data ?? 0;
                        return CartButton(
                          count: count,
                          onTap: () {
                            Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (context) => const CartPage(),
                              ),
                            ).then((_) {
                              // Refresh cart count when returning from cart page
                              _loadCartCount();
                            });
                          },
                        );
                      },
                    ),
                  ],
                ),
              ),
            ),

            // Search
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
              sliver: SliverToBoxAdapter(
                child: const StoreSearchBar(),
              ),
            ),

            // Featured Brands header
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 18, 16, 0),
              sliver: SliverToBoxAdapter(
                child: Row(
                  children: [
                    const Text(
                      'Featured Brands',
                      style: TextStyle(
                        color: AppColors.textDark,
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const Spacer(),
                    GestureDetector(
                      onTap: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (context) => const AllBrandsPage(),
                          ),
                        );
                      },
                      child: Text(
                        'View all',
                        style: TextStyle(
                          color: Colors.brown.shade300,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // Featured Brands grid
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
              sliver: SliverToBoxAdapter(
                child: FutureBuilder<List<BrandWithCount>>(
                  future: _featuredBrandsFuture,
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const SizedBox(
                        height: 100,
                        child: Center(child: CircularProgressIndicator()),
                      );
                    }

                    if (snapshot.hasError || snapshot.data == null || snapshot.data!.isEmpty) {
                      return const SizedBox(
                        height: 100,
                        child: Center(
                          child: Text(
                            'No brands available',
                            style: TextStyle(color: muted),
                          ),
                        ),
                      );
                    }

                    final brands = snapshot.data!;
                    return GridView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 2,
                        mainAxisSpacing: 12,
                        crossAxisSpacing: 12,
                        childAspectRatio: 2.25,
                      ),
                      itemCount: brands.length,
                      itemBuilder: (context, index) {
                        final brandData = brands[index];
                        return BrandCard(
                          data: BrandCardData(
                            name: brandData.brand.name,
                            productCountText: '${brandData.productCount} products',
                            logoUrl: brandData.brand.logoUrl,
                          ),
                          bg: card,
                          border: border,
                          muted: muted,
                          onTap: () {
                            // Navigate to products page
                            if (_selectedCategoryId != null) {
                              Navigator.of(context).push(
                                MaterialPageRoute(
                                  builder: (context) => ProductsPage(
                                    categoryId: _selectedCategoryId!,
                                    categoryName: _categories[_activeTabIndex].name,
                                    brandId: brandData.brand.id,
                                    brandName: brandData.brand.name,
                                  ),
                                ),
                              ).then((_) {
                                // Refresh cart count when returning from products page
                                _loadCartCount();
                              });
                            }
                          },
                        );
                      },
                    );
                  },
                ),
              ),
            ),

            // Tabs
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
              sliver: SliverToBoxAdapter(
                child: FutureBuilder<List<Category>>(
                  future: _categoriesFuture,
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const SizedBox(height: 34);
                    }

                    if (snapshot.hasData && snapshot.data!.isNotEmpty) {
                      _categories = snapshot.data!;
                    }

                    if (_categories.isEmpty) {
                      return const SizedBox(height: 34);
                    }

                    return SizedBox(
                      height: 34,
                      child: ListView.separated(
                        scrollDirection: Axis.horizontal,
                        itemCount: _categories.length,
                        separatorBuilder: (_, __) => const SizedBox(width: 16),
                        itemBuilder: (context, i) {
                          final active = i == _activeTabIndex;
                          return GestureDetector(
                            onTap: () => _onCategoryChanged(i),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.end,
                              children: [
                                Text(
                                  _categories[i].name,
                                  style: TextStyle(
                                    color: active ? Colors.brown.shade300 : muted,
                                    fontWeight: FontWeight.w600,
                                    fontSize: 12,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                AnimatedContainer(
                                  duration: const Duration(milliseconds: 180),
                                  height: 2,
                                  width: 22,
                                  decoration: BoxDecoration(
                                    color: active ? Colors.brown.shade300 : Colors.transparent,
                                    borderRadius: BorderRadius.circular(2),
                                  ),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                    );
                  },
                ),
              ),
            ),

            // Brand sections list
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
              sliver: SliverToBoxAdapter(
                child: FutureBuilder<Map<String, BrandProductsData>>(
                  future: _brandProductsFuture,
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(
                        child: Padding(
                          padding: EdgeInsets.all(20.0),
                          child: CircularProgressIndicator(),
                        ),
                      );
                    }

                    if (snapshot.hasError || snapshot.data == null || snapshot.data!.isEmpty) {
                      return const Center(
                        child: Padding(
                          padding: EdgeInsets.all(20.0),
                          child: CircularProgressIndicator(),
                        ),
                      );
                    }

                    final brandProducts = snapshot.data!;
                    final brandEntries = brandProducts.entries.toList();

                    return Column(
                      children: brandEntries.map((entry) {
                        final brandData = entry.value;
                        final brandName = brandData.brandName;
                        final brandId = brandData.brandId;
                        final products = brandData.products;
                        final productCount = products.length;
                        
                        // Get first 3 product images
                        final thumbnails = products
                            .take(3)
                            .map((p) => p.imageUrl)
                            .where((url) => url.isNotEmpty)
                            .toList();

                        return Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: BrandSectionCard(
                            data: BrandSectionData(
                              title: brandName,
                              productCountText: '$productCount products',
                              thumbnails: thumbnails,
                              brandId: brandId,
                            ),
                            bg: card,
                            border: border,
                            muted: muted,
                            onTap: () {
                              // Navigate to products page for this brand
                              if (_selectedCategoryId != null && brandId.isNotEmpty) {
                                Navigator.of(context).push(
                                  MaterialPageRoute(
                                    builder: (context) => ProductsPage(
                                      categoryId: _selectedCategoryId!,
                                      categoryName: _categories[_activeTabIndex].name,
                                      brandId: brandId,
                                      brandName: brandName,
                                    ),
                                  ),
                                ).then((_) {
                                  // Refresh cart count when returning from products page
                                  _loadCartCount();
                                });
                              }
                            },
                          ),
                        );
                      }).toList(),
                    );
                  },
                ),
              ),
            ),
          ],
        ),
      ),
    ));
  }
}

class CartButton extends StatelessWidget {
  final int count;
  final VoidCallback onTap;

  const CartButton({super.key, required this.count, required this.onTap});

  @override
  Widget build(BuildContext context) {
    const border = Color(0xFFE0E0E0);
    const card = Colors.white;
    return GestureDetector(
      onTap: onTap,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.brown.shade300,
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  blurRadius: 4,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: const Icon(Icons.shopping_bag_outlined, color: Colors.white),
          ),
          if (count > 0)
            Positioned(
              right: -4,
              top: -4,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.red,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.white, width: 2),
                ),
                child: Text(
                  count > 99 ? '99+' : '$count',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class BrandWithCount {
  final Brand brand;
  final int productCount;
  BrandWithCount({required this.brand, required this.productCount});
}

class BrandProductsData {
  final String brandId;
  final String brandName;
  final List<Product> products;
  BrandProductsData({
    required this.brandId,
    required this.brandName,
    required this.products,
  });
}

class BrandCardData {
  final String name;
  final String productCountText;
  final String? logoUrl;
  const BrandCardData({
    required this.name,
    required this.productCountText,
    this.logoUrl,
  });
}

class BrandCard extends StatelessWidget {
  final BrandCardData data;
  final Color bg;
  final Color border;
  final Color muted;
  final VoidCallback onTap;

  const BrandCard({super.key, 
    required this.data,
    required this.bg,
    required this.border,
    required this.muted,
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
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 4,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            child: Row(
              children: [
                Container(
                  width: 34,
                  height: 34,
                  decoration: BoxDecoration(
                    color: Colors.brown.shade300,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: border),
                  ),
                  child: data.logoUrl != null && data.logoUrl!.isNotEmpty
                      ? ClipRRect(
                          borderRadius: BorderRadius.circular(10),
                          child: Image.network(
                            data.logoUrl!,
                            fit: BoxFit.cover,
                            errorBuilder: (context, error, stackTrace) {
                              return Icon(Icons.storefront, color: Colors.white, size: 18);
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
                              data.name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: AppColors.textDark,
                                fontWeight: FontWeight.w700,
                                fontSize: 13,
                              ),
                            ),
                          ),
                          const SizedBox(width: 6),
                          Icon(Icons.verified, size: 14, color: Colors.brown.shade300),
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text(
                        data.productCountText,
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

class BrandSectionData {
  final String title;
  final String productCountText;
  final List<String> thumbnails; // Now contains image URLs
  final String brandId;
  const BrandSectionData({
    required this.title,
    required this.productCountText,
    required this.thumbnails,
    required this.brandId,
  });
}

class BrandSectionCard extends StatelessWidget {
  final BrandSectionData data;
  final Color bg;
  final Color border;
  final Color muted;
  final VoidCallback? onTap;

  const BrandSectionCard({super.key, 
    required this.data,
    required this.bg,
    required this.border,
    required this.muted,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Ink(
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: border),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 4,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Container(
            padding: const EdgeInsets.all(12),
            child: Column(
              children: [
                Row(
                  children: [
                    Container(
                      width: 34,
                      height: 34,
                      decoration: BoxDecoration(
                        color: Colors.brown.shade300,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: border),
                      ),
                      child: const Icon(Icons.storefront, color: Colors.white, size: 18),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Flexible(
                                child: Text(
                                  data.title,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    color: AppColors.textDark,
                                    fontWeight: FontWeight.w800,
                                    fontSize: 13,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 6),
                              Icon(Icons.verified, size: 14, color: Colors.brown.shade300),
                            ],
                          ),
                          const SizedBox(height: 2),
                          Text(
                            data.productCountText,
                            style: TextStyle(
                              color: muted,
                              fontSize: 11,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const Icon(Icons.arrow_forward_ios, size: 12, color: Colors.grey),
                  ],
                ),
                const SizedBox(height: 12),
                if (data.thumbnails.isNotEmpty)
                  Row(
                    children: data.thumbnails.take(3).map((url) {
                      return Expanded(
                        child: Padding(
                          padding: const EdgeInsets.only(right: 8.0),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: AspectRatio(
                              aspectRatio: 1,
                              child: Image.network(
                                url,
                                fit: BoxFit.cover,
                                errorBuilder: (context, error, stackTrace) {
                                  return Container(
                                    color: Colors.grey[200],
                                    child: const Icon(Icons.image_not_supported, color: Colors.grey),
                                  );
                                },
                              ),
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

