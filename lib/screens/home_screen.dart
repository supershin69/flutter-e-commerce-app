import 'dart:async';
import 'package:e_commerce_frontend/screens/CategoriesPage.dart';
import 'package:e_commerce_frontend/screens/NotificationPage.dart';
import 'package:e_commerce_frontend/screens/store/store_page.dart';
import 'package:e_commerce_frontend/screens/wishlist_page.dart';
import 'package:e_commerce_frontend/screens/auth/auth_gate.dart';
import 'package:e_commerce_frontend/utils/colors.dart';
import 'package:flutter/material.dart';
import '/widgets/bottom_nav_bar.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
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

  @override
  void initState() {
    super.initState();
    // Start auto-scroll timer
    _startBannerTimer();
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

  // pages for bottom navigation
  int _selectedIndex = 0;

  late final List<Widget> _pages = [
    _buildHomeContent(), // index 0 → Home
    const StorePage(), // index 1 → Store
    const NotificationPage(), // index 2 → Wishlist
    const AuthGate(), // index 3 → Profile
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.whiteBackground,
      // Remove AppBar - we'll use custom header
      body: IndexedStack(
        index: _selectedIndex,
        children: _pages,
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

  // Home UI redesigned to match uploaded image
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
                            color: Colors.black.withOpacity(0.1),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: TextField(
                        controller: _searchController,
                        decoration: const InputDecoration(
                          hintText: 'Search in Store',
                          prefixIcon: Icon(Icons.search, color: Colors.grey),
                          border: InputBorder.none,
                          contentPadding: EdgeInsets.symmetric(
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
              child: SingleChildScrollView(
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
                                        color: Colors.black.withOpacity(0.1),
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
                                margin:
                                    const EdgeInsets.symmetric(horizontal: 0),
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(20),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withOpacity(0.1),
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
                                        color: Colors.orange,
                                        child: const Center(
                                            child: Icon(Icons.error,
                                                color: Colors.white)),
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

                    // Featured Products Section
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
                    GridView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      gridDelegate:
                          const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 2,
                        crossAxisSpacing: 16,
                        mainAxisSpacing: 16,
                        // FIX: Increased from 0.65 to 0.75 to prevent bottom overflow
                        childAspectRatio: 0.75,
                      ),
                      itemCount: featuredProducts.length,
                      itemBuilder: (context, index) {
                        final product = featuredProducts[index];
                        return Container(
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(16),
                            color: Colors.white,
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.1),
                                blurRadius: 6,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // 1. Product Image Section
                              Expanded(
                                flex: 5, // Slightly more space for image
                                child: Stack(
                                  children: [
                                    ClipRRect(
                                      borderRadius: const BorderRadius.vertical(
                                          top: Radius.circular(16)),
                                      child: Image.asset(
                                        product['image'] as String,
                                        height: double.infinity,
                                        width: double.infinity,
                                        fit: BoxFit.cover,
                                        errorBuilder:
                                            (context, error, stackTrace) {
                                          return Container(
                                            color: Colors.grey[200],
                                            child: const Icon(
                                                Icons.image_not_supported,
                                                color: Colors.grey),
                                          );
                                        },
                                      ),
                                    ),
                                    // Discount Badge
                                    Positioned(
                                      top: 8,
                                      left: 8,
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 8, vertical: 4),
                                        decoration: BoxDecoration(
                                          color: Colors.yellow[700],
                                          borderRadius:
                                              BorderRadius.circular(8),
                                        ),
                                        child: Text(
                                          '${product['discount']}%',
                                          style: const TextStyle(
                                              fontSize: 10,
                                              fontWeight: FontWeight.bold),
                                        ),
                                      ),
                                    ),
                                    // Wishlist Icon
                                    Positioned(
                                      top: 8,
                                      right: 8,
                                      child: GestureDetector(
                                        onTap: () {
                                          setState(() {
                                            product['isWishlisted'] =
                                                !(product['isWishlisted']
                                                    as bool);
                                          });
                                        },
                                        child: CircleAvatar(
                                          radius: 14,
                                          backgroundColor: Colors.black26,
                                          child: Icon(
                                            product['isWishlisted'] as bool
                                                ? Icons.favorite
                                                : Icons.favorite_border,
                                            color:
                                                product['isWishlisted'] as bool
                                                    ? Colors.red
                                                    : Colors.white,
                                            size: 16,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),

                              // 2. Product Details Section
                              Expanded(
                                flex:
                                    4, // 45% of card height (gave it a bit more space)
                                child: Padding(
                                  // FIX: Reduced padding from 10 to 8 to avoid overflow
                                  padding: const EdgeInsets.all(8),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceBetween,
                                    children: [
                                      // Title and Brand Group
                                      Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Text(
                                            product['title'] as String,
                                            style: const TextStyle(
                                              fontWeight: FontWeight.bold,
                                              fontSize: 14,
                                              color: AppColors.textDark,
                                            ),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                          const SizedBox(height: 2),
                                          Row(
                                            children: [
                                              Flexible(
                                                child: Text(
                                                  product['brand'] as String,
                                                  style: TextStyle(
                                                      fontSize: 12,
                                                      color: Colors.grey[600]),
                                                  maxLines: 1,
                                                  overflow:
                                                      TextOverflow.ellipsis,
                                                ),
                                              ),
                                              const SizedBox(width: 4),
                                              const CircleAvatar(
                                                  radius: 2,
                                                  backgroundColor:
                                                      Color(0xFF4FC3F7)),
                                            ],
                                          ),
                                        ],
                                      ),

                                      // Price and Add Button Group
                                      Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.spaceBetween,
                                        children: [
                                          // Price
                                          Flexible(
                                            child: FittedBox(
                                              fit: BoxFit.scaleDown,
                                              alignment: Alignment.centerLeft,
                                              child: Text(
                                                product['price'] as String,
                                                style: const TextStyle(
                                                  color: AppColors.textDark,
                                                  fontSize: 14,
                                                  fontWeight: FontWeight.bold,
                                                ),
                                              ),
                                            ),
                                          ),
                                          const SizedBox(width: 4),
                                          // Add Button
                                          GestureDetector(
                                            onTap: () {},
                                            child: Container(
                                              width: 28,
                                              height: 28,
                                              decoration: BoxDecoration(
                                                color: Colors.grey[200],
                                                borderRadius:
                                                    BorderRadius.circular(8),
                                              ),
                                              child: Icon(Icons.add,
                                                  color: Colors.grey[800],
                                                  size: 18),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    ),

                    const SizedBox(height: 20),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}