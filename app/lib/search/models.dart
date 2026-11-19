import 'package:flutter/foundation.dart';

import 'package:letter_signing/workspace/models.dart';
import 'package:letter_signing/workspace/open_target.dart';

/// `GET /search` row: `{module, kind, id, subject_id, title, snippet, at}`.
@immutable
class SearchHit {
  const SearchHit({
    required this.module,
    required this.kind,
    required this.id,
    this.subjectId = '',
    this.title = '',
    this.snippet = '',
    this.at,
  });

  final String module;
  final String kind;
  final String id;
  final String subjectId;
  final String title;
  final String snippet;
  final DateTime? at;

  factory SearchHit.fromJson(Map<String, dynamic> j) => SearchHit(
    module: asString(j['module']),
    kind: asString(j['kind']),
    id: asString(j['id']),
    subjectId: asString(j['subject_id']),
    title: asString(j['title']),
    snippet: asString(j['snippet']),
    at: parseDate(j['at']),
  );

  /// A file name hit: its id is the file id, the owner screen is not known from the hit.
  bool get isFile => module == 'files';

  OpenTarget get target =>
      OpenTarget(module: module, kind: kind, id: id, subjectId: subjectId);
}

/// Hits of one module, in the server's order.
@immutable
class SearchGroup {
  const SearchGroup(this.module, this.hits);
  final String module;
  final List<SearchHit> hits;
}

/// The server already groups by module in registration order; this keeps that order.
List<SearchGroup> groupHits(List<SearchHit> hits) {
  final order = <String>[];
  final by = <String, List<SearchHit>>{};
  for (final h in hits) {
    if (!by.containsKey(h.module)) order.add(h.module);
    (by[h.module] ??= []).add(h);
  }
  return [for (final m in order) SearchGroup(m, by[m]!)];
}
