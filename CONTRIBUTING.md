# Contributing

Read [AGENTS.md](AGENTS.md) first: it is the canonical guide (layout, commands, gotchas).

```bash
make dev                                   # backend on :8090 (SQLite, no Docker)
cd server && DJANGO_DEBUG=1 uv run pytest  # server tests
npm test                                   # legacy offline crypto tests (Node >= 19)
cd app && flutter pub get && flutter test  # copy brands/demo/* to app/assets/brand/ first
```

- Branch from `develop`, open the PR against `develop`. Keep PRs small and focused.
- Commit style: `feat|fix|refactor|docs|test|chore|perf|ci: description`.
- Add or update tests with every behavior change. CI must be green.
- Security-sensitive changes (auth, crypto, access rules) need a note on the threat model in the PR.
- Never add network calls to the offline HTML app (`src/`, `dist/`). Never commit secrets or `.env` files.
- UI strings are Persian (RTL); keep them in the l10n files, not inline.

By contributing you agree your work is released under the [AGPL-3.0 license](LICENSE).
