# AGENTS.md — secure-letter-signing

> **Roadmap:** `docs/ROADMAP.md` (v2) is the plan for the company platform (Django Ninja + Unfold server, Flutter app,
> per-brand deployments, E2E letters, per-device keys). The offline HTML app below is the legacy/fallback and the
> crypto reference. New platform code lives in `server/`, `app/`, `brands/`.

Offline app shipped as THREE self-contained HTML files in `dist/`: `employee.html` (admin team writes a letter, sends it
encrypted, verifies the signed reply, prints, edits & resends), `manager.html` (opens the letter, approves / requests
revision / rejects, signs) and `keygen.html` (makes `.private` + `.pub`). UI is Persian (RTL).

## Layout
- `src/crypto.js` — pure WebCrypto layer (no DOM). Source of truth for all security logic.
- `src/shared.js` — helpers + canvas letter renderer used by both pages.
- `src/employee.js`, `src/manager.js`, `src/keygen.js` — per-page logic. `src/layout.html` + `src/pages/*.html` + `src/style.css` — markup/CSS; markers `{{TITLE}} {{BODY}} /*STYLE*/ /*CRYPTO*/ /*SHARED*/ /*APP*/`.
- `build.mjs` — inlines everything into `dist/{keygen,manager,employee}.html` (the deliverables, no external deps).
- `test/crypto.test.mjs` — Node tests for the crypto layer.
- `docs/security.md` — threat model, file formats, revision flow. Update it when formats change.

## Commands
- `npm run build` → `dist/keygen.html`, `dist/manager.html`, `dist/employee.html`
- `npm test` → crypto tests (Node >= 19)
- Browser check: serve `dist/` (e.g. `python3 -m http.server`); pages share an origin, so a test can pass files between them via localStorage (set `<input type=file>` via DataTransfer, capture downloads by stubbing `HTMLAnchorElement.prototype.click`).

## Rules / gotchas
- Never add network calls, CDNs or external fonts: the app must work offline.
- Signature validity = ECDSA over canonical JSON of the whole payload. Any new field that
  matters must go inside `payload`, never beside it.
- Bump `V` in `crypto.js` and document it in `docs/security.md` on any format change.
- Private key never leaves `unlockIdentity`; keep `extractable:false` on imported keys.
- Wrap digits/hex in `ltr()` when drawing inside RTL canvas text, or they render reversed.
- `localStorage` may be unavailable; `store` degrades with a warning, keep it that way.
- Letterhead is copied into each letter (`letter.head`) so the manager's page needs no settings and the signed document is self-contained.
- Revision loop: letter `{id, no, rev, prevHash}`. Decision `revision` → employee clicks "ویرایش و ارسال مجدد" → `rev+1`, same `id`/`no`, `prevHash` = doc hash of the manager's signed reply.
- Print: `#printArea` must stay a direct child of `<body>` (in `layout.html`, not in a page fragment) because the print CSS hides every other body child. Wait for the image `load` event before `window.print()`; `img.decode()` never settles inside a `display:none` container.
- Styling: glass theme in `src/style.css` (CSS variables, light/dark via OS). Mobile-first; keep inputs at 16px (iOS zoom) and check there is no horizontal scroll at 375px.
- Palette (design tokens, do not invent new hues): Dark `#081528`/`#0F203A`, Gold `#BFA46F`/`#FBD57F`, Blue `#165EF6` (action) `#A4B9E4` (light) `#32568A` (mid), State `#4CD8B9` ok / `#D65959` error / `#CFA44B` warn, tints `#BBF0E4` / `#EFC9C9`. UI colours live as CSS variables in `src/style.css`; the white letter paper uses the `PAPER` object in `src/shared.js` (darker shades of the same hues for contrast on white).
- Font: Vazirmatn (SIL OFL, `src/fonts/`, license in `OFL.txt`) is inlined as base64 `@font-face` by `build.mjs` (`/*FONT*/` marker in `style.css`), so pages stay offline. Canvas text must `await document.fonts.load(...)` before measuring (done in `renderLetter`).
- Layout: pages use `.split` > `.seg` (phone switch) + `.pane` cards. Phone shows one `.pane.active` at a time (`setPane(id, name)` in `shared.js`); ≥900px shows all panes side by side with the preview pane `.sticky` (scrolls inside itself). Keep each phone screen about one viewport tall; move content between panes rather than stacking cards. Scope tab handlers to `[data-tab]` so they never catch `.seg` buttons.
- Manager page: row 1 = collapsible `<details id="keySetup">` (open while locked, auto-collapses on unlock, summary shows the signer); row 2 = `.split` with letter pane + decision/sign pane. Employee page uses the same `<details>` pattern for its setup block.

## Platform (Phase 0+)
- `server/` Django 6 + django-ninja (API) + unfold (admin). `uv sync`, `DJANGO_DEBUG=1 uv run pytest`. Env-driven settings (`BRAND`, `DJANGO_SECRET_KEY`, `POSTGRES_*`); no secret → refuses to start unless `DJANGO_DEBUG=1`.
- `brands/<id>/brand.json` + `logo.svg` + `.env` (git-ignored; template `brands/.env.example`). One company per deployment.
- `./build.sh <brand> up` → docker compose (db, redis, server). `./build.sh <brand> app <apk|ios|macos|windows>` → copies brand into `app/assets/brand/` (git-ignored, generated) and runs `flutter build --dart-define=BRAND=<id>`. Before local `flutter test/run`, copy `brands/demo/*` into `app/assets/brand/`.
- `app/` Flutter (Android, iOS, macOS, Windows; no web). `app/lib/crypto/letter_crypto.dart` is the Dart port of `src/crypto.js` using pointycastle (the `cryptography` pkg has no pure-Dart ECDSA).
- **Crypto contract:** `test-vectors/v1.json` is generated by the JS code (`node test-vectors/make.mjs`, only on format change). Dart must verify/decrypt it (`app/test/crypto_interop_test.dart`) and JS must verify Dart's signature (`test/interop.test.mjs`, reads `test-vectors/dart-signed.json` written by the Dart test; `REQUIRE_DART_SIGNED=1` makes it mandatory). Signed payloads must not contain floats.
- `make dev` (port 8090 via `PORT=`; SQLite + in-memory channel layer/celery, no Docker, auto-reload), `make macos` (runs the macOS app against it; start `make dev` first), `make up|down|logs` (Docker, `BRAND=<id>`), `make test`, `make app`, `make superuser`. Redis is used only when `REDIS_URL` is set (compose sets it).
- Docker stack was written but not yet run end to end (Phase 0 gap: needs a running Docker daemon).

## Server apps (Phase 1)
- `accounts/`: custom email `User` (`is_manager` = the single manager, partial unique constraint; set only by the superuser in the Unfold admin), `Permission` catalog (seeded: user, letter.create, letter.see, letter.sign; user M2M is `grants`), `Session`, `InviteCode`, `CompanySettings` (singleton; signup switches + SMTP), `AuditEvent` (no hash chain yet, Phase 5).
- Tokens are opaque `django.core.signing` access tokens (10 min) + rotating refresh tokens; every request also checks the `Session` row, so revoke is immediate. Refresh reuse revokes the session. (Roadmap said JWT; this is simpler and instantly revocable.)
- API: `/api/auth/*` (signup, verify-email, login, refresh, logout, password-reset), `/api/me/*` (profile, sessions, revoke, password), `/api/manage/*` (manager only: users, permissions, company, invites). Domain signup needs email configured (verification token by mail) else 503; invite signup needs no email.
- No deletion anywhere: deactivate/revoke/unlist. Admin classes block delete. Superuser admin must never register letter models.
- Email goes through `accounts/mailer.py` using SMTP from `CompanySettings`; Django 6.1 deprecates `EMAIL_BACKEND`/`get_connection` (removed in 2028): migrate to `MAILERS`.
- Phase 1 reviews done (security + Django); fixes applied. Hardening: per-email login/reset/`/me/password` lockout (`accounts/ratelimit.py`, 10 failures/15 min, cache-backed); Redis `CACHES` when `REDIS_URL` set (throttles shared across workers); `NUM_PROXIES` (default 0 = ignore X-Forwarded-For) drives client IP; refresh tokens: every rotated token is kept in `RetiredRefresh`, reuse of any retired token revokes the session, except the immediate predecessor within 10 s (lost-response retry gets a fresh pair); `Cache-Control: no-store` on `/api/`; prod settings (HTTPS redirect, HSTS, secure cookies) unless `DJANGO_HTTPS=0` (compose default 0).
- **Known gaps:** mail is sent synchronously (use `on_commit` + Celery; also makes reset latency uniform); `smtp_password` plaintext; HSTS subdomains/preload not set; `MAILERS` migration pending.
- Flutter Phase 1: `app/lib/api/` (`ApiClient` auto-refresh single-flight, refresh token in `flutter_secure_storage`, access token memory-only; `AuthController`), `app/lib/screens/` (login, signup, reset, profile, devices, manager admin tab). Not yet run on a device.

## Server apps (Phases 2-5)
- `keys/`: `UserKey` (one per device; first key auto-active, later ones `pending` until the manager approves; rows are never overwritten), company key (`CompanyKeyVersion`/`CompanyKeyWrap`, server holds wrapped copies only), directory of active keys. Fingerprint is recomputed server-side (`core/cryptoutil.py`, same algorithm as JS/Dart). Key changes alert the owner and the manager.
- `letters/`: `Letter` (title plaintext, body = E2E `{iv, ct}`), `Participant` (signer/viewer; `role="removed"` rows are soft-dropped draft people), `DocKeyWrap` (doc key per user key), `Signature` (immutable), `Attachment` (ciphertext on `MEDIA_ROOT`), `LetterEvent` (catch-up cursor). Rules live in `letters/rules.py` (visibility, audience, who may decrypt). State: draft -> in_signing -> published | rejected | cancelled, plus `unlisted` (manager, published only). Sent letters are immutable; `shown_at` = when viewers may see it.
- **Signature contract:** payload `{letterId,title,decision,note,contentHash,signer{userId,keyId,fp},sessionId,deviceName,signedAt,nonce}`; `contentHash` = sha256 hex of canonical JSON of the body `{iv,ct}`; ECDSA P-256 raw r||s over canonical JSON; server checks every field, key must be active with a wrap for the letter, session must be the caller's, `signedAt` within 10 min, nonce unique.
- Live: `/ws/?token=<access>` (`letters/consumers.py`), events also stored in `LetterEvent`; client sends `{"after": id}` to catch up. Notifications: `accounts/notify.py` stores `Notification`, pushes over WS, emails when SMTP/email is configured. In-app list: `/api/me/notifications`.
- Audit: hash chain (`accounts/models.py: audit()`, `verify_audit_chain()`, `manage.py verify_audit`); Unfold shows chain status and CSV export. Never put letter titles in audit data (superuser reads it). DB triggers (`letters/migrations/0002`) refuse DELETE on all records and UPDATE on audit/signatures/events; never use `transaction=True` pytest tests (flush deletes) and use `django_capture_on_commit_callbacks(execute=True)` when a test needs `on_commit` hooks.
- Ops: `scripts/backup.sh`, `scripts/restore.sh`, `docs/RELEASE.md`.
- Security review of Phases 2-5 applied (drafts private to creator, wraps can't be poisoned/overwritten, `parentId` signed, size caps, HMAC audit chain keyed by SECRET_KEY, sent letters immutable at DB level). **Open:** attachments are not bound into the signature (put attachment ids + ciphertext hashes inside the encrypted body), no per-user upload quota (also set `client_max_body_size` at the proxy), WebSocket token is in the query string (keep it out of access logs), `no` assignment is max+1 without a lock, record `verify_audit`'s head hash off-database to detect deleted tail rows, run Postgres as a non-owner role.

## Flutter (Phases 2-4)
- `app/lib/crypto/`: `identity.dart` (keygen, password wrap, strong-password rule), `document_crypto.dart` (doc-key wrap = ECDH->HKDF->AES-GCM `{to,epk,iv,ct}`, body AES-GCM `{iv,ct}`, `signPayload`). Interop vectors: `test-vectors/v2.json` (JS) and `dart-e2e.json` (Dart, git-ignored; `REQUIRE_DART_SIGNED=1 npm test`).
- `app/lib/keys/`: `KeyStore` (secure storage; password-protected = transferable, biometric-sealed = never exportable), `DeviceKeyVault` (fresh unlock per signature), brute-force delay (`AttemptLimiter`), QR/file transfer (envelope `{v,keyId,keyFile}`, QR frames `SLK1|id|i|n|chunk`), manager approvals, `CompanyKeyService`.
- `app/lib/letters/`: `LettersEnv` bundles api/vault/company keys/live service; screens for list, detail, create, sign, admin, notifications; `LiveService` (WebSocket, cursor catch-up, 4401 = session ended); `RewrapService` after unlock. `app/lib/screens/home_screen.dart` wires everything into tabs.
- Never verified on a device/simulator: biometrics (`local_auth`), QR scanning, file picking/sharing, WebSocket against a real server, the home-screen wiring (no widget test). Pure-Dart PBKDF2 at 600k iterations takes ~5 s per unlock/wrap: consider moving to a native KDF if that is too slow on phones.

## Letterhead and paper print (Flutter)
- `CompanySettings.letterhead` (JSON: name, tagline, address, phone, email, website, footer, logo as PNG/JPEG data URL <=300k chars) is set by the manager via `PATCH /manage/company` (`clean_letterhead` whitelists) and read by any user at `GET /me/letterhead`. It is public, not encrypted.
- App: `screens/letterhead_card.dart` (Admin tab), `letters/letterhead.dart`, `letters/paper_pages.dart` (A4 595x842pt pagination by `TextPainter` lines, `PaperPage`), `letters/paper_screen.dart` (font-size slider 9-20pt, preview, print/save PDF). Print rasterizes each page widget (3x) into a `pdf` page and calls `Printing.layoutPdf`, so any font/RTL the UI renders prints correctly. Opened from the letter detail app bar. Not yet run on a real printer/device.
- Unfold admin: `CompanySettings` is a one-row admin (changelist redirects to add when empty, else to edit; add blocked once it exists; letterhead edited as flat fields + logo upload). Users admin has a "Import users from CSV" list action (`import_users_from_csv`: skips existing emails, no password, base permission).
- Departments: `accounts.Department` (name unique, `active`; never deleted). `User.department` is an FK. Only the manager manages them (`/manage/departments`, `PUT /manage/users/{id}/department`); users cannot edit their own department; Django admin shows them read-only. App: `screens/departments_card.dart` (Admin tab) + "Department" in each person's menu.
- Invitation codes carry `grants` (permission codes, besides the base one) and an optional `department`; both are applied to the user at invite signup. Set in the app's "New invitation code" dialog or in the admin.
- Rich letters: `letters/rich/` (`RichDoc` = text + one style flag per UTF-16 unit + one `ParaStyle` per line; `RichController` keeps it in step with the text field, undo/redo; `rich_layout.dart` paginates A4 by lines and draws paragraphs). Formatting is saved as `body.rich` (`{v:1, f:[[run,flags]], p:[[kind,align]]}`) inside the encrypted body, `body.text` stays the plain fallback; a `rich` that does not match `text` is ignored. Editor shows bold/italic/underline/headings live; alignment and bullets show in the A4 preview. No plaintext draft autosave on disk (it would break E2E): use Save draft.
