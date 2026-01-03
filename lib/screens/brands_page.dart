import 'package:e_commerce_frontend/utils/colors.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/brand_model.dart';

class BrandsPage extends StatelessWidget{
  BrandsPage({super.key, required this.categoryId, required this.categoryName });

  final String categoryId;
  final String categoryName;

  final supabase = Supabase.instance.client;

  Future<List<Brand>> fetchBrands() async {
    final data = await supabase.from('products')
                                .select('brand_id, brands(id, name, logo_url)')
                                .not('brand_id', 'is', null)
                                .eq('category_id', categoryId)
                                .eq('is_archived', false);
    
    final rows = List<Map<String, dynamic>>.from(data);

    final brands = <String, Brand>{};

    for (final row in rows) {
      final brandMap = row['brands'];
      if (brandMap != null) {
        final brand = Brand.fromMap(Map<String, dynamic>.from(brandMap));
        
        brands[brand.id] = brand;
      }
    }
    debugPrint(data.toString());

    return brands.values.toList();
  }


  @override
  Widget build(BuildContext context) {
    // TODO: implement build
    return Scaffold(
      appBar: AppBar(
        backgroundColor: AppColors.appbarColor,
        foregroundColor: Colors.black,
        title: Text(categoryName),
      ),
      body: FutureBuilder<List<Brand>>(
        future: fetchBrands(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(child: Text("Error ${snapshot.error}", style: TextStyle(color: Colors.red),));
          }

          final brands = snapshot.data!;

          return GridView.builder(
            padding: const EdgeInsets.all(10),
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              crossAxisSpacing: 10,
              mainAxisSpacing: 10
            ), 
            itemCount: brands.length,
            itemBuilder: (context, index) {
              final brand = brands[index];

              return InkWell(
                borderRadius: BorderRadius.circular(16),
                onTap: () {
                  // Navigate to products page filtered by brand
                },
                child: Card(
                  elevation: 4,
                  shadowColor: Colors.black12,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16)
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      //Image
                      Expanded(
                        child: ClipRRect(
                          borderRadius: BorderRadius.vertical(
                            top: Radius.circular(16)
                          ),
                          child: Container(
                           
                            color: Colors.white,
                            child: Image.network(
                              brand.logoUrl,
                              width: double.infinity,
                              fit: BoxFit.contain,
                              errorBuilder: (context, error, stackTrace) {
                                return const Center(
                                  child: Icon(Icons.broken_image, size: 40),
                                );
                              },
                              loadingBuilder: (context, child, loadingProgress) {
                                if (loadingProgress == null) {
                                  return child;
                                }
                                return const Center(
                                  child: CircularProgressIndicator(),
                                );
                              },
                            )
                            
                          ),
                        )
                      )
                    ],
                  ),
                ),
              );
            }
          );
        },
      ),
    );
  }
}
