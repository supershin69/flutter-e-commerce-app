import 'package:e_commerce_frontend/utils/colors.dart';
import 'package:flutter/material.dart';

class TransparentAppbar extends StatelessWidget implements PreferredSizeWidget {
  final bool isWishlisted;
  final VoidCallback onWishlistToggle;
  final int cartCount; // Added this

  const TransparentAppbar({
    super.key,
    required this.isWishlisted,
    required this.onWishlistToggle,
    this.cartCount = 0, // Default to 0
  });

  @override
  Size get preferredSize => const Size.fromHeight(56);

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      bottom: false,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            _CircleButton(
              icon: Icons.chevron_left,
              onTap: () => Navigator.pop(context),
            ),
            Row(
              children: [
                IconButton(
                  onPressed: onWishlistToggle,
                  icon: Icon(
                    isWishlisted ? Icons.favorite : Icons.favorite_border,
                    color: isWishlisted ? Colors.red : AppColors.appbarColor,
                  ),
                ),
                const SizedBox(width: 8),
                // Cart Button with Badge
                Stack(
                  children: [
                    _CircleButton(
                      icon: Icons.shopping_cart,
                      onTap: () {
                         // Navigate to Cart Page
                      },
                    ),
                    if (cartCount > 0)
                      Positioned(
                        right: 0,
                        top: 0,
                        child: Container(
                          padding: const EdgeInsets.all(4),
                          decoration: const BoxDecoration(
                            color: Colors.red,
                            shape: BoxShape.circle,
                          ),
                          child: Text(
                            cartCount > 9 ? '9+' : cartCount.toString(),
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                  ],
                )
              ],
            )
          ],
        ),
      ),
    );
  }
}

class _CircleButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;

  const _CircleButton({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.appbarColor.withOpacity(0.8), // Added opacity for better visibility on images
      shape: const CircleBorder(),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(10),
          child: Icon(icon, color: Colors.white, size: 20),
        ),
      ),
    );
  }
}