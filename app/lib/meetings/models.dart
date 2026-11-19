import 'package:flutter/foundation.dart';

import 'package:letter_signing/workspace/models.dart';

/// Meeting lifecycle values as the server sends them.
abstract final class MeetingStatus {
  static const draft = 'draft';
  static const scheduled = 'scheduled';
  static const held = 'held';
  static const closed = 'closed';
  static const cancelled = 'cancelled';
  static const all = [draft, scheduled, held, closed, cancelled];
}

abstract final class MeetingKind {
  static const simple = 'simple';
  static const organizational = 'organizational';
  static const all = [simple, organizational];
}

abstract final class AttendeeRole {
  static const chair = 'chair';
  static const secretary = 'secretary';
  static const member = 'member';
  static const guest = 'guest';
  static const all = [chair, secretary, member, guest];
}

abstract final class Attendance {
  static const unknown = 'unknown';
  static const present = 'present';
  static const absent = 'absent';
  static const excused = 'excused';
  static const all = [unknown, present, absent, excused];
}

/// A meeting as the list shows it (`MeetingBrief`).
@immutable
class MeetingBrief {
  const MeetingBrief({
    required this.id,
    required this.subjectId,
    required this.title,
    this.kind = MeetingKind.simple,
    this.status = MeetingStatus.draft,
    this.location = '',
    this.startsAt,
    this.endsAt,
    this.projectId,
    this.creatorId = 0,
    this.myRole,
    this.attendeeCount = 0,
    this.resolutionsDone = 0,
    this.resolutionsTotal = 0,
    this.labelIds = const [],
    this.unseen = false,
    this.revision = 1,
  });

  final String id;
  final String subjectId;
  final String title;
  final String kind;
  final String status;
  final String location;
  final DateTime? startsAt;
  final DateTime? endsAt;
  final String? projectId;
  final int creatorId;
  final String? myRole;
  final int attendeeCount;
  final int resolutionsDone;
  final int resolutionsTotal;
  final List<int> labelIds;
  final bool unseen;
  final int revision;

  bool get isOrganizational => kind == MeetingKind.organizational;

  factory MeetingBrief.fromJson(Map<String, dynamic> j) {
    final counts = asMap(j['resolutions']);
    return MeetingBrief(
      id: asString(j['id']),
      subjectId: asString(j['subject_id']),
      title: asString(j['title']),
      kind: asString(j['kind'], MeetingKind.simple),
      status: asString(j['status'], MeetingStatus.draft),
      location: asString(j['location']),
      startsAt: parseDate(j['starts_at']),
      endsAt: parseDate(j['ends_at']),
      projectId: j['project_id'] as String?,
      creatorId: asInt(j['creator_id']) ?? 0,
      myRole: j['my_role'] as String?,
      attendeeCount: asInt(j['attendee_count']) ?? 0,
      resolutionsDone: asInt(counts['done']) ?? 0,
      resolutionsTotal: asInt(counts['total']) ?? 0,
      labelIds: asIntList(j['label_ids']),
      unseen: j['unseen'] == true,
      revision: asInt(j['revision']) ?? 1,
    );
  }
}

@immutable
class Attendee {
  const Attendee({
    required this.id,
    required this.role,
    this.user,
    this.guestName = '',
    this.attendance = Attendance.unknown,
  });

  final int id;
  final UserRef? user;
  final String guestName;
  final String role;
  final String attendance;

  String get displayName => user?.displayName ?? guestName;
  bool get isGuest => user == null;

  factory Attendee.fromJson(Map<String, dynamic> j) => Attendee(
    id: asInt(j['id']) ?? 0,
    user: UserRef.maybe(j['user']),
    guestName: asString(j['guest_name']),
    role: asString(j['role'], AttendeeRole.member),
    attendance: asString(j['attendance'], Attendance.unknown),
  );
}

/// An attendee being edited in the form (a colleague by id, or an external guest by name).
@immutable
class AttendeeDraft {
  const AttendeeDraft({this.userId, this.guestName = '', required this.role});

  final int? userId;
  final String guestName;
  final String role;

  AttendeeDraft withRole(String value) =>
      AttendeeDraft(userId: userId, guestName: guestName, role: value);

  Map<String, dynamic> toJson() => {
    'user_id': ?userId,
    if (userId == null) 'guest_name': guestName,
    'role': role,
  };

  @override
  bool operator ==(Object other) =>
      other is AttendeeDraft &&
      other.userId == userId &&
      other.guestName == guestName &&
      other.role == role;

  @override
  int get hashCode => Object.hash(userId, guestName, role);
}

/// One resolution of the minutes; [taskId] links the follow-up task.
@immutable
class Resolution {
  const Resolution({
    required this.id,
    required this.text,
    this.dueAt,
    this.status = 'open',
    this.ownerIds = const [],
    this.taskId,
    this.taskStatus,
    this.taskProgress,
  });

  final int id;
  final String text;
  final DateTime? dueAt;

  /// `open`, `done` or `cancelled` (mirrors the task when there is one).
  final String status;
  final List<int> ownerIds;
  final String? taskId;
  final String? taskStatus;
  final int? taskProgress;

  factory Resolution.fromJson(Map<String, dynamic> j) => Resolution(
    id: asInt(j['id']) ?? 0,
    text: asString(j['text']),
    dueAt: parseDate(j['due_at']),
    status: asString(j['status'], 'open'),
    ownerIds: asIntList(j['owner_ids']),
    taskId: j['task_id'] as String?,
    taskStatus: j['task_status'] as String?,
    taskProgress: asInt(j['task_progress']),
  );
}

/// A sealed signature of the minutes.
@immutable
class MeetingSignature {
  const MeetingSignature({
    required this.id,
    required this.user,
    required this.decision,
    this.note = '',
    this.method = '',
    this.revision = 1,
    this.stale = false,
    this.valid = true,
    this.createdAt,
  });

  final int id;
  final UserRef user;
  final String decision;
  final String note;
  final String method;
  final int revision;

  /// Signed an earlier revision of the minutes.
  final bool stale;

  /// The Ed25519 seal verifies.
  final bool valid;
  final DateTime? createdAt;

  factory MeetingSignature.fromJson(Map<String, dynamic> j) => MeetingSignature(
    id: asInt(j['id']) ?? 0,
    user: UserRef.maybe(j['user']) ?? const UserRef(id: 0),
    decision: asString(j['decision']),
    note: asString(j['note']),
    method: asString(j['method']),
    revision: asInt(j['revision']) ?? 1,
    stale: j['stale'] == true,
    valid: j['valid'] != false,
    createdAt: parseDate(j['created_at']),
  );
}

@immutable
class MeetingCan {
  const MeetingCan({
    this.manage = false,
    this.record = false,
    this.run = false,
    this.chair = false,
    this.sign = false,
    this.comment = true,
  });

  final bool manage;
  final bool record;
  final bool run;
  final bool chair;
  final bool sign;
  final bool comment;

  factory MeetingCan.fromJson(Object? raw) {
    final j = asMap(raw);
    return MeetingCan(
      manage: j['manage'] == true,
      record: j['record'] == true,
      run: j['run'] == true,
      chair: j['chair'] == true,
      sign: j['sign'] == true,
      comment: j['comment'] != false,
    );
  }
}

/// A meeting in full (`MeetingOut`).
@immutable
class MeetingOut {
  const MeetingOut({
    required this.brief,
    this.description = '',
    this.creator = const UserRef(id: 0),
    this.attendees = const [],
    this.resolutions = const [],
    this.signatures = const [],
    this.templateId,
    this.allSigned = false,
    this.can = const MeetingCan(),
    this.createdAt,
  });

  final MeetingBrief brief;
  final String description;
  final UserRef creator;
  final List<Attendee> attendees;
  final List<Resolution> resolutions;
  final List<MeetingSignature> signatures;
  final int? templateId;
  final bool allSigned;
  final MeetingCan can;
  final DateTime? createdAt;

  String get id => brief.id;
  String get subjectId => brief.subjectId;
  String get title => brief.title;
  String get status => brief.status;

  /// Signatures of the current revision.
  Iterable<MeetingSignature> get currentSignatures =>
      signatures.where((s) => !s.stale);

  factory MeetingOut.fromJson(Map<String, dynamic> j) => MeetingOut(
    brief: MeetingBrief.fromJson(j),
    description: asString(asMap(j['description'])['text']),
    creator: UserRef.maybe(j['creator']) ?? const UserRef(id: 0),
    attendees: [
      for (final e in asMapList(j['attendees'])) Attendee.fromJson(e),
    ],
    resolutions: [
      for (final e in asMapList(j['resolution_items'])) Resolution.fromJson(e),
    ],
    signatures: [
      for (final e in asMapList(j['signatures'])) MeetingSignature.fromJson(e),
    ],
    templateId: asInt(j['template_id']),
    allSigned: j['all_signed'] == true,
    can: MeetingCan.fromJson(j['can']),
    createdAt: parseDate(j['created_at']),
  );
}

/// A saved meeting layout (`TemplateOut`).
@immutable
class MeetingTemplate {
  const MeetingTemplate({
    required this.id,
    required this.name,
    this.scope = 'personal',
    this.ownerId,
    this.kind = MeetingKind.simple,
    this.location = '',
    this.description = '',
    this.attendees = const [],
    this.active = true,
  });

  final int id;
  final String name;
  final String scope;
  final int? ownerId;
  final String kind;
  final String location;
  final String description;
  final List<AttendeeDraft> attendees;
  final bool active;

  factory MeetingTemplate.fromJson(Map<String, dynamic> j) {
    final data = asMap(j['data']);
    return MeetingTemplate(
      id: asInt(j['id']) ?? 0,
      name: asString(j['name']),
      scope: asString(j['scope'], 'personal'),
      ownerId: asInt(j['owner_id']),
      kind: asString(data['kind'], MeetingKind.simple),
      location: asString(data['location']),
      description: asString(data['description']),
      attendees: [
        for (final a in asMapList(data['attendees']))
          AttendeeDraft(
            userId: asInt(a['user_id']),
            role: asString(a['role'], AttendeeRole.member),
          ),
      ],
      active: j['active'] != false,
    );
  }

  /// The `data` object the server stores (only colleagues, never guests).
  static Map<String, dynamic> dataJson({
    required String kind,
    required String location,
    required String description,
    required List<AttendeeDraft> attendees,
  }) => {
    'kind': kind,
    'location': location,
    'description': description,
    'attendees': [
      for (final a in attendees)
        if (a.userId != null) {'user_id': a.userId, 'role': a.role},
    ],
  };
}

/// What the form submits to create or patch a meeting.
@immutable
class MeetingDraft {
  const MeetingDraft({
    this.title = '',
    this.kind = MeetingKind.simple,
    this.location = '',
    this.startsAt,
    this.endsAt,
    this.description = '',
    this.projectId,
    this.attendees = const [],
    this.templateId,
  });

  final String title;
  final String kind;
  final String location;
  final DateTime? startsAt;
  final DateTime? endsAt;
  final String description;
  final String? projectId;
  final List<AttendeeDraft> attendees;
  final int? templateId;

  factory MeetingDraft.fromMeeting(MeetingOut m) => MeetingDraft(
    title: m.title,
    kind: m.brief.kind,
    location: m.brief.location,
    startsAt: m.brief.startsAt?.toLocal(),
    endsAt: m.brief.endsAt?.toLocal(),
    description: m.description,
    projectId: m.brief.projectId,
    templateId: m.templateId,
    attendees: [
      for (final a in m.attendees)
        AttendeeDraft(userId: a.user?.id, guestName: a.guestName, role: a.role),
    ],
  );

  MeetingDraft copyWith({
    String? title,
    String? kind,
    String? location,
    DateTime? startsAt,
    bool clearStart = false,
    DateTime? endsAt,
    bool clearEnd = false,
    String? description,
    String? projectId,
    bool clearProject = false,
    List<AttendeeDraft>? attendees,
    int? templateId,
  }) => MeetingDraft(
    title: title ?? this.title,
    kind: kind ?? this.kind,
    location: location ?? this.location,
    startsAt: clearStart ? null : (startsAt ?? this.startsAt),
    endsAt: clearEnd ? null : (endsAt ?? this.endsAt),
    description: description ?? this.description,
    projectId: clearProject ? null : (projectId ?? this.projectId),
    attendees: attendees ?? this.attendees,
    templateId: templateId ?? this.templateId,
  );

  /// Problems the server would reject: an organizational meeting needs exactly one chair and one
  /// secretary; a scheduled one needs a start time.
  Set<MeetingIssue> issues({required bool schedule}) => {
    if (title.trim().isEmpty) MeetingIssue.titleMissing,
    if (schedule && startsAt == null) MeetingIssue.startMissing,
    if (startsAt != null && endsAt != null && endsAt!.isBefore(startsAt!))
      MeetingIssue.endBeforeStart,
    if (kind == MeetingKind.organizational) ..._roleIssues(),
  };

  Iterable<MeetingIssue> _roleIssues() sync* {
    int count(String role) => attendees.where((a) => a.role == role).length;
    if (count(AttendeeRole.chair) != 1) yield MeetingIssue.needOneChair;
    if (count(AttendeeRole.secretary) != 1) yield MeetingIssue.needOneSecretary;
  }

  static String? _iso(DateTime? d) => d?.toUtc().toIso8601String();

  Map<String, dynamic> toCreateJson({required bool schedule}) => {
    'title': title.trim(),
    'kind': kind,
    'location': location.trim(),
    'starts_at': _iso(startsAt),
    'ends_at': _iso(endsAt),
    'description': {'text': description},
    'project_id': projectId,
    'attendees': [for (final a in attendees) a.toJson()],
    'template_id': templateId,
    'status': schedule ? 'scheduled' : 'draft',
  };

  Map<String, dynamic> toPatchJson() => {
    'title': title.trim(),
    'kind': kind,
    'location': location.trim(),
    'starts_at': _iso(startsAt),
    'ends_at': _iso(endsAt),
    'description': {'text': description},
    'project_id': projectId,
  };
}

enum MeetingIssue {
  titleMissing,
  startMissing,
  endBeforeStart,
  needOneChair,
  needOneSecretary,
}
