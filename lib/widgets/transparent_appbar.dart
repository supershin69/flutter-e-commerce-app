import 'package:e_commerce_frontend/utils/colors.dart';
import 'package:flutter/material.dart';

class TransparentAppbar extends StatelessWidget implements PreferredSizeWidget {
  final bool isWishlisted;
  final VoidCallback onWishlistToggle;

  const TransparentAppbar({
    super.key,
    required this.isWishlisted,
    required this.onWishlistToggle,
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
            IconButton(
              onPressed: onWishlistToggle,
              icon: Icon(
                isWishlisted ? Icons.favorite : Icons.favorite_border,
                color: isWishlisted ? Colors.red : AppColors.appbarColor,
              ),
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