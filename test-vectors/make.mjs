// Generates test-vectors/v1.json with the JS reference implementation (src/crypto.js).
// Dart tests read this file, so both implementations stay byte-compatible.
// Run: node test-vectors/make.mjs [v1|v2]   (default v2; v1 regenerates the original vectors, avoid unless the format changes)
import { writeFileSync } from 'node:fs';
import { createRequire } from 'node:module';
const LC = createRequire(import.meta.url)('../src/crypto.js');
const subtle = globalThis.crypto.subtle;

const gen = (name, usage) => subtle.generateKey({ name, namedCurve: 'P-256' }, true, usage);
const target = process.argv[2] ?? 'v2';
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

if (target === 'v1') {
  writeFileSync(new URL('./v1.json', import.meta.url), JSON.stringify({ v: 1, pub, priv, fp, letter, signed, letterFile }, null, 2) + '\n');
  console.log('wrote test-vectors/v1.json, fp', fp);
  process.exit(0);
}

// v2: key file (600000 PBKDF2 iterations), doc-key wrap, body encryption.
const password = 'Vector-Pass#2026';
const keyFile = (await LC.generateIdentity('Vector User', password)).keyFile;
const unb64 = (s) => Uint8Array.from(Buffer.from(s, 'base64'));
const b64 = (u) => Buffer.from(u).toString('base64');
const te = new TextEncoder();
const canon = (o) => JSON.stringify((function s(v) { return Array.isArray(v) ? v.map(s) : v && typeof v === 'object' ? Object.fromEntries(Object.keys(v).sort().map((k) => [k, s(v[k])])) : v; })(o));
const aesKey = async (priv, pubJ, usage) => {
  const pubK = await subtle.importKey('jwk', pubJ, { name: 'ECDH', namedCurve: 'P-256' }, false, []);
  const bits = await subtle.deriveBits({ name: 'ECDH', public: pubK }, priv, 256);
  const base = await subtle.importKey('raw', bits, 'HKDF', false, ['deriveKey']);
  return subtle.deriveKey({ name: 'HKDF', hash: 'SHA-256', salt: new Uint8Array(0), info: te.encode('letter-v1') }, base, { name: 'AES-GCM', length: 256 }, false, usage);
};
const kfp = await LC.fingerprint(keyFile.pub);
const docKey = globalThis.crypto.getRandomValues(new Uint8Array(32));
const eph = await gen('ECDH', ['deriveBits']);
const wiv = globalThis.crypto.getRandomValues(new Uint8Array(12));
const wct = await subtle.encrypt({ name: 'AES-GCM', iv: wiv, additionalData: te.encode(kfp) }, await aesKey(eph.privateKey, keyFile.pub.enc, ['encrypt']), docKey);
const wrapped = { to: kfp, epk: pubJwk(await jwk(eph.publicKey)), iv: b64(wiv), ct: b64(wct) };
const biv = globalThis.crypto.getRandomValues(new Uint8Array(12));
const bodyPlain = { subject: 'Subject é中', paragraphs: ['one', 'two'], n: 3 };
const bct = await subtle.encrypt({ name: 'AES-GCM', iv: biv }, await subtle.importKey('raw', docKey, 'AES-GCM', false, ['encrypt']), te.encode(canon(bodyPlain)));
const body = { iv: b64(biv), ct: b64(bct) };

writeFileSync(new URL('./v2.json', import.meta.url), JSON.stringify({
  v: 2, password, keyFile, pub: keyFile.pub, fp: kfp,
  docKey: b64(docKey), wrapped, bodyPlain, body,
}, null, 2) + '\n');
console.log('wrote test-vectors/v2.json');
