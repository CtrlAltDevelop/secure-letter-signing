import 'dart:convert';

import 'package:material_ui/material_ui.dart';

/// Brand of the company this build belongs to (from assets/brand/brand.json).
@immutable
class Brand {
  const Brand({
    required this.id,
    required this.name,
    required this.primary,
    required this.accent,
    required this.dark,
    required this.apiUrl,
  });

  final String id;
  final String name;
  final Color primary;
  final Color accent;
  final Color dark;
  final String apiUrl;

  factory Brand.fromJson(String source) {
    final map = jsonDecode(source) as Map<String, dynamic>;
    for (final key in const ['id', 'name', 'colors', 'apiUrl']) {
      if (!map.containsKey(key)) {
        throw FormatException('brand.json is missing "$key"');
      }
    }
    final colors = map['colors'] as Map<String, dynamic>;
    return Brand(
      id: map['id'] as String,
      name: map['name'] as String,
      primary: parseHex(colors['primary'] as String),
      accent: parseHex(colors['accent'] as String),
      dark: parseHex(colors['dark'] as String),
      apiUrl: map['apiUrl'] as String,
    );
  }
}

/// "#RRGGBB" -> opaque Color.
Color parseHex(String hex) {
  final clean = hex.replaceFirst('#', '');
  if (clean.length != 6) throw FormatException('Bad color "$hex"');
  return Color(0xFF000000 | int.parse(clean, radix: 16));
}
