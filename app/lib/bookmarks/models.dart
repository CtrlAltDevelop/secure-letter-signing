import 'package:flutter/foundation.dart';

import 'package:letter_signing/workspace/models.dart';
import 'package:letter_signing/workspace/open_target.dart';

/// `GET /bookmarks` row: `{id, module, kind, target_id, subject_id, object_id, title, note,
/// created_at}`. For subject-backed modules `target_id` is the subject id and `object_id` the
/// module object id; chat messages only have `target_id`.
@immutable
class Bookmark {
  const Bookmark({
    required this.id,
    required this.module,
    required this.kind,
    required this.targetId,
    this.subjectId = '',
    this.objectId = '',
    this.title = '',
    this.note = '',
    this.createdAt,
  });

  final int id;
  final String module;
  final String kind;
  final String targetId;
  final String subjectId;
  final String objectId;
  final String title;
  final String note;
  final DateTime? createdAt;

  factory Bookmark.fromJson(Map<String, dynamic> j) => Bookmark(
    id: asInt(j['id']) ?? 0,
    module: asString(j['module']),
    kind: asString(j['kind']),
    targetId: asString(j['target_id']),
    subjectId: asString(j['subject_id']),
    objectId: asString(j['object_id']),
    title: asString(j['title']),
    note: asString(j['note']),
    createdAt: parseDate(j['created_at']),
  );

  /// Whether this bookmark is the one for [id] (subject id or object id) of [module].
  bool matches(String module, String id) =>
      this.module == module &&
      (targetId == id || objectId == id || subjectId == id);

  OpenTarget get target => OpenTarget(
    module: module,
    kind: kind,
    id: objectId.isEmpty ? targetId : objectId,
    subjectId: subjectId,
  );
}

/// `GET /pins` row: `{subject_id, module, kind, title}`.
@immutable
class Pin {
  const Pin({
    required this.subjectId,
    required this.module,
    this.objectId = '',
    this.kind = '',
    this.title = '',
  });

  final String subjectId;

  /// The module's own object id; empty from older servers.
  final String objectId;
  final String module;
  final String kind;
  final String title;

  factory Pin.fromJson(Map<String, dynamic> j) => Pin(
    subjectId: asString(j['subject_id']),
    objectId: asString(j['object_id']),
    module: asString(j['module']),
    kind: asString(j['kind']),
    title: asString(j['title']),
  );
}
