import 'dart:async';

import 'package:e_commerce_frontend/features/shop/controllers/product_controller.dart';
import 'package:get/get.dart';
import 'package:e_commerce_frontend/models/product_model.dart';
import 'package:e_commerce_frontend/screens/all_brands_page.dart';
import 'package:e_commerce_frontend/models/brand_model.dart';
import 'package:e_commerce_frontend/screens/auth/auth_gate.dart';
import 'package:e_commerce_frontend/screens/store/store_page.dart';
import 'package:e_commerce_frontend/screens/wishlist_page.dart';
import 'package:e_commerce_frontend/utils/colors.dart';
import 'package:e_commerce_frontend/widgets/product_card.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:e_commerce_frontend/features/personalization/screens/orders/order_detail_screen.dart';

import '/widgets/bottom_nav_bar.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final NumberFormat _priceFormatter = NumberFormat.decimalPattern();
  final PageController _bannerPageController = PageController();
  int _currentBannerPage = 0;
  Timer? _bannerTimer;

  final TextEditingController _searchController = TextEditingController();

  // Category data
  final List<Map<String, dynamic>> categories = [
    {
      'name': 'Phones',
      'icon': Icons.smartphone,
    },
    {
      'name': 'Cameras',
      'icon': Icons.camera_alt,
    },
    {
      'name': 'Tablets',
      'icon': Icons.tablet,
    },
    {
      'name': 'TVs',
      'icon': Icons.tv,
    },
    {
      'name': 'Headphones',
      'icon': Icons.headphones,
    },
    {
      'name': 'Watches',
      'icon': Icons.watch,
    },
  ];

  // Banner images - using uploaded banner images
  final List<String> bannerImages = [
    'assets/images/banners/banner1.png',
    'assets/images/banners/banner2.png',
    'assets/images/banners/banner3.png',
  ];

  // Featured products data
  final List<Map<String, dynamic>> featuredProducts = [
    {
      'image': 'assets/images/phone.jpg',
      'title': 'Phone',
      'brand': 'Samsung',
      'price': '1800000 MMK',
      'discount': '20',
      'isWishlisted': false,
    },
    {
      'image': 'assets/images/laptop.jpg',
      'title': 'Laptop',
      'brand': 'Dell',
      'price': '3000000 MMK',
      'discount': '15',
      'isWishlisted': false,
    },
    {
      'image': 'assets/images/airpod.jpg',
      'title': 'Airpod',
      'brand': 'Apple',
      'price': '850000 MMK',
      'discount': '30',
      'isWishlisted': false,
    },
  ];

  late Future<List<Product>> _productsFuture;
  late Future<List<Product>> _latestProductsFuture;
  late Future<List<Brand>> _brandsFuture;
  List<Product> _popularProductsCache = const [];
  DateTime? _popularProductsCacheAt;
  List<Product> _latestProductsCache = const [];
  DateTime? _latestProductsCacheAt;

  @override
  void initState() {
    super.initState();
    // Ensure controller is available
    if (!Get.isRegistered<ProductController>()) {
      Get.put(ProductController());
    }

    _productsFuture = _fetchPopularProducts();
    _latestProductsFuture = _fetchLatestProducts();
    _brandsFuture = _fetchBrands();
    _startBannerTimer();
  }

  Future<List<Brand>> _fetchBrands() async {
    try {
      final supabase = Supabase.instance.client;
      debugPrint('--- Diagnostic: Fetching brands ---');
      
      // Fetch brands from product_catalog to get active brands
      final catalogData = await supabase.from('product_catalog').select('brand_name');
      debugPrint('Catalog data count: ${catalogData.length}');
      
      final activeBrandNames = (catalogData as List<dynamic>)
          .map((e) => e['brand_name'] as String?)
          .where((name) => name != null && name.isNotEmpty)
          .toSet();
      debugPrint('Active brand names: $activeBrandNames');

      if (activeBrandNames.isEmpty) {
        debugPrint('Warning: No active brand names found in product_catalog');
        return [];
      }

      // Fetch brand details (logo, etc.) from brands table
      final brandsData = await supabase
          .from('brands')
          .select('id, name, logo_url');
      debugPrint('Brands table data count: ${brandsData.length}');
      
      final allBrands = (brandsData as List<dynamic>)
          .map((e) => Brand.fromMap(e as Map<String, dynamic>))
          .toList();

      // Filter to only include active brands
      final filteredBrands = allBrands.where((b) => activeBrandNames.contains(b.name)).toList();
      debugPrint('Filtered active brands count: ${filteredBrands.length}');
      return filteredBrands;
    } catch (e, stack) {
      debugPrint('Error fetching brands: $e');
      debugPrint('Stack trace: $stack');
      return [];
    }
  }

  Future<List<Product>> _fetchLatestProducts({bool forceRefresh = false}) async {
    try {
      final supabase = Supabase.instance.client;
      debugPrint('--- Diagnostic: Fetching latest products ---');
      
      if (!forceRefresh &&
          _latestProductsCacheAt != null &&
          _latestProductsCache.isNotEmpty &&
          DateTime.now().difference(_latestProductsCacheAt!) < const Duration(minutes: 2)) {
        return _latestProductsCache;
      }

      final response = await supabase
          .from('latest_products')
          .select()
          .order('created_at', ascending: false)
          .order('id', ascending: false)
          .limit(10);
      debugPrint('Latest products view response count: ${response.length}');

      final products = (response as List<dynamic>)
          .map((e) => Product.fromMap(e as Map<String, dynamic>))
          .toList();
      _latestProductsCache = products;
      _latestProductsCacheAt = DateTime.now();
      debugPrint('latest_products successfully parsed: ${products.length}');
      return products;
    } catch (e, stack) {
      debugPrint('Error fetching latest products: $e');
      debugPrint('Stack trace: $stack');
      return [];
    }
  }

  Future<List<Product>> _fetchPopularProducts({bool forceRefresh = false}) async {
    try {
      debugPrint('--- Diagnostic: Fetching popular products ---');
      if (!forceRefresh &&
          _popularProductsCacheAt != null &&
          _popularProductsCache.isNotEmpty &&
          DateTime.now().difference(_popularProductsCacheAt!) < const Duration(minutes: 2)) {
        return _popularProductsCache;
      }

      final supabase = Supabase.instance.client;
      // Fetch from popular_products view: already sorted by total_sold desc
      final response = await supabase
          .from('popular_products')
          .select()
          .limit(8);
      debugPrint('Popular products view response count: ${response.length}');

      final products = (response as List<dynamic>)
          .map((e) => Product.fromMap(e as Map<String, dynamic>))
          .toList();
      _popularProductsCache = products;
      _popularProductsCacheAt = DateTime.now();
      debugPrint('popular_products successfully parsed: ${products.length}');
      return products;
    } catch (e, stack) {
      debugPrint('Error fetching popular products: $e');
      debugPrint('Stack trace: $stack');
      return [];
    }
  }
    

  String _formatPrice(double value) {
    return '${_priceFormatter.format(value.round())} MMK';
  }

  @override
  void dispose() {
    _bannerTimer?.cancel();
    _searchController.dispose();
    _bannerPageController.dispose();
    super.dispose();
  }

  void _startBannerTimer() {
    _bannerTimer = Timer.periodic(const Duration(seconds: 4), (timer) {
      if (_bannerPageController.hasClients && mounted) {
        int nextPage = _currentBannerPage + 1;
        if (nextPage >= bannerImages.length) {
          nextPage = 0;
        }
        // Update state immediately so dots change right away
        if (mounted) {
          setState(() {
            _currentBannerPage = nextPage;
          });
        }
        // Then animate to next page
        _bannerPageController.animateToPage(
          nextPage,
          duration: const Duration(milliseconds: 500),
          curve: Curves.easeInOut,
        );
      }
    });
  }

  void _onBannerPageChanged(int index) {
    // This callback fires when page changes (both manual and auto scroll)
    if (mounted) {
      setState(() {
        _currentBannerPage = index;
      });
    }
    // Reset timer when user manually scrolls
    _bannerTimer?.cancel();
    _startBannerTimer();
  }

  Future<void> _onRefresh() async {
    setState(() {
      _productsFuture = _fetchPopularProducts(forceRefresh: true);
      _latestProductsFuture = _fetchLatestProducts(forceRefresh: true);
      _brandsFuture = _fetchBrands();
    });
    
    // Wait for all futures to complete
    await Future.wait([
      _productsFuture,
      _latestProductsFuture,
      _brandsFuture,
    ]);
  }

  // pages for bottom navigation
  int _selectedIndex = 0;

  @override
  Widget build(BuildContext context) {
    final pages = <Widget>[
      _buildHomeContent(),
      const StorePage(),
      const WishlistPage(),
      const AuthGate(),
    ];

    return Scaffold(
      backgroundColor: AppColors.whiteBackground,
      // Remove AppBar - we'll use custom header
      body: IndexedStack(
        index: _selectedIndex,
        children: pages,
      ),

      // Bottom Navigation Bar
      bottomNavigationBar: AppBottomNavBar(
        currentIndex: _selectedIndex,
        onTap: (index) {
          setState(() {
            _selectedIndex = index;
          });
        },
      ),
    );
  }

  void _showFilterModal(BuildContext context) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return Container(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Filter Products',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textDark,
                ),
              ),
              const SizedBox(height: 20),
              const Text(
                'Price Range',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textDark,
                ),
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () {},
                      child: const Text('Low to High'),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () {},
                      child: const Text('High to Low'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              const Text(
                'Category',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textDark,
                ),
              ),
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                children: categories.map((cat) {
                  return ChoiceChip(
                    label: Text(cat['name']),
                    selected: false,
                    onSelected: (selected) {},
                  );
                }).toList(),
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.pop(context);
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.brown.shade300,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                  child: const Text('Apply Filters', style: TextStyle(color: Colors.white)),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  // Home UI redesigned to match uploaded image
  Widget _buildHomeContent() {
    return GestureDetector(
      onTap: () => FocusScope.of(context).unfocus(),
      child: Column(
        children: [
          // Header Section
          Container(
            width: double.infinity,
            decoration: BoxDecoration(
              color: Colors.brown.shade300,
              borderRadius: const BorderRadius.only(
                bottomLeft: Radius.circular(30),
                bottomRight: Radius.circular(30),
              ),
            ),
            child: SafeArea(
              bottom: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 10, 20, 30),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Welcome Text in Burmese
                    const Text(
                      'WELCOME TO DIGITAL HUB',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 20),

                    // Search Bar
                    Container(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withAlpha(25),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: TextField(
                        controller: _searchController,
                        decoration: InputDecoration(
                          hintText: 'Search in Store',
                          prefixIcon: const Icon(Icons.search, color: Colors.grey),
                          suffixIcon: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                icon: Icon(Icons.mic, color: Colors.grey[600]),
                                onPressed: () {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text('Voice Search coming soon'),
                                      duration: Duration(seconds: 1),
                                    ),
                                  );
                                },
                              ),
                              Container(
                                height: 24,
                                width: 1,
                                color: Colors.grey[300],
                              ),
                              IconButton(
                                icon: Icon(Icons.tune, color: Colors.grey[600]),
                                onPressed: () {
                                  _showFilterModal(context);
                                },
                              ),
                            ],
                          ),
                          border: InputBorder.none,
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 12,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

          // Content Section with White Background
          Expanded(
            child: Container(
              color: Colors.white, // White background
              child: RefreshIndicator(
                onRefresh: _onRefresh,
                color: Colors.brown.shade300,
                child: SingleChildScrollView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                  // Popular Categories Section
                  const Text(
                    'Popular Categories',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textDark,
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Categories Horizontal List
                  SizedBox(
                    height: 100,
                    child: ListView.builder(
                      scrollDirection: Axis.horizontal,
                      itemCount: categories.length,
                      itemBuilder: (context, index) {
                        final category = categories[index];
                        return Container(
                          width: 80,
                          margin: const EdgeInsets.only(right: 16),
                          child: Column(
                            children: [
                              // Circular Icon Container
                              Container(
                                width: 70,
                                height: 70,
                                decoration: BoxDecoration(
                                  color: AppColors.categoryIconBg,
                                  shape: BoxShape.circle,
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withAlpha(25),
                                      blurRadius: 4,
                                      offset: const Offset(0, 2),
                                    ),
                                  ],
                                ),
                                child: Icon(
                                  category['icon'] as IconData,
                                  size: 32,
                                  color: Colors.white,
                                ),
                              ),
                              const SizedBox(height: 8),
                              // Category Name
                              Text(
                                category['name'] as String,
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: AppColors.textDark,
                                  fontWeight: FontWeight.w500,
                                ),
                                textAlign: TextAlign.center,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                  ),

                  const SizedBox(height: 30),

                  // Shop by Brand Section
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Shop by Brand',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: AppColors.textDark,
                        ),
                      ),
                      GestureDetector(
                        onTap: () {
                          // Navigate to all brands page
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => const AllBrandsPage(),
                            ),
                          );
                        },
                        child: const Text(
                          'View all',
                          style: TextStyle(
                            fontSize: 14,
                            color: Color(0xFF4FC3F7), // Light blue
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  
                  // Brands Horizontal List
                  SizedBox(
                    height: 110,
                    child: FutureBuilder<List<Brand>>(
                      future: _brandsFuture,
                      builder: (context, snapshot) {
                        if (snapshot.connectionState == ConnectionState.waiting) {
                          return const Center(child: CircularProgressIndicator());
                        }
                        if (snapshot.hasError || !snapshot.hasData || snapshot.data!.isEmpty) {
                          return const Center(child: Text('No brands available'));
                        }
                        
                        final brands = snapshot.data!;
                        
                        return ListView.builder(
                          scrollDirection: Axis.horizontal,
                          itemCount: brands.length,
                          itemBuilder: (context, index) {
                            final brand = brands[index];
                            return GestureDetector(
                              onTap: () {
                                // Navigate to BrandProductsPage
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) => BrandProductsPage(
                                      brandId: brand.id,
                                      brandName: brand.name,
                                    ),
                                  ),
                                );
                              },
                              child: Container(
                                width: 80,
                                margin: const EdgeInsets.only(right: 16),
                                child: Column(
                                  children: [
                                    // Circular Logo Container
                                    Container(
                                      width: 70,
                                      height: 70,
                                      padding: const EdgeInsets.all(12),
                                      decoration: BoxDecoration(
                                        color: Colors.white,
                                        shape: BoxShape.circle,
                                        boxShadow: [
                                          BoxShadow(
                                            color: Colors.black.withAlpha(20),
                                            blurRadius: 4,
                                            offset: const Offset(0, 2),
                                          ),
                                        ],
                                      ),
                                      child: brand.logoUrl.isNotEmpty
                                          ? ClipOval(
                                              child: Image.network(
                                                brand.logoUrl,
                                                fit: BoxFit.contain,
                                                errorBuilder: (context, error, stackTrace) {
                                                  return Center(
                                                    child: Text(
                                                      brand.name[0],
                                                      style: const TextStyle(
                                                        fontSize: 24,
                                                        fontWeight: FontWeight.bold,
                                                        color: AppColors.textDark,
                                                      ),
                                                    ),
                                                  );
                                                },
                                              ),
                                            )
                                          : Center(
                                              child: Text(
                                                brand.name.isNotEmpty ? brand.name[0] : '?',
                                                style: const TextStyle(
                                                  fontSize: 24,
                                                  fontWeight: FontWeight.bold,
                                                  color: AppColors.textDark,
                                                ),
                                              ),
                                            ),
                                    ),
                                    const SizedBox(height: 8),
                                    // Brand Name
                                    Text(
                                      brand.name,
                                      style: const TextStyle(
                                        fontSize: 12,
                                        color: AppColors.textDark,
                                        fontWeight: FontWeight.w500,
                                      ),
                                      textAlign: TextAlign.center,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        );
                      },
                    ),
                  ),

                  const SizedBox(height: 30),

                  // Promotional Banner Section with Auto-Scroll
                  SizedBox(
                    height: 220, // Wider banner size
                    child: Stack(
                      children: [
                        // Banner Image Carousel
                        PageView.builder(
                          controller: _bannerPageController,
                          onPageChanged: (index) {
                            _onBannerPageChanged(index);
                          },
                          itemCount: bannerImages.length,
                          itemBuilder: (context, index) {
                            return Container(
                              margin: const EdgeInsets.symmetric(horizontal: 0),
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(20),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withAlpha(25),
                                    blurRadius: 8,
                                    offset: const Offset(0, 4),
                                  ),
                                ],
                              ),
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(20),
                                child: Image.asset(
                                  bannerImages[index],
                                  fit: BoxFit.cover,
                                  width: double.infinity,
                                  height: 220,
                                  errorBuilder: (context, error, stackTrace) {
                                    return Container(
                                      decoration: BoxDecoration(
                                        borderRadius: BorderRadius.circular(20),
                                        gradient: const LinearGradient(
                                          begin: Alignment.centerLeft,
                                          end: Alignment.centerRight,
                                          colors: [
                                            AppColors.bannerGradientStart,
                                            Color(0xFFE67E22),
                                            AppColors.bannerGradientEnd,
                                          ],
                                        ),
                                      ),
                                      child: const Center(
                                        child: Icon(
                                          Icons.image_not_supported,
                                          color: Colors.white,
                                          size: 50,
                                        ),
                                      ),
                                    );
                                  },
                                ),
                              ),
                            );
                          },
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 30),

                  // Latest Products Section
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Latest',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: AppColors.textDark,
                        ),
                      ),
                      GestureDetector(
                        onTap: () {
                          // Navigate to all products page
                        },
                        child: const Text(
                          'View all',
                          style: TextStyle(
                            fontSize: 14,
                            color: Color(0xFF4FC3F7), // Light blue
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  SizedBox(
                    height: 260,
                    child: FutureBuilder<List<Product>>(
                      future: _latestProductsFuture,
                      builder: (context, snapshot) {
                        if (snapshot.connectionState == ConnectionState.waiting) {
                          return const Center(child: CircularProgressIndicator());
                        }
                        if (snapshot.hasError || !snapshot.hasData || snapshot.data!.isEmpty) {
                           return const Center(child: Text('No latest products'));
                        }
                        final products = snapshot.data!;
                        return ListView.builder(
                          scrollDirection: Axis.horizontal,
                          itemCount: products.length,
                          itemBuilder: (context, index) {
                            return Padding(
                              padding: const EdgeInsets.only(right: 16.0, bottom: 8.0),
                              child: ProductCard(
                                product: products[index],
                                width: 160,
                              ),
                            );
                          },
                        );
                      },
                    ),
                  ),

                  const SizedBox(height: 30),

                  // Popular Products Section
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Popular Products',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: AppColors.textDark,
                        ),
                      ),
                      GestureDetector(
                        onTap: () {
                          // Navigate to all products page
                        },
                        child: const Text(
                          'View all',
                          style: TextStyle(
                            fontSize: 14,
                            color: Color(0xFF4FC3F7), // Light blue
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // Featured Products Grid
                  FutureBuilder<List<Product>>(
                    future: _productsFuture,
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return const Center(child: CircularProgressIndicator());
                      }
                      if (snapshot.hasError || !snapshot.hasData || snapshot.data!.isEmpty) {
                         if (snapshot.hasError) {
                           debugPrint('Error in Home FutureBuilder: ${snapshot.error}');
                         }
                         return const Center(child: CircularProgressIndicator());
                      }
                      final products = snapshot.data!;
                      return GridView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 2,
                          crossAxisSpacing: 16,
                          mainAxisSpacing: 16,
                          childAspectRatio: 0.6,
                        ),
                        itemCount: products.length,
                        itemBuilder: (context, index) {
                          return ProductCard(product: products[index]);
                        },
                      );
                    },
                  ),

                  const SizedBox(height: 20),
                ],
              ),
            ),
          ),
        ),
      )],
      ),
    );
  }
}
