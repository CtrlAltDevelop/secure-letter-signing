---
name: format-change
description: Change a signed letter payload or file format in secure-letter-signing: bump the version, update the docs and test vectors, run the tests. Use when adding or changing a field in a signed payload, or when the user says change the letter format.
---

# Change the letter format

1. Edit `src/crypto.js`. New fields that matter go inside `payload`, never beside it.
2. Bump `V` in `src/crypto.js`.
3. Update `docs/security.md`: threat model, file formats, revision flow.
4. Regenerate vectors: `node test-vectors/make.mjs`.
5. If the app is affected, port the change to `app/lib/crypto/letter_crypto.dart`.
6. `npm test` and `npm run build`; for the app, `flutter test` in `app/`.
7. Run the `crypto-reviewer` agent on the diff.

Never leave `V` unchanged after a format change: old files would verify as the new format.
