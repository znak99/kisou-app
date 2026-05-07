import 'package:flutter/material.dart';

class KisouTheme {
  const KisouTheme._();

  static const Color skyBlue = Color(0xFF74BDE8);
  static const Color deepSky = Color(0xFF216B94);
  static const Color cloudWhite = Color(0xFFF7FBFD);
  static const Color mistGray = Color(0xFFE8F0F4);
  static const Color ink = Color(0xFF1F2A30);
  static const Color softInk = Color(0xFF5D6B73);

  static ThemeData light() {
    const textTheme = TextTheme(
      displaySmall: TextStyle(
        fontSize: 34,
        fontWeight: FontWeight.w700,
        color: ink,
        height: 1.2,
        fontFamilyFallback: _fontFallback,
      ),
      headlineSmall: TextStyle(
        fontSize: 24,
        fontWeight: FontWeight.w700,
        color: ink,
        height: 1.3,
        fontFamilyFallback: _fontFallback,
      ),
      titleMedium: TextStyle(
        fontSize: 18,
        fontWeight: FontWeight.w600,
        color: ink,
        height: 1.4,
        fontFamilyFallback: _fontFallback,
      ),
      bodyMedium: TextStyle(
        fontSize: 16,
        fontWeight: FontWeight.w400,
        color: ink,
        height: 1.6,
        fontFamilyFallback: _fontFallback,
      ),
      bodySmall: TextStyle(
        fontSize: 14,
        fontWeight: FontWeight.w400,
        color: softInk,
        height: 1.5,
        fontFamilyFallback: _fontFallback,
      ),
      labelLarge: TextStyle(
        fontSize: 16,
        fontWeight: FontWeight.w600,
        color: ink,
        height: 1.3,
        fontFamilyFallback: _fontFallback,
      ),
    );

    final colorScheme = ColorScheme.fromSeed(
      seedColor: skyBlue,
      brightness: Brightness.light,
      primary: deepSky,
      surface: cloudWhite,
    );

    return ThemeData(
      useMaterial3: true,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: cloudWhite,
      textTheme: textTheme,
      appBarTheme: const AppBarTheme(
        backgroundColor: cloudWhite,
        foregroundColor: ink,
        centerTitle: true,
        elevation: 0,
      ),
      cardTheme: const CardThemeData(
        color: Colors.white,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(8)),
          side: BorderSide(color: mistGray),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: deepSky,
          foregroundColor: Colors.white,
          minimumSize: const Size.fromHeight(48),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          textStyle: textTheme.labelLarge,
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colors.white,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 14,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: mistGray),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: mistGray),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: deepSky, width: 1.5),
        ),
      ),
    );
  }

  static const List<String> _fontFallback = [
    'Hiragino Sans',
    'Hiragino Kaku Gothic ProN',
    'Yu Gothic',
    'Noto Sans CJK JP',
    'sans-serif',
  ];
}
