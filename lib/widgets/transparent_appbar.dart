import 'package:e_commerce_frontend/utils/colors.dart';
import 'package:flutter/material.dart';

class TransparentAppbar extends StatelessWidget implements PreferredSizeWidget {
  final Widget? trailing;

  const TransparentAppbar({
    super.key,
    this.trailing,
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
            if (trailing != null) trailing!,
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
      color: AppColors.appbarColor.withAlpha(204), // Added opacity for better visibility on images
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
