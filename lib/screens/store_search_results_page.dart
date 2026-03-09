import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/product_model.dart';
import '../utils/colors.dart';
import '../widgets/product_card.dart';

class StoreSearchResultsPage extends StatefulWidget {
  final String searchQuery;

  const StoreSearchResultsPage({
    super.key,
    required this.searchQuery,
  });

  @override
  State<StoreSearchResultsPage> createState() => _StoreSearchResultsPageState();
}

class _StoreSearchResultsPageState extends State<StoreSearchResultsPage> {
  final supabase = Supabase.instance.client;
  late Future<List<Product>> _searchResultsFuture;
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _searchController.text = widget.searchQuery;
    _searchResultsFuture = _performSearch(widget.searchQuery);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  /// Normalizes a string for fuzzy matching by converting to lowercase and removing spaces
  String _normalizeString(String input) {
    return input.toLowerCase().replaceAll(' ', '');
  }

  Future<List<Product>> _performSearch(String query) async {
    try {
      // If search query is empty, return all products
      if (query.trim().isEmpty) {
        final data = await supabase.from('product_catalog').select();
        return data.map<Product>((e) => Product.fromMap(e)).toList();
      }

      final searchTerm = query.trim();
      
      // Normalize the search term for fuzzy matching
      // This converts "i phone" to "iphone", "IPHONE" to "iphone", etc.
      final normalizedSearchTerm = _normalizeString(searchTerm);

      // Fetch all products from product_catalog
      // We'll do client-side filtering for better fuzzy matching control
      final data = await supabase.from('product_catalog').select();
      final allProducts = data.map<Product>((e) => Product.fromMap(e)).toList();

      // Filter products using fuzzy matching across three fields:
      // 1. Product Name (e.g., "iPhone 15", "iPhone 15 Pro Max")
      // 2. Brand Name (e.g., "Apple")
      // 3. Category Name (e.g., "Smartphones")
      return allProducts.where((product) {
        // Normalize each field for comparison
        final normalizedProductName = _normalizeString(product.name);
        final normalizedBrandName = _normalizeString(product.brandName);
        final normalizedCategoryName = _normalizeString(product.categoryName);

        // Check if normalized search term is contained in any of the normalized fields
        final productNameMatch = normalizedProductName.contains(normalizedSearchTerm);
        final brandNameMatch = normalizedBrandName.contains(normalizedSearchTerm);
        final categoryNameMatch = normalizedCategoryName.contains(normalizedSearchTerm);

        // Return true if search term matches any field
        return productNameMatch || brandNameMatch || categoryNameMatch;
      }).toList();
    } catch (e) {
      debugPrint('Error performing search: $e');
      return [];
    }
  }

  void _onSearchSubmitted(String query) {
    setState(() {
      _searchResultsFuture = _performSearch(query);
    });
  }

  Future<void> _onRefresh() async {
    setState(() {
      _searchResultsFuture = _performSearch(_searchController.text);
    });
  }

  @override
  Widget build(BuildContext context) {
    const muted = Color(0xFF9AA0A6);
    const border = Color(0xFFE0E0E0);
    const card = Colors.white;

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: AppColors.textDark),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Container(
          decoration: BoxDecoration(
            color: card,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: border),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withAlpha(13),
                blurRadius: 4,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: TextField(
            controller: _searchController,
            style: const TextStyle(color: AppColors.textDark),
            decoration: InputDecoration(
              hintText: 'Search in Store',
              hintStyle: const TextStyle(color: muted),
              prefixIcon: const Icon(Icons.search, color: muted),
              suffixIcon: _searchController.text.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear, color: muted),
                      onPressed: () {
                        _searchController.clear();
                        setState(() {});
                      },
                    )
                  : null,
              border: InputBorder.none,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 14,
                vertical: 10,
              ),
            ),
            onChanged: (value) {
              setState(() {});
            },
            onSubmitted: _onSearchSubmitted,
            autofocus: false,
          ),
        ),
      ),
      body: RefreshIndicator(
        onRefresh: _onRefresh,
        child: FutureBuilder<List<Product>>(
          future: _searchResultsFuture,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(
                child: Padding(
                  padding: EdgeInsets.all(20.0),
                  child: CircularProgressIndicator(),
                ),
              );
            }

            if (snapshot.hasError) {
              return Center(
                child: Padding(
                  padding: const EdgeInsets.all(20.0),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.error_outline, size: 48, color: Colors.red),
                      const SizedBox(height: 16),
                      Text(
                        'Error: ${snapshot.error}',
                        style: const TextStyle(color: Colors.red),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
              );
            }

            final products = snapshot.data ?? [];

            if (products.isEmpty) {
              return Center(
                child: Padding(
                  padding: const EdgeInsets.all(20.0),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.search_off, size: 64, color: muted),
                      const SizedBox(height: 16),
                      Text(
                        'No products found',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                          color: muted,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Try searching with a different term',
                        style: TextStyle(
                          fontSize: 14,
                          color: muted,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }

            return GridView.builder(
              padding: const EdgeInsets.all(16),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                crossAxisSpacing: 16,
                mainAxisSpacing: 16,
                childAspectRatio: 0.6,
              ),
              itemCount: products.length,
              itemBuilder: (context, index) {
                return ProductCard(product: products[index]);
              },
            );
          },
        ),
      ),
    );
  }
}
