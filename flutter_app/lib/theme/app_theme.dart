import 'package:flutter/material.dart';

class AppTheme {
  // HTML/CSS에서 사용하는 색상
  static const Color primaryColor = Color(0xFF667EEA); // #667eea
  static const Color secondaryColor = Color(0xFF764BA2); // #764ba2
  // 기존 프로그램과 동일한 배경색
  static const Color backgroundColor = Color(0xFFF1EFFF); // CSS: #f1efff
  static const Color textPrimary = Color(0xFF333333); // #333
  static const Color textSecondary = Color(0xFF666666); // #666
  static const Color textTertiary = Color(0xFF999999); // #999
  static const Color cardBackground = Colors.white;
  static const Color errorColor = Color(0xFFE74C3C); // #e74c3c
  static const Color likeColor = Color(0xFFFF6B6B); // #ff6b6b

  // 그라데이션 (CSS: linear-gradient(135deg, #667eea 0%, #764ba2 100%))
  static LinearGradient get primaryGradient => const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [primaryColor, secondaryColor],
      );

  static ThemeData get lightTheme {
    final colorScheme = ColorScheme.fromSeed(
      seedColor: primaryColor,
      brightness: Brightness.light,
    ).copyWith(
      primary: primaryColor,
      secondary: secondaryColor,
      error: errorColor,
      surface: cardBackground,
    );

    return ThemeData(
      useMaterial3: true,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: backgroundColor,
      // 플랫폼 기본 폰트 사용 (Android/Windows에서 더 자연스러움)
      
      // AppBar 테마
      appBarTheme: AppBarTheme(
        backgroundColor: Colors.white.withOpacity(0.95),
        foregroundColor: textPrimary,
        elevation: 0,
        scrolledUnderElevation: 2,
        shadowColor: Colors.black.withOpacity(0.12),
      ),

      // 카드 테마
      cardTheme: CardTheme(
        color: cardBackground,
        elevation: 0,
        shadowColor: Colors.black.withOpacity(0.08),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        margin: const EdgeInsets.symmetric(vertical: 8),
      ),

      // 입력 필드 테마
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: const Color(0xFFFFFFFF),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFFE6E8F0), width: 1),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFFE6E8F0), width: 1),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: primaryColor, width: 1.6),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: errorColor, width: 1.6),
        ),
        labelStyle: const TextStyle(
          color: textPrimary,
          fontWeight: FontWeight.w600,
        ),
        hintStyle: const TextStyle(color: textTertiary),
      ),

      // 버튼 테마
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primaryColor,
          foregroundColor: Colors.white,
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          textStyle: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),

      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: primaryColor,
          textStyle: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w500,
          ),
        ),
      ),

      // 탭 바 테마
      tabBarTheme: const TabBarTheme(
        labelColor: primaryColor,
        unselectedLabelColor: textSecondary,
        labelStyle: TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w600,
          fontFamily: 'Segoe UI',
        ),
        unselectedLabelStyle: TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w500,
          fontFamily: 'Segoe UI',
        ),
        indicator: UnderlineTabIndicator(
          borderSide: BorderSide(width: 3, color: primaryColor),
        ),
      ),

      // Bottom Navigation Bar 테마
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor: Colors.white,
        selectedItemColor: primaryColor,
        unselectedItemColor: textTertiary,
        selectedLabelStyle: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
        unselectedLabelStyle: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w500,
        ),
        elevation: 8,
        type: BottomNavigationBarType.fixed,
      ),

      // 텍스트 테마
      textTheme: ThemeData.light(useMaterial3: true).textTheme.copyWith(
            titleLarge: const TextStyle(
              color: textPrimary,
              fontSize: 20,
              fontWeight: FontWeight.w700,
            ),
            titleMedium: const TextStyle(
              color: textPrimary,
              fontSize: 16,
              fontWeight: FontWeight.w700,
            ),
            bodyMedium: const TextStyle(
              color: textPrimary,
              fontSize: 14,
            ),
            bodySmall: const TextStyle(
              color: textSecondary,
              fontSize: 12,
            ),
          ),
    );
  }

  // 그라데이션 버튼 스타일 (CSS 스타일과 동일)
  static BoxDecoration get gradientButtonDecoration => BoxDecoration(
        gradient: primaryGradient,
        borderRadius: BorderRadius.circular(25),
        boxShadow: [
          BoxShadow(
            color: primaryColor.withOpacity(0.4),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      );

  // 카드 스타일 (CSS: box-shadow: 0 4px 6px rgba(0, 0, 0, 0.1))
  static BoxDecoration get cardDecoration => BoxDecoration(
        color: cardBackground,
        borderRadius: BorderRadius.circular(15),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 12,
            offset: Offset.zero,
          ),
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 6,
            offset: const Offset(2, 2),
          ),
        ],
      );
}

