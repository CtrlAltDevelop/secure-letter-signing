import 'package:flutter/foundation.dart';

/// Character style bits.
const int flagBold = 1;
const int flagItalic = 2;
const int flagUnderline = 4;
const int flagSmall = 8;
const int flagLarge = 16;
const int maskSize = flagSmall | flagLarge;
const int colorShift = 5;
const int maskColor = 3 << colorShift; // 0 ink, 1 blue, 2 red, 3 green

int colorIndex(int flags) => (flags & maskColor) >> colorShift;

// New kinds only at the end: the index is stored in saved letters.
enum ParaKind { normal, h1, h2, bullet, numbered }

enum ParaAlign { start, center, end, justify }

@immutable
class ParaStyle {
  const ParaStyle([this.kind = ParaKind.normal, this.align = ParaAlign.start]);
  final ParaKind kind;
  final ParaAlign align;

  ParaStyle copyWith({ParaKind? kind, ParaAlign? align}) =>
      ParaStyle(kind ?? this.kind, align ?? this.align);

  @override
  bool operator ==(Object other) =>
      other is ParaStyle && other.kind == kind && other.align == align;

  @override
  int get hashCode => Object.hash(kind, align);
}

/// Letter text with character flags (one per UTF-16 unit) and one [ParaStyle] per line.
/// Immutable: every edit returns a new document. `text` stays the plain-text fallback.
@immutable
class RichDoc {
  RichDoc(this.text, List<int> flags, List<ParaStyle> paras)
    : flags = List.unmodifiable(_fitFlags(text, flags)),
      paras = List.unmodifiable(_fitParas(text, paras));

  factory RichDoc.plain(String text) => RichDoc(text, const [], const []);

  final String text;
  final List<int> flags;
  final List<ParaStyle> paras;

  static const int version = 1;

  static List<int> _fitFlags(String text, List<int> flags) => [
    for (var i = 0; i < text.length; i++) i < flags.length ? flags[i] : 0,
  ];

  static List<ParaStyle> _fitParas(String text, List<ParaStyle> paras) {
    final n = '\n'.allMatches(text).length + 1;
    return [
      for (var i = 0; i < n; i++)
        i < paras.length ? paras[i] : const ParaStyle(),
    ];
  }

  bool get hasFormatting =>
      flags.any((f) => f != 0) || paras.any((p) => p != const ParaStyle());

  /// Start offset of each paragraph (`paras.length` entries).
  List<int> get paraStarts {
    final starts = [0];
    for (var i = 0; i < text.length; i++) {
      if (text.codeUnitAt(i) == 10) starts.add(i + 1);
    }
    return starts;
  }

  /// Paragraph index that holds [offset] (an offset at a line break belongs to the line it ends).
  int paraAt(int offset) {
    var k = 0;
    final end = offset.clamp(0, text.length);
    for (var i = 0; i < end; i++) {
      if (text.codeUnitAt(i) == 10) k++;
    }
    return k;
  }

  /// The document after the text became [newText] by typing/pasting/deleting. Characters that were not touched
  /// keep their style; new ones get [typing] flags; a split line copies the paragraph style.
  RichDoc afterEdit(String newText, int typing) {
    if (newText == text) return this;
    final maxCommon = newText.length < text.length
        ? newText.length
        : text.length;
    var p = 0;
    while (p < maxCommon && text.codeUnitAt(p) == newText.codeUnitAt(p)) {
      p++;
    }
    var s = 0;
    while (s < maxCommon - p &&
        text.codeUnitAt(text.length - 1 - s) ==
            newText.codeUnitAt(newText.length - 1 - s)) {
      s++;
    }
    final inserted = newText.length - p - s;
    final removedText = text.substring(p, text.length - s);
    final insertedText = newText.substring(p, p + inserted);
    final newFlags = [
      ...flags.sublist(0, p),
      ...List.filled(inserted, typing),
      ...flags.sublist(text.length - s),
    ];
    final k = paraAt(p);
    final removedBreaks = '\n'.allMatches(removedText).length;
    final insertedBreaks = '\n'.allMatches(insertedText).length;
    final newParas = List.of(paras);
    if (removedBreaks > 0) {
      newParas.removeRange(
        k + 1,
        (k + 1 + removedBreaks).clamp(0, newParas.length),
      );
    }
    if (insertedBreaks > 0) {
      newParas.insertAll(k + 1, List.filled(insertedBreaks, paras[k]));
    }
    return RichDoc(newText, newFlags, newParas);
  }

  /// Flag at the character before [offset], used as the style of newly typed text.
  int flagsBefore(int offset) =>
      offset > 0 && offset <= flags.length ? flags[offset - 1] : 0;

  /// Sets or clears [flag] on [start, end). Clears when every character already has it.
  RichDoc toggleFlag(int start, int end, int flag) {
    if (start >= end) return this;
    final all = flags.sublist(start, end).every((f) => f & flag != 0);
    final next = [
      for (var i = 0; i < flags.length; i++)
        if (i >= start && i < end)
          (all ? flags[i] & ~flag : flags[i] | flag)
        else
          flags[i],
    ];
    return RichDoc(text, next, paras);
  }

  /// Applies [change] to every paragraph touched by the selection [start, end].
  RichDoc mapParas(int start, int end, ParaStyle Function(ParaStyle) change) {
    final from = paraAt(start);
    final to = paraAt(end);
    return RichDoc(text, flags, [
      for (var i = 0; i < paras.length; i++)
        if (i >= from && i <= to) change(paras[i]) else paras[i],
    ]);
  }

  /// Replaces the [mask] bits with [value] on [start, end).
  RichDoc setBits(int start, int end, int mask, int value) {
    if (start >= end) return this;
    return RichDoc(text, [
      for (var i = 0; i < flags.length; i++)
        if (i >= start && i < end) (flags[i] & ~mask) | value else flags[i],
    ], paras);
  }

  RichDoc withText(String t) => RichDoc.plain(t);

  int get wordCount =>
      text.trim().isEmpty ? 0 : text.trim().split(RegExp(r'\s+')).length;

  /// Compact JSON stored inside the encrypted body: run-length flags and per-paragraph [kind, align].
  Map<String, dynamic> toJson() {
    final runs = <List<int>>[];
    for (final f in flags) {
      if (runs.isNotEmpty && runs.last[1] == f) {
        runs.last[0]++;
      } else {
        runs.add([1, f]);
      }
    }
    return {
      'v': version,
      'f': runs,
      'p': [
        for (final p in paras) [p.kind.index, p.align.index],
      ],
    };
  }

  /// Rebuilds a document for [text]; returns a plain one when the data is missing or does not fit.
  static RichDoc fromJson(String text, Object? json) {
    if (json is! Map || json['v'] != version) return RichDoc.plain(text);
    try {
      final flags = <int>[
        for (final r in json['f'] as List)
          ...List.filled((r as List)[0] as int, r[1] as int),
      ];
      final paras = [
        for (final p in json['p'] as List)
          ParaStyle(
            ParaKind.values[(p as List)[0] as int],
            ParaAlign.values[p[1] as int],
          ),
      ];
      if (flags.length != text.length) return RichDoc.plain(text);
      return RichDoc(text, flags, paras);
    } on Object {
      return RichDoc.plain(text);
    }
  }
}
