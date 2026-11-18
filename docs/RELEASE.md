# Release and operations

## One company = one deployment
```bash
cp brands/.env.example brands/<brand>/.env   # edit secrets, SERVER_PORT, DJANGO_ALLOWED_HOSTS
./build.sh <brand> up                         # db + redis + server, project name letters-<brand>
./build.sh <brand> app apk|ios|macos|windows  # app with the brand baked in
```
Run two companies side by side by giving each brand its own `SERVER_PORT` (and set `apiUrl` in its `brand.json` to match):
`brands/demo` uses 8000, `brands/acme` uses 8001. Each has its own database, Redis, attachments volume and secrets.

Behind a TLS proxy set in the brand `.env`: `DJANGO_HTTPS=1`, `NUM_PROXIES=1`, `DJANGO_CSRF_TRUSTED_ORIGINS=https://letters.example.com`.
Without HTTPS the app must not be used outside a trial (tokens travel in the clear).

## First-time setup
1. `docker compose -p letters-<brand> exec server python manage.py createsuperuser` (the developer account).
2. In the Unfold admin (`/admin/`): create the users or enable signup; mark exactly one user **Manager**; set SMTP in Company settings if email should be used (otherwise notifications are in-app only).
3. The manager signs in, creates a key (first key is auto-approved), then creates the **company key** (Keys screen) so public letters work.

## Backup and restore drill
```bash
./scripts/backup.sh <brand>                 # backups/<brand>-<time>/ (db.sql.gz, attachments.tar.gz, SHA256SUMS)
./scripts/restore.sh <brand> backups/<dir>  # destructive; asks you to type the brand name
docker compose -p letters-<brand> exec server python manage.py verify_audit
```
Drill (do it before go-live and after each upgrade): back up, restore into a **scratch** brand stack, sign in, open a letter, run `verify_audit`.
Backups hold only ciphertext bodies and public keys, never private keys; still store them encrypted and off the host.

## Release checklist
- `make test` green (server, JS, Flutter); `python manage.py check --deploy` with the production env.
- Rotate `DJANGO_SECRET_KEY` only with a plan: it invalidates every session and outstanding token.
- Builds: Android `apk`/`appbundle` (sign with your keystore), iOS/macOS (Xcode signing, notarize), Windows (MSIX or installer). The brand is chosen at build time with `--dart-define=BRAND=<id>`.
- Verify the audit chain after every restore or database maintenance.

## Not verified in this repository
Docker images, the compose stack, store/installer builds, push of the app to real devices and the two-brands-side-by-side run were not executed in the environment where this was written (no Docker daemon, no device). Treat them as the first thing to run.
