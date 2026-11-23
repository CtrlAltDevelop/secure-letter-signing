# Security policy

This project handles confidential letters and signatures, so please report vulnerabilities privately.

**Do not open a public issue.** Use GitHub's
[private vulnerability reporting](https://github.com/CtrlAltDevelop/secure-letter-signing/security/advisories/new)
(Security tab → "Report a vulnerability"). Include affected component (`server/`, `app/`, `src/`), steps to reproduce
and impact. You will get an acknowledgement within a few days.

Supported: the `main` branch only. The trust model and known limits are in [docs/security.md](docs/security.md) and
[docs/signing-v3.md](docs/signing-v3.md); please read them before reporting a documented limit.

Never commit real secrets. Deployment secrets live in `brands/<brand>/.env` (git-ignored); see `brands/.env.example`.
