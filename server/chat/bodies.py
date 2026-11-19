"""Encrypted message bodies: `{"text": ...}` plus, for system messages, a few reference fields."""
import logging

from ninja.errors import HttpError

from core import cryptoutil

logger = logging.getLogger(__name__)


def seal_body(text: str, **extra) -> dict:
    return cryptoutil.encrypt_body({"text": text, **extra}) if (text or extra) else {}


def open_body(stored: dict) -> dict:
    if not stored:
        return {}
    try:
        return cryptoutil.decrypt_body(stored)
    except cryptoutil.DecryptError as exc:
        logger.error("Stored chat message cannot be decrypted: %s", exc)
        raise HttpError(500, "Stored text cannot be decrypted; check DJANGO_DATA_KEY") from exc


def open_text(stored: dict) -> str:
    return str(open_body(stored).get("text", ""))
