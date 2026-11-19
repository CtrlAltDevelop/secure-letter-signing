"""SMS delivery behind a small provider interface. `SMS_BACKEND` (dotted path) picks the implementation."""
import logging
from collections.abc import Sequence
from typing import Protocol

from django.conf import settings
from django.utils.module_loading import import_string

logger = logging.getLogger(__name__)


class SmsBackend(Protocol):
    def send(self, recipients: Sequence[str], text: str) -> None: ...


class ConsoleSmsBackend:
    """Default: delivers nothing and logs only how many recipients there were (never numbers or text)."""

    def send(self, recipients: Sequence[str], text: str) -> None:
        logger.info("SMS (console backend): %d recipient(s), %d characters", len(recipients), len(text))


def get_backend() -> SmsBackend:
    return import_string(settings.SMS_BACKEND)()


def send_sms(recipients: Sequence[str], text: str) -> None:
    get_backend().send(list(recipients), text)
