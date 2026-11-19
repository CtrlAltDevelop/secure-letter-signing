import 'package:flutter/foundation.dart';

import 'package:letter_signing/workspace/models.dart';

/// Most images a note can hold (server limit).
const maxNoteImages = 10;

/// One checklist line of a note. Items not yet saved have a negative [id].
@immutable
class NoteItem {
  const NoteItem({required this.id, required this.text, this.done = false});

  final int id;
  final String text;
  final bool done;

  bool get isLocal => id < 0;

  factory NoteItem.fromJson(Map<String, dynamic> j) => NoteItem(
    id: asInt(j['id']) ?? 0,
    text: asString(j['text']),
    done: j['done'] == true,
  );

  NoteItem copyWith({String? text, bool? done}) =>
      NoteItem(id: id, text: text ?? this.text, done: done ?? this.done);
}

/// A personal note (`GET /notes`). Private to its owner.
@immutable
class NoteOut {
  const NoteOut({
    required this.id,
    required this.subjectId,
    this.title = '',
    this.body = '',
    this.color = 0,
    this.pinned = false,
    this.archived = false,
    this.items = const [],
    this.labelIds = const [],
    this.imageCount = 0,
    this.updatedAt,
  });

  final String id;
  final String subjectId;
  final String title;
  final String body;

  /// Palette index 0..15 (see `noteColors`).
  final int color;
  final bool pinned;
  final bool archived;
  final List<NoteItem> items;
  final List<int> labelIds;
  final int imageCount;
  final DateTime? updatedAt;

  factory NoteOut.fromJson(Map<String, dynamic> j) => NoteOut(
    id: asString(j['id']),
    subjectId: asString(j['subject_id']),
    title: asString(j['title']),
    body: asString(asMap(j['body'])['text']),
    color: (asInt(j['color']) ?? 0).clamp(0, 15),
    pinned: j['pinned'] == true,
    archived: j['archived'] == true,
    items: [
      for (final e in asMapList(j['checklist_items'])) NoteItem.fromJson(e),
    ],
    labelIds: asIntList(j['label_ids']),
    imageCount: asInt(j['image_count']) ?? 0,
    updatedAt: parseDate(j['updated_at']),
  );
}

/// Filters of `GET /notes`; empty values are not sent.
@immutable
class NoteFilter {
  const NoteFilter({this.q = '', this.labelId, this.archived = false});

  final String q;
  final int? labelId;
  final bool archived;

  NoteFilter copyWith({
    String? q,
    int? labelId,
    bool clearLabel = false,
    bool? archived,
  }) => NoteFilter(
    q: q ?? this.q,
    labelId: clearLabel ? null : (labelId ?? this.labelId),
    archived: archived ?? this.archived,
  );

  Map<String, Object?> toQuery({int limit = 100, int offset = 0}) => {
    'q': q,
    'label': labelId,
    'archived': archived ? 'true' : null,
    'limit': limit,
    'offset': offset,
  };

  bool get filtered => q.isNotEmpty || labelId != null;
}
