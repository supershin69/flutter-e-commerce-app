import 'package:e_commerce_frontend/screens/brands_page.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/category_model.dart';


class CategoryPage extends StatefulWidget {
  CategoryPage({super.key});

  @override
  State<StatefulWidget> createState() => _CategoryState();
}

class _CategoryState extends State<CategoryPage> {
  final supabase = Supabase.instance.client;

  late Future<List<Category>> _CategoryFuture;

  @override
  void initState() {
    super.initState();
    _CategoryFuture = fetchCategories();
  }

  Future<List<Category>> fetchCategories() async {
    final data = await supabase.from('categories').select();
    return data.map<Category>((e) => Category.fromMap(e)).toList();
  }

  Future<void> _onRefresh() async {
    setState(() {
      _CategoryFuture = fetchCategories();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: RefreshIndicator(
        onRefresh: _onRefresh,
        child: FutureBuilder<List<Category>>(
          future: _CategoryFuture,
          builder: (context, snapshot) {
            // Loading
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
        
            // Error
            if (snapshot.hasError) {
              return Center(child: Text(snapshot.error.toString()));
            }
        
            final categories = snapshot.data!;
        
            return GridView.builder(
              padding: const EdgeInsets.all(10),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                crossAxisSpacing: 10,
                mainAxisSpacing: 10,
              ),
              itemCount: categories.length,
              itemBuilder: (context, index) {
                final category = categories[index];
            
               return InkWell(
                  borderRadius: BorderRadius.circular(16),
                  onTap: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(builder: (context) => BrandsPage(categoryId: category.id, categoryName: category.name))
                    );
                  },
                  child: Card(
                    elevation: 4,
                    shadowColor: Colors.black12,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Image
                        Expanded(
                          child: ClipRRect(
                            borderRadius: const BorderRadius.vertical(
                              top: Radius.circular(16),
                            ),
                            child: Container(
                              color: Colors.white,
                              child: Image.network(
                                category.imageUrl,
                                width: double.infinity,
                                fit: BoxFit.contain,
                                errorBuilder: (context, error, stackTrace) {
                                  return const Center(
                                    child: Icon(Icons.broken_image, size: 40),
                                  );
                                },
                                loadingBuilder: (context, child, loadingProgress) {
                                  if (loadingProgress == null) return child;
                                  return const Center(
                                    child: CircularProgressIndicator(strokeWidth: 2),
                                  );
                                },
                              ),
                            ),
                          ),
                        ),
               
                        // Text
                        Container(
                          width: double.infinity,
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: const BorderRadius.vertical(
                              bottom: Radius.circular(16),
                            ),
                          ),
                          child: Padding(
                            padding: const EdgeInsets.all(10),
                            child: Center(
                              child: Text(
                                category.name,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            );
          },
        ),
      ),
    );


  }
}