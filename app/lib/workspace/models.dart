import 'package:flutter/foundation.dart';

/// Tolerant JSON helpers: a server field that is missing or of an unexpected type becomes a
/// neutral default instead of crashing the screen.
Map<String, dynamic> asMap(Object? value) =>
    value is Map ? Map<String, dynamic>.from(value) : <String, dynamic>{};

List<Map<String, dynamic>> asMapList(Object? value) => [
  if (value is List)
    for (final e in value)
      if (e is Map) Map<String, dynamic>.from(e),
];

DateTime? parseDate(Object? value) =>
    value is String ? DateTime.tryParse(value) : null;

int? asInt(Object? value) => value is num ? value.toInt() : null;

List<int> asIntList(Object? value) => [
  if (value is List)
    for (final e in value)
      if (e is num) e.toInt(),
];

String asString(Object? value, [String fallback = '']) =>
    value is String ? value : fallback;

/// A person as the workspace endpoints embed them: `{id, full_name, email}`.
@immutable
class UserRef {
  const UserRef({required this.id, this.fullName = '', this.email = ''});

  final int id;
  final String fullName;
  final String email;

  String get displayName => fullName.isEmpty ? email : fullName;

  factory UserRef.fromJson(Map<String, dynamic> j) => UserRef(
    id: asInt(j['id']) ?? 0,
    fullName: asString(j['full_name']),
    email: asString(j['email']),
  );

  static UserRef? maybe(Object? value) =>
      value is Map ? UserRef.fromJson(asMap(value)) : null;

  @override
  bool operator ==(Object other) => other is UserRef && other.id == id;

  @override
  int get hashCode => id.hashCode;
}

/// A label (`GET /labels`): organisation-wide or personal, coloured by a palette index.
@immutable
class LabelInfo {
  const LabelInfo({
    required this.id,
    required this.name,
    this.color = 0,
    this.scope = 'org',
    this.active = true,
  });

  final int id;
  final String name;
  final int color;
  final String scope;
  final bool active;

  factory LabelInfo.fromJson(Map<String, dynamic> j) => LabelInfo(
    id: asInt(j['id']) ?? 0,
    name: asString(j['name']),
    color: asInt(j['color']) ?? 0,
    scope: asString(j['scope'], 'org'),
    active: j['active'] != false,
  );
}

/// One comment or progress report on a subject. Replies are flattened into the list and linked
/// by [parentId].
@immutable
class CommentInfo {
  const CommentInfo({
    required this.id,
    required this.author,
    required this.text,
    this.parentId,
    this.kind = commentKind,
    this.progress,
    this.active = true,
    this.edited = false,
    this.createdAt,
  });

  static const commentKind = 'comment';
  static const reportKind = 'report';

  final int id;
  final UserRef author;
  final int? parentId;
  final String kind;
  final String text;
  final int? progress;
  final bool active;
  final bool edited;
  final DateTime? createdAt;

  bool get isReport => kind == reportKind;

  factory CommentInfo.fromJson(Map<String, dynamic> j) => CommentInfo(
    id: asInt(j['id']) ?? 0,
    author: UserRef.maybe(j['author']) ?? const UserRef(id: 0),
    parentId: asInt(j['parent_id']),
    kind: asString(j['kind'], commentKind),
    text: asString(asMap(j['body'])['text']),
    progress: asInt(j['progress_snapshot']) ?? asInt(j['progress']),
    active: j['active'] != false,
    edited: j['edited'] == true,
    createdAt: parseDate(j['created_at']),
  );

  /// Parses a comment list that is either flat (`parent_id`) or nested (`replies`).
  static List<CommentInfo> parseAll(Object? raw) {
    final out = <CommentInfo>[];
    void walk(Map<String, dynamic> json, int? parent) {
      final c = CommentInfo.fromJson(json);
      out.add(parent != null && c.parentId == null ? c.withParent(parent) : c);
      for (final r in asMapList(json['replies'])) {
        walk(r, c.id);
      }
    }

    for (final json in asMapList(raw)) {
      walk(json, null);
    }
    return [
      for (final c in out)
        if (c.active) c,
    ];
  }

  CommentInfo withParent(int parent) => CommentInfo(
    id: id,
    author: author,
    text: text,
    parentId: parent,
    kind: kind,
    progress: progress,
    active: active,
    edited: edited,
    createdAt: createdAt,
  );
}

/// A file attached to a subject.
@immutable
class FileInfo {
  const FileInfo({
    required this.id,
    required this.name,
    this.contentType = '',
    this.size = 0,
    this.uploadedBy,
    this.createdAt,
  });

  final String id;
  final String name;
  final String contentType;
  final int size;
  final UserRef? uploadedBy;
  final DateTime? createdAt;

  factory FileInfo.fromJson(Map<String, dynamic> j) => FileInfo(
    id: asString(j['id']),
    name: asString(j['name']),
    contentType: asString(j['content_type']),
    size: asInt(j['size']) ?? 0,
    uploadedBy: UserRef.maybe(j['uploaded_by']),
    createdAt: parseDate(j['created_at']),
  );
}

/// One audited change (`GET /subjects/{id}/history`).
@immutable
class HistoryEntry {
  const HistoryEntry({
    required this.field,
    this.actor,
    this.oldValue,
    this.newValue,
    this.at,
  });

  final UserRef? actor;
  final String field;
  final Object? oldValue;
  final Object? newValue;
  final DateTime? at;

  factory HistoryEntry.fromJson(Map<String, dynamic> j) => HistoryEntry(
    actor: UserRef.maybe(j['actor']),
    field: asString(j['field']),
    oldValue: j['old'],
    newValue: j['new'],
    at: parseDate(j['at']),
  );
}

/// Who opened a subject and when.
@immutable
class SeenEntry {
  const SeenEntry({required this.user, this.firstAt, this.lastAt});

  final UserRef user;
  final DateTime? firstAt;
  final DateTime? lastAt;

  factory SeenEntry.fromJson(Map<String, dynamic> j) => SeenEntry(
    user: UserRef.maybe(j['user']) ?? const UserRef(id: 0),
    firstAt: parseDate(j['first_at']),
    lastAt: parseDate(j['last_at']),
  );
}

/// How a reminder repeats; weekdays count from Saturday = 0 to Friday = 6 like the server.
@immutable
class ReminderRule {
  const ReminderRule({
    this.freq = daily,
    this.interval = 1,
    this.weekdays = const [],
    this.day,
  });

  static const daily = 'daily';
  static const weekly = 'weekly';
  static const monthly = 'monthly_jalali';
  static const freqs = [daily, weekly, monthly];

  final String freq;
  final int interval;
  final List<int> weekdays;
  final int? day;

  factory ReminderRule.fromJson(Map<String, dynamic> j) => ReminderRule(
    freq: asString(j['freq'], daily),
    interval: asInt(j['interval']) ?? 1,
    weekdays: asIntList(j['weekdays']),
    day: asInt(j['day']),
  );

  Map<String, dynamic> toJson() => {
    'freq': freq,
    'interval': interval,
    if (freq == weekly && weekdays.isNotEmpty) 'weekdays': weekdays,
    if (freq == monthly && day != null) 'day': day,
  };
}

/// One of my reminders on a subject (`GET /subjects/{id}/reminders`).
@immutable
class ReminderInfo {
  const ReminderInfo({required this.id, required this.at, this.rule});

  final int id;
  final DateTime at;
  final ReminderRule? rule;

  factory ReminderInfo.fromJson(Map<String, dynamic> j) => ReminderInfo(
    id: asInt(j['id']) ?? 0,
    at: parseDate(j['at']) ?? DateTime.fromMillisecondsSinceEpoch(0),
    rule: j['rule'] is Map ? ReminderRule.fromJson(asMap(j['rule'])) : null,
  );
}
