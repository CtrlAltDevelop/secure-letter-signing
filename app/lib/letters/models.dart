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
    required this.keyId,
    required this.fingerprint,
    required this.decision,
    required this.payload,
    required this.signature,
    required this.createdAt,
  });

  final int signerId;
  final String keyId;
  final String fingerprint;
  final String decision;
  final Map<String, dynamic> payload;
  final String signature;
  final DateTime createdAt;

  String get deviceName => (payload['deviceName'] as String?) ?? '';
  String get note => (payload['note'] as String?) ?? '';

  factory SignatureInfo.fromJson(Map<String, dynamic> j) => SignatureInfo(
    signerId: j['signer_id'] as int,
    keyId: j['key_id'] as String,
    fingerprint: j['fingerprint'] as String,
    decision: j['decision'] as String,
    payload: Map<String, dynamic>.from(j['payload'] as Map),
    signature: j['signature'] as String,
    createdAt: DateTime.parse(j['created_at'] as String),
  );
}

@immutable
class AttachmentInfo {
  const AttachmentInfo({
    required this.id,
    required this.contentType,
    required this.label,
    required this.iv,
    required this.size,
  });

  final String id;
  final String contentType;

  /// Position of the attachment in the encrypted body's `attachments` list (the server never sees real names).
  final String label;
  final String iv;
  final int size;

  factory AttachmentInfo.fromJson(Map<String, dynamic> j) => AttachmentInfo(
    id: j['id'] as String,
    contentType: j['content_type'] as String,
    label: j['label'] as String,
    iv: j['iv'] as String,
    size: j['size'] as int,
  );
}

@immutable
class WrapEntry {
  const WrapEntry({required this.keyId, required this.wrap});
  final String keyId;
  final Map<String, dynamic> wrap;

  factory WrapEntry.fromJson(Map<String, dynamic> j) => WrapEntry(
    keyId: j['key_id'] as String,
    wrap: Map<String, dynamic>.from(j['wrap'] as Map),
  );
  Map<String, dynamic> toJson() => {'key_id': keyId, 'wrap': wrap};
}

@immutable
class LetterDetail {
  const LetterDetail({
    required this.brief,
    required this.publishMode,
    required this.order,
    required this.dueAt,
    required this.body,
    required this.companyKeyVersion,
    required this.companyWrap,
    required this.participants,
    required this.signatures,
    required this.myWraps,
    required this.children,
    required this.attachments,
  });

  final LetterBrief brief;
  final String publishMode;
  final String order;
  final DateTime? dueAt;
  final Map<String, dynamic> body; // {iv, ct}
  final int? companyKeyVersion;
  final Map<String, dynamic>? companyWrap;
  final List<Participant> participants;
  final List<SignatureInfo> signatures;
  final List<WrapEntry> myWraps;
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
      companyKeyVersion: j['company_key_version'] as int?,
      companyWrap: j['company_wrap'] == null
          ? null
          : Map<String, dynamic>.from(j['company_wrap'] as Map),
      participants: list('participants', Participant.fromJson),
      signatures: list('signatures', SignatureInfo.fromJson),
      myWraps: list('my_wraps', WrapEntry.fromJson),
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
class KeyInfo {
  const KeyInfo({
    required this.id,
    required this.userId,
    required this.deviceName,
    required this.encPub,
    required this.fingerprint,
  });
  final String id;
  final int userId;
  final String deviceName;
  final Map<String, dynamic> encPub;
  final String fingerprint;

  factory KeyInfo.fromJson(Map<String, dynamic> j) => KeyInfo(
    id: j['id'] as String,
    userId: j['user_id'] as int,
    deviceName: (j['device_name'] as String?) ?? '',
    encPub: Map<String, dynamic>.from(j['enc_pub'] as Map),
    fingerprint: j['fingerprint'] as String,
  );
}

@immutable
class DirectoryUser {
  const DirectoryUser({
    required this.id,
    required this.email,
    required this.fullName,
    required this.permissions,
    required this.keys,
  });
  final int id;
  final String email;
  final String fullName;
  final List<String> permissions;
  final List<KeyInfo> keys;

  String get displayName => fullName.isEmpty ? email : fullName;
  bool get canSign => permissions.contains('letter.sign');

  factory DirectoryUser.fromJson(Map<String, dynamic> j) => DirectoryUser(
    id: j['id'] as int,
    email: j['email'] as String,
    fullName: j['full_name'] as String,
    permissions: List<String>.from(j['permissions'] as List),
    keys: [
      for (final k in j['keys'] as List)
        KeyInfo.fromJson(Map<String, dynamic>.from(k as Map)),
    ],
  );
}

/// A key some participant owns that lacks a wrapped document key (new device approved later).
@immutable
class RewrapItem {
  const RewrapItem({required this.letterId, required this.key});
  final String letterId;
  final KeyInfo key;

  factory RewrapItem.fromJson(Map<String, dynamic> j) => RewrapItem(
    letterId: j['letter_id'] as String,
    key: KeyInfo.fromJson(Map<String, dynamic>.from(j['key'] as Map)),
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
    required this.wraps,
    this.dueAt,
    this.parentId,
    this.companyKeyVersion,
    this.companyWrap,
  });
  final String title;
  final Map<String, String> body;
  final String visibility;
  final String publishMode;
  final String order;
  final List<int> signerIds;
  final List<int> viewerIds;
  final List<WrapEntry> wraps;
  final DateTime? dueAt;
  final String? parentId;
  final int? companyKeyVersion;
  final Map<String, dynamic>? companyWrap;

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
    'wraps': [for (final w in wraps) w.toJson()],
    'company_key_version': companyKeyVersion,
    'company_wrap': companyWrap,
  };
}

/// A pushed event: type 'letter' (carries `eventId`) or 'notification'.
@immutable
class LiveEvent {
  const LiveEvent(this.raw);
  final Map<String, dynamic> raw;

  String get type => (raw['type'] as String?) ?? '';
  bool get isLetter => type == 'letter';
  bool get isNotification => type == 'notification';
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
