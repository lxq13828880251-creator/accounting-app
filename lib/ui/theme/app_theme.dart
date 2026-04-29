import 'package:flutter/material.dart';

/// 小红书风格配色
class XHSColors {
  // 主色：珊瑚粉橙
  static const Color primary = Color(0xFFFF6B6B);
  static const Color primaryLight = Color(0xFFFF8C8C);
  static const Color primaryDark = Color(0xFFE85555);

  // 背景色：奶油白
  static const Color background = Color(0xFFFFF8F5);
  static const Color surface = Color(0xFFFFFFFF);

  // 渐变色
  static const Color gradientStart = Color(0xFFFF8C8C);
  static const Color gradientEnd = Color(0xFFFF6B6B);

  // 收入/支出
  static const Color income = Color(0xFF4CAF50);
  static const Color expense = Color(0xFFFF6B6B);

  // 文字色
  static const Color textPrimary = Color(0xFF2D2D2D);
  static const Color textSecondary = Color(0xFF8E8E8E);
  static const Color textHint = Color(0xFFBDBDBD);

  // 卡片
  static const Color cardBorder = Color(0xFFF5F0EB);
  static const Color cardShadow = Color(0x0A000000);

  // 标签色
  static const Color tagPeach = Color(0xFFFFE8E8);
  static const Color tagMint = Color(0xFFE8F8F0);
  static const Color tagLavender = Color(0xFFF0E8FF);
}

/// App主题配置
class AppTheme {
  static const double _radiusSmall = 12.0;
  static const double _radiusMedium = 16.0;
  static const double _radiusLarge = 24.0;

  static ThemeData get lightTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      scaffoldBackgroundColor: XHSColors.background,
      colorScheme: ColorScheme.fromSeed(
        seedColor: XHSColors.primary,
        brightness: Brightness.light,
        primary: XHSColors.primary,
        onPrimary: Colors.white,
        secondary: XHSColors.primaryLight,
        surface: XHSColors.surface,
        onSurface: XHSColors.textPrimary,
        error: XHSColors.expense,
      ),
      appBarTheme: const AppBarTheme(
        centerTitle: true,
        elevation: 0,
        scrolledUnderElevation: 0,
        backgroundColor: XHSColors.background,
        foregroundColor: XHSColors.textPrimary,
        titleTextStyle: TextStyle(
          color: XHSColors.textPrimary,
          fontSize: 17,
          fontWeight: FontWeight.w600,
        ),
      ),
      cardTheme: CardTheme(
        elevation: 0,
        color: XHSColors.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(_radiusLarge),
          side: const BorderSide(color: XHSColors.cardBorder, width: 1),
        ),
        margin: EdgeInsets.zero,
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: XHSColors.primary,
          foregroundColor: Colors.white,
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(_radiusMedium)),
          textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: XHSColors.primary,
          side: const BorderSide(color: XHSColors.primary, width: 1.5),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(_radiusMedium)),
          textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: XHSColors.primary,
          textStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: XHSColors.surface,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(_radiusMedium),
          borderSide: const BorderSide(color: XHSColors.cardBorder),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(_radiusMedium),
          borderSide: const BorderSide(color: XHSColors.cardBorder),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(_radiusMedium),
          borderSide: const BorderSide(color: XHSColors.primary, width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(_radiusMedium),
          borderSide: const BorderSide(color: XHSColors.expense),
        ),
        labelStyle: const TextStyle(color: XHSColors.textSecondary, fontSize: 14),
        hintStyle: const TextStyle(color: XHSColors.textHint, fontSize: 14),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: XHSColors.primary,
          foregroundColor: Colors.white,
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(_radiusMedium)),
          textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: XHSColors.surface,
        elevation: 0,
        height: 72,
        indicatorColor: XHSColors.tagPeach,
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
        iconTheme: MaterialStateProperty.resolveWith((states) {
          if (states.contains(MaterialState.selected)) {
            return const IconThemeData(color: XHSColors.primary, size: 24);
          }
          return const IconThemeData(color: XHSColors.textSecondary, size: 24);
        }),
        labelTextStyle: MaterialStateProperty.resolveWith((states) {
          if (states.contains(MaterialState.selected)) {
            return const TextStyle(color: XHSColors.primary, fontSize: 11, fontWeight: FontWeight.w600);
          }
          return const TextStyle(color: XHSColors.textSecondary, fontSize: 11);
        }),
      ),
      dividerTheme: const DividerThemeData(
        color: XHSColors.cardBorder,
        thickness: 1,
        space: 1,
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: XHSColors.textPrimary,
        contentTextStyle: const TextStyle(color: Colors.white, fontSize: 14),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(_radiusSmall)),
        behavior: SnackBarBehavior.floating,
      ),
      dialogTheme: DialogTheme(
        backgroundColor: XHSColors.surface,
        elevation: 8,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(_radiusLarge)),
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: XHSColors.surface,
        elevation: 8,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(_radiusLarge)),
        ),
      ),
    );
  }

  static ThemeData get darkTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      scaffoldBackgroundColor: const Color(0xFF1A1A1A),
      colorScheme: ColorScheme.fromSeed(
        seedColor: XHSColors.primary,
        brightness: Brightness.dark,
        primary: XHSColors.primaryLight,
        onPrimary: Colors.white,
        secondary: XHSColors.primary,
        surface: const Color(0xFF2A2A2A),
        onSurface: Colors.white,
        error: XHSColors.expense,
      ),
      appBarTheme: const AppBarTheme(
        centerTitle: true,
        elevation: 0,
        backgroundColor: Color(0xFF1A1A1A),
        foregroundColor: Colors.white,
      ),
      cardTheme: CardTheme(
        elevation: 0,
        color: const Color(0xFF2A2A2A),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(_radiusLarge),
          side: BorderSide(color: Colors.white.withOpacity(0.08)),
        ),
      ),
    );
  }
}
