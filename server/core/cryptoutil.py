"""Server-side verification helpers; byte-compatible with src/crypto.js (canonical JSON, fingerprint, ECDSA raw r||s)."""
import base64
import binascii
import hashlib
import json

from cryptography.exceptions import InvalidSignature
from cryptography.hazmat.primitives import hashes
from cryptography.hazmat.primitives.asymmetric import ec
from cryptography.hazmat.primitives.asymmetric.utils import encode_dss_signature

PUB_FIELDS = ("kty", "crv", "x", "y")


class BadKey(ValueError):
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


def clean_jwk(jwk: dict) -> dict:
    """Public-only EC P-256 JWK with a real curve point, or BadKey."""
    if not isinstance(jwk, dict) or jwk.get("kty") != "EC" or jwk.get("crv") != "P-256":
        raise BadKey("Public key must be an EC P-256 JWK")
    out = {f: jwk.get(f) for f in PUB_FIELDS}
    if not all(isinstance(out[f], str) for f in PUB_FIELDS):
        raise BadKey("Incomplete public key")
    _load(out)
    return out


def _b64url(s: str) -> int:
    try:
        return int.from_bytes(base64.urlsafe_b64decode(s + "=" * (-len(s) % 4)), "big")
    except (binascii.Error, ValueError) as exc:
        raise BadKey("Malformed public key") from exc


def _load(jwk: dict) -> ec.EllipticCurvePublicKey:
    try:
        return ec.EllipticCurvePublicNumbers(_b64url(jwk["x"]), _b64url(jwk["y"]), ec.SECP256R1()).public_key()
    except ValueError as exc:
        raise BadKey("Not a point on P-256") from exc


def fingerprint(sign_pub: dict, enc_pub: dict) -> str:
    text = canonical_json({"sign": clean_jwk(sign_pub), "enc": clean_jwk(enc_pub)})
    digest = hashlib.sha256(text.encode()).hexdigest()[:32]
    return "-".join(digest[i : i + 4] for i in range(0, 32, 4))


def verify_ecdsa(payload: dict, signature_b64: str, sign_pub: dict) -> bool:
    try:
        raw = base64.b64decode(signature_b64, validate=True)
        if len(raw) != 64:
            return False
        der = encode_dss_signature(int.from_bytes(raw[:32], "big"), int.from_bytes(raw[32:], "big"))
        _load(sign_pub).verify(der, canonical_json(payload).encode(), ec.ECDSA(hashes.SHA256()))
        return True
    except (InvalidSignature, binascii.Error, ValueError, BadKey):
        return False


def content_hash(body: dict) -> str:
    """What a signature binds to: SHA-256 hex of the canonical JSON of the ciphertext body {iv, ct}."""
    return hashlib.sha256(canonical_json(body).encode()).hexdigest()
