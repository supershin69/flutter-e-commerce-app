import 'package:e_commerce_frontend/screens/products_page.dart';
import 'package:e_commerce_frontend/utils/colors.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/brand_model.dart';

class BrandsPage extends StatefulWidget{
  const BrandsPage({super.key, required this.categoryId, required this.categoryName });

  final String categoryId;
  final String categoryName;

  @override
  State<StatefulWidget> createState() => _BrandState();
}

class _BrandState extends State<BrandsPage> {
  final supabase = Supabase.instance.client;

  late Future<List<Brand>> _brandFuture;

  @override
  void initState() {
    super.initState();
    _brandFuture = fetchBrands();
  }

  Future<List<Brand>> fetchBrands() async {
    final data = await supabase
        .from('product_catalog')
        .select('brand_name')
        .eq('category_name', widget.categoryName);
    
    final rows = List<Map<String, dynamic>>.from(data);
    final brandNames = rows
        .map((row) => row['brand_name']?.toString() ?? '')
        .where((name) => name.isNotEmpty)
        .toSet();

    final brands = <String, Brand>{};

    for (final brandName in brandNames) {
      final brandData = await supabase
          .from('brands')
          .select('id, name, logo_url')
          .eq('name', brandName)
          .maybeSingle();
      if (brandData == null) {
        continue;
      }
      final brand = Brand.fromMap(Map<String, dynamic>.from(brandData));
      brands[brand.id] = brand;
    }
    debugPrint(data.toString());

    return brands.values.toList();
  }

  Future<void> _onRefresh() async {
    final future = fetchBrands();
    setState(() {
      _brandFuture = future;
    });
    await future;
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
        color: Colors.brown.shade300,
        child: FutureBuilder<List<Brand>>(
          future: _brandFuture,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
        
            if (snapshot.hasError) {
              return SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                child: SizedBox(
                  height: MediaQuery.of(context).size.height - 200,
                  child: Center(
                    child: Text(
                      "Error ${snapshot.error}",
                      style: const TextStyle(color: Colors.red),
                    ),
                  ),
                ),
              );
            }
        
            final brands = snapshot.data!;
        
            if (brands.isEmpty) {
              return SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                child: SizedBox(
                  height: MediaQuery.of(context).size.height - 200,
                  child: Center(
                    child: Text(
                      "No ${widget.categoryName} available.",
                      softWrap: true,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ),
              );
            } 
        
            return GridView.builder(
              padding: const EdgeInsets.all(10),
              physics: const AlwaysScrollableScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
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
