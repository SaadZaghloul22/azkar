import 'package:flutter/material.dart';

/// Visual identity: emerald green + gold on off-white; dark green at night.
class AppColors {
  static const emerald = Color(0xFF0E6B4E);
  static const emeraldDark = Color(0xFF0A5139);
  static const emeraldLight = Color(0xFF2E9C74);
  static const gold = Color(0xFFC9A227);
  static const goldSoft = Color(0xFFE9D79A);
  static const offWhite = Color(0xFFF7F4EC);
  static const ink = Color(0xFF1B2A23);
  static const nightBg = Color(0xFF0A1C15);
  static const nightSurface = Color(0xFF11291F);
  static const nightSurfaceHigh = Color(0xFF183528);
  static const nightInk = Color(0xFFEDE8DA);
}

class AppTheme {
  static ThemeData light() {
    final scheme = ColorScheme.fromSeed(
      seedColor: AppColors.emerald,
      brightness: Brightness.light,
    ).copyWith(
      primary: AppColors.emerald,
      onPrimary: Colors.white,
      secondary: AppColors.gold,
      onSecondary: AppColors.ink,
      surface: Colors.white,
      onSurface: AppColors.ink,
      surfaceContainerHighest: const Color(0xFFEFEADD),
      surfaceContainerHigh: const Color(0xFFF2EEE3),
      surfaceContainer: const Color(0xFFF4F1E8),
      surfaceContainerLow: const Color(0xFFFBF9F4),
      outlineVariant: const Color(0xFFE2DCCB),
    );
    return _base(scheme, AppColors.offWhite);
  }

  static ThemeData dark() {
    final scheme = ColorScheme.fromSeed(
      seedColor: AppColors.emerald,
      brightness: Brightness.dark,
    ).copyWith(
      primary: const Color(0xFF3FBF8E),
      onPrimary: const Color(0xFF00281A),
      secondary: const Color(0xFFDDB84E),
      onSecondary: const Color(0xFF2A2000),
      surface: AppColors.nightSurface,
      onSurface: AppColors.nightInk,
      surfaceContainerHighest: const Color(0xFF21402F),
      surfaceContainerHigh: AppColors.nightSurfaceHigh,
      surfaceContainer: const Color(0xFF153024),
      surfaceContainerLow: const Color(0xFF0F2519),
      outlineVariant: const Color(0xFF2A4A3A),
    );
    return _base(scheme, AppColors.nightBg);
  }

  static ThemeData _base(ColorScheme scheme, Color bg) {
    final textTheme = Typography.material2021(platform: TargetPlatform.android)
        .black
        .apply(fontFamily: 'Cairo');
    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      scaffoldBackgroundColor: bg,
      fontFamily: 'Cairo',
      textTheme: (scheme.brightness == Brightness.dark
              ? Typography.material2021(platform: TargetPlatform.android).white
              : textTheme)
          .apply(
        fontFamily: 'Cairo',
        bodyColor: scheme.onSurface,
        displayColor: scheme.onSurface,
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: bg,
        foregroundColor: scheme.onSurface,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: true,
        titleTextStyle: TextStyle(
          fontFamily: 'Cairo',
          fontSize: 19,
          fontWeight: FontWeight.w700,
          color: scheme.onSurface,
        ),
      ),
      cardTheme: CardThemeData(
        color: scheme.surface,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(color: scheme.outlineVariant),
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: scheme.surface,
        indicatorColor: scheme.primary.withValues(alpha: 0.14),
        height: 68,
        labelTextStyle: WidgetStateProperty.resolveWith(
          (s) => TextStyle(
            fontFamily: 'Cairo',
            fontSize: 12,
            fontWeight:
                s.contains(WidgetState.selected) ? FontWeight.w700 : FontWeight.w500,
            color: s.contains(WidgetState.selected)
                ? scheme.primary
                : scheme.onSurface.withValues(alpha: 0.65),
          ),
        ),
        iconTheme: WidgetStateProperty.resolveWith(
          (s) => IconThemeData(
            color: s.contains(WidgetState.selected)
                ? scheme.primary
                : scheme.onSurface.withValues(alpha: 0.6),
          ),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          textStyle: const TextStyle(
              fontFamily: 'Cairo', fontWeight: FontWeight.w700, fontSize: 15),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          textStyle: const TextStyle(
              fontFamily: 'Cairo', fontWeight: FontWeight.w700, fontSize: 14),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        ),
      ),
      chipTheme: ChipThemeData(
        labelStyle: TextStyle(fontFamily: 'Cairo', fontSize: 13, color: scheme.onSurface),
        secondaryLabelStyle: TextStyle(
            fontFamily: 'Cairo', fontSize: 13, color: scheme.primary, fontWeight: FontWeight.w700),
        selectedColor: scheme.primary.withValues(alpha: 0.14),
        checkmarkColor: scheme.primary,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        side: BorderSide(color: scheme.outlineVariant),
      ),
      listTileTheme: ListTileThemeData(
        iconColor: scheme.primary,
        titleTextStyle: TextStyle(
            fontFamily: 'Cairo',
            fontSize: 15,
            fontWeight: FontWeight.w600,
            color: scheme.onSurface),
        subtitleTextStyle: TextStyle(
            fontFamily: 'Cairo',
            fontSize: 13,
            color: scheme.onSurface.withValues(alpha: 0.65)),
      ),
      dividerTheme: DividerThemeData(color: scheme.outlineVariant, space: 1),
      pageTransitionsTheme: const PageTransitionsTheme(builders: {
        TargetPlatform.android: FadeForwardsPageTransitionsBuilder(),
      }),
    );
  }
}
