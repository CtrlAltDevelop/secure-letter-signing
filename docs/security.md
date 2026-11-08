# Security model & file formats

## Primitives (WebCrypto only)
- Identity: ECDSA P-256 (signing) + ECDH P-256 (letter decryption).
- Key file protection: PBKDF2-SHA256 (600k iterations, 16-byte salt) → AES-256-GCM.
- Letter confidentiality: ephemeral ECDH → HKDF-SHA256 (`info="letter-v1"`) → AES-256-GCM, AAD = recipient fingerprint.
- Signature: ECDSA-SHA256 over canonical JSON (sorted keys) of `payload`.
- Fingerprint: first 128 bits of SHA-256 over canonical public keys, grouped `xxxx-xxxx-…`.

## Files (all JSON, `v: 1`)
| Ext | Who → whom | Content |
|---|---|---|
| `.pub` | manager → admin | `{name, sign, enc}` public JWKs |
| `.private` | manager only | `{name, pub, kdf, iv, ct}` — private JWKs encrypted with password |
| `.letter` | admin → manager | `{to, epk, iv, ct}` — encrypted letter |
| `.signed` | manager → admin | `{payload:{letter,decision,note,sigImage,signedAt,signer}, sig}` — `decision` ∈ `approved`/`revision`/`rejected` |

## What it prevents
- Forged/edited `.signed` (body, decision, note, signature image, time, letter number) → verification fails.
- Signature by anyone else → fingerprint mismatch vs the pinned manager key.
- Reading a `.letter` in transit or opening it with another key → AES-GCM / AAD failure.
- A pasted/scanned signature *image* has no authority; only the cryptographic signature counts.

## Known limits (MVP)
- Whoever has the `.private` file **and** its password can sign. Use a strong password; keep the file off shared devices. Passkey/Touch ID (non-extractable key) is the next hardening step (needs HTTPS, not `file://`).
- Pinning relies on the admin team registering the correct `.pub` once; verify the fingerprint out-of-band (phone call).
- `.signed` is signed but not encrypted (it travels back to the admin team). Encrypting it to an admin key is a possible later step.
- No revocation/rotation: on key loss, generate a new key and re-pin; old signed files stay verifiable only against the old `.pub` (keep it).
- Replay: each letter has a unique `id` and number inside the signed payload; there is no central registry offline, so the admin archive is the source of truth for duplicates.

## Letter object & revisions
`letter = {id, no, rev, prevHash?, date, subject, body, head, createdAt}`, encrypted in `.letter` and echoed inside the signed `payload`.
A revision keeps `id`/`no`, increments `rev`, and sets `prevHash` to the manager's previous signed reply hash (first 64 bits of SHA-256 of canonical payload),
so versions form a verifiable chain. The letterhead (`head`) is part of the signed content.
