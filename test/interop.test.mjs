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

// Dart -> JS for the E2E layer: key file, doc-key wrap, body encryption, payload signature.
const e2eFile = new URL('../test-vectors/dart-e2e.json', import.meta.url);
const skipE2e = !existsSync(e2eFile) && !required && 'run `flutter test` in app/ first';
const canonJs = (v) => JSON.stringify((function s(x) { return Array.isArray(x) ? x.map(s) : x && typeof x === 'object' ? Object.fromEntries(Object.keys(x).sort().map((k) => [k, s(x[k])])) : x; })(v));
const fromB64 = (s) => Uint8Array.from(Buffer.from(s, 'base64'));

test('JS opens Dart key file, unwraps doc key, decrypts body, verifies signature', { skip: skipE2e }, async () => {
  const d = JSON.parse(readFileSync(e2eFile, 'utf8'));
  const subtle = globalThis.crypto.subtle;
  const ident = await LC.unlockIdentity(d.keyFile, d.password);
  assert.equal(ident.fp, await LC.fingerprint(d.pub));
  const epk = await subtle.importKey('jwk', d.wrapped.epk, { name: 'ECDH', namedCurve: 'P-256' }, false, []);
  const bits = await subtle.deriveBits({ name: 'ECDH', public: epk }, ident.encKey, 256);
  const base = await subtle.importKey('raw', bits, 'HKDF', false, ['deriveKey']);
  const kek = await subtle.deriveKey({ name: 'HKDF', hash: 'SHA-256', salt: new Uint8Array(0), info: new TextEncoder().encode('letter-v1') }, base, { name: 'AES-GCM', length: 256 }, false, ['decrypt']);
  const docKey = new Uint8Array(await subtle.decrypt({ name: 'AES-GCM', iv: fromB64(d.wrapped.iv), additionalData: new TextEncoder().encode(ident.fp) }, kek, fromB64(d.wrapped.ct)));
  assert.equal(Buffer.from(docKey).toString('base64'), d.docKey);
  const bodyKey = await subtle.importKey('raw', docKey, 'AES-GCM', false, ['decrypt']);
  const pt = await subtle.decrypt({ name: 'AES-GCM', iv: fromB64(d.body.iv) }, bodyKey, fromB64(d.body.ct));
  assert.equal(new TextDecoder().decode(pt), canonJs(d.plain));
  const signed = { v: 1, type: 'signed', payload: d.payload, sig: d.sig };
  assert.equal((await LC.verifySigned(signed, d.pub)).ok, true);
});
