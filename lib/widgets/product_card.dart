import 'package:e_commerce_frontend/features/shop/controllers/product_controller.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import '../models/product_model.dart';
import '../models/cart_item_model.dart';
import '../services/cart_service.dart';
import '../utils/colors.dart';
import '../screens/product_detail_page.dart';

class ProductCard extends StatelessWidget {
  final Product product;
  final double? width;
  final double? height;

  const ProductCard({
    super.key,
    required this.product,
    this.width,
    this.height,
  });

  String _formatPrice(double value) {
    final formatter = NumberFormat.decimalPattern();
    return '${formatter.format(value.round())} MMK';
  }

  @override
  Widget build(BuildContext context) {
    final imageUrl = product.imageUrl;
    final hasVariants = product.variants.isNotEmpty;
    final hasMultipleVariants = product.variants.length > 1;
    final needsVariantSelection = !hasVariants || hasMultipleVariants;
    
    return GestureDetector(
      onTap: () {
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (context) => ProductDetails(product: product),
          ),
        );
      },
      child: Container(
        width: width,
        height: height,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          color: Colors.white,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withAlpha(25),
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Stack(
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(
                  child: ClipRRect(
                    borderRadius: const BorderRadius.vertical(
                      top: Radius.circular(16),
                    ),
                    child: imageUrl.isEmpty
                        ? Container(
                            color: Colors.grey[100],
                            child: const Center(
                              child: Icon(
                                Icons.image_not_supported,
                                color: Colors.grey,
                              ),
                            ),
                          )
                        : CachedNetworkImage(
                            imageUrl: imageUrl,
                            fit: BoxFit.cover,
                            placeholder: (context, url) {
                              return Container(
                                color: Colors.grey[100],
                                child: const Center(
                                  child: SizedBox(
                                    width: 18,
                                    height: 18,
                                    child: CircularProgressIndicator(strokeWidth: 2),
                                  ),
                                ),
                              );
                            },
                            errorWidget: (context, url, error) {
                              return Container(
                                color: Colors.grey[100],
                                child: const Center(
                                  child: Icon(
                                    Icons.broken_image_outlined,
                                    color: Colors.grey,
                                  ),
                                ),
                              );
                            },
                          ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(12.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        product.name,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                          color: AppColors.textDark,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      // Use Obx to listen to real-time price changes
                      Obx(() {
                        final controller = Get.find<ProductController>();
                        // Get current price from controller (real-time or initial)
                        final currentPrice = controller.getPrice(product.id, product.displayPrice);
                        
                        return Text(
                          '${NumberFormat.decimalPattern().format(currentPrice)} MMK',
                          style: const TextStyle(
                            color: AppColors.matchaGreen,
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
                        );
                      }),
                      const SizedBox(height: 8),
                    ],
                  ),
                ),
              ],
            ),
            if (product.discount > 0)
              Positioned(
                top: 8,
                left: 8,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.yellow[700],
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    '${product.discount.toInt()}% OFF',
                    style: const TextStyle(
                      color: Colors.black,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            if (needsVariantSelection)
              Positioned(
                top: 8,
                right: 8,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.black.withAlpha(153),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    hasVariants ? 'Select variant' : 'View options',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            Positioned(
              bottom: 55,
              right: 8,
              child: GestureDetector(
                onTap: () async {
                   try {
                     if (needsVariantSelection) {
                       if (context.mounted) {
                         ScaffoldMessenger.of(context).showSnackBar(
                           SnackBar(
                             content: Text(hasVariants ? 'Please select a variant first' : 'Open the product to view options'),
                             duration: const Duration(seconds: 1),
                           ),
                         );
                       }
                       if (!context.mounted) return;
                       Navigator.of(context).push(
                         MaterialPageRoute(
                           builder: (context) => ProductDetails(product: product),
                         ),
                       );
                       return;
                     }
                     final cartItem = CartItem(
                       id: DateTime.now().millisecondsSinceEpoch.toString(),
                       productId: product.id,
                       productName: product.name,
                       variantId: product.variants.first.id,
                       variantName: product.variants.first.attributes.map((a) => a.value).join(', '),
                       price: product.displayPrice.toInt(),
                       quantity: 1,
                       imageUrl: imageUrl,
                       brandName: product.brandName,
                       categoryName: product.categoryName,
                     );
                     
                     final cartService = CartService();
                     final success = await cartService.addToCart(cartItem);
                     
                     if (context.mounted) {
                       ScaffoldMessenger.of(context).showSnackBar(
                         SnackBar(
                           content: Text(success ? 'Added to Cart' : 'Failed to add to cart'),
                           duration: const Duration(seconds: 1),
                           backgroundColor: success ? Colors.green : Colors.red,
                         ),
                       );
                     }
                   } catch (e) {
                     debugPrint('Error adding to cart: $e');
                   }
                },
                child: Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: needsVariantSelection ? Colors.brown.shade300 : Colors.grey[200],
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withAlpha(25),
                        blurRadius: 4,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Icon(
                    needsVariantSelection ? Icons.tune : Icons.add,
                    color: needsVariantSelection ? Colors.white : Colors.grey[800],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
