# Roadmap v2 — company letter-signing platform

Status: **final draft v2** · supersedes v1. Source: product owner's final flow. Open questions in §10.

## 1. Decisions

| Topic | Decision |
|---|---|
| Backend | Django + **Django Ninja** (API) + **Unfold** (admin panel), PostgreSQL, Redis, Celery, Django Channels (live updates). Self-hosted, Docker |
| Client | One Flutter codebase: Android, iOS, macOS, Windows. **No web client.** English only (l10n-ready) |
| Branding | Each company has a brand (name, logo, colors). Backend and app are **built and run per brand** from one config (§2) |
| Superuser | The **developer**. Changes all settings and behaviors (permission catalog, feature flags, brand, roles) in the Unfold admin |
| Users | Company employees **sign up in the app**. Superuser promotes some to **Manager** |
| Manager | **Exactly one per company.** Handles day-to-day company administration: grants/revokes letter permissions, approves new keys, toggles signup switches, creates invitation codes, unlists published letters (including private ones, seeing title and participants only), edits own-company settings. **Cannot create or remove managers** |
| Manager role assignment | **Only the superuser** gives or takes the Manager role |
| Superuser vs letters | Superuser has **no access to letters**: no letter models, titles or content in the Unfold admin, no key approvals. (Bodies are E2E ciphertext anyway) |
| Permissions (for now) | `user` (base), `letter.create`, `letter.see`, `letter.sign`. New ones are added as data, not code |
| Keys | A user may hold **several active key pairs, one per device**. Public keys on the server, private keys only on the device that made them, never uploaded. **The manager approves each new key** |
| Key transfer | Only **password-protected** keys can move to another device by **QR or file** (same key, same password, no new approval). **Biometric-sealed keys never move**: a new device makes its own key and needs manager approval |
| Signing | Every signature needs a fresh unlock at that moment: biometric/passkey if the device has it, otherwise the typed strong key password |
| Sessions | User sees all login sessions (device, IP, last active), can revoke any. History is visible on every device |
| Tenancy | **One company per deployment** (own backend, database and app build per brand) |
| Confidentiality | **End-to-end encrypted.** Only the letter **title** is readable by the server and shown in lists; body and attachments are ciphertext. Notifications carry the title only |
| No deletion | Nothing is ever deleted (letters, drafts, users, sessions, keys, audit). Things are cancelled, deactivated, retired or unlisted. No delete endpoints; DB triggers block `DELETE` |
| Unlisting | A **manager can only unlist a published letter** (remove it from users' lists). They cannot read, edit or delete it |
| Letter chains | A new letter can be **chained to an existing letter** (follow-up/reply), shown as a thread |
| Signup | Two independent switches (on/off): **company-domain signup** (any email of the domain may register) and **invitation code** (any email with a valid code) |
| Publish timing | Chosen by creator at creation: **publish now** (viewers see it immediately) or **after all sign** |
| Attachments | PDF and images only, max **25 MB** each, encrypted in the app before upload, stored on a local Docker volume |
| Notifications | **Email via SMTP** configured by the superuser in settings. If no SMTP is configured, fall back to **in-app notifications over the WebSocket** (shown while the app is open). No FCM/APNs push |
| Login | **Email + password**; forgotten login password is reset by an emailed link. Reset never touches the private key or key password. (Without SMTP the manager issues a reset link instead) |
| Key unlock | If the device has biometrics: unlock the private key with a **passkey/biometric** (key sealed in the secure store). If not: a **strong key password**, min 10 chars with upper, lower, digit and symbol |

## 2. Per-company build and run

```
brands/<company>/brand.yaml   # name, logo, colors, domain, API URL, enabled features
        │
        ├─► backend: docker compose --env-file brands/<company>/.env up   (BRAND=<company>)
        └─► app:     flutter build <platform> --dart-define=BRAND=<company>  (assets from brand folder)
```
- One command builds both for a brand; no code changes per company.
- Logo/name/colors served by `GET /brand` and baked into the app's assets so the splash screen works offline.
- Each brand = its own database and secrets; no cross-company code paths.

## 3. Roles and permissions

- **Superuser** (developer): full Unfold admin. Defines the permission catalog, roles, defaults, brand, feature switches, limits.
- **Manager** (role, given only by the superuser): in-app screens to grant/revoke `letter.create`, `letter.see`, `letter.sign` on any company user, approve new-key requests (§5.4), toggle signup switches, manage invitation codes, unlist letters, and edit allowed company settings (e.g. display name, logo). Cannot create managers or touch superuser-only settings (permission catalog, feature flags, deployment settings).
- The superuser's Unfold admin deliberately excludes letter, letter-key and signature models, and has no approve-key action.
- **User**: signs up, gets `user` only; a manager adds the rest.
- **Signup switches** (company settings, superuser-controlled; manager may toggle if allowed, Q5): `signup_domain_enabled` + `allowed_domain`, `signup_invite_enabled`. Invitation codes: created by manager/superuser, single- or multi-use, expiry, any email, all audited. Both off = no new registrations.
- Enforced in Django Ninja dependencies on every endpoint; the app only hides what the API refuses. Every grant/revoke is audited.

## 4. Accounts and sessions

- Signup → login (JWT access token, short-lived; refresh token bound to a `Session` row).
- `Session{user, device name, platform, ip, user agent, created, last_active, revoked}`. Revoke = refresh token dead, access token rejected within minutes, WebSocket closed, and signing from that session refused.
- A logged-in session can open and read letters. **Signing additionally requires the key password.**
- Optional later: TOTP 2FA as a superuser switch.

## 5. Keys

### 5.1 Creation (any device that has no key yet)
The first key of a brand-new user is auto-approved when the manager activates the account; every later key (new device, new key after loss) is *pending* until the manager approves (§5.4).
1. App generates ECDSA P-256 (sign) + ECDH P-256 (decrypt) pair.
2. If the device has biometrics, the key is sealed in the secure store behind the passkey/biometric. Otherwise the user sets a **strong key password** (min 10, upper+lower+digit+symbol, strength meter, 10 wrong tries then growing delay). Private keys are wrapped with it (PBKDF2/Argon2 → AES-256-GCM, same format family as the offline app's `.private`).
3. Public keys are uploaded; server stores them with a fingerprint. Private blob is saved in the OS secure store (Keychain / Keystore / DPAPI). A **biometric-sealed key cannot be exported or transferred**; only password-protected keys can move by QR/file (§5.3).

### 5.2 Signing
Sign screen asks for the unlock (biometric/passkey where available, otherwise the typed strong key password) → unwrap in memory → ECDSA-sign the letter payload → wipe. Payload includes `letterId, decision, note, signer{userId, keyId, fp}, sessionId, deviceName, signedAt, nonce`.
Server verifies the signature with the stored public key of that `keyId` (must be *active* and owned by the user) and records "**user X from device X signed letter X**". Because each device has its own key, the signature itself proves which device signed. Any one of the user's active keys is enough to sign.

### 5.3 Transfer to a new device (password-protected keys only)
Users on devices with biometrics get a new, manager-approved key per device (§5.4) instead of transferring.
- **QR:** old device shows the encrypted private blob as QR (compact format, single QR or animated frames); new device scans.
- **File:** old device exports the same encrypted blob as a file; new device imports it.
- The blob is already encrypted by the key password, so QR/file is useless without it. New device asks for the **same key password** to verify before saving.
- Export itself requires the key password; each export/import is audited and notifies the user's other sessions.

### 5.4 New device, lost key, forgotten key password
Server never holds a private key, so none can be recovered. On a new biometric device, or after a loss, the user requests a **new key**: new pair, new public key uploaded. The user's other keys stay active (new device) or are marked *retired* by the user or manager (lost device; old signatures stay verifiable against them). The request stays *pending* until **the manager** approves it after checking identity; the superuser cannot approve. A pending key can log in but cannot sign or read. Every approval is written to the audit chain and triggers the key-change alert (§5.4a), which is the check on the single approver.
**There is exactly one manager per company.** If the manager loses their own key there is nobody to approve it, so the **superuser moves the Manager role** to another user (the superuser can already assign the role, but still cannot approve keys or read letters). The new manager then approves the old manager's new key if wanted; the old manager is demoted to a normal user.

### 5.4a Public-key change alerts and fingerprints
- Every user profile shows the key **fingerprint**; users can compare it out-of-band.
- Any change to a user's public key (new key approved, retired key, or a direct database edit) triggers an alert: push + in-app notice to that user on all sessions, and to all managers. The user can confirm "this was me" or report it.
- The server keeps a `KeyVersion` history per user (never overwritten). Signatures and letter key wraps reference the key version, so a silent swap cannot make old signatures pass for a different key, and apps pin the last-seen fingerprint and warn on mismatch.
- Alerts are written to the audit chain.

### 5.4b Access for a newly approved key
Content is E2E and wrapped per key, so a new key cannot read old letters until they are re-wrapped. After approval: the new key receives the company key (§5.5), and the user's **other active device** re-wraps each of that user's letters for the new key in the background. If the user has no other active key (all lost), any online participant's app re-wraps; letters nobody can re-wrap stay locked (title still visible). New letters are wrapped for **every active key of every recipient**.

### 5.5 Company group key (for public letters and new members)
- A symmetric **company key** is created by the first manager's app (a deployment needs at least one manager, set up by the superuser) and wrapped to every user's encryption public key; the server stores only wrapped copies.
- A new user gets it from an online manager/member app when their account is approved; it rotates when a user is deactivated, with new letters using the new version.
- Used only for **public** letters (§6.1).

## 6. Letter flow

1. **Create** (needs `letter.create`): **title** (plaintext, shown in lists), body, attachments (E2E). Creator adds a **list of users who can see** and a **list of users who must sign** (serial or parallel; optional due date), optionally **chains it to an existing letter** (`parentId`, creator must be able to read the parent; signed inside the payload), and picks **publish now** or **publish after all sign**.
2. **Send:** letter goes to all signers (push + in-app, title only). Status `in_signing`. If *publish now*, viewers get it too.
3. **Open and decide:** signer opens it in a logged-in session, reads details, picks **approve or reject** with a note, then unlocks the key (biometric or key password) to sign. A **reject is final**: the letter becomes `rejected`; the creator may start a **new letter chained** to it.
4. **Live:** every event (sent, opened, signed, rejected) is pushed over WebSocket so all participants see the latest signatures instantly; reconnect catch-up by event id.
5. **Publish:** *after all sign* (default): when all required signers approved the current revision. *Publish now*: at send. Signers can always see it.
6. **Visibility** chosen by the creator: **Public** = all company users; **Private** = a selected list of users.
7. **History:** every letter a user took part in or may see appears in history on every device and session.
8. **Order:** the creator chooses **parallel** (everyone at once) or **in order** (list order; the next signer is notified only after the previous signs).
8a. **No edits after send:** a sent letter is immutable. Changes go in a new chained letter (so there is no `rev`/revision loop; the legacy offline app's revision flow is not carried over).
9. **Chains:** a letter with `parentId` appears under its parent as a thread; each letter is still signed independently.
10. **Unlist:** a manager may unlist a published letter; it disappears from users' lists but remains in the database, audit and the participants' history (unlisted flag, reversible by manager, audited). It is not deleted or edited.
- State machine: `draft → in_signing → published | rejected | cancelled`, plus orthogonal `unlisted`. Cancel is a state, not a delete.

### 6.1 Encryption
- Random **document key** per letter revision encrypts body + attachments (AES-256-GCM). Title and metadata (ids, participants, states, timestamps) stay plaintext so the server can route, list and enforce permissions.
- Document key is wrapped (ECDH → HKDF → AES-GCM) for the creator and each signer; for **private** letters also for each listed viewer; for **public** letters under the **company key** (§5.5).
- If the viewer set changes later, the creator's app (or any holder) re-wraps for added users; removing a viewer cannot revoke what they already decrypted (stated in UI).
- Because the server cannot read bodies: no server-side body search, only title search; PDFs/exports are rendered in the app.

## 7. Audit
Append-only, hash-chained `AuditEvent{actor, session, action, object, hash, prevHash, at}`: logins, session revokes, permission changes, key creation/export/import/retire, letter create/send/sign/publish. Viewer in Unfold; CSV export; per-letter signature certificate.

## 8. Phases

Each phase ends runnable, with ≥80% test coverage on auth, permissions and crypto.

| Phase | Scope | Done when |
|---|---|---|
| **0 Foundations** (1–2 wk) | Repo layout (`server/`, `app/`, `brands/`, `docs/`, keep legacy web app), Docker Compose, CI, brand build script, crypto spec + shared test vectors (Dart ↔ `src/crypto.js`) | `./build <brand>` produces running backend + app; Dart verifies a JS signature and vice versa |
| **1 Accounts, roles, sessions** (2 wk) | Ninja API, signup/login, JWT + Session model, session list/revoke, Unfold admin, permission catalog, Manager role and screens, brand endpoint | Superuser makes a manager; manager grants `letter.create`; revoking a session kills it |
| **2 Keys** (2 wk) | Key generation, key password, public key upload, secure local storage, QR and file transfer, new-key flow, password prompt component | Key moved to a second device by QR and by file with the same password; wrong password refused |
| **3 Letters** (4 wk) | Create with title + see/sign lists, E2E encryption + company key, chaining, publish timing, send, open, decide + sign, server verification, public/private visibility, manager unlist, no-delete DB triggers, history | 3 signers sign, letter publishes, public/private enforced, a chained letter shows under its parent, history identical on two devices, server cannot read any body |
| **4 Live + notifications** (2 wk) | Channels WebSocket per letter, SMTP email (superuser-configured) with in-app WebSocket fallback, reconnect catch-up | Signature on phone A appears on laptop B within a second |
| **5 Audit & reports** (1–2 wk) | Audit chain, Unfold viewer, exports, signature certificate | Tampering with an audit row is detected |
| **6 Release** (2 wk) | Security review, backup/restore drill, store builds and installers per brand, docs | Two different brands built and running side by side |
| *Later* | Generic document signing (PDF), custom workflow builder, TOTP 2FA | Re-plan after Phase 6 |

Total about 14–16 weeks for one small team. Phase 1 also covers the signup switches and invitation codes.

## 9. Risks

| Risk | Mitigation |
|---|---|
| Private key copied by QR/file; stolen file + guessed password signs as the user | Strong key-password rules, slow KDF (Argon2/600k PBKDF2), lock after N bad tries on-device, audit every export/import, session shown on all devices |
| Signature cannot prove *which device* signed (one key per user) | Device/session recorded server-side and inside the signed payload; export/import audited |
| Forgotten key password = lost key | By design; new-key flow with approval (Q2) |
| Public letters + E2E | Company group key (§5.5); rotates on user deactivation |
| New key = old letters locked | Access-recovery re-wrap by participants (§5.4) |
| Developer/manager abuse (swap public key, approve impostor key) | Single manager is the trust point; every approval audited, public-key change alerts, fingerprints visible, audit chain (§5.4, §5.4a) |
| Signup switches misused | Both off by default, audited, domain verified by email confirmation |
| Dart/JS crypto drift | Shared test vectors in CI |
| Every new device needs manager approval (manager workload, delay) | Approval queue with push/email to manager, identity check checklist, password-key QR/file transfer needs no approval |

## 10. Open questions

Resolved: tenancy (one company per deployment), confidentiality (E2E, title plaintext), signup (two switches), publish timing (creator chooses at creation).

Also resolved: new-key approval (manager only), manager scope (any letter permission, no manager creation), signup switches (managers and superuser), unlist scope (any letter, title and participants only), superuser has no letter access.

Resolved: **Q6 Retention/legal:** letters are kept **forever** (no archive step, no expiry job), and signatures are for **internal company use only**: the cryptographic signature plus audit trail is the evidence, with no qualified-signature or certified-timestamp requirement. If a company later needs legal-grade e-signatures, add a legal review and a timestamping service as a separate phase.

Also resolved: attachments (PDF/images, 25 MB, local volume), notifications (SMTP, in-app fallback), login (email + reset link), key unlock (biometric else strong password), biometric keys cannot transfer, rejection is final (chain a new letter), order is creator's choice, no web client.

**Open:**
Resolved: **Q12** each biometric device gets its own key, approved by the manager (several active keys per user).

**No open questions remain.** Next step: Phase 0.
Resolved: **single manager per company approves keys** (supersedes the two-manager idea, Q9/Q11) and **public-key change alerts with fingerprints** (Q10), see §5.4 and §5.4a.

