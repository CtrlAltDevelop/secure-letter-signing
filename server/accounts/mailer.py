"""Email via SMTP settings the superuser enters in the admin (CompanySettings)."""
import logging

from django.conf import settings
from django.core.mail import EmailMessage, get_connection

from .models import CompanySettings

logger = logging.getLogger(__name__)
SMTP_BACKEND = "django.core.mail.backends.smtp.EmailBackend"


def email_configured(cs: CompanySettings | None = None) -> bool:
    cs = cs or CompanySettings.load()
    return bool(cs.smtp_host) or settings.EMAIL_BACKEND != SMTP_BACKEND


def send(to: str, subject: str, body: str) -> bool:
    """Returns False when email is not configured or sending fails (callers fall back to in-app)."""
    cs = CompanySettings.load()
    if not email_configured(cs):
        return False
    try:
        if settings.EMAIL_BACKEND == SMTP_BACKEND:
            conn = get_connection(
                SMTP_BACKEND, host=cs.smtp_host, port=cs.smtp_port, username=cs.smtp_user,
                password=cs.smtp_password, use_tls=cs.smtp_use_tls, timeout=10,
            )
        else:
            conn = get_connection(settings.EMAIL_BACKEND)
        EmailMessage(subject, body, cs.from_email or None, [to], connection=conn).send()
        return True
    except OSError:
        logger.exception("Email to %s failed", to)
        return False
