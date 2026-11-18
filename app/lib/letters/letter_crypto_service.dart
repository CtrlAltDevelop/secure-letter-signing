import 'dart:convert';

import 'package:flutter/foundation.dart';

import 'package:letter_signing/api/api_client.dart';
import 'package:letter_signing/crypto/crypto_primitives.dart';
import 'package:letter_signing/crypto/document_crypto.dart';
import 'package:letter_signing/keys/key_vault.dart';
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
const _missingWraps = 'Missing document-key wraps';

/// A letter operation failed for a reason the UI can show verbatim.
class LetterException implements Exception {
  const LetterException(this.message);
  final String message;
  @override
  String toString() => message;
}

/// Real file name/type/size live only inside the encrypted body.
@immutable
class AttachmentMeta {
  const AttachmentMeta({required this.name, required this.type, required this.size});
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
  const PendingAttachment({required this.name, required this.type, required this.bytes});
  final String name;
  final String type;
  final Uint8List bytes;
  AttachmentMeta get meta => AttachmentMeta(name: name, type: type, size: bytes.length);
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
  });
  final String title;
  final String text;
  final List<int> signerIds;
  final List<int> viewerIds;
  final List<PendingAttachment> attachments;
  final String visibility;
  final String publishMode;
  final String order;
  final String? parentId;
  final DateTime? dueAt;

  bool get isPublic => visibility == 'public';

  /// Users whose active keys must hold a wrapped document key (server `rules.readers_ids`).
  Set<int> readerIds(int creatorId) => {
    creatorId,
    ...signerIds,
    if (!isPublic) ...viewerIds,
  };
}

@immutable
class DraftSaved {
  const DraftSaved({required this.brief, required this.docKey, required this.uploaded});
  final LetterBrief brief;
  final Uint8List docKey;

  /// How many attachments of the input are already on the server (do not upload twice).
  final int uploaded;
}

@immutable
class DecryptedLetter {
  const DecryptedLetter({required this.text, required this.attachments, required this.docKey});
  final String text;
  final List<AttachmentMeta> attachments;
  final Uint8List docKey;
}

/// Encrypt/wrap on create, unwrap/decrypt on read, attachments. The server only ever gets ciphertext.
class LetterCryptoService {
  LetterCryptoService({required this.api, required this.companyKeys, required this.userId});

  final LettersApi api;
  final CompanyKeys companyKeys;

  /// The signed-in user (creator of new letters).
  final int userId;

  static Map<String, dynamic> bodyJson(String text, List<AttachmentMeta> attachments) => {
    'text': text,
    'attachments': [for (final a in attachments) a.toJson()],
  };

  /// One wrap per active key of [users] (optionally only [onlyKeyIds]).
  static List<WrapEntry> wrapsFor(
    Uint8List docKey,
    Iterable<DirectoryUser> users, {
    Set<String>? onlyKeyIds,
  }) => [
    for (final u in users)
      for (final k in u.keys)
        if (onlyKeyIds == null || onlyKeyIds.contains(k.id))
          WrapEntry(keyId: k.id, wrap: wrapDocKey(docKey, k.encPub, k.fingerprint)),
  ];

  /// Builds the request for a draft: encrypts the body and wraps for every reader (+ company key if public).
  Future<DraftPayload> buildDraft(
    DraftInput input,
    Uint8List docKey,
    List<DirectoryUser> directory, {
    UnlockedKey? key,
  }) async {
    final readers = input.readerIds(userId);
    final wraps = wrapsFor(docKey, directory.where((u) => readers.contains(u.id)));
    ({int version, Map<String, dynamic> wrap})? company;
    if (input.isPublic) {
      if (key == null) throw const LetterException('Unlock your key to publish a public letter');
      company = await companyKeys.wrapForCompany(docKey, key);
      if (company == null) throw const LetterException('No company key exists yet');
    }
    return DraftPayload(
      title: input.title.trim(),
      body: encryptJson(
        bodyJson(input.text, [for (final a in input.attachments) a.meta]),
        docKey,
      ),
      visibility: input.visibility,
      publishMode: input.publishMode,
      order: input.order,
      signerIds: input.signerIds,
      viewerIds: input.isPublic ? const [] : input.viewerIds,
      wraps: wraps,
      dueAt: input.dueAt,
      parentId: input.parentId,
      companyKeyVersion: company?.version,
      companyWrap: company?.wrap,
    );
  }

  /// Creates (or, with [letterId]+[docKey], replaces) a draft and uploads attachments not yet uploaded.
  Future<DraftSaved> saveDraft(
    DraftInput input, {
    String? letterId,
    Uint8List? docKey,
    int uploaded = 0,
    UnlockedKey? key,
  }) async {
    for (final a in input.attachments) {
      if (!attachmentTypes.contains(a.type)) {
        throw LetterException('${a.name}: only PDF and images are allowed');
      }
      if (a.bytes.length > maxAttachmentBytes) {
        throw LetterException('${a.name} is larger than 25 MB');
      }
    }
    final dk = docKey ?? newDocKey();
    final payload = await buildDraft(input, dk, await api.directory(), key: key);
    final brief = letterId == null
        ? await api.createDraft(payload)
        : await api.updateDraft(letterId, payload);
    for (var i = uploaded; i < input.attachments.length; i++) {
      await uploadAttachment(brief.id, input.attachments[i], dk, i);
    }
    return DraftSaved(brief: brief, docKey: dk, uploaded: input.attachments.length);
  }

  Future<AttachmentInfo> uploadAttachment(
    String letterId,
    PendingAttachment file,
    Uint8List docKey,
    int index,
  ) {
    final iv = randomBytes(12);
    return api.uploadAttachment(
      letterId,
      cipher: aesGcm(true, docKey, iv, file.bytes),
      iv: base64Encode(iv),
      contentType: file.type,
      label: '$index',
    );
  }

  /// Plaintext bytes of attachment [info] (decrypted in the app).
  Future<Uint8List> downloadAttachment(String letterId, AttachmentInfo info, Uint8List docKey) async {
    final cipher = await api.downloadAttachment(letterId, info.id);
    return aesGcm(false, docKey, base64Decode(info.iv), cipher);
  }

  /// Sends a draft. On 409 "Missing document-key wraps" (a key was approved since) adds those wraps and retries once.
  /// [docKey] is known right after creating; otherwise [key] is used to unwrap it.
  Future<LetterBrief> send(String letterId, {Uint8List? docKey, UnlockedKey? key}) async {
    try {
      return await api.send(letterId);
    } on ApiException catch (e) {
      if (e.status != 409 || !e.message.startsWith(_missingWraps)) rethrow;
      final missing = e.message.split(':').skip(1).join(':').split(',').map((s) => s.trim()).toSet();
      final detail = await api.detail(letterId);
      final dk = docKey ?? (key == null ? null : (await open(detail, key)).docKey);
      if (dk == null) throw const LetterException('Unlock your key to finish sending');
      final wraps = wrapsFor(dk, await api.directory(), onlyKeyIds: missing);
      if (wraps.isEmpty) throw const LetterException('A reader has no usable key for this letter');
      await api.addWraps(letterId, wraps);
      return api.send(letterId);
    }
  }

  /// Unwraps the document key (this device's wrap, else the company key for public letters) and decrypts the body.
  Future<DecryptedLetter> open(LetterDetail letter, UnlockedKey key) async {
    final docKey = await documentKey(letter, key);
    final body = decryptJson(letter.body, docKey) as Map<String, dynamic>;
    return DecryptedLetter(
      text: (body['text'] as String?) ?? '',
      attachments: [
        for (final a in (body['attachments'] as List?) ?? const [])
          AttachmentMeta.fromJson(Map<String, dynamic>.from(a as Map)),
      ],
      docKey: docKey,
    );
  }

  Future<Uint8List> documentKey(LetterDetail letter, UnlockedKey key) async {
    for (final w in letter.myWraps) {
      if (w.keyId == key.keyId) return unwrapDocKey(w.wrap, key.identity.encJwk, key.identity.fp);
    }
    final version = letter.companyKeyVersion;
    final wrap = letter.companyWrap;
    if (version != null && wrap != null) {
      final companyKey = await companyKeys.get(version, key);
      if (companyKey != null) return decryptBytes(wrap, companyKey);
    }
    throw const LetterException('This device cannot read the letter yet. Ask a participant to re-wrap it.');
  }
}
