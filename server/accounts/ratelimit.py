"""Failure counters for lockout/backoff, kept in the Django cache (Redis in production)."""
from django.core.cache import cache
from ninja.errors import HttpError
from ninja.throttling import AnonRateThrottle

MAX_FAILURES = 10
WINDOW = 15 * 60  # seconds


def client_ip(request) -> str | None:
    """Honours NUM_PROXIES (default 0 = REMOTE_ADDR only, so X-Forwarded-For cannot be spoofed)."""
    return AnonRateThrottle().get_ident(request)


def _key(scope: str, ident: str) -> str:
    return f"fail:{scope}:{ident.lower()}"


def check(scope: str, ident: str) -> None:
    """Raise 429 while `ident` is locked out."""
    if cache.get(_key(scope, ident), 0) >= MAX_FAILURES:
        raise HttpError(429, "Too many attempts; try again later")


def fail(scope: str, ident: str) -> None:
    key = _key(scope, ident)
    cache.add(key, 0, WINDOW)
    cache.incr(key)


def reset(scope: str, ident: str) -> None:
    cache.delete(_key(scope, ident))
