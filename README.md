# Secure Letter Signing

[![CI](https://github.com/CtrlAltDevelop/secure-letter-signing/actions/workflows/ci.yml/badge.svg)](https://github.com/CtrlAltDevelop/secure-letter-signing/actions/workflows/ci.yml)
[![License: MIT](https://img.shields.io/badge/license-MIT-blue.svg)](LICENSE)

Self-hosted company workspace built around **signed, confidential letters**: write a letter, send it to the manager,
approve / request revision / reject, and get a tamper-evident signed reply. Around it: tasks, projects with Gantt,
meetings, chat, polls, notes, CRM, finance and sales. Persian (RTL) UI. One company per deployment.

- **Server** (`server/`): Django 6, django-ninja API, Unfold admin, Channels (live), PostgreSQL + Redis. Letters are
  encrypted at rest; signatures are sealed server-side (Ed25519); audit log is a hash chain; no deletion anywhere.
- **App** (`app/`): Flutter for Android, iOS, macOS and Windows. PIN or biometric signing.
- **Offline app** (`src/`, `dist/`): three self-contained HTML files with end-to-end ECDSA/AES-GCM, no network.
- **Landing page** (`site/`): static page, published with GitHub Pages.

## Quick start

```bash
make dev                                  # backend on http://localhost:8090 (SQLite, no Docker)
cd server && DJANGO_DEBUG=1 uv run pytest # server tests
make macos                                # Flutter app against the dev server (copy brands/demo first, see Makefile)
```

Production (Docker, one brand per company):

```bash
cp brands/.env.example brands/<brand>/.env   # fill in secrets, never commit it
./build.sh <brand> up
```

See [docs/RELEASE.md](docs/RELEASE.md) (deploy, backup, restore), [AGENTS.md](AGENTS.md) (architecture and gotchas),
[docs/security.md](docs/security.md) and [docs/signing-v3.md](docs/signing-v3.md) (trust model).

## Contributing, security, license

[CONTRIBUTING.md](CONTRIBUTING.md) · [SECURITY.md](SECURITY.md) (report privately) · [MIT](LICENSE)

---

## نسخه‌ی آفلاین (HTML)
سه فایل HTML مستقل و آفلاین در `dist/`:
- `keygen.html` — ساخت کلید (یک بار): خروجی `manager.private` و `manager.pub`
- `manager.html` — پنل مدیر
- `employee.html` — پنل کارمند (تیم اداری)

## ساخت و اجرا
```bash
npm run build   # تولید dist/keygen.html و manager.html و employee.html
npm test        # تست لایه رمزنگاری
```
هر فایل را فقط به نقش خودش بدهید: `manager.html` به مدیر، `employee.html` به کارمند. `keygen.html` فقط یک بار و روی دستگاه مدیر اجرا می‌شود. (برای موبایل: روی یک آدرس HTTPS داخلی قرار دهید یا فایل را به دستگاه منتقل کنید.)

## جریان کار
1. **یک‌بار — ساخت کلید** (`keygen.html`، روی دستگاه مدیر): دو فایل دانلود می‌شود: `manager.private` (خصوصی، با رمز؛ فقط نزد مدیر) و `manager.pub` (عمومی؛ برای کارمند).
2. **یک‌بار — کارمند** (`employee.html`): `manager.pub` را ثبت کند و اثرانگشت را تلفنی با مدیر تطبیق دهد. سربرگ شرکت را هم همین‌جا تنظیم کند.
3. **کارمند:** موضوع و متن ← پیش‌نمایش ← دانلود `.letter` (رمزشده) و ارسال برای مدیر. عکس PNG نامه هم قابل دانلود است.
4. **مدیر:** کلید را باز کند ← `.letter` را باز کند ← یکی از سه تصمیم: **تأیید**، **نیاز به اصلاح** (توضیح الزامی)، **رد** ← امضا (کشیدن یا PNG) ← دانلود `.signed` و ارسال به کارمند.
5. **کارمند:** `.signed` را بارگذاری کند ← نتیجه‌ی بررسی (معتبر/نامعتبر).
   - اگر **تأیید** بود: چاپ یا دانلود PNG.
   - اگر **نیاز به اصلاح** یا **رد** بود: دکمه‌ی «ویرایش و ارسال مجدد» ← متن اصلاح می‌شود (توضیح مدیر بالای فرم دیده می‌شود) ← نسخه‌ی ۲ با همان شماره‌ی نامه ساخته و دوباره رمزشده برای مدیر فرستاده می‌شود. این چرخه تا تأیید نهایی تکرار می‌شود.

## تضمین‌ها
| شرط | راه‌حل |
|---|---|
| جعل نشدن | امضای دیجیتال ECDSA P-256 روی کل محتوا؛ تغییر یک حرف = نامعتبر |
| فقط مدیر | کلید خصوصی فقط در `.private` رمزگذاری‌شده (PBKDF2 + AES-GCM) نزد مدیر |
| بررسی توسط تیم اداری | تأیید آفلاین با کلید عمومی ثبت‌شده |
| آفلاین | بدون هیچ درخواست شبکه |

جزئیات و محدودیت‌ها: [docs/security.md](docs/security.md)

فونت: Vazirmatn (مجوز SIL OFL) داخل هر فایل جاسازی شده و نیازی به اینترنت نیست.


