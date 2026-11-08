import test from 'node:test';
import assert from 'node:assert/strict';
import { createRequire } from 'node:module';
const LC = createRequire(import.meta.url)('../src/crypto.js');

const letter = { id: 'x1', no: '1405/08/17-0001', date: '1405/08/17', subject: 'موضوع', body: 'متن نامه' };

async function setup() {
  const { keyFile, pubFile } = await LC.generateIdentity('مدیر', 'correct horse');
  const ident = await LC.unlockIdentity(keyFile, 'correct horse');
  return { keyFile, pubFile, ident };
}

test('letter encrypts to manager and decrypts back', async () => {
  const { pubFile, ident } = await setup();
  const file = await LC.encryptLetter(letter, pubFile);
  assert.ok(!JSON.stringify(file).includes('متن نامه'));
  assert.deepEqual(await LC.decryptLetter(file, ident), letter);
});

test('wrong password cannot unlock key file', async () => {
  const { keyFile } = await setup();
  await assert.rejects(LC.unlockIdentity(keyFile, 'wrong'));
});

test('tampered ciphertext is rejected', async () => {
  const { pubFile, ident } = await setup();
  const file = await LC.encryptLetter(letter, pubFile);
  const bytes = Buffer.from(file.ct, 'base64'); bytes[0] ^= 1;
  await assert.rejects(LC.decryptLetter({ ...file, ct: bytes.toString('base64') }, ident));
});

test('letter for another manager cannot be opened', async () => {
  const { pubFile } = await setup();
  const other = await setup();
  await assert.rejects(LC.decryptLetter(await LC.encryptLetter(letter, pubFile), other.ident));
});

test('signed letter verifies and any edit breaks it', async () => {
  const { pubFile, ident } = await setup();
  const signed = await LC.signLetter(ident, { letter, decision: 'approved', note: 'ok', sigImage: 'data:image/png;base64,AAAA' });
  assert.equal((await LC.verifySigned(signed, pubFile)).ok, true);
  for (const edit of [
    (s) => { s.payload.letter.body = 'متن جعلی'; },
    (s) => { s.payload.decision = 'rejected'; },
    (s) => { s.payload.sigImage = 'data:image/png;base64,BBBB'; },
  ]) {
    const copy = structuredClone(signed); edit(copy);
    assert.equal((await LC.verifySigned(copy, pubFile)).ok, false);
  }
});

test('signature by another key is rejected', async () => {
  const { pubFile } = await setup();
  const forger = await setup();
  const forged = await LC.signLetter(forger.ident, { letter, decision: 'approved', note: '', sigImage: '' });
  assert.equal((await LC.verifySigned(forged, pubFile)).ok, false);
});
