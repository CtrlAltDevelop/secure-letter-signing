// Dart -> JS direction: a signature made by the Dart app code must verify with src/crypto.js.
// test-vectors/dart-signed.json is written by app/test/crypto_interop_test.dart (run it first; CI does).
import test from 'node:test';
import assert from 'node:assert/strict';
import { existsSync, readFileSync } from 'node:fs';
import { createRequire } from 'node:module';
const LC = createRequire(import.meta.url)('../src/crypto.js');

const dartFile = new URL('../test-vectors/dart-signed.json', import.meta.url);
const vectors = JSON.parse(readFileSync(new URL('../test-vectors/v1.json', import.meta.url), 'utf8'));
const required = process.env.REQUIRE_DART_SIGNED === '1';

test('JS verifies a signature produced by Dart', { skip: !existsSync(dartFile) && !required && 'run `flutter test` in app/ first' }, async () => {
  const signed = JSON.parse(readFileSync(dartFile, 'utf8'));
  const res = await LC.verifySigned(signed, vectors.pub);
  assert.equal(res.ok, true, res.reason);
});

test('JS rejects the Dart signature after tampering', { skip: !existsSync(dartFile) && !required && 'run `flutter test` in app/ first' }, async () => {
  const signed = JSON.parse(readFileSync(dartFile, 'utf8'));
  signed.payload.note = 'tampered';
  assert.equal((await LC.verifySigned(signed, vectors.pub)).ok, false);
});
