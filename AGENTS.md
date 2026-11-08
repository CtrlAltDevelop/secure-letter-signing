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
- Print: `#printArea` must stay a direct child of `<body>` (in `layout.html`, not in a page fragment) because the print CSS hides every other body child. Wait for the image `load` event before `window.print()`; `img.decode()` never settles inside a `display:none` container.
- Styling: glass theme in `src/style.css` (CSS variables, light/dark via OS). Mobile-first; keep inputs at 16px (iOS zoom) and check there is no horizontal scroll at 375px.
- Palette (design tokens, do not invent new hues): Dark `#081528`/`#0F203A`, Gold `#BFA46F`/`#FBD57F`, Blue `#165EF6` (action) `#A4B9E4` (light) `#32568A` (mid), State `#4CD8B9` ok / `#D65959` error / `#CFA44B` warn, tints `#BBF0E4` / `#EFC9C9`. UI colours live as CSS variables in `src/style.css`; the white letter paper uses the `PAPER` object in `src/shared.js` (darker shades of the same hues for contrast on white).
- Font: Vazirmatn (SIL OFL, `src/fonts/`, license in `OFL.txt`) is inlined as base64 `@font-face` by `build.mjs` (`/*FONT*/` marker in `style.css`), so pages stay offline. Canvas text must `await document.fonts.load(...)` before measuring (done in `renderLetter`).
- Layout: pages use `.split` > `.seg` (phone switch) + `.pane` cards. Phone shows one `.pane.active` at a time (`setPane(id, name)` in `shared.js`); ≥900px shows all panes side by side with the preview pane `.sticky` (scrolls inside itself). Keep each phone screen about one viewport tall; move content between panes rather than stacking cards. Scope tab handlers to `[data-tab]` so they never catch `.seg` buttons.
- Manager page: row 1 = collapsible `<details id="keySetup">` (open while locked, auto-collapses on unlock, summary shows the signer); row 2 = `.split` with letter pane + decision/sign pane. Employee page uses the same `<details>` pattern for its setup block.
