import 'package:e_commerce_frontend/models/product_model.dart';
import 'package:e_commerce_frontend/screens/auth/auth_gate.dart';
import 'package:e_commerce_frontend/utils/colors.dart';
import 'package:e_commerce_frontend/widgets/product_action_bar.dart';
import 'package:e_commerce_frontend/widgets/transparent_appbar.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/variant_attribute_model.dart';

class ProductDetails extends StatefulWidget {
  final Product product; // Pass the product here

  const ProductDetails({super.key, required this.product});

  @override
  State<StatefulWidget> createState() => _ProductDetailState();
}

class _ProductDetailState extends State<ProductDetails> {
  bool isWishlisted = false;

  final supabase = Supabase.instance.client;

  late Future<List<Product>> _RelatedProductFuture;

  Future<List<Product>> fetchRelatedProducts() async {
    final data = await supabase.from('product_catalog')
                              .select()
                              .eq('category_name', widget.product.categoryName)
                              .neq('id', widget.product.id) // Exclude current product
                              .limit(10); // Limit to 10 related products
    
    debugPrint(data.toString());
    
    return data.map<Product>((e) => Product.fromMap(e)).toList();
  }
  
  // State for selections
  // Key: Attribute Type (e.g., 'color'), Value: Selected Attribute Object
  Map<String, VariantAttribute> selectedAttributes = {};
  
  ProductVariant? currentVariant;
  int currentPrice = 0;
  List<ProductImage> displayImages = [];

  @override
  void initState() {
    super.initState();
    _initializeSelection();
    _RelatedProductFuture = fetchRelatedProducts();
  }

  void _initializeSelection() {
    
    // 1. If variants exist, pre-select the attributes of the first variant
    if (widget.product.variants.isNotEmpty) {
      final firstVariant = widget.product.variants.first;
      for (var attr in firstVariant.attributes) {
        selectedAttributes[attr.type] = attr;
      }
      _updateVariantAndImages();
    } else {
      // No variants, just set defaults
      currentPrice = widget.product.minPrice;
      displayImages = widget.product.images;
    }
  }

  void _updateVariantAndImages() {
    // 1. Find the variant that matches ALL selected attributes
    try {
      final matchingVariant = widget.product.variants.firstWhere((variant) {
        // Check if this variant has all the currently selected attributes
        return selectedAttributes.entries.every((entry) {
          return variant.attributes.any((attr) => 
            attr.type == entry.key && attr.value == entry.value.value
          );
        });
      });

      setState(() {
        currentVariant = matchingVariant;
        currentPrice = matchingVariant.price;
      });
    } catch (e) {
      // No exact match found (rare if logic is tight, but possible)
      setState(() {
        currentVariant = null;
      });
    }

    // 2. Update Images based on 'color' attribute if it exists
    if (selectedAttributes.containsKey('color')) {
      final colorId = selectedAttributes['color']!.attributeValueId;
      
      final variantImages = widget.product.images.where(
        (img) => img.attributeValueId == colorId
      ).toList();

      setState(() {
        // If variant images exist, show them. Otherwise fallback to defaults (null id) or all.
        displayImages = variantImages.isNotEmpty 
            ? variantImages 
            : widget.product.images.where((img) => img.attributeValueId == null).toList();
            
        // If fallback is empty, just show everything
        if (displayImages.isEmpty) displayImages = widget.product.images;
      });
    } else {
      setState(() {
        displayImages = widget.product.images;
      });
    }
  }

  void onAttributeSelected(String type, VariantAttribute attribute) {
    setState(() {
      selectedAttributes[type] = attribute;
    });
    _updateVariantAndImages();
  }

  void onWishlistToggle() {
    // TODO: Call Supabase/API to add widget.product.id to wishlist
    setState(() {
      isWishlisted = !isWishlisted;
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(isWishlisted ? "Added to Wishlist" : "Removed from Wishlist"))
    );
  }

  void addToCart() {
    if (currentVariant == null && widget.product.variants.isNotEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please select all options"))
      );
      return;
    }
    
    // TODO: Add logic to add to cart provider/database
    // You would pass: widget.product.id, currentVariant?.id, quantity
    
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text("Added ${currentVariant?.attributes.map((e) => e.displayValue).join(' ')} to Cart"))
    );
  }

  @override
  Widget build(BuildContext context) {
    // Extract unique attributes to build the UI (e.g. unique Colors, unique RAMs)
    final Map<String, List<VariantAttribute>> attributesByType = {};
    for (var variant in widget.product.variants) {
      for (var attr in variant.attributes) {
        if (!attributesByType.containsKey(attr.type)) {
          attributesByType[attr.type] = [];
        }
        // Avoid duplicates in the UI list
        if (!attributesByType[attr.type]!.any((e) => e.value == attr.value)) {
          attributesByType[attr.type]!.add(attr);
        }
      }
    }

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.dark,
      child: Scaffold(
        extendBodyBehindAppBar: true,
        appBar: TransparentAppbar(
          isWishlisted: isWishlisted, 
          onWishlistToggle: onWishlistToggle,
          cartCount: 2, // Example: Replace with real cart provider count
        ),
        body: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                height: 40,
              ),
              // --- Image Gallery ---
              AspectRatio(
                aspectRatio: 4/3, // 1.0 = Square. Use 4/3 for a slightly shorter rectangle.
                child: Container(
                  color: Colors.white, // Background color for when the image is smaller than the box
                  child: displayImages.isNotEmpty
                      ? PageView.builder(
                          itemCount: displayImages.length,
                          itemBuilder: (context, index) {
                            return InteractiveViewer( // Optional: Allows user to pinch-to-zoom
                              child: Image.network(
                                displayImages[index].url,
                                
                                // THE KEY CHANGE:
                                // scaleDown behaves like 'contain' if the image is big,
                                // but behaves like 'none' (actual size) if the image is small.
                                fit: BoxFit.scaleDown, 
                                
                                // Ensure loading experience is smooth
                                loadingBuilder: (context, child, loadingProgress) {
                                  if (loadingProgress == null) return child;
                                  return Center(
                                    child: CircularProgressIndicator(
                                      value: loadingProgress.expectedTotalBytes != null
                                          ? loadingProgress.cumulativeBytesLoaded /
                                              loadingProgress.expectedTotalBytes!
                                          : null,
                                    ),
                                  );
                                },
                                errorBuilder: (context, error, stackTrace) =>
                                    const Center(child: Icon(Icons.error_outline, color: Colors.grey)),
                              ),
                            );
                          },
                        )
                      : const Center(
                          child: Icon(Icons.image_not_supported, size: 50, color: Colors.grey)
                        ),
                ),
              ),
              
              const SizedBox(height: 20),

              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // --- Price & Name ---
                    Text(
                      widget.product.name,
                      style: const TextStyle(
                        fontSize: 22, 
                        fontWeight: FontWeight.bold
                      ),
                      softWrap: true,
                    ),
                    SizedBox(
                      height: 8,
                    ),
                    Text(
                      '$currentPrice MMK',
                      style: const TextStyle(
                        fontSize: 20, 
                        fontWeight: FontWeight.bold,
                        color: AppColors.matchaGreen
                      ),
                    ),
                    const SizedBox(height: 10),
                    _buildDivider(),
                    const SizedBox(height: 10),
                    
                   

                    ...attributesByType.entries.map((entry) {
                    final type = entry.key;
                    final attributes = entry.value;
                    debugPrint("ATTRIBUTES BY TYPE:");
                      attributesByType.forEach((key, value) {
                        debugPrint("$key -> ${value.map((e) => e.displayValue).toList()}");
                      });

                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          type.toUpperCase(),
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Colors.grey,
                          ),
                        ),
                        const SizedBox(height: 8),

                        Wrap(
                          spacing: 10,
                          children: attributes.map((attr) {
                            final isSelected = selectedAttributes[type]?.value == attr.value;

                            return ChoiceChip(
                              label: Text(attr.displayValue),

                              // if only 1 value: auto select & disable tap
                              selected: isSelected || attributes.length == 1,
                              onSelected: (selected) {
                                      if (selected) onAttributeSelected(type, attr);
                                    },

                              selectedColor: AppColors.appbarColor,
                              labelStyle: TextStyle(
                                color: (isSelected || attributes.length == 1)
                                    ? Colors.white
                                    : AppColors.appbarColor,
                              ),
                              checkmarkColor: Colors.white,
                            );
                          }).toList(),
                        ),

                        const SizedBox(height: 15),
                      ],
                    );
                  }),

                    _buildDivider(),
                    const SizedBox(height: 10),

                     // --- Description ---
                    Text(
                      widget.product.description,
                      style: TextStyle(color: Colors.grey[600], height: 1.5),
                    ),
                    const SizedBox(height: 10),
                    
                    // Extra spacing for bottom bar
                    _buildDivider(),
                    const SizedBox(height: 10),
                    Padding(
                      padding: EdgeInsets.only(
                        bottom: 10
                      ),
                      child: Text(
                        'Related Products',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w600
                        ),
                      ),
                    ),
                    FutureBuilder(
                      future: _RelatedProductFuture, 
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

                        final relatedProducts = snapshot.data!;

                        return SizedBox(
                          height: 250,
                          child: ListView.builder(
                            scrollDirection: Axis.horizontal, 
                            itemCount: relatedProducts.length,
                            itemBuilder: (context, index) {
                              final relatedProduct = relatedProducts[index];
                              return InkWell(
                                borderRadius: BorderRadius.circular(16),
                                onTap: () {
                                  // Navigate to product details page
                                  
                                  Navigator.of(context).push(
                                    MaterialPageRoute(builder: (context) => ProductDetails(product: relatedProduct))
                                  );
                                },
                                child: Container(
                                  width: 160,
                                  height: 230,
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(16),
                                    color: Colors.transparent
                                  ),
                                  margin: EdgeInsets.only(right: 16),
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
                                              width: double.infinity,
                                              child: AspectRatio(
                                                aspectRatio: 1,
                                                child: Image.network(
                                                  relatedProduct.images.isNotEmpty 
                                                    ? relatedProduct.images[0].url  // Access .url here
                                                    : 'https://via.placeholder.com/150', // Placeholder if images list is empty
                                                  fit: BoxFit.cover,
                                                  width: double.infinity,
                                                ),
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
                                            relatedProduct.name,
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
                                          child: relatedProduct.minPrice == relatedProduct.maxPrice ?
                                            Text(
                                              '${relatedProduct.minPrice} MMK',
                                              style: TextStyle(
                                                color: AppColors.matchaGreen,
                                                fontWeight: FontWeight.bold,
                                                fontSize: 14
                                              ),
                                            ) : Text(
                                              '${relatedProduct.minPrice} - ${relatedProduct.maxPrice} MMK',
                                              style: TextStyle(
                                                color: AppColors.matchaGreen,
                                                fontWeight: FontWeight.bold,
                                                fontSize: 14
                                              ),
                                            ),
                                        ),
                                      
                                      ],
                                    ),
                                  ),
                                ),
                              );
                            },
                          ),
                        );
                      }
                    )
                    
                  ],
                ),
              ),
            ],
          ),
        ),
        bottomNavigationBar: ProductActionBar(addToCart: addToCart),
      ),
    );
  }
}

Widget _buildDivider() {
    return const Divider(
      height: 1,
      thickness: 0.5, 
    );
  }
