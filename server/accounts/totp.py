"""TOTP (RFC 6238, HMAC-SHA1, 30 s step, 6 digits) with the standard library only."""
import base64
import hashlib
import hmac
import secrets
import struct
import time
from urllib.parse import quote

STEP = 30
DIGITS = 6
WINDOW = 1  # accepted drift in steps, either side
SECRET_BYTES = 20


def new_secret() -> str:
    """Random base32 secret (no padding), as authenticator apps expect."""
    return base64.b32encode(secrets.token_bytes(SECRET_BYTES)).decode().rstrip("=")


def _key(secret: str) -> bytes:
    padded = secret.strip().replace(" ", "").upper()
    return base64.b32decode(padded + "=" * (-len(padded) % 8))


def hotp(key: bytes, counter: int, digits: int = DIGITS) -> str:
    digest = hmac.new(key, struct.pack(">Q", counter), hashlib.sha1).digest()
    offset = digest[-1] & 0x0F
    value = struct.unpack(">I", digest[offset : offset + 4])[0] & 0x7FFFFFFF
    return str(value % 10**digits).zfill(digits)


def code_at(secret: str, at: float | None = None, step: int = STEP, digits: int = DIGITS) -> str:
    return hotp(_key(secret), int((time.time() if at is None else at) // step), digits)


def verify(secret: str, code: str, at: float | None = None) -> bool:
    """True when `code` matches the current step or one step either side. Compares every candidate in constant time."""
    code = (code or "").strip().replace(" ", "")
    if len(code) != DIGITS or not code.isdigit():
        return False
    counter = int((time.time() if at is None else at) // STEP)
    key = _key(secret)
    ok = False
    for delta in range(-WINDOW, WINDOW + 1):
        ok |= hmac.compare_digest(hotp(key, counter + delta), code)
    return ok


def otpauth_uri(secret: str, account: str, issuer: str) -> str:
    label = quote(f"{issuer}:{account}", safe="")
    return f"otpauth://totp/{label}?secret={secret}&issuer={quote(issuer, safe='')}&algorithm=SHA1&digits={DIGITS}&period={STEP}"
