import 'package:e_commerce_frontend/screens/product_detail_page.dart';
import 'package:e_commerce_frontend/utils/colors.dart';
import 'package:flutter/material.dart';
import '../models/product_model.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class ProductsPage extends StatefulWidget{

    final String categoryName;
    final String categoryId;
    final String brandId;
    final String brandName;

    ProductsPage ({
      super.key,
      required this.categoryId,
      required this.categoryName,
      required this.brandId,
      required this.brandName
    });

   

  @override
  State<StatefulWidget> createState() => _ProductState();
}

class _ProductState extends State<ProductsPage> {

    final supabase = Supabase.instance.client;

    late Future<List<Product>> _ProductFuture;

    @override
    void initState() {
      super.initState();
      _ProductFuture = fetchProducts();
    }

    Future <List<Product>> fetchProducts() async {
      final data = await supabase.from('product_catalog')
                                .select()
                                .eq('category_name', widget.categoryName)
                                .eq('brand_name', widget.brandName);
      
      debugPrint(data.toString());
      
      return data.map<Product>((e) => Product.fromMap(e)).toList();
    }

    Future<void> _onRefresh() async {
      setState(() {
        _ProductFuture = fetchProducts();
      });
    }


  @override
  Widget build(BuildContext context) {
    // TODO: implement build
    return Scaffold(
      appBar: AppBar(
        backgroundColor: AppColors.appbarColor,
        foregroundColor: Colors.black,
        title: Text('${widget.brandName} Products'),
      ),
      body: RefreshIndicator(
        onRefresh: _onRefresh,
        child: FutureBuilder(
          future: _ProductFuture, 
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
        
            if (snapshot.hasError) {
              return Center(
                child: Text(
                  "Error ${snapshot.error}",
                  style: TextStyle(
                    color: Colors.red
                  ),
                ),
              );
            }
        
            final products = snapshot.data!;
        
            return GridView.builder(
              padding: EdgeInsets.all(10),
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                mainAxisSpacing: 10,
                crossAxisSpacing: 10,
                childAspectRatio: 0.7
              ), 
              itemCount: products.length,
              itemBuilder: (context, index) {
                final product = products[index];
                return InkWell(
                  borderRadius: BorderRadius.circular(16),
                  onTap: () {
                    // Navigate to product details page
                    
                    Navigator.of(context).push(
                      MaterialPageRoute(builder: (context) => ProductDetails())
                    );
                  },
                  child: Card(
                    elevation: 4,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16)
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Image
                        Expanded(
                          child: ClipRRect(
                            borderRadius: BorderRadius.vertical(
                              top: Radius.circular(16)
                            ),
                            child: Container(
                              color: Colors.white,
                              child: Image.network(
                                product.images.isNotEmpty 
                                  ? product.images[0].url  // Access .url here
                                  : 'https://via.placeholder.com/150', // Placeholder if images list is empty
                                fit: BoxFit.contain,
                                width: double.infinity,
                              ),
                            ),
                          )
                        ),
                        // Product Name
                        Container(
                          color: Colors.white,
                          width: double.infinity,
                          padding: EdgeInsets.all(10),
                          child: Text(
                            product.name,
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 14
                            ),
                          ),
                        ),
                        // Product Price
                        Container(
                          padding: EdgeInsets.all(10),
                          width: double.infinity,
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.vertical(
                              bottom: Radius.circular(16)
                            )
                          ),
                          child: product.minPrice == product.maxPrice ?
                            Text(
                              '${product.minPrice} MMK',
                              style: TextStyle(
                                color: Colors.red,
                                fontWeight: FontWeight.bold,
                                fontSize: 14
                              ),
                            ) : Text(
                              '${product.minPrice} - ${product.maxPrice} MMK',
                              style: TextStyle(
                                color: Colors.red,
                                fontWeight: FontWeight.bold,
                                fontSize: 14
                              ),
                            ),
                        ),
                      
                      ],
                    ),
                  ),
                );
              }
            );
          }
        ),
      ),

    );
  }
}