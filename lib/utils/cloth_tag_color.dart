import 'package:flutter/material.dart';

/// Maps cloth color tag strings (Firestore / AI labels, hex, `RGB(r,g,b)`) to a [Color].
Color colorForClothTag(String raw) {
  final t = raw.trim();
  if (t.isEmpty) return Colors.grey.shade400;

  final hexMatch = RegExp(r'^#([0-9A-Fa-f]{6}|[0-9A-Fa-f]{8})$').firstMatch(t);
  if (hexMatch != null) {
    final hex = hexMatch.group(1)!;
    if (hex.length == 6) {
      return Color(int.parse(hex, radix: 16) + 0xFF000000);
    }
    return Color(int.parse(hex, radix: 16));
  }

  final rgbMatch = RegExp(
    r'^RGB\s*\(\s*(\d+)\s*,\s*(\d+)\s*,\s*(\d+)\s*\)$',
    caseSensitive: false,
  ).firstMatch(t);
  if (rgbMatch != null) {
    final r = int.parse(rgbMatch.group(1)!).clamp(0, 255);
    final g = int.parse(rgbMatch.group(2)!).clamp(0, 255);
    final b = int.parse(rgbMatch.group(3)!).clamp(0, 255);
    return Color.fromARGB(255, r, g, b);
  }

  final key = t.toLowerCase();
  const named = <String, Color>{
    'red': Color(0xFFE53935),
    'blue': Color(0xFF1E88E5),
    'green': Color(0xFF43A047),
    'black': Color(0xFF212121),
    'white': Color(0xFFFAFAFA),
    'yellow': Color(0xFFFDD835),
    'pink': Color(0xFFEC407A),
    'orange': Color(0xFFFB8C00),
    'purple': Color(0xFF8E24AA),
    'brown': Color(0xFF6D4C41),
    'grey': Color(0xFF9E9E9E),
    'gray': Color(0xFF9E9E9E),
    'navy': Color(0xFF283593),
    'navy blue': Color(0xFF283593),
    'maroon': Color(0xFF880E4F),
    'beige': Color(0xFFD7CCC8),
    'cream': Color(0xFFFFFDE7),
    'gold': Color(0xFFFFB300),
    'silver': Color(0xFFB0BEC5),
    'turquoise': Color(0xFF26A69A),
    'coral': Color(0xFFFF7043),
    'lavender': Color(0xFFCE93D8),
    'teal': Color(0xFF00897B),
    'burgundy': Color(0xFF6A1B1B),
    'magenta': Color(0xFFD81B60),
    'cyan': Color(0xFF00ACC1),
    'olive': Color(0xFF827717),
    'khaki': Color(0xFFC0A080),
    'indigo': Color(0xFF3949AB),
    'violet': Color(0xFF7E57C2),
    'peach': Color(0xFFFFCCBC),
    'mint': Color(0xFF80CBC4),
    'dark': Color(0xFF424242),
    'light': Color(0xFFE0E0E0),
  };

  if (named.containsKey(key)) return named[key]!;
  for (final part in key.split(RegExp(r'[\s,]+'))) {
    if (part.isNotEmpty && named.containsKey(part)) {
      return named[part]!;
    }
  }

  return _hashToColor(t);
}

Color _hashToColor(String s) {
  var h = 0;
  for (final u in s.codeUnits) {
    h = (h * 31 + u) & 0x7FFFFFFF;
  }
  final hue = (h % 360).toDouble();
  return HSVColor.fromAHSV(1.0, hue, 0.5, 0.82).toColor();
}

/// Border that stays visible on very light or very dark fills.
Color borderColorForSwatch(Color fill) {
  final l = fill.computeLuminance();
  if (l > 0.72) return Colors.black38;
  if (l < 0.12) return Colors.white30;
  return Colors.black26;
}
