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
  ];
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Padding(
          padding: EdgeInsets.all(10),
        child: GridView.builder(
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              crossAxisSpacing: 10,
              mainAxisSpacing: 10,
            ),
            itemCount: products.length,
            itemBuilder: (context,index){
              return Container(
                decoration: BoxDecoration(
                  color: Colors.blueGrey,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children:[
                    Expanded(
                        child:
                        Image.asset(
                          products[index]['image']!,
                          fit: BoxFit.cover,
                          width: double.infinity,
                        ),
                    ),
                    const SizedBox(height: 10,),
                    Text(
                      products [index]['name']!,
                      style: TextStyle(
                        fontSize: 15,
                          fontWeight: FontWeight.bold,
                          color:Colors.black ),
                    ),

                  ],
                )
              );
            }
        ),
          
      )
    );
  }
}