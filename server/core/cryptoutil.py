"""Server-side crypto: Fernet encryption at rest and the Ed25519 seal that stamps every signature.

Both keys are derived (HKDF-SHA256) from secrets in settings (`DATA_KEY`, `SEAL_SEED`), never stored in the database.
"""
import base64
import binascii
import hashlib
import json
from functools import lru_cache

from cryptography.exceptions import InvalidSignature
from cryptography.fernet import Fernet, InvalidToken
from cryptography.hazmat.primitives import hashes, serialization
from cryptography.hazmat.primitives.asymmetric.ed25519 import Ed25519PrivateKey, Ed25519PublicKey
from cryptography.hazmat.primitives.kdf.hkdf import HKDF
from django.conf import settings

BODY_VERSION = 3
DATA_SALT, SEAL_SALT = b"letter-signing/salt/data-key/v1", b"letter-signing/salt/seal-seed/v1"  # not secret


class DecryptError(ValueError):
    pass


def canonical_json(value) -> str:
    """Sorted keys, no whitespace, no floats (matches JSON.stringify(sortKeys(v)))."""
    return json.dumps(_reject_floats(value), sort_keys=True, separators=(",", ":"), ensure_ascii=False)


def _reject_floats(v):
    if isinstance(v, float):
        raise ValueError("floats are not allowed in signed payloads")
    if isinstance(v, dict):
        return {k: _reject_floats(x) for k, x in v.items()}
    if isinstance(v, list):
        return [_reject_floats(x) for x in v]
    return v


def content_hash(body: dict) -> str:
    """What a signature binds to: SHA-256 hex of the canonical JSON of the PLAINTEXT body."""
    return hashlib.sha256(canonical_json(body).encode()).hexdigest()


def _derive(secret: str, info: bytes, salt: bytes) -> bytes:
    """Fixed, non-secret salt per purpose. Changing a salt (or a key) makes data derived from it unreadable."""
    return HKDF(algorithm=hashes.SHA256(), length=32, salt=salt, info=info).derive(secret.encode())


# --- encryption at rest ---------------------------------------------------------------------------------------


@lru_cache(maxsize=4)
def _fernet(secret: str) -> Fernet:
    return Fernet(base64.urlsafe_b64encode(_derive(secret, b"letter-signing/data-key/v1", DATA_SALT)))


def encrypt_bytes(data: bytes) -> bytes:
    return _fernet(settings.DATA_KEY).encrypt(data)


def decrypt_bytes(token: bytes) -> bytes:
    try:
        return _fernet(settings.DATA_KEY).decrypt(token)
    except InvalidToken as exc:
        raise DecryptError("stored data cannot be decrypted with the configured DJANGO_DATA_KEY") from exc


def encrypt_body(body: dict) -> dict:
    token = encrypt_bytes(canonical_json(body).encode())
    return {"v": BODY_VERSION, "ct": token.decode()}


def decrypt_body(stored: dict) -> dict:
    if not isinstance(stored, dict) or stored.get("v") != BODY_VERSION or not isinstance(stored.get("ct"), str):
        raise DecryptError("unsupported stored body format")
    return json.loads(decrypt_bytes(stored["ct"].encode()))


# --- the seal ------------------------------------------------------------------------------------------------


@lru_cache(maxsize=4)
def _seal_key(secret: str) -> Ed25519PrivateKey:
    return Ed25519PrivateKey.from_private_bytes(_derive(secret, b"letter-signing/seal-seed/v1", SEAL_SALT))


def _public_raw(key: Ed25519PrivateKey | Ed25519PublicKey) -> bytes:
    pub = key.public_key() if isinstance(key, Ed25519PrivateKey) else key
    return pub.public_bytes(serialization.Encoding.Raw, serialization.PublicFormat.Raw)


def seal_payload(payload: dict) -> str:
    return base64.b64encode(_seal_key(settings.SEAL_SEED).sign(canonical_json(payload).encode())).decode()


def verify_seal(payload: dict, seal_b64: str) -> bool:
    try:
        public = _seal_key(settings.SEAL_SEED).public_key()
        public.verify(base64.b64decode(seal_b64, validate=True), canonical_json(payload).encode())
        return True
    except (InvalidSignature, binascii.Error, ValueError):
        return False


def seal_public_info() -> dict:
    raw = _public_raw(_seal_key(settings.SEAL_SEED))
    digest = hashlib.sha256(raw).hexdigest()[:32]
    return {"alg": "Ed25519", "public_key": base64.b64encode(raw).decode(),
            "fingerprint": "-".join(digest[i : i + 4] for i in range(0, 32, 4))}
