import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

/// 상단 프로필 아이콘 스타일(화이트 원형 + 입체 그림자 + 보라색 person 아이콘)을
/// 앱 전체에서 재사용하기 위한 위젯.
class AppProfileIcon extends StatelessWidget {
  final double size;
  final double? iconSize;
  final bool flat; // 입체감 제거 옵션 (게시물 카드용)

  const AppProfileIcon({
    super.key,
    this.size = 44,
    this.iconSize,
    this.flat = false, // 기본값은 입체감 있음
  });

  @override
  Widget build(BuildContext context) {
    final resolvedIconSize = iconSize ?? (size * 0.6);

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: Colors.white,
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white, width: 2),
        boxShadow: flat
            ? [] // 입체감 제거 (게시물 카드용)
            : [
                // 입체감 있음 (상단 네비게이션, 마이페이지용)
                BoxShadow(
                  color: Colors.black.withOpacity(0.12),
                  blurRadius: 8,
                  offset: const Offset(0, 3),
                ),
                BoxShadow(
                  color: Colors.white.withOpacity(0.7),
                  blurRadius: 2,
                  offset: const Offset(0, -1),
                ),
              ],
      ),
      child: Center(
        child: Icon(
          Icons.person,
          color: AppTheme.primaryColor,
          size: resolvedIconSize,
        ),
      ),
    );
  }
}


