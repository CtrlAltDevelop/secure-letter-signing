"""Encrypted text values (`{"text": ..}` sealed as `{"v":3,"ct":..}`): descriptions and comments."""
import logging

from ninja.errors import HttpError

from core import cryptoutil

logger = logging.getLogger(__name__)


def seal_text(text: str) -> dict:
    """Stored form of `text`; an empty text is stored as an empty dict."""
    return cryptoutil.encrypt_body({"text": text}) if text else {}


def open_text(stored: dict) -> str:
    if not stored:
        return ""
    try:
        return str(cryptoutil.decrypt_body(stored).get("text", ""))
    except cryptoutil.DecryptError as exc:
        logger.error("Stored text cannot be decrypted: %s", exc)
        raise HttpError(500, "Stored text cannot be decrypted; check DJANGO_DATA_KEY") from exc
