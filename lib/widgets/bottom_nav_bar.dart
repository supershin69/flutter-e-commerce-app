import 'dart:ui';
import 'package:flutter/material.dart';

class AppBottomNavBar extends StatelessWidget {
  final int currentIndex;
  final ValueChanged<int> onTap;

  const AppBottomNavBar({
    super.key,
    required this.currentIndex,
    required this.onTap,
  });

  static const _items = [
    (Icons.home, 'Home'),
    (Icons.shopping_cart, 'Products'),
    (Icons.notifications, 'Notification'),
    (Icons.person, 'Profile'),
  ];

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(18, 0, 18, 14), // floating spacing
        child: ClipRRect(
          borderRadius: BorderRadius.circular(28), // pill shape
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 22, sigmaY: 22), // glass blur
            child: Container(
              height: 70,
              padding: const EdgeInsets.symmetric(horizontal: 8),
              decoration: BoxDecoration(
                color: Colors.brown.shade300.withOpacity(0.35), // glass tint
                borderRadius: BorderRadius.circular(28),
                border: Border.all(color: Colors.white.withOpacity(0.12)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.35),
                    blurRadius: 24,
                    offset: const Offset(0, 10), // lift / floating shadow
                  ),
                ],
              ),
              child: Row(
                children: List.generate(_items.length, (i) {
                  final active = i == currentIndex;
                  final (icon, label) = _items[i];

                  return Expanded(
                    child: InkWell(
                      onTap: () => onTap(i),
                      splashColor: Colors.transparent,
                      highlightColor: Colors.transparent,
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        curve: Curves.easeOut,
                        height: 54,
                        margin: const EdgeInsets.symmetric(horizontal: 6),
                        decoration: BoxDecoration(
                          color: active
                              ? Colors.white.withOpacity(0.14)
                              : Colors.transparent, // selected bubble
                          borderRadius: BorderRadius.circular(18),
                          border: active
                              ? Border.all(color: Colors.white.withOpacity(0.18))
                              : null,
                        ),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              icon,
                              size: active ? 28 : 26,
                              color: active ? Colors.brown.shade500 : Colors.white70,
                            ),
                            const SizedBox(height: 4),
                            Text(
                              label,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: active
                                    ? FontWeight.w700
                                    : FontWeight.w500,
                                color: active ? Colors.black : Colors.white70,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                }),
              ),
            ),
          ),
        ),
      ),
    );
  }
}