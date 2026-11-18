import 'package:flutter/foundation.dart';

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
    );
  }
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
    return platform.isEmpty ? 'Unknown device' : platform;
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
