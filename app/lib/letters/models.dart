import 'package:flutter/foundation.dart';

import 'package:letter_signing/l10n/tr.dart';
import 'package:letter_signing/tasks/models.dart' show TaskBrief;
import 'package:letter_signing/workspace/models.dart'
    show UserRef, asInt, asIntList, asMap, asMapList, asString, parseDate;

DateTime? _date(Object? v) => v == null ? null : DateTime.parse(v as String);

/// Letter states as the server sends them.
abstract final class LetterStatus {
  static const draft = 'draft';
  static const inSigning = 'in_signing';
  static const published = 'published';
  static const rejected = 'rejected';
  static const cancelled = 'cancelled';
  static const all = [draft, inSigning, published, rejected, cancelled];
}

@immutable
class LetterBrief {
  const LetterBrief({
    required this.id,
    required this.no,
    required this.title,
    required this.status,
    required this.creatorId,
    required this.parentId,
    required this.visibility,
    required this.unlisted,
    required this.createdAt,
    required this.sentAt,
    this.subjectId,
    this.labelIds = const [],
    this.numberLabel = '',
    this.referralCount = 0,
    this.archived = false,
  });

  final String id;
  final int no;
  final String title;
  final String status;
  final int creatorId;
  final String? parentId;
  final String visibility;
  final bool unlisted;
  final DateTime createdAt;
  final DateTime? sentAt;

  /// Workspace anchor (labels, comments, files); null on an older server.
  final String? subjectId;
  final List<int> labelIds;

  /// Secretariat number such as `1405/0012`; empty until registered.
  final String numberLabel;
  final int referralCount;

  /// Archived by the caller (a per-user mark).
  final bool archived;

  LetterBrief copyWith({List<int>? labelIds, bool? archived}) => LetterBrief(
    id: id,
    no: no,
    title: title,
    status: status,
    creatorId: creatorId,
    parentId: parentId,
    visibility: visibility,
    unlisted: unlisted,
    createdAt: createdAt,
    sentAt: sentAt,
    subjectId: subjectId,
    labelIds: labelIds ?? this.labelIds,
    numberLabel: numberLabel,
    referralCount: referralCount,
    archived: archived ?? this.archived,
  );

  factory LetterBrief.fromJson(Map<String, dynamic> j) => LetterBrief(
    id: j['id'] as String,
    no: j['no'] as int,
    title: j['title'] as String,
    status: j['status'] as String,
    creatorId: j['creator_id'] as int,
    parentId: j['parent_id'] as String?,
    visibility: j['visibility'] as String,
    unlisted: j['unlisted'] as bool,
    createdAt: DateTime.parse(j['created_at'] as String),
    sentAt: _date(j['sent_at']),
    subjectId: j['subject_id'] as String?,
    labelIds: asIntList(j['label_ids']),
    numberLabel: asString(j['number_label']),
    referralCount: asInt(j['referral_count']) ?? 0,
    archived: j['archived'] == true,
  );
}

@immutable
class Participant {
  const Participant({
    required this.userId,
    required this.email,
    required this.fullName,
    required this.role,
    required this.position,
    required this.decision,
    required this.decidedAt,
  });

  final int userId;
  final String email;
  final String fullName;
  final String role; // signer | viewer
  final int position;
  final String decision; // '' | approved | rejected
  final DateTime? decidedAt;

  String get displayName => fullName.isEmpty ? email : fullName;

  factory Participant.fromJson(Map<String, dynamic> j) => Participant(
    userId: j['user_id'] as int,
    email: j['email'] as String,
    fullName: j['full_name'] as String,
    role: j['role'] as String,
    position: j['position'] as int,
    decision: j['decision'] as String,
    decidedAt: _date(j['decided_at']),
  );
}

@immutable
class SignatureInfo {
  const SignatureInfo({
    required this.signerId,
    required this.decision,
    required this.note,
    required this.method,
    required this.deviceName,
    required this.signedAt,
    required this.seal,
    required this.payload,
  });

  final int signerId;
  final String decision;
  final String note;

  /// `pin` or `biometric`.
  final String method;
  final String deviceName;
  final DateTime? signedAt;

  /// Base64 Ed25519 seal the server put on the payload.
  final String seal;
  final Map<String, dynamic> payload;

  String get contentHash => (payload['contentHash'] as String?) ?? '';

  factory SignatureInfo.fromJson(Map<String, dynamic> j) => SignatureInfo(
    signerId: j['signer_id'] as int,
    decision: j['decision'] as String,
    note: (j['note'] as String?) ?? '',
    method: (j['method'] as String?) ?? '',
    deviceName: (j['device_name'] as String?) ?? '',
    signedAt: _date(j['signed_at']),
    seal: (j['seal'] as String?) ?? '',
    payload: Map<String, dynamic>.from((j['payload'] as Map?) ?? const {}),
  );
}

@immutable
class AttachmentInfo {
  const AttachmentInfo({
    required this.id,
    required this.contentType,
    required this.label,
    required this.size,
  });

  final String id;
  final String contentType;

  /// Position of the attachment in the body's `attachments` list.
  final String label;
  final int size;

  factory AttachmentInfo.fromJson(Map<String, dynamic> j) => AttachmentInfo(
    id: j['id'] as String,
    contentType: j['content_type'] as String,
    label: j['label'] as String,
    size: j['size'] as int,
  );
}

@immutable
class LetterDetail {
  const LetterDetail({
    required this.brief,
    required this.publishMode,
    required this.order,
    required this.dueAt,
    required this.body,
    required this.participants,
    required this.signatures,
    required this.children,
    required this.attachments,
    this.paraphs = const [],
    this.tasks = const [],
    this.customerRefs = const [],
  });

  final LetterBrief brief;
  final String publishMode;
  final String order;
  final DateTime? dueAt;
  final Map<String, dynamic> body; // plaintext {text, rich?, attachments?}
  final List<Participant> participants;
  final List<SignatureInfo> signatures;
  final List<LetterBrief> children;
  final List<AttachmentInfo> attachments;
  final List<ParaphInfo> paraphs;

  /// Linked tasks the caller may see.
  final List<TaskBrief> tasks;
  final List<String> customerRefs;

  String get id => brief.id;
  String get title => brief.title;
  String get status => brief.status;

  Iterable<Participant> get signers =>
      participants.where((p) => p.role == 'signer');
  Iterable<Participant> get viewers =>
      participants.where((p) => p.role == 'viewer');

  factory LetterDetail.fromJson(Map<String, dynamic> j) {
    List<T> list<T>(String k, T Function(Map<String, dynamic>) f) => [
      for (final e in j[k] as List) f(Map<String, dynamic>.from(e as Map)),
    ];
    return LetterDetail(
      brief: LetterBrief.fromJson(j),
      publishMode: j['publish_mode'] as String,
      order: j['order'] as String,
      dueAt: _date(j['due_at']),
      body: Map<String, dynamic>.from(j['body'] as Map),
      participants: list('participants', Participant.fromJson),
      signatures: list('signatures', SignatureInfo.fromJson),
      children: list('children', LetterBrief.fromJson),
      attachments: list('attachments', AttachmentInfo.fromJson),
      paraphs: [
        for (final e in asMapList(j['paraphs'])) ParaphInfo.fromJson(e),
      ],
      tasks: [for (final e in asMapList(j['tasks'])) TaskBrief.fromJson(e)],
      customerRefs: [
        if (j['customer_refs'] is List)
          for (final e in j['customer_refs'] as List) '$e',
      ],
    );
  }
}

/// A sealed initial of one participant on a letter (`ParaphOut`).
@immutable
class ParaphInfo {
  const ParaphInfo({
    required this.signerId,
    required this.signerName,
    required this.method,
    required this.deviceName,
    required this.paraphedAt,
    this.seal = '',
  });

  final int signerId;
  final String signerName;

  /// `pin` or `biometric`.
  final String method;
  final String deviceName;
  final DateTime? paraphedAt;
  final String seal;

  factory ParaphInfo.fromJson(Map<String, dynamic> j) => ParaphInfo(
    signerId: asInt(j['signer_id']) ?? 0,
    signerName: asString(j['signer_name']),
    method: asString(j['method']),
    deviceName: asString(j['device_name']),
    paraphedAt: parseDate(j['paraphed_at']),
    seal: asString(j['seal']),
  );
}

/// One referral of a letter to a colleague (`ReferralOut`).
@immutable
class ReferralInfo {
  const ReferralInfo({
    required this.id,
    required this.letterId,
    required this.fromUser,
    required this.toUser,
    required this.note,
    required this.status,
    required this.responseNote,
    this.createdAt,
    this.respondedAt,
  });

  static const pending = 'pending';
  static const done = 'done';
  static const declined = 'declined';

  final int id;
  final String letterId;
  final UserRef fromUser;
  final UserRef toUser;
  final String note;
  final String status;
  final String responseNote;
  final DateTime? createdAt;
  final DateTime? respondedAt;

  bool get isPending => status == pending;

  factory ReferralInfo.fromJson(Map<String, dynamic> j) => ReferralInfo(
    id: asInt(j['id']) ?? 0,
    letterId: asString(j['letter_id']),
    fromUser: UserRef.maybe(j['from_user']) ?? const UserRef(id: 0),
    toUser: UserRef.maybe(j['to_user']) ?? const UserRef(id: 0),
    note: asString(asMap(j['note'])['text']),
    status: asString(j['status'], pending),
    responseNote: asString(asMap(j['response_note'])['text']),
    createdAt: parseDate(j['created_at']),
    respondedAt: parseDate(j['responded_at']),
  );
}

/// One row of the secretariat register (`EntryOut`).
@immutable
class SecretariatEntry {
  const SecretariatEntry({
    required this.id,
    required this.subjectId,
    required this.direction,
    required this.number,
    required this.title,
    this.partyName = '',
    this.partyRef = '',
    this.letterId,
    this.summary = '',
    this.customerRefs = const [],
    this.labelIds = const [],
    this.registeredBy = const UserRef(id: 0),
    this.registeredAt,
  });

  static const incoming = 'in';
  static const outgoing = 'out';

  final String id;
  final String subjectId;

  /// `in` or `out`.
  final String direction;

  /// `1405/0012`.
  final String number;
  final String title;
  final String partyName;
  final String partyRef;
  final String? letterId;
  final String summary;
  final List<String> customerRefs;
  final List<int> labelIds;
  final UserRef registeredBy;
  final DateTime? registeredAt;

  bool get isIncoming => direction == incoming;

  factory SecretariatEntry.fromJson(Map<String, dynamic> j) => SecretariatEntry(
    id: asString(j['id']),
    subjectId: asString(j['subject_id']),
    direction: asString(j['direction'], incoming),
    number: asString(j['number']),
    title: asString(j['title']),
    partyName: asString(j['party_name']),
    partyRef: asString(j['party_ref']),
    letterId: j['letter_id'] as String?,
    summary: asString(asMap(j['summary'])['text']),
    customerRefs: [
      if (j['customer_refs'] is List)
        for (final e in j['customer_refs'] as List) '$e',
    ],
    labelIds: asIntList(j['label_ids']),
    registeredBy: UserRef.maybe(j['registered_by']) ?? const UserRef(id: 0),
    registeredAt: parseDate(j['registered_at']),
  );
}

@immutable
class AdminLetter {
  const AdminLetter({
    required this.brief,
    required this.creatorEmail,
    required this.participants,
  });
  final LetterBrief brief;
  final String creatorEmail;
  final List<Participant> participants;

  factory AdminLetter.fromJson(Map<String, dynamic> j) => AdminLetter(
    brief: LetterBrief.fromJson(j),
    creatorEmail: j['creator_email'] as String,
    participants: [
      for (final p in j['participants'] as List)
        Participant.fromJson(Map<String, dynamic>.from(p as Map)),
    ],
  );
}

@immutable
class DirectoryUser {
  const DirectoryUser({
    required this.id,
    required this.email,
    required this.fullName,
    required this.permissions,
  });
  final int id;
  final String email;
  final String fullName;
  final List<String> permissions;

  String get displayName => fullName.isEmpty ? email : fullName;
  bool get canSign => permissions.contains('letter.sign');

  factory DirectoryUser.fromJson(Map<String, dynamic> j) => DirectoryUser(
    id: j['id'] as int,
    email: j['email'] as String,
    fullName: j['full_name'] as String,
    permissions: List<String>.from(j['permissions'] as List),
  );
}

@immutable
class AppNotification {
  const AppNotification({
    required this.id,
    required this.kind,
    required this.title,
    required this.data,
    required this.at,
    required this.read,
  });
  final int id;
  final String kind;
  final String title;
  final Map<String, dynamic> data;
  final DateTime? at;
  final bool read;

  String? get letterId => data['letter_id'] as String?;

  AppNotification markRead() => AppNotification(
    id: id,
    kind: kind,
    title: title,
    data: data,
    at: at,
    read: true,
  );

  factory AppNotification.fromJson(Map<String, dynamic> j) => AppNotification(
    id: j['id'] as int,
    kind: j['kind'] as String,
    title: j['title'] as String,
    data: Map<String, dynamic>.from((j['data'] as Map?) ?? const {}),
    at: _date(j['at']),
    read: (j['read'] as bool?) ?? false,
  );
}

/// What the app sends to create/replace a draft.
@immutable
class DraftPayload {
  const DraftPayload({
    required this.title,
    required this.body,
    required this.visibility,
    required this.publishMode,
    required this.order,
    required this.signerIds,
    required this.viewerIds,
    this.dueAt,
    this.parentId,
  });
  final String title;
  final Map<String, dynamic> body;
  final String visibility;
  final String publishMode;
  final String order;
  final List<int> signerIds;
  final List<int> viewerIds;
  final DateTime? dueAt;
  final String? parentId;

  Map<String, dynamic> toJson() => {
    'title': title,
    'body': body,
    'visibility': visibility,
    'publish_mode': publishMode,
    'order': order,
    'due_at': dueAt?.toUtc().toIso8601String(),
    'parent_id': parentId,
    'signer_ids': signerIds,
    'viewer_ids': viewerIds,
  };
}

/// A request to approve a signature on another device (`SignRequestOut`).
@immutable
class SignRequest {
  const SignRequest({
    required this.id,
    required this.letterId,
    required this.letterTitle,
    required this.decision,
    required this.note,
    required this.status,
    required this.requesterSessionId,
    required this.requesterDeviceName,
    required this.approverSessionId,
    required this.createdAt,
    required this.expiresAt,
    this.resolvedAt,
  });

  static const pending = 'pending';
  static const approved = 'approved';
  static const declined = 'declined';
  static const cancelled = 'cancelled';
  static const expired = 'expired';

  final String id;
  final String letterId;
  final String letterTitle;
  final String decision;
  final String note;
  final String status;
  final String requesterSessionId;
  final String requesterDeviceName;
  final String approverSessionId;
  final DateTime createdAt;
  final DateTime expiresAt;
  final DateTime? resolvedAt;

  bool get isPending => status == pending;
  bool get isApproved => status == approved;

  factory SignRequest.fromJson(Map<String, dynamic> j) => SignRequest(
    id: '${j['id']}',
    letterId: '${j['letter_id']}',
    letterTitle: (j['letter_title'] as String?) ?? '',
    decision: j['decision'] as String,
    note: (j['note'] as String?) ?? '',
    status: j['status'] as String,
    requesterSessionId: '${j['requester_session_id'] ?? ''}',
    requesterDeviceName: (j['requester_device_name'] as String?) ?? '',
    approverSessionId: '${j['approver_session_id'] ?? ''}',
    createdAt: DateTime.parse(j['created_at'] as String),
    expiresAt: DateTime.parse(j['expires_at'] as String),
    resolvedAt: _date(j['resolved_at']),
  );
}

/// One signed-in device of the user (`SessionOut`).
@immutable
class SessionInfo {
  const SessionInfo({
    required this.id,
    required this.deviceName,
    required this.platform,
    required this.ip,
    required this.lastActive,
    required this.current,
    required this.biometric,
  });

  final String id;
  final String deviceName;
  final String platform;
  final String ip;
  final String lastActive;
  final bool current;
  final bool biometric;

  String get displayName {
    if (deviceName.isNotEmpty) return deviceName;
    return platform.isEmpty ? tr.sessionsUnknownDevice : platform;
  }

  factory SessionInfo.fromJson(Map<String, dynamic> j) => SessionInfo(
    id: '${j['id']}',
    deviceName: '${j['device_name'] ?? ''}',
    platform: '${j['platform'] ?? ''}',
    ip: '${j['ip'] ?? ''}',
    lastActive: '${j['last_active'] ?? ''}',
    current: j['current'] == true,
    biometric: j['biometric'] == true,
  );
}

/// A pushed event: 'letter' / 'notification' (carry `eventId`) or a session-targeted 'sign_request' frame.
@immutable
class LiveEvent {
  const LiveEvent(this.raw);
  final Map<String, dynamic> raw;

  String get type => (raw['type'] as String?) ?? '';
  bool get isLetter => type == 'letter';
  bool get isNotification => type == 'notification';
  bool get isSignRequest => type == 'sign_request';
  bool get isSignRequestUpdate => type == 'sign_request_update';

  /// A workspace (tasks/projects) frame: `{"type": "ws", "stream": "w", ...}`.
  bool get isWorkspace => type == 'ws' && raw['stream'] == 'w';

  /// The request carried by a `sign_request` / `sign_request_update` frame.
  SignRequest? get request {
    final r = raw['request'];
    if (!(isSignRequest || isSignRequestUpdate) || r is! Map) return null;
    return SignRequest.fromJson(Map<String, dynamic>.from(r));
  }

  int? get eventId => raw['event_id'] as int?;
  String? get letterId => raw['letter_id'] as String?;
  String get kind => (raw['kind'] as String?) ?? '';
  int? get actorId => raw['actor_id'] as int?;
  String get title => (raw['title'] as String?) ?? '';

  AppNotification? toNotification() => isNotification
      ? AppNotification(
          id: raw['id'] as int,
          kind: kind,
          title: title,
          data: Map<String, dynamic>.from((raw['data'] as Map?) ?? const {}),
          at: DateTime.now(),
          read: false,
        )
      : null;
}
