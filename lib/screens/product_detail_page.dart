import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; // REQUIRED for SystemUiOverlayStyle
import 'package:supabase_flutter/supabase_flutter.dart'; // REQUIRED for Supabase
import 'package:e_commerce_frontend/models/product_model.dart';
import 'package:e_commerce_frontend/models/cart_item_model.dart';
import 'package:e_commerce_frontend/utils/colors.dart';
import 'package:e_commerce_frontend/widgets/product_action_bar.dart';
import 'package:e_commerce_frontend/widgets/transparent_appbar.dart';
import 'package:get/get.dart';
import 'package:e_commerce_frontend/features/shop/controllers/product_controller.dart';
import '../services/cart_service.dart';
import 'package:uuid/uuid.dart';

class ProductDetails extends StatefulWidget {
  final Product product;

  const ProductDetails({super.key, required this.product});

  @override
  State<StatefulWidget> createState() => _ProductDetailState();
}

class _ProductDetailState extends State<ProductDetails> {
  final supabase = Supabase.instance.client;
  final CartService _cartService = CartService();
  final _uuid = const Uuid();

  late Product _product;
  late Future<List<Product>> _relatedProductFuture;
  bool _isLoadingProduct = false;

  // State for selections
  Map<String, VariantAttribute> selectedAttributes = {};
  ProductVariant? currentVariant;
  double currentPrice = 0.0;
  List<ProductImage> displayImages = [];

  @override
  void initState() {
    super.initState();
    _product = widget.product;
    _initializeSelection();
    _loadFullProductIfNeeded();
    _relatedProductFuture = fetchRelatedProducts();
  }

  Future<void> _loadFullProductIfNeeded() async {
    if (_product.variants.isNotEmpty && _product.images.isNotEmpty) return;
    setState(() {
      _isLoadingProduct = true;
    });
    try {
      final data = await supabase
          .from('product_catalog')
          .select()
          .eq('id', _product.id)
          .maybeSingle();
      if (data != null) {
        final loaded = Product.fromMap(Map<String, dynamic>.from(data));
        if (mounted) {
          setState(() {
            _product = loaded;
            selectedAttributes = {};
            currentVariant = null;
            currentPrice = 0.0;
            displayImages = [];
            _initializeSelection();
          });
        }
      }
    } catch (e) {
      debugPrint('Error loading product_catalog for ${_product.id}: $e');
    } finally {
      if (mounted) {
        setState(() {
          _isLoadingProduct = false;
        });
      }
    }
  }

  Future<List<Product>> fetchRelatedProducts() async {
    final data = await supabase
        .from('product_catalog')
        .select()
        .eq('category_name', _product.categoryName)
        .neq('id', _product.id)
        .limit(10);

    return data.map<Product>((e) => Product.fromMap(e)).toList();
  }

  void _initializeSelection() {
    if (_product.variants.isNotEmpty) {
      final firstVariant = _product.variants.first;
      currentVariant = firstVariant;
      currentPrice = firstVariant.price.toDouble();
      displayImages = _product.images;
      for (var attr in firstVariant.attributes) {
        selectedAttributes[attr.type] = attr;
      }
    } else {
      currentPrice = _product.minPrice.toDouble();
      displayImages = _product.images;
    }
  }

  void _updateVariantAndImages() {
    if (_product.variants.isEmpty) return;

    ProductVariant? newVariant;
    double newPrice = currentPrice;
    List<ProductImage> newImages;

    try {
      final matchingVariant = _product.variants.firstWhere((variant) {
        return selectedAttributes.values.every((selectedAttr) {
          return variant.attributes.any((variantAttr) => variantAttr.id == selectedAttr.id);
        });
      });
      newVariant = matchingVariant;
      newPrice = matchingVariant.price.toDouble();
    } catch (e) {
      newVariant = null;
    }

    if (selectedAttributes.containsKey('color')) {
      final selectedColorAttribute = selectedAttributes['color']!;
      final variantImages = _product.images
          .where((img) => img.attributeValueId == selectedColorAttribute.id)
          .toList();

      newImages = variantImages.isNotEmpty
          ? variantImages
          : _product.images.where((img) => img.attributeValueId == null).toList();
      if (newImages.isEmpty) newImages = _product.images;
    } else {
      newImages = _product.images;
    }

    setState(() {
      currentVariant = newVariant;
      currentPrice = newPrice;
      displayImages = newImages;
    });
  }

  Future<void> addToCart(int quantity) async {
    if (_product.variants.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("No variants available for this product")),
      );
      return;
    }

    if (currentVariant == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please select all options")),
      );
      return;
    }

    try {
      final price = currentPrice;
      final variantId = currentVariant!.id;
      final variantName = currentVariant!.attributes.map((e) => e.value).join(', ');
      final firstImage = _product.images.isNotEmpty ? _product.images.first.url : '';

      final cartItem = CartItem(
        id: _uuid.v4(),
        productId: _product.id,
        productName: _product.name,
        variantId: variantId,
        variantName: variantName,
        price: price.toInt(),
        quantity: quantity,
        imageUrl: firstImage,
        brandName: _product.brandName,
        categoryName: _product.categoryName,
      );

      final success = await _cartService.addToCart(cartItem);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(success ? "Added ${quantity}x ${_product.name} to Cart" : "Failed to add to cart"),
            backgroundColor: success ? Colors.green : Colors.red,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Error: ${e.toString()}"), backgroundColor: Colors.red),
        );
      }
    }
  }

  


  void _showPriceAlertSheet() {
    final TextEditingController priceController = TextEditingController();
    
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom,
          ),
          child: Container(
            padding: const EdgeInsets.all(20),
            child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    'Set Price Alert',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 20),
                  Text(
                    'Current price: ${_product.minPrice.round()} MMK',
                    style: const TextStyle(fontSize: 16),
                  ),
                  const SizedBox(height: 20),
                  TextField(
                    controller: priceController,
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(
                      labelText: 'Target price (MMK)',
                      hintText: 'Enter price below which to alert',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () async {
                        final targetPrice = int.tryParse(priceController.text);
                        if (targetPrice == null) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Please enter a valid price'),
                              backgroundColor: Colors.red,
                            ),
                          );
                          return;
                        }
                        
                        await _savePriceAlert(targetPrice);
                        Navigator.pop(context);
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.brown.shade300,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                      ),
                      child: const Text(
                        'Save Alert',
                        style: TextStyle(color: Colors.white, fontSize: 16),
                      ),
                    ),
                  ),
                ],
              ),
            ),
        );
      },
    );
  }

  // Add this method to save the alert
  Future<void> _savePriceAlert(int targetPrice) async {
    final user = Supabase.instance.client.auth.currentUser;
    
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please login to set price alerts'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }
    
    try {
      await Supabase.instance.client
          .from('price_alerts')
          .upsert({
            'user_id': user.id,
            'product_id': _product.id,
            'target_price': targetPrice,
            'is_active': true,
          }, onConflict: 'user_id, product_id');
      
      // Update local controller state as well if it exists
      if (Get.isRegistered<ProductController>()) {
        Get.find<ProductController>().fetchPriceAlerts();
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('✅ Alert set! We\'ll notify you when price drops below $targetPrice MMK'),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('❌ Error: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Widget _buildDivider() {
    return const Divider(height: 1, thickness: 0.5);
  }

  Future<void> _showAvailabilityDebug() async {
    try {
      final productRow = await supabase
          .from('products')
          .select('id, name, is_archived, created_at')
          .eq('id', _product.id)
          .maybeSingle();

      final variants = await supabase
          .from('product_variants')
          .select('id, price, quantity, is_active')
          .eq('product_id', _product.id);
      final variantsList = (variants as List<dynamic>?) ?? const <dynamic>[];

      Map<String, dynamic>? catalogRow;
      try {
        catalogRow = await supabase
            .from('product_catalog')
            .select()
            .eq('id', _product.id)
            .maybeSingle();
      } catch (_) {
        catalogRow = null;
      }

      final text = StringBuffer()
        ..writeln('Product:')
        ..writeln(productRow == null ? '-' : productRow.toString())
        ..writeln('')
        ..writeln('Variants:')
        ..writeln(variantsList.isNotEmpty ? variantsList.toString() : '[]')
        ..writeln('')
        ..writeln('Catalog row:')
        ..writeln(catalogRow == null ? '-' : catalogRow.toString())
        ..writeln('')
        ..writeln('Parsed in app:')
        ..writeln('variants=${_product.variants.length} images=${_product.images.length} archived=${_product.archived} isAvailable=${_product.isAvailable}');

      if (!mounted) return;
      await showDialog<void>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Availability Debug'),
          content: SizedBox(
            width: double.maxFinite,
            child: SingleChildScrollView(child: SelectableText(text.toString())),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Close'),
            ),
          ],
        ),
      );
    } catch (e) {
      debugPrint('Availability debug error: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final Map<String, List<VariantAttribute>> attributesByType = {};
    for (var variant in _product.variants) {
      for (var attr in variant.attributes) {
        if (!attributesByType.containsKey(attr.type)) attributesByType[attr.type] = [];
        if (!attributesByType[attr.type]!.any((e) => e.id == attr.id)) {
          attributesByType[attr.type]!.add(attr);
        }
      }
    }

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.dark,
      child: Scaffold(
        extendBodyBehindAppBar: true,
        appBar: const PreferredSize(
          preferredSize: Size.fromHeight(56),
          child: TransparentAppbar(),
        ),
        body: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 40),
              if (_isLoadingProduct) const LinearProgressIndicator(minHeight: 2),
              AspectRatio(
                aspectRatio: 4 / 3,
                child: Container(
                  color: Colors.white,
                  child: displayImages.isNotEmpty
                      ? PageView.builder(
                          itemCount: displayImages.length,
                          itemBuilder: (context, index) {
                            return InteractiveViewer(
                              child: Image.network(
                                displayImages[index].url,
                                fit: BoxFit.scaleDown,
                                loadingBuilder: (context, child, progress) {
                                  if (progress == null) return child;
                                  return const Center(child: CircularProgressIndicator());
                                },
                                errorBuilder: (context, error, stack) => const Icon(Icons.error_outline),
                              ),
                            );
                          },
                        )
                      : const Center(child: Icon(Icons.image_not_supported)),
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(_product.name, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    Text('$currentPrice MMK', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: AppColors.matchaGreen)),
                    const SizedBox(height: 10),
                    _buildDivider(),
                    const SizedBox(height: 10),
                    
                    ...attributesByType.entries.map((entry) {
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(entry.key.toUpperCase(), style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.grey)),
                          const SizedBox(height: 8),
                          Wrap(
                            spacing: 10,
                            children: entry.value.map((attr) {
                              final isSelected = selectedAttributes[entry.key]?.id == attr.id;
                              return ChoiceChip(
                                label: Text(attr.value),
                                selected: isSelected,
                                onSelected: (selected) {
                                  setState(() {
                                    if (selected) {
                                      selectedAttributes[entry.key] = attr;
                                    } else {
                                      selectedAttributes.remove(entry.key);
                                    }
                                    _updateVariantAndImages();
                                  });
                                },
                                selectedColor: AppColors.appbarColor,
                                labelStyle: TextStyle(color: isSelected ? Colors.white : AppColors.appbarColor),
                              );
                            }).toList(),
                          ),
                          const SizedBox(height: 15),
                        ],
                      );
                    }),
                    _buildDivider(),
                    const SizedBox(height: 10),
                    Text(_product.description, style: TextStyle(color: Colors.grey[600], height: 1.5)),
                    const SizedBox(height: 20),
                    // Add to Wishlist Button
                    Obx(() {
                      final controller = Get.find<ProductController>();
                      final isWishlisted = controller.wishlistedProductIds.contains(_product.id.trim());
                      return SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          onPressed: () => controller.toggleWishlist(_product),
                          icon: Icon(
                            isWishlisted ? Icons.favorite : Icons.favorite_border,
                            color: isWishlisted ? Colors.red : Colors.white,
                          ),
                          label: Text(
                            isWishlisted ? "Remove from Wishlist" : "Add to Wishlist",
                            style: TextStyle(
                              color: isWishlisted ? Colors.black : Colors.white,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: isWishlisted ? Colors.grey[300] : Colors.brown,
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          ),
                        ),
                      );
                    }),
                    
                    const SizedBox(height: 10),

                    // Price Alert Button
                    OutlinedButton.icon(
                      onPressed: _showPriceAlertSheet,
                      icon: const Icon(Icons.notifications_active, color: Colors.orange),
                      label: const Text(
                        'Notify me when price drops',
                        style: TextStyle(color: Colors.orange),
                      ),
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: Colors.orange),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        minimumSize: const Size(double.infinity, 50),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                    ),
                    const SizedBox(height: 20),
                    const Text('Related Products', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w600)),
                    const SizedBox(height: 10),
                    FutureBuilder<List<Product>>(
                      future: _relatedProductFuture,
                      builder: (context, snapshot) {
                        if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
                        if (snapshot.hasError) return Text("Error: ${snapshot.error}");
                        final products = snapshot.data ?? [];
                        return SizedBox(
                          height: 250,
                          child: ListView.builder(
                            scrollDirection: Axis.horizontal,
                            itemCount: products.length,
                            itemBuilder: (context, index) {
                              final p = products[index];
                              return GestureDetector(
                                onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => ProductDetails(product: p))),
                                child: Container(
                                  width: 160,
                                  margin: const EdgeInsets.only(right: 16),
                                  child: Card(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Expanded(child: Image.network(p.images.isNotEmpty ? p.images[0].url : '', fit: BoxFit.cover)),
                                        Padding(
                                          padding: const EdgeInsets.all(8.0),
                                          child: Text(p.name, maxLines: 1, overflow: TextOverflow.ellipsis),
                                        ),
                                        Padding(
                                          padding: const EdgeInsets.symmetric(horizontal: 8.0),
                                          child: Text('${p.minPrice} MMK', style: const TextStyle(color: AppColors.matchaGreen, fontWeight: FontWeight.bold)),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              );
                            },
                          ),
                        );
                      },
                    ),
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
