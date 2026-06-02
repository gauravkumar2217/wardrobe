import 'package:flutter/material.dart';
import 'wardrobe_tokens.dart';

abstract final class WardrobeTheme {
  static ColorScheme colorScheme() {
    // A tuned dark scheme using our emerald + gold palette.
    return const ColorScheme.dark(
      primary: WardrobeTokens.goldPrimary,
      onPrimary: Color(0xFF1A1405),
      secondary: WardrobeTokens.goldSecondary,
      onSecondary: Color(0xFF1A1405),
      surface: WardrobeTokens.emeraldCard,
      onSurface: WardrobeTokens.textPrimary,
      surfaceContainerHighest: Color(0xFF09332B),
      outline: WardrobeTokens.outlineGold,
    );
  }

  static ThemeData theme() {
    final scheme = colorScheme();
    final base = ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      colorScheme: scheme,
      scaffoldBackgroundColor: WardrobeTokens.emeraldBg,
    );

    final textTheme = base.textTheme.copyWith(
      headlineSmall: base.textTheme.headlineSmall?.copyWith(
        fontWeight: FontWeight.w700,
        letterSpacing: -0.4,
      ),
      titleLarge: base.textTheme.titleLarge?.copyWith(
        fontWeight: FontWeight.w700,
        letterSpacing: -0.2,
      ),
      titleMedium: base.textTheme.titleMedium?.copyWith(
        fontWeight: FontWeight.w600,
        letterSpacing: -0.1,
      ),
      bodyMedium: base.textTheme.bodyMedium?.copyWith(
        height: 1.25,
      ),
      labelLarge: base.textTheme.labelLarge?.copyWith(
        fontWeight: FontWeight.w700,
        letterSpacing: 0.2,
      ),
    );

    return base.copyWith(
      textTheme: textTheme,
      dividerTheme: DividerThemeData(
        color: scheme.outline.withValues(alpha: 0.35),
        thickness: 1,
        space: 1,
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: WardrobeTokens.emeraldBg,
        foregroundColor: scheme.onSurface,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
      ),
      cardTheme: CardThemeData(
        color: WardrobeTokens.emeraldCard,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: WardrobeTokens.cardRadius,
          side: WardrobeTokens.hairlineGold,
        ),
        margin: EdgeInsets.zero,
      ),
      iconTheme: IconThemeData(
        color: scheme.onSurface.withValues(alpha: 0.92),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: const Color(0xFF031613),
        indicatorColor: WardrobeTokens.goldPrimary.withValues(alpha: 0.16),
        labelTextStyle: WidgetStatePropertyAll(
          textTheme.labelSmall?.copyWith(
            color: scheme.onSurface.withValues(alpha: 0.9),
            fontWeight: FontWeight.w600,
            fontSize: 8,
          ),
        ),
        iconTheme: WidgetStateProperty.resolveWith((states) {
          final selected = states.contains(WidgetState.selected);
          return IconThemeData(
            color: selected
                ? WardrobeTokens.goldPrimary
                : scheme.onSurface.withValues(alpha: 0.70),
          );
        }),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: WardrobeTokens.goldPrimary,
          foregroundColor: scheme.onPrimary,
          shape: RoundedRectangleBorder(
            borderRadius: WardrobeTokens.controlRadius,
          ),
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: WardrobeTokens.goldPrimary,
          side: WardrobeTokens.hairlineGold,
          shape: RoundedRectangleBorder(
            borderRadius: WardrobeTokens.controlRadius,
          ),
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
        ),
      ),
      chipTheme: base.chipTheme.copyWith(
        backgroundColor: const Color(0xFF06231E),
        side: WardrobeTokens.hairlineGold,
        labelStyle: textTheme.labelMedium?.copyWith(
          color: WardrobeTokens.textPrimary,
          fontWeight: FontWeight.w600,
        ),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(WardrobeTokens.radiusMd),
        ),
      ),
    );
  }
}

