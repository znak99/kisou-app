import 'dart:ui';

import 'package:flutter/material.dart';

/// Whether the platform's effective body-text scale needs a reflow layout.
///
/// Android 14+ uses nonlinear font scaling, so measuring `scale(1)` can report
/// 1.0 even when the user selected 200%. A representative 14sp body size
/// correctly reflects the effective scale on both linear and nonlinear
/// platforms.
bool usesLargeText(BuildContext context, {double threshold = 1.3}) {
  const referenceFontSize = 14.0;
  final scaled = MediaQuery.textScalerOf(context).scale(referenceFontSize);
  return scaled / referenceFontSize > threshold;
}

/// キソウ v2 design system.
///
/// Modern light/dark theme: near-white off-white canvas, an indigo→violet
/// accent gradient (no more navy), gradient + glassmorphism accents, and a
/// compact spacing scale. Theme-dependent colors live in the [KisouColors]
/// extension so widgets adapt to dark mode via `context.kisou`.
class KisouTheme {
  const KisouTheme._();

  // --- Modern accent (shared across light/dark) ---
  // Light-mode primary: 5.7:1 against white, so it is safe for small text.
  // Dark surfaces use the brighter theme-dependent `context.kisou.accent`.
  static const Color accent = Color(0xFF4C5BCC); // indigo
  static const Color accentAlt = Color(0xFF7551B9); // violet
  static const LinearGradient accentGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [accent, accentAlt],
  );

  // Backwards-compatible aliases (repointed to the new accent so existing
  // references pick up the modern color automatically).
  static const Color deepSky = accent;
  static const Color skyBlue = accent;
  static const Color topBlue = Color(0xFF6BB7EC);
  static const Color bottomSand = Color(0xFFF4E3BE);
  static const Color outerOrange = Color(0xFFF39950);
  static const Color warm = Color(0xFFC24A1A);
  static const Color cool = Color(0xFF2F67B2);

  // Light-mode neutral aliases (kept for un-migrated call sites).
  static const Color sand = Color(0xFFF8F9FA);
  static const Color surface = Colors.white;
  static const Color cloudWhite = sand;
  static const Color ink = Color(0xFF1A1B1E);
  static const Color softInk = Color(0xFF6B7280);
  static const Color hairline = Color(0xFFE8EAED);
  static const Color mistGray = hairline;

  // --- Compact spacing (≈20% tighter than v1) ---
  static const double pagePad = 16;
  static const double cardPad = 16;
  static const double gapXs = 5;
  static const double gapS = 8;
  static const double gapM = 12;
  static const double gapL = 16;
  static const double gapXl = 20;

  // Rounding tokens
  static const double rSm = 14;
  static const double rMd = 18;
  static const double rLg = 24;

  static const List<BoxShadow> softShadow = [
    BoxShadow(color: Color(0x0D000000), blurRadius: 2, offset: Offset(0, 1)),
    BoxShadow(color: Color(0x14000000), blurRadius: 22, offset: Offset(0, 10)),
  ];
  static const List<BoxShadow> tileShadow = [
    BoxShadow(color: Color(0x12000000), blurRadius: 12, offset: Offset(0, 5)),
  ];

  /// 7-step comfort feeling colors (hot → cold), theme-independent.
  static const Map<String, Color> feelingColors = {
    'VERY_HOT': Color(0xFFF0533A),
    'HOT': Color(0xFFF47B44),
    'WARM': Color(0xFFF3A64C),
    'PERFECT': Color(0xFF4FC08A),
    'COOL': Color(0xFF44B6DE),
    'COLD': Color(0xFF4F86E8),
    'VERY_COLD': Color(0xFF5B6CF0),
  };

  static Color feelingColor(String code) => feelingColors[code] ?? accent;

  /// All current feeling colors have at least 4.5:1 contrast against black.
  /// Keeping the foreground independent from hue also prevents color-only
  /// status communication.
  static const Color feelingForeground = Colors.black;

  static ThemeData light() => _build(Brightness.light, KisouColors.light);
  static ThemeData dark() => _build(Brightness.dark, KisouColors.dark);

  static ThemeData _build(Brightness brightness, KisouColors colors) {
    final textTheme = _textTheme(colors.ink, colors.softInk);
    final colorScheme =
        ColorScheme.fromSeed(
          seedColor: colors.accent,
          brightness: brightness,
        ).copyWith(
          primary: colors.accent,
          onPrimary: colors.onAccent,
          surface: colors.surface,
          onSurface: colors.ink,
        );

    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: colorScheme,
      materialTapTargetSize: MaterialTapTargetSize.padded,
      visualDensity: VisualDensity.standard,
      scaffoldBackgroundColor: colors.bg,
      textTheme: textTheme,
      splashFactory: InkRipple.splashFactory,
      extensions: [colors],
      appBarTheme: AppBarTheme(
        backgroundColor: colors.bg,
        foregroundColor: colors.ink,
        centerTitle: true,
        elevation: 0,
        scrolledUnderElevation: 0,
      ),
      cardTheme: CardThemeData(
        color: colors.surface,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(rMd)),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: colors.accent,
          foregroundColor: colors.onAccent,
          minimumSize: const Size.fromHeight(48),
          tapTargetSize: MaterialTapTargetSize.padded,
          elevation: 0,
          shape: const StadiumBorder(),
          textStyle: textTheme.labelLarge,
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: colors.ink,
          backgroundColor: colors.surface,
          minimumSize: const Size.fromHeight(48),
          tapTargetSize: MaterialTapTargetSize.padded,
          side: BorderSide(color: colors.hairline),
          shape: const StadiumBorder(),
          textStyle: textTheme.labelLarge,
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: colors.accent,
          minimumSize: const Size(48, 48),
          tapTargetSize: MaterialTapTargetSize.padded,
          textStyle: textTheme.labelLarge,
        ),
      ),
      iconButtonTheme: const IconButtonThemeData(
        style: ButtonStyle(
          minimumSize: WidgetStatePropertyAll(Size.square(48)),
          tapTargetSize: MaterialTapTargetSize.padded,
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: colors.surface,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 14,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(rSm),
          borderSide: BorderSide(color: colors.hairline),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(rSm),
          borderSide: BorderSide(color: colors.hairline),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(rSm),
          borderSide: const BorderSide(color: accent, width: 1.5),
        ),
      ),
      dividerTheme: DividerThemeData(
        color: colors.hairline,
        thickness: 1,
        space: 1,
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: colors.bg,
        surfaceTintColor: Colors.transparent,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(rLg)),
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: colors.ink,
        contentTextStyle: TextStyle(
          color: colors.bg,
          fontWeight: FontWeight.w600,
        ),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(rSm)),
      ),
    );
  }

  static TextTheme _textTheme(Color ink, Color softInk) => TextTheme(
    displaySmall: TextStyle(
      fontSize: 32,
      fontWeight: FontWeight.w800,
      color: ink,
      height: 1.15,
      letterSpacing: -0.5,
      fontFamilyFallback: _fontFallback,
    ),
    headlineSmall: TextStyle(
      fontSize: 22,
      fontWeight: FontWeight.w800,
      color: ink,
      height: 1.3,
      letterSpacing: -0.3,
      fontFamilyFallback: _fontFallback,
    ),
    titleMedium: TextStyle(
      fontSize: 16,
      fontWeight: FontWeight.w700,
      color: ink,
      height: 1.4,
      fontFamilyFallback: _fontFallback,
    ),
    bodyMedium: TextStyle(
      fontSize: 15,
      fontWeight: FontWeight.w400,
      color: ink,
      height: 1.5,
      fontFamilyFallback: _fontFallback,
    ),
    bodySmall: TextStyle(
      fontSize: 13,
      fontWeight: FontWeight.w400,
      color: softInk,
      height: 1.45,
      fontFamilyFallback: _fontFallback,
    ),
    labelLarge: TextStyle(
      fontSize: 15,
      fontWeight: FontWeight.w700,
      color: ink,
      height: 1.3,
      fontFamilyFallback: _fontFallback,
    ),
  );

  static const List<String> _fontFallback = [
    'Hiragino Sans',
    'Hiragino Kaku Gothic ProN',
    'Yu Gothic',
    'Noto Sans CJK JP',
    'sans-serif',
  ];
}

/// Theme-dependent color tokens (light/dark). Read via `context.kisou`.
@immutable
class KisouColors extends ThemeExtension<KisouColors> {
  const KisouColors({
    required this.bg,
    required this.surface,
    required this.surfaceAlt,
    required this.glass,
    required this.glassBorder,
    required this.ink,
    required this.softInk,
    required this.hairline,
  });

  final Color bg;
  final Color surface;
  final Color surfaceAlt;
  final Color glass;
  final Color glassBorder;
  final Color ink;
  final Color softInk;
  final Color hairline;

  bool get _isDark => bg.computeLuminance() < 0.2;

  Color get accent => _isDark ? const Color(0xFF98A2FF) : KisouTheme.accent;
  Color get accentAlt =>
      _isDark ? const Color(0xFFB8A2FF) : KisouTheme.accentAlt;
  Color get onAccent => _isDark ? Colors.black : Colors.white;
  Color get warm => _isDark ? const Color(0xFFFF9B73) : KisouTheme.warm;
  Color get cool => _isDark ? const Color(0xFF84B6FF) : KisouTheme.cool;
  Color get success =>
      _isDark ? const Color(0xFF6DD6A4) : const Color(0xFF287A55);
  LinearGradient get accentGradient => KisouTheme.accentGradient;

  List<BoxShadow> get softShadow => KisouTheme.softShadow;
  List<BoxShadow> get tileShadow => KisouTheme.tileShadow;

  static const light = KisouColors(
    bg: Color(0xFFF8F9FA),
    surface: Colors.white,
    surfaceAlt: Color(0xFFF1F3F5),
    glass: Color(0xCCFFFFFF),
    glassBorder: Color(0x22FFFFFF),
    ink: Color(0xFF1A1B1E),
    softInk: Color(0xFF6B7280),
    hairline: Color(0xFFE8EAED),
  );

  static const dark = KisouColors(
    bg: Color(0xFF0F1114),
    surface: Color(0xFF1A1D22),
    surfaceAlt: Color(0xFF23262D),
    glass: Color(0xCC1A1D22),
    glassBorder: Color(0x22FFFFFF),
    ink: Color(0xFFF3F4F6),
    softInk: Color(0xFF9BA1AC),
    hairline: Color(0xFF2A2E35),
  );

  @override
  KisouColors copyWith({
    Color? bg,
    Color? surface,
    Color? surfaceAlt,
    Color? glass,
    Color? glassBorder,
    Color? ink,
    Color? softInk,
    Color? hairline,
  }) {
    return KisouColors(
      bg: bg ?? this.bg,
      surface: surface ?? this.surface,
      surfaceAlt: surfaceAlt ?? this.surfaceAlt,
      glass: glass ?? this.glass,
      glassBorder: glassBorder ?? this.glassBorder,
      ink: ink ?? this.ink,
      softInk: softInk ?? this.softInk,
      hairline: hairline ?? this.hairline,
    );
  }

  @override
  KisouColors lerp(ThemeExtension<KisouColors>? other, double t) {
    if (other is! KisouColors) return this;
    return KisouColors(
      bg: Color.lerp(bg, other.bg, t)!,
      surface: Color.lerp(surface, other.surface, t)!,
      surfaceAlt: Color.lerp(surfaceAlt, other.surfaceAlt, t)!,
      glass: Color.lerp(glass, other.glass, t)!,
      glassBorder: Color.lerp(glassBorder, other.glassBorder, t)!,
      ink: Color.lerp(ink, other.ink, t)!,
      softInk: Color.lerp(softInk, other.softInk, t)!,
      hairline: Color.lerp(hairline, other.hairline, t)!,
    );
  }
}

extension KisouColorsX on BuildContext {
  KisouColors get kisou =>
      Theme.of(this).extension<KisouColors>() ?? KisouColors.light;
}

/// Soft rounded surface card (dark-aware). Compact padding by default.
class ClayCard extends StatelessWidget {
  const ClayCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(KisouTheme.cardPad),
    this.radius = KisouTheme.rLg,
    this.color,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final double radius;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final c = context.kisou;
    return Container(
      decoration: BoxDecoration(
        color: color ?? c.surface,
        borderRadius: BorderRadius.circular(radius),
        boxShadow: c.softShadow,
        border: Border.all(color: c.hairline.withValues(alpha: 0.6)),
      ),
      child: Padding(padding: padding, child: child),
    );
  }
}

/// Glassmorphism container: blurred translucent surface with a hairline border.
/// Alpha is kept high enough to stay readable over busy backgrounds.
class GlassContainer extends StatelessWidget {
  const GlassContainer({
    super.key,
    required this.child,
    this.padding = EdgeInsets.zero,
    this.radius = KisouTheme.rLg,
    this.blur = 18,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final double radius;
  final double blur;

  @override
  Widget build(BuildContext context) {
    final c = context.kisou;
    return ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: blur, sigmaY: blur),
        child: Container(
          decoration: BoxDecoration(
            color: c.glass,
            borderRadius: BorderRadius.circular(radius),
            border: Border.all(color: c.hairline.withValues(alpha: 0.7)),
          ),
          child: Padding(padding: padding, child: child),
        ),
      ),
    );
  }
}
