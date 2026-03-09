import 'package:e_commerce_frontend/features/shop/controllers/product_controller.dart';
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
                        : Image.network(
                            imageUrl,
                            fit: BoxFit.cover,
                            errorBuilder: (context, error, stackTrace) {
                              return Container(
                                color: Colors.grey[100],
                                child: const Center(
                                  child: Icon(
                                    Icons.image_not_supported,
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
            Positioned(
              bottom: 55,
              right: 8,
              child: GestureDetector(
                onTap: () async {
                   try {
                     final cartItem = CartItem(
                       id: DateTime.now().millisecondsSinceEpoch.toString(),
                       productId: product.id,
                       productName: product.name,
                       variantId: product.variants.isNotEmpty ? product.variants.first.id : '',
                       variantName: product.variants.isNotEmpty ? product.variants.first.attributes.map((a) => a.value).join(', ') : null,
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
                    color: Colors.grey[200],
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
                    Icons.add,
                    color: Colors.grey[800],
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
