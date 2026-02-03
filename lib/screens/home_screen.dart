import 'package:e_commerce_frontend/screens/CategoriesPage.dart';
import 'package:e_commerce_frontend/screens/NotificationPage.dart';
import 'package:e_commerce_frontend/screens/auth/auth_gate.dart';
import 'package:e_commerce_frontend/screens/cart_page.dart';
import 'package:e_commerce_frontend/utils/colors.dart';
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

  final brandimages = [
    'assets/images/applelogo.jpg',
    'assets/images/oppologo.jpg',
    'assets/images/samsaunglogo.webp',
    'assets/images/vivologo.jpg',
    'assets/images/milogo.jpg',
    'assets/images/huaweilogo.jpg',
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
    CategoryPage(), // index 1
    const Notificationpage(),
    const AuthGate(),    // index 2
  ];


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Digital Hub'),
        backgroundColor: AppColors.appbarColor,
        foregroundColor: Colors.black,

        // Cart Widgets

        actions: [
          Stack(
            children: [
              IconButton(
                  onPressed: (){
                    Navigator.push(
                        context,
                        MaterialPageRoute(builder: (context)=> CartPage()
                        )
                    );
                  },
                  icon: Icon(Icons.shopping_cart)
              ),
              Positioned(
                  right: 2,
                  child: Container(
                    width: 20,
                    height: 20,
                    decoration: BoxDecoration(
                      color: Colors.black,
                      shape: BoxShape.circle,
                    ),
                    child: Center(
                      child: Text(
                        '9',
                        style: TextStyle(
                            fontSize: 12,
                            color: Colors.white
                        ),
                      ),
                    ),

                  )
              )
            ],
          )

        ],
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
              children: [
                Text(
                  'Promotions',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
                GestureDetector(
                  onTap: (){},
                  child:
                  Text('See All',
                      style: TextStyle(
                        color: Colors.blue,
                        decoration: TextDecoration.underline,decorationColor: Colors.blue
                      )
                  ),
                )

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
            SizedBox(height: 25,),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                GestureDetector(
                  onTap: (){},
                  child: Text('Hot Items',
                    style: TextStyle(
                        color: Colors.black,
                      fontSize: 18,
                      fontWeight: FontWeight.bold
                    ),
                  ),
                ),
                GestureDetector(
                  onTap: (){},
                  child:
                  Text('See All',
                      style: TextStyle(
                          color: Colors.blue,
                          decoration: TextDecoration.underline,decorationColor: Colors.blue
                      )
                  ),
                )
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
            SizedBox(height: 12,),
            Text('Brand For You',
              style: TextStyle(
                color: Colors.black,
                fontSize: 18,
                fontWeight: FontWeight.bold
              ),
            ),
            GridView.builder(
              padding: const EdgeInsets.all(8),
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: 6, // total 6 items (2 rows)
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 3, // 3 items in a line
                crossAxisSpacing: 8,
                mainAxisSpacing: 8,
              ),
              itemBuilder: (context, index) {
                return InkWell(
                  onTap: () {
                    // Navigator.push(...);  // go to detail page if you want
                  },
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Image.asset(
                      brandimages[index],
                      fit: BoxFit.cover,
                    ),
                  ),
                );
              },
            )

          ],
        ),
      ),
    );
  }
}
