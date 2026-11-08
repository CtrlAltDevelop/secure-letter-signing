// Pure WebCrypto layer: no DOM, runs in browsers and Node >= 19.
// Identity = ECDSA P-256 (sign) + ECDH P-256 (decrypt). Private part is password-wrapped.
const LC = (() => {
  const V = 1;
  const PBKDF2_ITER = 600000;
  const enc = new TextEncoder();
  const dec = new TextDecoder();
  const subtle = globalThis.crypto.subtle;
  const rand = (n) => globalThis.crypto.getRandomValues(new Uint8Array(n));

  const b64 = (buf) => {
    const u = new Uint8Array(buf);
    let s = '';
    for (let i = 0; i < u.length; i += 0x8000) s += String.fromCharCode(...u.subarray(i, i + 0x8000));
    return btoa(s);
  };
  const unb64 = (s) => Uint8Array.from(atob(s), (c) => c.charCodeAt(0));
  const hex = (buf) => [...new Uint8Array(buf)].map((x) => x.toString(16).padStart(2, '0')).join('');

  const sortKeys = (v) => {
    if (Array.isArray(v)) return v.map(sortKeys);
    if (v && typeof v === 'object') return Object.fromEntries(Object.keys(v).sort().map((k) => [k, sortKeys(v[k])]));
    return v;
  };
  const canon = (o) => JSON.stringify(sortKeys(o));
  const sha256hex = async (text) => hex(await subtle.digest('SHA-256', enc.encode(text)));

  const pubJwk = (j) => ({ kty: j.kty, crv: j.crv, x: j.x, y: j.y });

  async function fingerprint(pub) {
    const h = await sha256hex(canon({ sign: pubJwk(pub.sign), enc: pubJwk(pub.enc) }));
    return h.slice(0, 32).match(/.{4}/g).join('-');
  }

  async function checkPub(pub) {
    if (!pub || pub.v !== V || !pub.sign || !pub.enc || pub.sign.kty !== 'EC' || pub.enc.kty !== 'EC') {
      throw new Error('فایل کلید عمومی نامعتبر است');
    }
    return { ...pub, fp: await fingerprint(pub) };
  }

  async function wrapKey(password, salt, usage) {
    const base = await subtle.importKey('raw', enc.encode(password), 'PBKDF2', false, ['deriveKey']);
    return subtle.deriveKey(
      { name: 'PBKDF2', hash: 'SHA-256', salt, iterations: PBKDF2_ITER },
      base, { name: 'AES-GCM', length: 256 }, false, usage);
  }

  async function generateIdentity(name, password) {
    const sign = await subtle.generateKey({ name: 'ECDSA', namedCurve: 'P-256' }, true, ['sign', 'verify']);
    const encK = await subtle.generateKey({ name: 'ECDH', namedCurve: 'P-256' }, true, ['deriveBits']);
    const pub = {
      v: V, name,
      sign: pubJwk(await subtle.exportKey('jwk', sign.publicKey)),
      enc: pubJwk(await subtle.exportKey('jwk', encK.publicKey)),
    };
    const priv = {
      sign: await subtle.exportKey('jwk', sign.privateKey),
      enc: await subtle.exportKey('jwk', encK.privateKey),
    };
    const salt = rand(16);
    const iv = rand(12);
    const key = await wrapKey(password, salt, ['encrypt']);
    const ct = await subtle.encrypt({ name: 'AES-GCM', iv }, key, enc.encode(canon(priv)));
    const keyFile = { v: V, type: 'key', name, pub, kdf: { salt: b64(salt), iter: PBKDF2_ITER }, iv: b64(iv), ct: b64(ct) };
    return { keyFile, pubFile: pub };
  }

  async function unlockIdentity(keyFile, password) {
    if (keyFile?.v !== V || keyFile.type !== 'key') throw new Error('فایل کلید نامعتبر است');
    const key = await wrapKey(password, unb64(keyFile.kdf.salt), ['decrypt']);
    let priv;
    try {
      priv = JSON.parse(dec.decode(await subtle.decrypt({ name: 'AES-GCM', iv: unb64(keyFile.iv) }, key, unb64(keyFile.ct))));
    } catch {
      throw new Error('رمز اشتباه است یا فایل کلید خراب است');
    }
    const pub = await checkPub(keyFile.pub);
    return {
      name: keyFile.name, pub, fp: pub.fp,
      signKey: await subtle.importKey('jwk', priv.sign, { name: 'ECDSA', namedCurve: 'P-256' }, false, ['sign']),
      encKey: await subtle.importKey('jwk', priv.enc, { name: 'ECDH', namedCurve: 'P-256' }, false, ['deriveBits']),
    };
  }

  async function deriveAes(priv, pub, usage) {
    const bits = await subtle.deriveBits({ name: 'ECDH', public: pub }, priv, 256);
    const base = await subtle.importKey('raw', bits, 'HKDF', false, ['deriveKey']);
    return subtle.deriveKey(
      { name: 'HKDF', hash: 'SHA-256', salt: new Uint8Array(0), info: enc.encode('letter-v1') },
      base, { name: 'AES-GCM', length: 256 }, false, usage);
  }

  // Hybrid encryption to the manager: ephemeral ECDH -> HKDF -> AES-GCM (AAD = recipient fingerprint).
  async function encryptLetter(letter, mgrPub) {
    const pub = await checkPub(mgrPub);
    const eph = await subtle.generateKey({ name: 'ECDH', namedCurve: 'P-256' }, true, ['deriveBits']);
    const recipient = await subtle.importKey('jwk', pub.enc, { name: 'ECDH', namedCurve: 'P-256' }, false, []);
    const aes = await deriveAes(eph.privateKey, recipient, ['encrypt']);
    const iv = rand(12);
    const ct = await subtle.encrypt({ name: 'AES-GCM', iv, additionalData: enc.encode(pub.fp) }, aes, enc.encode(canon(letter)));
    return { v: V, type: 'letter', to: pub.fp, epk: pubJwk(await subtle.exportKey('jwk', eph.publicKey)), iv: b64(iv), ct: b64(ct) };
  }

  async function decryptLetter(file, ident) {
    if (file?.v !== V || file.type !== 'letter') throw new Error('فایل نامه نامعتبر است');
    if (file.to !== ident.fp) throw new Error('این نامه برای کلید دیگری رمز شده است');
    const epk = await subtle.importKey('jwk', file.epk, { name: 'ECDH', namedCurve: 'P-256' }, false, []);
    const aes = await deriveAes(ident.encKey, epk, ['decrypt']);
    try {
      const pt = await subtle.decrypt({ name: 'AES-GCM', iv: unb64(file.iv), additionalData: enc.encode(ident.fp) }, aes, unb64(file.ct));
      return JSON.parse(dec.decode(pt));
    } catch {
      throw new Error('رمزگشایی ناموفق: فایل دستکاری شده است');
    }
  }

  // The signature covers the whole original letter + decision + note + signature image + time.
  async function signLetter(ident, { letter, decision, note, sigImage }) {
    const payload = {
      v: V, letter, decision, note, sigImage,
      signedAt: new Date().toISOString(),
      signer: { name: ident.name, fp: ident.fp },
    };
    const sig = await subtle.sign({ name: 'ECDSA', hash: 'SHA-256' }, ident.signKey, enc.encode(canon(payload)));
    return { v: V, type: 'signed', payload, sig: b64(sig) };
  }

  async function verifySigned(file, pinnedPub) {
    const fail = (reason) => ({ ok: false, reason });
    try {
      if (file?.v !== V || file.type !== 'signed' || !file.payload || !file.sig) return fail('فرمت فایل امضاشده نامعتبر است');
      const pub = await checkPub(pinnedPub);
      if (file.payload.signer?.fp !== pub.fp) return fail('امضاکننده با کلید ثبت‌شده‌ی مدیر مطابقت ندارد');
      const key = await subtle.importKey('jwk', pub.sign, { name: 'ECDSA', namedCurve: 'P-256' }, false, ['verify']);
      const ok = await subtle.verify({ name: 'ECDSA', hash: 'SHA-256' }, key, unb64(file.sig), enc.encode(canon(file.payload)));
      if (!ok) return fail('امضا نامعتبر است: محتوا دستکاری شده یا امضا جعلی است');
      return { ok: true, payload: file.payload, hash: await docHash(file.payload), fp: pub.fp };
    } catch (e) {
      return fail('بررسی ناموفق: ' + e.message);
    }
  }

  const docHash = async (payload) => (await sha256hex(canon(payload))).slice(0, 16);

  return { docHash, generateIdentity, unlockIdentity, checkPub, encryptLetter, decryptLetter, signLetter, verifySigned, fingerprint, sha256hex, uuid: () => globalThis.crypto.randomUUID() };
})();

if (typeof module !== 'undefined') module.exports = LC;
