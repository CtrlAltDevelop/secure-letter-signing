"""Encrypted file storage: bytes are Fernet-encrypted (core/cryptoutil) before they reach MEDIA_ROOT."""
from django.core.files.base import ContentFile
from django.db.models.fields.files import FieldFile

from . import cryptoutil

DecryptError = cryptoutil.DecryptError
# Types accepted for letter attachments and workspace files.
ATTACHMENT_TYPES = {"application/pdf", "image/png", "image/jpeg", "image/webp", "image/heic"}


def save_encrypted(field: FieldFile, data: bytes, name: str = "blob") -> None:
    """Store `data` encrypted in the model's FileField (does not save the model instance)."""
    field.save(name, ContentFile(cryptoutil.encrypt_bytes(data)), save=False)


def read_decrypted(field: FieldFile) -> bytes:
    """Plaintext of a file written by `save_encrypted`. Raises `DecryptError` if the key does not match."""
    with field.open("rb") as handle:
        stored = handle.read()
    return cryptoutil.decrypt_bytes(stored)
