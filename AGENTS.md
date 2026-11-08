# AGENTS.md — secure-letter-signing

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
