// Generates test-vectors/v1.json with the JS reference implementation (src/crypto.js).
// Dart tests read this file, so both implementations stay byte-compatible.
// Run: node test-vectors/make.mjs   (only when the crypto format changes; commit the result)
import { writeFileSync } from 'node:fs';
import { createRequire } from 'node:module';
const LC = createRequire(import.meta.url)('../src/crypto.js');
const subtle = globalThis.crypto.subtle;

const gen = (name, usage) => subtle.generateKey({ name, namedCurve: 'P-256' }, true, usage);
const sign = await gen('ECDSA', ['sign', 'verify']);
const encK = await gen('ECDH', ['deriveBits']);
const jwk = (k) => subtle.exportKey('jwk', k);
const pubJwk = (j) => ({ kty: j.kty, crv: j.crv, x: j.x, y: j.y });

const pub = { v: 1, name: 'Vector User', sign: pubJwk(await jwk(sign.publicKey)), enc: pubJwk(await jwk(encK.publicKey)) };
const priv = { sign: await jwk(sign.privateKey), enc: await jwk(encK.privateKey) };

const fp = await LC.fingerprint(pub);
const ident = { name: pub.name, fp, signKey: sign.privateKey };
const letter = { id: 'vec-1', no: '0001', subject: 'Subject é中', body: 'Body text', createdAt: '2026-01-01T00:00:00.000Z' };

const signed = await LC.signLetter(ident, { letter, decision: 'approved', note: 'ok', sigImage: '' });
const letterFile = await LC.encryptLetter(letter, pub);

writeFileSync(new URL('./v1.json', import.meta.url), JSON.stringify({ v: 1, pub, priv, fp, letter, signed, letterFile }, null, 2) + '\n');
console.log('wrote test-vectors/v1.json, fp', fp);
