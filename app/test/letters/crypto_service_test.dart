import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:letter_signing/crypto/document_crypto.dart';
import 'package:letter_signing/letters/letter_crypto_service.dart';
import 'package:letter_signing/letters/models.dart';
import 'package:letter_signing/letters/rewrap_service.dart';

import 'fakes.dart';

void main() {
  final creator = FakeUser(
    1,
    'boss@x.test',
    permissions: ['letter.create', 'letter.see'],
  );
  final signerA = FakeUser(2, 'a@x.test');
  final signerB = FakeUser(3, 'b@x.test');
  final viewer = FakeUser(4, 'v@x.test');
  final outsider = FakeUser(5, 'o@x.test');
  final everyone = [creator, signerA, signerB, viewer, outsider];
  final directory = [
    for (final u in everyone) DirectoryUser.fromJson(u.directoryJson),
  ];

  LetterCryptoService service(
    ({dynamic client, dynamic api, dynamic calls}) f, {
    bool emptyCompany = false,
  }) => LetterCryptoService(
    api: f.api,
    companyKeys: FakeCompanyKeys(empty: emptyCompany),
    userId: 1,
  );

  DraftInput input({String visibility = 'private'}) => DraftInput(
    title: ' Budget ',
    text: 'secret body',
    signerIds: [2, 3],
    viewerIds: [4],
    visibility: visibility,
    attachments: [
      PendingAttachment(
        name: 'real-name.pdf',
        type: 'application/pdf',
        bytes: utf8.encode('%PDF') as dynamic,
      ),
    ],
  );

  Set<String> wrapKeyIds(DraftPayload p) => {for (final w in p.wraps) w.keyId};

  test('private letter: wraps for creator, signers and viewers only; no company wrap', () async {
    final f = fakeApi((_, _) => json({}));
    final p = await service(f).buildDraft(input(), newDocKey(), directory);
    expect(wrapKeyIds(p), {
      creator.keyId,
      signerA.keyId,
      signerB.keyId,
      viewer.keyId,
    });
    expect(p.companyWrap, isNull);
    expect(p.companyKeyVersion, isNull);
    expect(p.viewerIds, [4]);
    expect(p.title, 'Budget');
  });

  test('public letter: no viewers, wraps for creator+signers, company wrap present', () async {
    final f = fakeApi((_, _) => json({}));
    final p = await service(f).buildDraft(
      input(visibility: 'public'),
      newDocKey(),
      directory,
      key: creator.unlocked,
    );
    expect(wrapKeyIds(p), {creator.keyId, signerA.keyId, signerB.keyId});
    expect(p.viewerIds, isEmpty);
    expect(p.companyKeyVersion, 1);
    expect(p.companyWrap, isNotNull);
  });

  test('public letter needs an unlocked key and a company key', () async {
    final f = fakeApi((_, _) => json({}));
    expect(
      service(f)
          .buildDraft(input(visibility: 'public'), newDocKey(), directory),
      throwsA(isA<LetterException>()),
    );
    expect(
      service(f, emptyCompany: true).buildDraft(
        input(visibility: 'public'),
        newDocKey(),
        directory,
        key: creator.unlocked,
      ),
      throwsA(isA<LetterException>()),
    );
  });

  test('every wrap opens with its recipient key, body and real filename stay inside the ciphertext', () async {
    final f = fakeApi((_, _) => json({}));
    final svc = service(f);
    final docKey = newDocKey();
    final p = await svc.buildDraft(input(), docKey, directory);
    expect(jsonEncode(p.toJson()).contains('real-name'), isFalse);
    expect(jsonEncode(p.toJson()).contains('secret body'), isFalse);
    final brief = briefJson('L1');
    for (final u in [creator, signerA, signerB, viewer]) {
      final mine = p.wraps.firstWhere((w) => w.keyId == u.keyId);
      final detail = LetterDetail.fromJson(
        detailJson(brief, body: p.body, myWraps: [mine.toJson()]),
      );
      final plain = await svc.open(detail, u.unlocked);
      expect(plain.text, 'secret body');
      expect(plain.attachments.single.name, 'real-name.pdf');
    }
  });

  test('public letters can be read through the company key without a personal wrap', () async {
    final f = fakeApi((_, _) => json({}));
    final svc = service(f);
    final p = await svc.buildDraft(
      input(visibility: 'public'),
      newDocKey(),
      directory,
      key: creator.unlocked,
    );
    final detail = LetterDetail.fromJson(
      detailJson(
        briefJson('L1', visibility: 'public'),
        body: p.body,
        companyWrap: p.companyWrap,
      ),
    );
    expect((await svc.open(detail, outsider.unlocked)).text, 'secret body');
  });

  test('a device without a wrap gets a clear error', () async {
    final f = fakeApi((_, _) => json({}));
    final svc = service(f);
    final p = await svc.buildDraft(input(), newDocKey(), directory);
    final detail = LetterDetail.fromJson(
      detailJson(briefJson('L1'), body: p.body),
    );
    expect(
      svc.open(detail, outsider.unlocked),
      throwsA(isA<LetterException>()),
    );
  });

  test(
    'send retries after adding wraps on 409 Missing document-key wraps',
    () async {
      final docKey = newDocKey();
      var sends = 0;
      Map<String, dynamic>? posted;
      final f = fakeApi((req, body) {
        final path = req.url.path;
        if (path == '/api/letters/L1/send') {
          sends++;
          return sends == 1
              ? json({
                  'detail': 'Missing document-key wraps for: ${signerB.keyId}',
                }, 409)
              : json(briefJson('L1', status: 'in_signing'));
        }
        if (path == '/api/keys/directory') {
          return json([for (final u in everyone) u.directoryJson]);
        }
        if (path == '/api/letters/L1/wraps') {
          posted = {'wraps': jsonDecode(req.body)};
          return json({'detail': 'Stored'});
        }
        return json({});
      });
      final sent = await service(f).send('L1', docKey: docKey);
      expect(sent.status, 'in_signing');
      expect(sends, 2);
      final wraps = posted!['wraps'] as List;
      expect(wraps.map((w) => (w as Map)['key_id']), [signerB.keyId]);
    },
  );

  test('rewrap wraps the doc key for each missing key from enc_pub', () async {
    final docKey = newDocKey();
    final svc0 = service(fakeApi((_, _) => json({})));
    final p = await svc0.buildDraft(input(), docKey, directory);
    final mine = p.wraps.firstWhere((w) => w.keyId == signerA.keyId);
    List<dynamic>? posted;
    final f = fakeApi((req, body) {
      final path = req.url.path;
      if (path == '/api/letters/rewrap-needed') {
        return json([
          {'letter_id': 'L1', 'key': outsider.directoryJson['keys'][0]},
        ]);
      }
      if (path == '/api/letters/L1') {
        return json(
          detailJson(
            briefJson('L1', status: 'in_signing'),
            body: p.body,
            myWraps: [mine.toJson()],
          ),
        );
      }
      if (path == '/api/letters/L1/wraps') {
        posted = jsonDecode(req.body) as List;
        return json({'detail': 'Stored'});
      }
      return json({});
    });
    final svc = service(f);
    final result = await RewrapService(
      api: f.api,
      crypto: svc,
    ).run(signerA.unlocked);
    expect(result.done, 1);
    expect(result.failed, isEmpty);
    final wrapped = Map<String, dynamic>.from(
      (posted!.single as Map)['wrap'] as Map,
    );
    expect(
      unwrapDocKey(wrapped, outsider.identity.encJwk, outsider.identity.fp),
      docKey,
    );
  });
}
