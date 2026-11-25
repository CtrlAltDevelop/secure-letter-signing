# Changelog

All notable changes to this project are documented here. The format follows
[Keep a Changelog](https://keepachangelog.com/en/1.1.0/) and the project uses
[Semantic Versioning](https://semver.org/).

## [1.0.0] - 2026-11-25

First public release.

### Added
- **Offline edition** (`dist/`): three self-contained HTML files (`keygen`, `employee`, `manager`) with
  ECDSA signatures and AES-GCM encryption, a revision loop, print support and a Persian RTL glass UI with
  the inlined Vazirmatn font. No network requests.
- **Server** (Django 6, django-ninja, Unfold admin): accounts with opaque, instantly revocable tokens,
  two-step login, sessions and login history, invitation codes, guests, a permission catalog and
  departments/company titles.
- **Signed letters (signing v3):** server-side encryption at rest (Fernet) and Ed25519-sealed signatures,
  confirmed by signing PIN, biometric session or remote approval from another device. Letter numbering,
  referrals, paraphs, secretariat, archive/search and a verifiable certificate. See `docs/signing-v3.md`.
- **Audit:** HMAC hash chain with a `verify_audit` command; database triggers refuse deletes and updates on
  immutable records; nothing is deleted anywhere.
- **Workspace modules:** tasks (approval chains, checklists, templates), projects (board, list and
  calendar views, Gantt with critical path, imports), meetings with signed minutes and LiveKit video,
  chat, polls, notes, CRM, finance and sales, calendar with Jalali dates and holidays, search, bookmarks,
  reminders, mentions, and push notifications (server side, FCM).
- **Flutter app** for Android, iOS, macOS and Windows, with rich A4 letter editor, letterhead and print,
  Persian UI and per-brand builds.
- **Deployment:** per-brand Docker Compose stack (Postgres, Redis, server, optional nginx TLS proxy),
  backup and restore scripts, a daily backup cron installer, and `make dev` for a Docker-free setup.
- **Landing site** (`site/`): bilingual page with a Three.js hero and app screenshots, published to GitHub
  Pages from `main`.
- `SECURITY.md`, `CONTRIBUTING.md`, MIT license and release notes in `docs/RELEASE.md`.

### Changed
- CI runs tests only on pull requests into `main`; Pages publishes when `site/` changes on `main`.

[1.0.0]: https://github.com/CtrlAltDevelop/secure-letter-signing/releases/tag/v1.0.0
