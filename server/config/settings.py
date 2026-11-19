"""Settings are env-driven. One deployment = one company (BRAND)."""
import os
from pathlib import Path

from core import secretcheck

BASE_DIR = Path(__file__).resolve().parent.parent

DEBUG = os.environ.get("DJANGO_DEBUG", "0") == "1"
SECRET_KEY = os.environ.get("DJANGO_SECRET_KEY", "")
if not SECRET_KEY:
    if not DEBUG:
        raise RuntimeError("DJANGO_SECRET_KEY is required when DJANGO_DEBUG != 1")
    SECRET_KEY = "dev-only-insecure-key"  # nosec: only reachable with DJANGO_DEBUG=1


def _required_secret(name: str, dev_fallback: str) -> str:
    value = os.environ.get(name, "")
    if value:
        return value
    if not DEBUG:
        raise RuntimeError(f"{name} is required when DJANGO_DEBUG != 1")
    return dev_fallback  # nosec: only reachable with DJANGO_DEBUG=1


# At-rest encryption (letters, attachments) and the Ed25519 seal on signatures. Changing DATA_KEY makes stored
# letters unreadable; changing SEAL_SEED makes old seals fail verification. Back both up with the database.
DATA_KEY = _required_secret("DJANGO_DATA_KEY", "dev-only-insecure-data-key")
SEAL_SEED = _required_secret("DJANGO_SEAL_SEED", "dev-only-insecure-seal-seed")
if not DEBUG:
    secretcheck.validate_secrets(DATA_KEY, SEAL_SEED, ("dev-only-insecure-data-key", "dev-only-insecure-seal-seed"))
ALLOWED_HOSTS = [h for h in os.environ.get("DJANGO_ALLOWED_HOSTS", "localhost,127.0.0.1").split(",") if h]

BRAND = os.environ.get("BRAND", "demo")
BRANDS_DIR = Path(os.environ.get("BRANDS_DIR", BASE_DIR.parent / "brands"))

INSTALLED_APPS = [
    "daphne",  # runserver serves ASGI (WebSockets) in dev
    "unfold",  # must come before django.contrib.admin
    "django.contrib.admin",
    "django.contrib.auth",
    "django.contrib.contenttypes",
    "django.contrib.sessions",
    "django.contrib.messages",
    "django.contrib.staticfiles",
    "core",
    "accounts",
    "letters",
    "workspace",
    "tasks",
    "projects",
    "meetings",
    "notes",
    "polls",
    "crm",
    "finance",
    "sales",
    "chat",
]

MIDDLEWARE = [
    "django.middleware.security.SecurityMiddleware",
    "accounts.middleware.NoStoreApiMiddleware",
    "django.contrib.sessions.middleware.SessionMiddleware",
    "django.middleware.common.CommonMiddleware",
    "django.middleware.csrf.CsrfViewMiddleware",
    "django.contrib.auth.middleware.AuthenticationMiddleware",
    "django.contrib.messages.middleware.MessageMiddleware",
    "django.middleware.clickjacking.XFrameOptionsMiddleware",
]

ROOT_URLCONF = "config.urls"
WSGI_APPLICATION = "config.wsgi.application"
ASGI_APPLICATION = "config.asgi.application"

TEMPLATES = [
    {
        "BACKEND": "django.template.backends.django.DjangoTemplates",
        "DIRS": [],
        "APP_DIRS": True,
        "OPTIONS": {
            "context_processors": [
                "django.template.context_processors.request",
                "django.contrib.auth.context_processors.auth",
                "django.contrib.messages.context_processors.messages",
            ]
        },
    }
]

if os.environ.get("POSTGRES_HOST"):
    DATABASES = {
        "default": {
            "ENGINE": "django.db.backends.postgresql",
            "HOST": os.environ["POSTGRES_HOST"],
            "NAME": os.environ.get("POSTGRES_DB", "letters"),
            "USER": os.environ.get("POSTGRES_USER", "letters"),
            "PASSWORD": os.environ["POSTGRES_PASSWORD"],
        }
    }
else:  # local dev and tests only
    DATABASES = {"default": {"ENGINE": "django.db.backends.sqlite3", "NAME": BASE_DIR / "db.sqlite3"}}

# Redis in Docker; without REDIS_URL (make dev) use in-memory equivalents, no Redis needed.
REDIS_URL = os.environ.get("REDIS_URL", "")
secretcheck.warn_if_limits_are_per_process(debug=DEBUG, redis_url=REDIS_URL)
if REDIS_URL:
    CHANNEL_LAYERS = {"default": {"BACKEND": "channels_redis.core.RedisChannelLayer", "CONFIG": {"hosts": [REDIS_URL]}}}
    CELERY_BROKER_URL = REDIS_URL
    # Shared across workers and restarts: throttles and lockouts depend on it.
    CACHES = {"default": {"BACKEND": "django.core.cache.backends.redis.RedisCache", "LOCATION": REDIS_URL}}
else:
    CHANNEL_LAYERS = {"default": {"BACKEND": "channels.layers.InMemoryChannelLayer"}}
    CELERY_BROKER_URL = "memory://"
    CELERY_TASK_ALWAYS_EAGER = True  # run tasks inline in dev and tests

# Number of reverse proxies in front of the server. 0 = trust REMOTE_ADDR only (X-Forwarded-For ignored).
NINJA_NUM_PROXIES = int(os.environ.get("NUM_PROXIES", "0"))

# Production is HTTPS-only unless DJANGO_HTTPS=0 (plain-HTTP trial runs, e.g. the bare docker compose stack).
if not DEBUG and os.environ.get("DJANGO_HTTPS", "1") == "1":
    if NINJA_NUM_PROXIES:
        SECURE_PROXY_SSL_HEADER = ("HTTP_X_FORWARDED_PROTO", "https")
    SECURE_SSL_REDIRECT = True
    SECURE_HSTS_SECONDS = 31536000
    SESSION_COOKIE_SECURE = CSRF_COOKIE_SECURE = True
    CSRF_TRUSTED_ORIGINS = [o for o in os.environ.get("DJANGO_CSRF_TRUSTED_ORIGINS", "").split(",") if o]

AUTH_PASSWORD_VALIDATORS = [
    {"NAME": "django.contrib.auth.password_validation.UserAttributeSimilarityValidator"},
    {"NAME": "django.contrib.auth.password_validation.MinimumLengthValidator"},
    {"NAME": "django.contrib.auth.password_validation.CommonPasswordValidator"},
    {"NAME": "django.contrib.auth.password_validation.NumericPasswordValidator"},
]

AUTH_USER_MODEL = "accounts.User"
PUBLIC_URL = os.environ.get("PUBLIC_URL", "http://localhost:8000")
EMAIL_BACKEND = os.environ.get(
    "EMAIL_BACKEND",
    "django.core.mail.backends.console.EmailBackend" if DEBUG else "django.core.mail.backends.smtp.EmailBackend",
)

LANGUAGE_CODE = "en"
TIME_ZONE = "UTC"
USE_I18N = True
USE_TZ = True

MEDIA_ROOT = Path(os.environ.get("ATTACHMENTS_DIR", BASE_DIR / "attachments"))
MAX_ATTACHMENT_BYTES = 25 * 1024 * 1024
CUSTOMER_LIMIT = int(os.environ.get("CUSTOMER_LIMIT", "10000"))  # customer files (all statuses) per deployment
SALES_SHARED_VISIBILITY = os.environ.get("SALES_SHARED_VISIBILITY", "1") not in ("0", "false", "False")  # sales.manage holders see every lead
SMS_BACKEND = os.environ.get("SMS_BACKEND", "core.sms.ConsoleSmsBackend")  # dotted path, see core/sms.py
DATA_UPLOAD_MAX_MEMORY_SIZE = MAX_ATTACHMENT_BYTES + 1024 * 1024

STATIC_URL = "static/"
STATIC_ROOT = BASE_DIR / "staticfiles"
DEFAULT_AUTO_FIELD = "django.db.models.BigAutoField"
