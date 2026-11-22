"""Model field that stores its text Fernet-encrypted (key: DJANGO_DATA_KEY, see core/cryptoutil)."""
import logging

from django.db import models

from . import cryptoutil

logger = logging.getLogger(__name__)


class EncryptedTextField(models.TextField):
    def get_prep_value(self, value):
        value = super().get_prep_value(value)
        return cryptoutil.encrypt_bytes(value.encode()).decode() if value else value

    def from_db_value(self, value, expression, connection):
        if not value:
            return value
        try:
            return cryptoutil.decrypt_bytes(value.encode()).decode()
        except cryptoutil.DecryptError:
            logger.error("Cannot decrypt a stored secret (wrong DJANGO_DATA_KEY?); treating it as empty")
            return ""
