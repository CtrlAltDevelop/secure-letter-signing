import 'package:material_ui/material_ui.dart';

/// Message text with `*bold*`, `_italic_` and `@Name` mentions as styled spans.
/// ponytail: no nesting (bold inside italic stays literal); add a real parser if asked.
List<InlineSpan> chatSpans(
  String text, {
  required TextStyle base,
  required TextStyle mentionStyle,
  List<String> mentionNames = const [],
}) {
  const edge = r'[\p{L}\p{N}]';
  final names = [...mentionNames]..sort((a, b) => b.length.compareTo(a.length));
  final parts = [
    '(?<!$edge)\\*(?=\\S)([^*\\n]+?)(?<=\\S)\\*(?!$edge)',
    '(?<!$edge)_(?=\\S)([^_\\n]+?)(?<=\\S)_(?!$edge)',
    if (names.isNotEmpty)
      '@(${[for (final n in names) RegExp.escape(n)].join('|')})',
  ];
  final re = RegExp(parts.join('|'), unicode: true);
  final spans = <InlineSpan>[];
  var at = 0;
  for (final m in re.allMatches(text)) {
    if (m.start > at) spans.add(TextSpan(text: text.substring(at, m.start)));
    if (m.group(1) != null) {
      spans.add(
        TextSpan(
          text: m.group(1),
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
      );
    } else if (m.group(2) != null) {
      spans.add(
        TextSpan(
          text: m.group(2),
          style: const TextStyle(fontStyle: FontStyle.italic),
        ),
      );
    } else {
      final name = m.group(3)!;
      spans.add(TextSpan(text: '@$name', style: mentionStyle));
    }
    at = m.end;
  }
  if (at < text.length) spans.add(TextSpan(text: text.substring(at)));
  return spans;
}

/// The user ids whose `@Name` still appears in [text].
List<int> mentionedIds(String text, Map<int, String> namesById) => [
  for (final e in namesById.entries)
    if (text.contains('@${e.value}')) e.key,
];
