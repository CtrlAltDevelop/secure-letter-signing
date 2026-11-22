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


## Server app (signing v3): trust model

The server app no longer uses client-side end-to-end encryption. See `docs/signing-v3.md` for the contract.

- **At rest:** letter bodies and attachment files are encrypted by the server with Fernet (AES-128-CBC + HMAC-SHA256).
  The key is derived (HKDF-SHA256) from `DJANGO_DATA_KEY`. The database and the attachments volume alone do not reveal
  content; the running server (and whoever holds the key) can read it. Back the key up with the database; losing it
  makes stored letters unreadable.
- **Signing:** by the 6-digit signing PIN (stored hashed; every attempt is counted atomically before verification: 5 per user and 10 per session per 15 minutes, then 429; a correct PIN gives its attempt back so failures are what stay counted, and changing the PIN clears the count), or by a session
  that was enrolled as `biometric` with the signing PIN, or by remote approval from another biometric session of the same user.
- **Seal:** every signature payload is sealed with an Ed25519 key derived from `DJANGO_SEAL_SEED`; the public key is
  published at `GET /api/letters/seal-key`. The certificate endpoint re-verifies each seal and that the signed
  `contentHash` still matches the decrypted body. Rows in `letters_signature` are immutable (database trigger) and every
  signature is recorded in the HMAC-chained audit log (`letter_signed` with its method).
- **Attachments:** the sealed payload carries `attachments: [{id, size, sha256}]` (plaintext SHA-256, sorted by id),
  computed when the signature is made; signatures made before this change do not have the field.
- **Abuse limits:** each user may upload `MAX_USER_UPLOAD_BYTES_PER_DAY` (default 500 MB, rolling 24h, workspace files
  and letter attachments; backgrounds are capped at 2 MB each) then gets 429. The TLS proxy must set
  `client_max_body_size 30m;` (nginx; attachments are capped at 25 MB) so oversized bodies are refused before Django.
- **WebSocket token:** the live socket takes the access token in the query string. daphne runs with `-v 0` (no access log;
  its default would log requests), and the proxy must not log the query string of `/ws` (nginx: `log_format` with
  `$uri` instead of `$request`, or `access_log off;` in the `/ws` location).
- **Audit head:** `manage.py verify_audit` prints `head: #id <hash>`; store it outside the database (cron to another
  host). `verify_audit --expect-head <hash>` then fails if that hash is no longer in an intact chain (deleted tail).
- **Database role:** compose creates `letters_app` (no superuser/createdb/createrole, owns nothing) from
  `scripts/db/10-app-role.sh`; the server process uses it, while `migrate` runs as the owner `letters` in the start
  command. A compromised app therefore cannot alter tables or drop the immutability triggers. Needs `APP_DB_PASSWORD`
  in `brands/<brand>/.env`; for an existing database run the script's SQL once by hand.
- **Limitations:** the server cannot verify that a biometric check really happened (no device-bound key); it trusts the
  `biometric` flag of the session. The flag cannot come from login (ignored); enabling it needs the signing PIN (same
  rate limit as signing), so a stolen token or phished password alone cannot make a session an approver. Anyone who controls the server and both secrets can forge seals; the audit chain is
  keyed by `DJANGO_SECRET_KEY`. A 6-digit PIN is weak against an attacker who can bypass the rate limit (it is per
  user, kept in the cache), so keep Redis available in production.

- **Secrets:** outside `DJANGO_DEBUG=1` the server refuses to start unless `DJANGO_DATA_KEY` and `DJANGO_SEAL_SEED` are
  each at least 32 characters, differ from each other and are not the dev fallbacks. HKDF uses a fixed, non-secret salt
  per purpose (`core/cryptoutil.py`). Changing a salt or a key makes data encrypted or sealed with the old one
  unreadable or unverifiable; never edit them on an existing deployment. Without `REDIS_URL` the PIN and login rate
  limits are per-process and a loud warning is logged at start.
