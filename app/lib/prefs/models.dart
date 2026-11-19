import 'package:material_ui/material_ui.dart';

import 'package:letter_signing/workspace/models.dart';

/// `GET /me/prefs`.
@immutable
class UserPrefs {
  const UserPrefs({
    this.theme = 'auto',
    this.birthday,
    this.birthdayVisible = true,
    this.dndUntil,
    this.personalEmail = '',
    this.personalEmailVerified = false,
    this.hasBackground = false,
  });

  final String theme; // light | dark | auto
  final DateTime? birthday;
  final bool birthdayVisible;
  final DateTime? dndUntil;
  final String personalEmail;
  final bool personalEmailVerified;
  final bool hasBackground;

  factory UserPrefs.fromJson(Object? raw) {
    final j = asMap(raw);
    return UserPrefs(
      theme: asString(j['theme'], 'auto'),
      birthday: parseDate(j['birthday']),
      birthdayVisible: j['birthday_visible'] != false,
      dndUntil: parseDate(j['dnd_until'])?.toLocal(),
      personalEmail: asString(j['personal_email']),
      personalEmailVerified: j['personal_email_verified'] == true,
      hasBackground: j['has_background'] == true,
    );
  }

  ThemeMode get themeMode => switch (theme) {
    'light' => ThemeMode.light,
    'dark' => ThemeMode.dark,
    _ => ThemeMode.system,
  };

  bool dndActive([DateTime? now]) =>
      dndUntil != null && dndUntil!.isAfter(now ?? DateTime.now());
}

/// `GET /me/mentions` row.
@immutable
class MentionItem {
  const MentionItem({
    required this.commentId,
    required this.subjectId,
    required this.module,
    this.kind = '',
    this.title = '',
    this.excerpt = '',
    this.author = '',
    this.report = false,
    this.createdAt,
  });

  final int commentId;
  final String subjectId;
  final String module;
  final String kind;
  final String title;
  final String excerpt;
  final String author;
  final bool report;
  final DateTime? createdAt;

  factory MentionItem.fromJson(Map<String, dynamic> j) => MentionItem(
    commentId: asInt(j['comment_id']) ?? 0,
    subjectId: asString(j['subject_id']),
    module: asString(j['module']),
    kind: asString(j['kind']),
    title: asString(j['title']),
    excerpt: asString(j['excerpt']),
    author: UserRef.fromJson(asMap(j['author'])).displayName,
    report: j['report'] == true,
    createdAt: parseDate(j['created_at']),
  );
}
