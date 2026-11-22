"""Email via SMTP settings the superuser enters in the admin (CompanySettings)."""
import logging
import time
from concurrent.futures import ThreadPoolExecutor

from django.conf import settings
from django.db import close_old_connections, transaction
from django.core.mail import EmailMessage, mailers
from django.core.mail.backends.smtp import EmailBackend

from .models import CompanySettings

logger = logging.getLogger(__name__)
SMTP_BACKEND = "django.core.mail.backends.smtp.EmailBackend"


def _backend() -> str:
    return settings.MAILERS["default"]["BACKEND"]


def email_configured(cs: CompanySettings | None = None) -> bool:
    cs = cs or CompanySettings.load()
    return bool(cs.smtp_host) or _backend() != SMTP_BACKEND


def send(to: str, subject: str, body: str) -> bool:
    """Returns False when email is not configured or sending fails (callers fall back to in-app)."""
    cs = CompanySettings.load()
    if not email_configured(cs):
        return False
    try:
        if _backend() == SMTP_BACKEND:
            # Instantiated directly: the SMTP settings are per-company rows, not static settings (Django 6.1 deprecates
            # get_connection(backend, **kwargs)).
            conn = EmailBackend(
                alias="default", host=cs.smtp_host, port=cs.smtp_port, username=cs.smtp_user,
                password=cs.smtp_password, use_tls=cs.smtp_use_tls, timeout=10,
            )
        else:
            conn = mailers.default
        conn.send_messages([EmailMessage(subject, body, cs.from_email or None, [to])])
        return True
    except OSError:
        logger.exception("Email to %s failed", to)
        return False


# ponytail: in-process thread pool (no Celery worker is deployed); move to a Celery task once one runs in compose.
_pool = ThreadPoolExecutor(max_workers=2, thread_name_prefix="mail")


RETRY_DELAYS = (1, 5, 30)  # seconds slept before attempts 2..4; tests patch to (0, 0, 0)


def _deliver(to: str, subject: str, body: str) -> None:
    try:
        if not email_configured():
            return
        for delay in (None, *RETRY_DELAYS):
            if delay:
                time.sleep(delay)
            if send(to, subject, body):
                return
        logger.error("Email to %s failed after %d attempts", to, len(RETRY_DELAYS) + 1)
    finally:
        close_old_connections()


def send_later(to: str, subject: str, body: str) -> None:
    """Send after the surrounding transaction commits, off the request thread (inline when MAIL_ASYNC is off).
    Callers needing a fallback check `email_configured()` first; delivery is retried with backoff in the pool, then logged."""
    run = (lambda: _pool.submit(_deliver, to, subject, body)) if settings.MAIL_ASYNC else (lambda: send(to, subject, body))
    transaction.on_commit(run)
