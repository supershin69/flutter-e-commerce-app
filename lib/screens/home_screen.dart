import 'package:e_commerce_frontend/screens/CategoriesPage.dart';
import 'package:e_commerce_frontend/screens/NotificationPage.dart';
import 'package:e_commerce_frontend/screens/ProfilePage.dart';
import 'package:flutter/material.dart';
import '/widgets/bottom_nav_bar.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {

  // ====== Promotion items data ======
  final List<Map<String, String>> promotions = [
    {
      'image': 'assets/images/phone.jpg',
      'title': 'Phone',
      'price': '1800000 MMK',
      'discount': '20% OFF',
    },
    {
      'image': 'assets/images/laptop.jpg',
      'title': 'Laptop',
      'price': '3000000 MMK',
      'discount': '15% OFF',
    },
    {
      'image': 'assets/images/airpod.jpg',
      'title': 'Airpod',
      'price': '850000 MMK',
      'discount': '30% OFF',
    },
    {
      'image': 'assets/images/phone.jpg',
      'title': 'Airpod',
      'price': '850000 MMK',
      'discount': '30% OFF',
    },
  ];

  final PageController _pageController = PageController();
  int _currentPage = 0;

  final List<String> images = [
    'assets/images/ad1.jpg',
    'assets/images/ad2.jpg',
    'assets/images/ad3.jpg',
  ];

  final TextEditingController _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    _pageController.dispose();
    super.dispose();
  }

  // pages for bottom navigation
  int _selectedIndex = 0;

  late final List<Widget> _pages = [
    _buildHomeContent(), // index 0 → Home
     ProductPage(), // index 1
    const Notificationpage(),
    const ProfilePage(),    // index 2
  ];


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Digital Hub'),
        backgroundColor: const Color(0xFF45C3F5),
        foregroundColor: Colors.black,
      ),

      // uses IndexedStack
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

  // Home UI moved into method
  Widget _buildHomeContent() {
    return GestureDetector(
      onTap: () => FocusScope.of(context).unfocus(),
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [

            // 🔍 Search
            TextFormField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Search products',
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),

            const SizedBox(height: 30),

            // 🖼 Image Slider
            SizedBox(
              height: 200,
              child: PageView.builder(
                controller: _pageController,
                itemCount: images.length,
                onPageChanged: (index) {
                  setState(() => _currentPage = index);
                },
                itemBuilder: (context, index) {
                  return Image.asset(images[index], fit: BoxFit.cover);
                },
              ),
            ),

            const SizedBox(height: 30),

            // 🔥 Promotions
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: const [
                Text(
                  'Promotions',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
                Text('See All', style: TextStyle(color: Colors.blue)),
              ],
            ),

            const SizedBox(height: 12),

            SizedBox(
              height: 230,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                itemCount: promotions.length,
                itemBuilder: (context, index) {
                  final item = promotions[index];
                  return Container(
                    width: 160,
                    margin: const EdgeInsets.only(right: 16),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(16),
                      color: Colors.white,
                      boxShadow: const [
                        BoxShadow(color: Colors.black12, blurRadius: 6),
                      ],
                    ),
                    child: Column(
                      children: [
                        ClipRRect(
                          borderRadius: const BorderRadius.vertical(
                            top: Radius.circular(16),
                          ),
                          child: Image.asset(
                            item['image']!,
                            height: 120,
                            width: double.infinity,
                            //fit: BoxFit.cover,
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.all(8),
                          child: Column(
                            children: [
                              Text(item['title']!,
                                  style: const TextStyle(fontWeight: FontWeight.bold)),
                              Text(item['price']!,
                                  style: const TextStyle(color: Colors.red)),
                              Text(item['discount']!,
                                  style: const TextStyle(color: Colors.green)),
                            ],
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
