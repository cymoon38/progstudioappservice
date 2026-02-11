import 'dart:ui';

import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

class CustomBottomNavbar extends StatelessWidget {
  final int currentIndex;
  final Function(int) onTap;

  const CustomBottomNavbar({
    super.key,
    required this.currentIndex,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ClipRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10), // CSS: backdrop-filter: blur(10px)
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.95), // CSS: rgba(255, 255, 255, 0.95)
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.1),
                blurRadius: 10,
                offset: const Offset(0, -2),
              ),
            ],
            border: Border(
              top: BorderSide(
                color: Colors.black.withOpacity(0.1),
                width: 1,
              ),
            ),
          ),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 0, vertical: 8), // CSS: padding: 0.5rem 0
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _BottomNavItem(
                  icon: Icons.home,
                  activeIcon: Icons.home,
                  label: '홈',
                  isActive: currentIndex == 0,
                  onTap: () => onTap(0),
                ),
                _BottomNavItemWithImage(
                  imagePath: 'assets/icons/star.png',
                  label: '인기작품',
                  isActive: currentIndex == 1,
                  onTap: () => onTap(1),
                ),
                _BottomNavItem(
                  icon: Icons.assignment,
                  activeIcon: Icons.assignment,
                  label: '미션',
                  isActive: currentIndex == 2,
                  onTap: () => onTap(2),
                ),
                _BottomNavItem(
                  icon: Icons.shopping_cart,
                  activeIcon: Icons.shopping_cart,
                  label: '스토어',
                  isActive: currentIndex == 3,
                  onTap: () => onTap(3),
                ),
              ],
            ),
            ),
        ),
      ),
    );
  }
}

class _BottomNavItem extends StatelessWidget {
  final IconData icon;
  final IconData activeIcon;
  final String label;
  final bool isActive;
  final VoidCallback onTap;

  const _BottomNavItem({
    required this.icon,
    required this.activeIcon,
    required this.label,
    required this.isActive,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(14),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6), // CSS: padding: 0.5rem (약간 줄임)
            child: Column(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                AnimatedScale(
                  scale: isActive ? 1.1 : 1.0, // CSS: transform: scale(1.1)
                  duration: const Duration(milliseconds: 200), // CSS: transition: all 0.2s
                  child: Icon(
                    isActive ? activeIcon : icon,
                    color: isActive ? AppTheme.primaryColor : const Color(0xFF999999), // CSS: #999
                    size: 24, // CSS: width: 24px, height: 24px
                  ),
                ),
                const SizedBox(height: 3), // CSS: gap: 0.25rem (약간 줄임)
                Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 11.2, // CSS: font-size: 0.7rem ≈ 11.2px
                    height: 1.1, // 약간 여유 공간
                    fontWeight: FontWeight.w600, // CSS: font-weight: 600
                    color: isActive ? AppTheme.primaryColor : const Color(0xFF999999), // CSS: #999
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// PNG 이미지를 사용하는 인기작품 버튼
class _BottomNavItemWithImage extends StatelessWidget {
  final String imagePath;
  final String label;
  final bool isActive;
  final VoidCallback onTap;

  const _BottomNavItemWithImage({
    required this.imagePath,
    required this.label,
    required this.isActive,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(14),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6), // CSS: padding: 0.5rem (약간 줄임)
            child: Column(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                AnimatedScale(
                  scale: isActive ? 1.1 : 1.0, // CSS: transform: scale(1.1)
                  duration: const Duration(milliseconds: 200), // CSS: transition: all 0.2s
                  child: Image.asset(
                    imagePath,
                    width: 24,
                    height: 24,
                    color: isActive ? AppTheme.primaryColor : const Color(0xFF999999), // CSS: #999
                    errorBuilder: (context, error, stackTrace) => Icon(
                      isActive ? Icons.star : Icons.star_outline,
                      color: isActive ? AppTheme.primaryColor : const Color(0xFF999999),
                      size: 24,
                    ),
                  ),
                ),
                const SizedBox(height: 3), // CSS: gap: 0.25rem (약간 줄임)
                Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 11.2, // CSS: font-size: 0.7rem ≈ 11.2px
                    height: 1.1, // 약간 여유 공간
                    fontWeight: FontWeight.w600, // CSS: font-weight: 600
                    color: isActive ? AppTheme.primaryColor : const Color(0xFF999999), // CSS: #999
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

