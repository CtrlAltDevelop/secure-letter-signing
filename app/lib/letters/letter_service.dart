import 'package:flutter/foundation.dart';

import 'package:letter_signing/letters/letters_api.dart';
import 'package:letter_signing/letters/models.dart';

const maxAttachmentBytes = 25 * 1024 * 1024;
const attachmentTypes = {
  'application/pdf',
  'image/png',
  'image/jpeg',
  'image/webp',
  'image/heic',
};

/// A letter operation failed for a reason the UI can show verbatim.
class LetterException implements Exception {
  const LetterException(this.message);
  final String message;
  @override
  String toString() => message;
}

/// Real file name/type/size live inside the letter body; the server stores the bytes.
@immutable
class AttachmentMeta {
  const AttachmentMeta({
    required this.name,
    required this.type,
    required this.size,
  });
  final String name;
  final String type;
  final int size;

  Map<String, dynamic> toJson() => {'name': name, 'type': type, 'size': size};
  factory AttachmentMeta.fromJson(Map<String, dynamic> j) => AttachmentMeta(
    name: j['name'] as String,
    type: j['type'] as String,
    size: j['size'] as int,
  );
}

class PendingAttachment {
  const PendingAttachment({
    required this.name,
    required this.type,
    required this.bytes,
  });
  final String name;
  final String type;
  final Uint8List bytes;
  AttachmentMeta get meta =>
      AttachmentMeta(name: name, type: type, size: bytes.length);
}

/// Everything the create screen collects.
@immutable
class DraftInput {
  const DraftInput({
    required this.title,
    required this.text,
    required this.signerIds,
    this.viewerIds = const [],
    this.attachments = const [],
    this.visibility = 'private',
    this.publishMode = 'after_sign',
    this.order = 'parallel',
    this.parentId,
    this.dueAt,
    this.rich,
  });
  final String title;
  final String text;

  /// Formatting of [text] (bold, headings, alignment...), stored inside the body. Null = plain.
  final Map<String, dynamic>? rich;
  final List<int> signerIds;
  final List<int> viewerIds;
  final List<PendingAttachment> attachments;
  final String visibility;
  final String publishMode;
  final String order;
  final String? parentId;
  final DateTime? dueAt;

  bool get isPublic => visibility == 'public';
}

@immutable
class DraftSaved {
  const DraftSaved({required this.brief, required this.uploaded});
  final LetterBrief brief;

  /// How many attachments of the input are already on the server (do not upload twice).
  final int uploaded;
}

/// The readable body of a letter as the API returns it.
@immutable
class LetterContent {
  const LetterContent({
    required this.text,
    required this.attachments,
    this.rich,
  });

  factory LetterContent.fromBody(Map<String, dynamic> body) => LetterContent(
    text: (body['text'] as String?) ?? '',
    rich: body['rich'],
    attachments: [
      for (final a in (body['attachments'] as List?) ?? const [])
        AttachmentMeta.fromJson(Map<String, dynamic>.from(a as Map)),
    ],
  );

  final String text;
  final Object? rich; // raw formatting JSON, see RichDoc.fromJson
  final List<AttachmentMeta> attachments;
}

/// Create/replace drafts and upload attachments. The server encrypts at rest; the app sends plain JSON.
class LetterService {
  LetterService({required this.api, required this.userId});

  final LettersApi api;

  /// The signed-in user (creator of new letters).
  final int userId;

  static Map<String, dynamic> bodyJson(
    String text,
    List<AttachmentMeta> attachments, {
    Map<String, dynamic>? rich,
  }) => {
    'text': text,
    'attachments': [for (final a in attachments) a.toJson()],
    'rich': ?rich,
  };

  DraftPayload buildDraft(DraftInput input) => DraftPayload(
    title: input.title.trim(),
    body: bodyJson(input.text, [
      for (final a in input.attachments) a.meta,
    ], rich: input.rich),
    visibility: input.visibility,
    publishMode: input.publishMode,
    order: input.order,
    signerIds: input.signerIds,
    viewerIds: input.isPublic ? const [] : input.viewerIds,
    dueAt: input.dueAt,
    parentId: input.parentId,
  );

  static void _validate(DraftInput input) {
    for (final a in input.attachments) {
      if (!attachmentTypes.contains(a.type)) {
        throw LetterException('${a.name}: only PDF and images are allowed');
      }
      if (a.bytes.length > maxAttachmentBytes) {
        throw LetterException('${a.name} is larger than 25 MB');
      }
    }
  }

  /// Creates (or, with [letterId], replaces) a draft and uploads attachments not yet uploaded.
  Future<DraftSaved> saveDraft(
    DraftInput input, {
    String? letterId,
    int uploaded = 0,
  }) async {
    _validate(input);
    final payload = buildDraft(input);
    final brief = letterId == null
        ? await api.createDraft(payload)
        : await api.updateDraft(letterId, payload);
    for (var i = uploaded; i < input.attachments.length; i++) {
      final file = input.attachments[i];
      await api.uploadAttachment(
        brief.id,
        bytes: file.bytes,
        contentType: file.type,
        label: '$i',
      );
    }
    return DraftSaved(brief: brief, uploaded: input.attachments.length);
  }

  Future<Uint8List> downloadAttachment(String letterId, AttachmentInfo info) =>
      api.downloadAttachment(letterId, info.id);
}
