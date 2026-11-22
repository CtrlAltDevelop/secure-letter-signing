# Signing v3: server-side crypto, PIN and biometric approval

This replaces the client-side end-to-end encryption (per-user keys, document-key wraps, company key, key approvals,
QR key transfer) with a server-managed model aimed at automation. Existing dev data is discarded.

## Model

- **Reading:** the server decrypts letters for any user allowed to see them (`letters/rules.py` visibility is unchanged).
  Letters and attachments are encrypted **at rest** by the server (Fernet). Nobody needs a personal key to read.
- **Signing:** a signer proves identity with ONE of
  1. their **signing PIN** (6 digits, one per account, identical on every device), or
  2. **biometric**: the current session has `biometric=true` and the app confirmed fingerprint/face locally, or
  3. **remote biometric approval**: a session without biometrics asks another session of the same user that has
     `biometric=true`; the user approves there with fingerprint/face.
- The **server seals** every signature with an Ed25519 company seal key. Seal public key is published; the audit chain
  records every signature.
- Limitation to document: the server cannot verify that a biometric check really happened (no device-bound key). It trusts
  a session flagged `biometric`. To stop a stolen token or a phished password from flagging a session, **turning the
  flag on requires the signing PIN** (enrolment); a new session always starts with `biometric=false`. PIN attempts are
  rate limited.

## Server API (all under `/api`, Bearer auth, `Cache-Control: no-store`)

Removed: the whole `/keys/*` router, `GET /letters/rewrap-needed`, `POST /letters/{id}/wraps`, wraps/company fields on letters.

### Sessions and PIN
- `POST /auth/login`: a `biometric` field in the body is accepted for old clients but IGNORED; every new session starts with
  `Session.biometric = false`.
- `PATCH /me/sessions/current` body `{biometric: bool, pin?: str}` -> `SessionOut`. Turning `biometric` from false to true
  REQUIRES `pin` (checked and rate limited exactly like signing: 409 if no PIN is set, 403 `Wrong signing PIN`, 429
  when locked; audit `session_biometric_enabled`). Setting true when already true is a no-op. Setting false needs no
  PIN and is always allowed (app does it when biometrics are no longer available).
- `SessionOut` gains `biometric: bool`. `GET /me` (`UserOut`) gains `has_signing_pin: bool`.
- `PUT /me/signing-pin` body `{pin: "123456", password: "<login password>"}` -> `{detail}`. Sets or changes the PIN. The
  login password is required and rate limited like `/me/password`. PIN must be exactly 6 digits. Stored hashed
  (Django password hasher). Audit `signing_pin_set`.

### Letters (changed shapes)
- `LetterIn{title, body, visibility, publish_mode, order, due_at?, parent_id?, signer_ids[], viewer_ids[]}` where
  `body` is a plain JSON object (app puts `{text, rich?, attachments?}` in it). Serialized size cap 2,000,000 chars.
- `LetterOut` = previous fields minus wraps/company fields, with `body` as the plaintext object and
  `signatures: [SignatureOut]`.
- Storage: `Letter.body` column holds `{"v": 3, "ct": "<Fernet token of canonical JSON>"}`; API encrypts on write and
  decrypts on read. The "sent letters are immutable" DB trigger keeps working on that column.
- Attachments: `POST /letters/{id}/attachments` multipart `content_type`, `label`, `file` (plain bytes, same type/size
  limits, drafts only). File bytes are Fernet-encrypted on disk. `GET /letters/{id}/attachments/{att}` returns plain
  bytes with the stored `content_type`. `AttachmentOut{id, content_type, label, size}` (no `iv`).
- `contentHash` = sha256 hex of the canonical JSON of the PLAINTEXT body (so rotating the data key never breaks it).

### Signing
Common rules (unchanged): caller is a signer participant, letter `in_signing`, not already decided, it is their turn.
`decision` is `approved` or `rejected`, `note` <= 2000 chars.

- `POST /letters/{id}/sign` body `{decision, note, pin}` -> `LetterBrief`. Wrong PIN -> 403 `Wrong signing PIN`
  (counted with `accounts/ratelimit.py`, scope `sign-pin`, keyed by user id, max 5 failures/15 min -> 429).
  No PIN set -> 409 `Set your signing PIN first`.
- `POST /letters/{id}/sign-biometric` body `{decision, note}` -> `LetterBrief`. Requires the current session
  `biometric=true`, else 403.
- `POST /letters/{id}/sign-requests` body `{decision, note, approver_session_id}` -> `SignRequestOut` (201).
  Approver must be a live session of the same user, `biometric=true`, and not the requesting session. A new request
  cancels this user's older pending request for the same letter. Expires after 5 minutes.
- Router `/sign-requests`:
  - `GET /incoming` -> `[SignRequestOut]` pending and not expired, for the current session as approver.
  - `GET /{rid}` -> `SignRequestOut` (requester user only).
  - `POST /{rid}/approve` -> `SignRequestOut`. Current session must be the approver session and `biometric=true`. Re-checks
    all signing rules, then creates the signature (method `biometric`, `sessionId`/`deviceName` = the APPROVER session).
  - `POST /{rid}/decline` -> `SignRequestOut` (approver session). `POST /{rid}/cancel` -> `SignRequestOut` (requester
    session). Expired requests are reported as `expired` and cannot be approved.
- `SignRequestOut{id, letter_id, letter_title, decision, note, status, requester_session_id, requester_device_name,
  approver_session_id, created_at, expires_at, resolved_at?}` with `status` in `pending|approved|declined|cancelled|expired`.

### Signature stamp
- Payload: `{v:3, letterId, title, decision, note, contentHash, parentId, signer{userId, email, name}, method:"pin"|"biometric",
  sessionId, deviceName, signedAt, nonce}` (no floats). `seal` = base64 Ed25519 signature over its canonical JSON.
- `Signature` model: `letter, signer, decision, payload JSON, seal, method, nonce unique, created_at`, unique
  (letter, signer), immutable (existing DB triggers). No `key` FK.
- `SignatureOut{signer_id, decision, note, method, device_name, signed_at, seal, payload}`.
- `GET /letters/seal-key` -> `{alg: "Ed25519", public_key: "<b64>", fingerprint}`.
- `GET /letters/{id}/certificate` re-verifies each seal against the seal public key and each `contentHash` against the
  decrypted body, returns per-signature `verified` plus `method` and `device`.
- Settings: `DJANGO_DATA_KEY` (at-rest encryption secret) and `DJANGO_SEAL_SEED` (seal key seed), both required unless
  `DJANGO_DEBUG=1` (dev fallbacks only under debug).

### WebSocket (`/ws/?token=`)
New session-targeted frames (no `event_id`, not replayed; the app fetches `/sign-requests/incoming` on connect):
- to the approver session: `{type:"sign_request", request: SignRequestOut}`
- to requester and approver sessions on every status change: `{type:"sign_request_update", request: SignRequestOut}`
The consumer joins group `session_<session id>` in addition to `user_<id>`; delivery re-checks the live Session as before.
Existing `letter` and `notification` frames are unchanged. Audit actions: `signing_pin_set`, `sign_pin_failed`,
`sign_requested`, `letter_signed` (data includes method), `sign_request_declined`.

## App (Flutter)

- No key gate. After login, if `user.hasSigningPin` is false a full-screen "Set your signing PIN" step (PIN, repeat, login
  password) shows before the shell; Profile has a "Signing PIN" card to change it.
- `Biometrics`/`LocalAuthBiometrics` move to `lib/auth/biometrics.dart`. Enrolment: after login/restore, if biometrics are
  available and the current session is not flagged, a one-time dialog 'Use fingerprint/face on this device' asks for the
  signing PIN and PATCHes `{biometric:true, pin}` (also offered as a button on the current device in the Devices tab; 'Not
  now' is remembered for the app run). If biometrics are unavailable but the session is flagged, PATCH `{biometric:false}`.
  Old text: login used to send `biometric`;
  on every app start `PATCH /me/sessions/current`.
- Sign screen: decision + note, then methods: PIN field; "Fingerprint / face" when this session is biometric;
  "Ask my <device>" for each other live session with `biometric` (from `GET /me/sessions`), which creates a sign request,
  waits (live `sign_request_update`, 5-minute timeout, Cancel), PIN stays available as fallback.
- Approver side: an app-wide host listens to live `sign_request` frames and `GET /sign-requests/incoming` on start, shows
  letter title/decision/note and requester device with Approve (local biometric, then `/approve`) and Decline.
- Devices tab shows a biometric chip per session. Letter detail/create need no decrypt/wrap/rewrap/company key code.
- Delete: `lib/crypto/*`, key vault/store/transfer/approvals/setup/my-keys screens, company key card, rewrap service, and
  their tests; drop unused dependencies (qr_flutter, mobile_scanner, pointycastle if nothing else uses them).

## Attachment binding
The server seal payload includes `attachments: [{id, size, sha256}]` (plaintext SHA-256, sorted by id), computed when a
signature is made. Sent letters are immutable, so it equals what the signer saw. The Dart app treats the payload as
opaque, so no app or test-vector change was needed. Signatures sealed earlier lack the field. Not done: putting the
hashes inside the encrypted body as well (the seal already binds them).
