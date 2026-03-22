import 'package:e_commerce_frontend/utils/colors.dart';
import 'package:e_commerce_frontend/widgets/product_card.dart';
import 'package:flutter/material.dart';
import '../models/product_model.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class ProductsPage extends StatefulWidget{

    final String categoryName;
    final String categoryId;
    final String brandId;
    final String brandName;

    const ProductsPage ({
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

    late Future<List<Product>> _productFuture;

    @override
    void initState() {
      super.initState();
      _productFuture = fetchProducts();
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
      final future = fetchProducts();
      setState(() {
        _productFuture = future;
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
        title: Text('${widget.brandName} Products'),
      ),
      body: RefreshIndicator(
        onRefresh: _onRefresh,
        color: Colors.brown.shade300,
        child: FutureBuilder(
          future: _productFuture, 
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
                      style: const TextStyle(
                        color: Colors.red
                      ),
                    ),
                  ),
                ),
              );
            }
        
            final products = snapshot.data!;
            
            if (products.isEmpty) {
              return SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                child: SizedBox(
                  height: MediaQuery.of(context).size.height - 200,
                  child: const Center(
                    child: Text("No products found"),
                  ),
                ),
              );
            }
        
            return GridView.builder(
              padding: const EdgeInsets.all(16),
              physics: const AlwaysScrollableScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                crossAxisSpacing: 16,
                mainAxisSpacing: 16,
                childAspectRatio: 0.6,
              ), 
                itemCount: products.length,
              itemBuilder: (context, index) {
                final product = products[index];
                return ProductCard(product: product);
              }
            );
          }
        ),
      ),

    );
  }
}