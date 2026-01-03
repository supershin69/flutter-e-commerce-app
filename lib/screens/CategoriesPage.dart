import 'package:flutter/material.dart';

class ProductPage extends StatelessWidget {
   ProductPage({super.key});

  final List<Map<String,String>> products = [
    {
      'image': 'assets/images/phone.jpg',
      'name': 'Phone'
    },
    {
      'image': 'assets/images/flash_logo.png',
      'name': 'Laptop'
    },
    {
      'image': 'assets/images/airpod.jpg',
      'name': 'airpod'
    },
    {
      'image': 'assets/images/flash_logo.png',
      'name': 'Laptop'
    },
    {
      'image': 'assets/images/flash_logo.png',
      'name': 'Laptop'
    },
    {
      'image': 'assets/images/flash_logo.png',
      'name': 'Laptop'
    },
    {
      'image': 'assets/images/flash_logo.png',
      'name': 'Laptop'
    },
    {
      'image': 'assets/images/flash_logo.png',
      'name': 'Laptop'
    },
  ];
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white54,
      body: Padding(
        padding: const EdgeInsets.all(10),
        child: GridView.builder(
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            crossAxisSpacing: 20,
            mainAxisSpacing: 20,
            childAspectRatio: 0.75, // adjusts item height
          ),
          itemCount: products.length,
          itemBuilder: (context, index) {
            // ===== Wrapped each item with InkWell =====
            return InkWell(
              borderRadius: BorderRadius.circular(20), // ripple effect follows border
              onTap: () {
                // Action when item is clicked
                // You can also navigate to a details page:
                // Navigator.push(context, MaterialPageRoute(builder: (_) => ProductDetailPage(product: products[index])));
              },
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: const [
                    BoxShadow(
                      color: Colors.black12,
                      blurRadius: 6,
                      offset: Offset(2, 2),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Expanded(
                      child: ClipRRect(
                        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
                        child: Image.asset(
                          products[index]['image']!,
                          fit: BoxFit.cover,
                        ),
                      ),
                    ),
                    const Divider(
                      color: Colors.black,
                      thickness: 0.1,
                    ),
                    Padding(
                      padding: const EdgeInsets.all(8.0),
                      child: Text(
                        products[index]['name']!,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                          color: Colors.black87,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
            // ===== End of InkWell wrapper =====
          },
        ),
      ),
    );


  }
}