import 'package:flutter/material.dart';

/// キソウ "soft clay" design system.
///
/// The palette is pulled from the 3D clay clothing icons so the whole UI reads
/// as one piece: sky blue (tops), warm sand (bottoms) and warm orange (outers)
/// over a warm off-white canvas, with generous rounding and soft shadows.
class KisouTheme {
  const KisouTheme._();

  // Canvas & surfaces
  static const Color sand = Color(0xFFFBF7F0); // warm app background
  static const Color surface = Colors.white; // cards
  static const Color cloudWhite = sand; // kept for backwards-compat

  // Brand / accents (matched to the icon backgrounds)
  static const Color skyBlue = Color(0xFF6BB7EC); // top icon background
  static const Color deepSky = Color(0xFF2E7CB0); // primary text/button
  static const Color topBlue = Color(0xFF6BB7EC);
  static const Color bottomSand = Color(0xFFF4E3BE);
  static const Color outerOrange = Color(0xFFF39950);

  // Warm / cool temperature accents
  static const Color warm = Color(0xFFE8804B);
  static const Color cool = Color(0xFF3E8FCB);

  // Ink & lines (warm neutrals for a clay feel)
  static const Color ink = Color(0xFF2C2622);
  static const Color softInk = Color(0xFF837A70);
  static const Color hairline = Color(0xFFEDE6DA);
  static const Color mistGray = hairline; // kept for backwards-compat

  // Rounding tokens
  static const double rSm = 16;
  static const double rMd = 22;
  static const double rLg = 28;

  /// Soft, slightly warm shadow used on clay cards and icon tiles.
  static const List<BoxShadow> softShadow = [
    BoxShadow(color: Color(0x0D2C2622), blurRadius: 2, offset: Offset(0, 1)),
    BoxShadow(color: Color(0x14B0925E), blurRadius: 28, offset: Offset(0, 12)),
  ];

  /// Lighter shadow for smaller elements (icon tiles, chips).
  static const List<BoxShadow> tileShadow = [
    BoxShadow(color: Color(0x12A8895A), blurRadius: 14, offset: Offset(0, 6)),
  ];

  /// Colors for the 7-step comfort feeling headline (hot → cold).
  static const Map<String, Color> feelingColors = {
    'VERY_HOT': Color(0xFFE8623A),
    'HOT': Color(0xFFF0894C),
    'WARM': Color(0xFFF2B45C),
    'PERFECT': Color(0xFF6FBF73),
    'COOL': Color(0xFF5FB0D9),
    'COLD': Color(0xFF3E8FCB),
    'VERY_COLD': Color(0xFF2E6FB0),
  };

  static Color feelingColor(String code) =>
      feelingColors[code] ?? deepSky;

  static ThemeData light() {
    const textTheme = TextTheme(
      displaySmall: TextStyle(
        fontSize: 36,
        fontWeight: FontWeight.w800,
        color: ink,
        height: 1.15,
        letterSpacing: -0.5,
        fontFamilyFallback: _fontFallback,
      ),
      headlineSmall: TextStyle(
        fontSize: 25,
        fontWeight: FontWeight.w800,
        color: ink,
        height: 1.3,
        letterSpacing: -0.3,
        fontFamilyFallback: _fontFallback,
      ),
      titleMedium: TextStyle(
        fontSize: 18,
        fontWeight: FontWeight.w700,
        color: ink,
        height: 1.4,
        fontFamilyFallback: _fontFallback,
      ),
      bodyMedium: TextStyle(
        fontSize: 16,
        fontWeight: FontWeight.w400,
        color: ink,
        height: 1.55,
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
        fontWeight: FontWeight.w700,
        color: ink,
        height: 1.3,
        fontFamilyFallback: _fontFallback,
      ),
    );

    final colorScheme =
        ColorScheme.fromSeed(
          seedColor: skyBlue,
          brightness: Brightness.light,
          primary: deepSky,
          surface: surface,
        ).copyWith(
          onSurface: ink,
          surfaceContainerHighest: sand,
        );

    return ThemeData(
      useMaterial3: true,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: sand,
      textTheme: textTheme,
      splashFactory: InkRipple.splashFactory,
      appBarTheme: const AppBarTheme(
        backgroundColor: sand,
        foregroundColor: ink,
        centerTitle: true,
        elevation: 0,
        scrolledUnderElevation: 0,
      ),
      cardTheme: CardThemeData(
        color: surface,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(rMd),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: deepSky,
          foregroundColor: Colors.white,
          minimumSize: const Size.fromHeight(54),
          elevation: 0,
          shape: const StadiumBorder(),
          textStyle: textTheme.labelLarge,
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: ink,
          backgroundColor: surface,
          minimumSize: const Size.fromHeight(54),
          side: const BorderSide(color: hairline),
          shape: const StadiumBorder(),
          textStyle: textTheme.labelLarge,
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: deepSky,
          textStyle: textTheme.labelLarge,
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: surface,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 18,
          vertical: 16,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(rSm),
          borderSide: const BorderSide(color: hairline),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(rSm),
          borderSide: const BorderSide(color: hairline),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(rSm),
          borderSide: const BorderSide(color: deepSky, width: 1.5),
        ),
      ),
      dividerTheme: const DividerThemeData(
        color: hairline,
        thickness: 1,
        space: 1,
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: sand,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(rLg)),
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: ink,
        contentTextStyle: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.w600,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(rSm),
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

/// A reusable soft "clay" card: rounded white surface with a warm soft shadow.
class ClayCard extends StatelessWidget {
  const ClayCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(20),
    this.radius = KisouTheme.rLg,
    this.color = KisouTheme.surface,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final double radius;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(radius),
        boxShadow: KisouTheme.softShadow,
      ),
      child: Padding(padding: padding, child: child),
    );
  }
}
