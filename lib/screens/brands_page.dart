import 'package:e_commerce_frontend/screens/products_page.dart';
import 'package:e_commerce_frontend/utils/colors.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/brand_model.dart';

class BrandsPage extends StatefulWidget{
  BrandsPage({super.key, required this.categoryId, required this.categoryName });

  final String categoryId;
  final String categoryName;

  @override
  State<StatefulWidget> createState() => _BrandState();
}

class _BrandState extends State<BrandsPage> {
  final supabase = Supabase.instance.client;

  late Future<List<Brand>> _BrandFuture;

  @override
  void initState() {
    super.initState();
    _BrandFuture = fetchBrands();
  }

  Future<List<Brand>> fetchBrands() async {
    final data = await supabase.from('products')
                                .select('brand_id, brands(id, name, logo_url)')
                                .not('brand_id', 'is', null)
                                .eq('category_id', widget.categoryId)
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

  Future<void> _onRefresh() async {
    setState(() {
      _BrandFuture = fetchBrands();
    });
  }


  @override
  Widget build(BuildContext context) {
    // TODO: implement build
    return Scaffold(
      appBar: AppBar(
        backgroundColor: AppColors.appbarColor,
        foregroundColor: Colors.black,
        title: Text(widget.categoryName),
      ),
      body: RefreshIndicator(
        onRefresh: _onRefresh,
        child: FutureBuilder<List<Brand>>(
          future: _BrandFuture,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
        
            if (snapshot.hasError) {
              return Center(child: Text("Error ${snapshot.error}", style: TextStyle(color: Colors.red),));
            }
        
            final brands = snapshot.data!;
        
            if (brands.isEmpty) {
              return Center(
                child: Text(
                  "No ${widget.categoryName} available.",
                  softWrap: true,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              );
            } 
        
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
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (context) => ProductsPage(
                          categoryId: widget.categoryId, 
                          categoryName: widget.categoryName, 
                          brandId: brand.id, 
                          brandName: brand.name))
                    );
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
                        ),
                        Container(
                          width: double.infinity,
                          decoration: BoxDecoration(
                            color: Colors.grey.shade100,
                            borderRadius: BorderRadius.vertical(
                              bottom: Radius.circular(16)
                            )
                          ),
                          child: Padding(
                            padding: const EdgeInsets.all(10),
                            child: Center(
                              child: Text(
                                brand.name,
                                maxLines: 1,
                                style: TextStyle(
                                  overflow: TextOverflow.ellipsis,
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600
                                ),
                              )
                            ),
                          ),
                        )
                      ],
                    ),
                  ),
                );
              }
            );
          },
        ),
      ),
    );
  }
}
