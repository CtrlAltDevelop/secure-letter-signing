import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:letter_signing/crypto/document_crypto.dart';
import 'package:letter_signing/letters/sign_payload.dart';

import 'fakes.dart';

void main() {
  const body = {'iv': 'YWE=', 'ct': 'YmI='};

  test('contentHash is sha256 hex of canonical {iv, ct} (server vector)', () {
    expect(
      contentHashOf(body),
      '0585004302cd89b872d2358e97807cf245a13d26b5dd0ed0e100a205badbcc93',
    );
    expect(contentHashOf({...body, 'extra': 1}), contentHashOf(body));
  });

  test('payload has exactly the keys the server checks and verifies', () {
    final user = FakeUser(5, 'a@x.test');
    final payload = buildSignPayload(
      letterId: 'L1',
      title: 'Budget',
      parentId: null,
      body: body,
      decision: 'approved',
      note: 'ok',
      userId: user.id,
      keyId: user.keyId,
      fingerprint: user.identity.fp,
      sessionId: 'S1',
      deviceName: 'phone',
      now: DateTime.utc(2026, 1, 2, 3, 4, 5, 678),
    );
    expect(payload.keys.toSet(), {
      'letterId',
      'title',
      'parentId',
      'decision',
      'note',
      'contentHash',
      'signer',
      'sessionId',
      'deviceName',
      'signedAt',
      'nonce',
    });
    expect(payload['parentId'], isNull);
    expect(payload['signer'], {
      'userId': 5,
      'keyId': user.keyId,
      'fp': user.identity.fp,
    });
    expect(payload['signedAt'], '2026-01-02T03:04:05+00:00');
    expect((payload['nonce'] as String).length, greaterThanOrEqualTo(16));
    expect(RegExp(r'^[0-9a-f]+$').hasMatch(payload['nonce'] as String), isTrue);
    final sig = signDecision(payload, user.unlocked);
    expect(
      verifyPayload(
        payload,
        sig,
        user.identity.publicFile['sign'] as Map<String, dynamic>,
      ),
      isTrue,
    );
  });

  test('parentId of a chained letter is carried in the payload', () {
    final payload = buildSignPayload(
      letterId: 'L2',
      title: 't',
      parentId: 'P',
      body: body,
      decision: 'rejected',
      note: '',
      userId: 1,
      keyId: 'k',
      fingerprint: 'f',
      sessionId: 's',
      deviceName: '',
    );
    expect(payload['parentId'], 'P');
  });

  test('nonces are unique', () => expect(newNonce() == newNonce(), isFalse));

  test('session id is read from plain and zlib-compressed access tokens', () {
    String b64(List<int> b) => base64Url.encode(b).replaceAll('=', '');
    final raw = utf8.encode('{"s":"abc-123"}');
    expect(sessionIdFromAccessToken('${b64(raw)}:1abc:sig'), 'abc-123');
    expect(
      sessionIdFromAccessToken('.${b64(zlib.encode(raw))}:1abc:sig'),
      'abc-123',
    );
    expect(sessionIdFromAccessToken('garbage'), isNull);
    expect(sessionIdFromAccessToken(null), isNull);
  });
}
