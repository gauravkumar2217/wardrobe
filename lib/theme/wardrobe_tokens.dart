import 'package:flutter/material.dart';

/// Centralized design tokens for Wardrobe (luxury dark + gold).
abstract final class WardrobeTokens {
  // Core palette
  static const Color emeraldBg = Color(0xFF041E1A);
  static const Color emeraldCard = Color(0xFF072822);
  static const Color goldPrimary = Color(0xFFD4AF37);
  static const Color goldSecondary = Color(0xFFF5E6A3);

  // Neutrals
  static const Color textPrimary = Color(0xFFF3F2EE);
  static const Color textSecondary = Color(0xFFC9C6BB);
  static const Color outlineGold = Color(0x55D4AF37);

  // Layout
  static const double radiusSm = 12;
  static const double radiusMd = 16;
  static const double radiusLg = 20;

  static BorderRadius get cardRadius => BorderRadius.circular(radiusLg);
  static BorderRadius get controlRadius => BorderRadius.circular(radiusMd);

  static const EdgeInsets pagePadding = EdgeInsets.symmetric(horizontal: 16);
  static const EdgeInsets sectionPadding =
      EdgeInsets.symmetric(horizontal: 16, vertical: 10);

  static BorderSide get hairlineGold =>
      const BorderSide(color: outlineGold, width: 1);
}

