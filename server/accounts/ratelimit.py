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


def check(scope: str, ident: str, max_failures: int = MAX_FAILURES) -> None:
    """Raise 429 while `ident` is locked out (after `max_failures` failures in the window)."""
    if cache.get(_key(scope, ident), 0) >= max_failures:
        raise HttpError(429, "Too many attempts; try again later")


def fail(scope: str, ident: str) -> None:
    key = _key(scope, ident)
    cache.add(key, 0, WINDOW)
    cache.incr(key)


def reset(scope: str, ident: str) -> None:
    cache.delete(_key(scope, ident))


def count(scope: str, ident: str) -> int:
    return cache.get(_key(scope, ident), 0)


def hit(scope: str, ident: str, max_attempts: int, window: int = WINDOW) -> int:
    """Atomically count one attempt BEFORE the guarded work and raise 429 once the count exceeds `max_attempts`
    (concurrent guesses cannot race past it); `window` is the counting period in seconds.
    Call `refund` once the attempt turned out to be legitimate."""
    key = _key(scope, ident)
    cache.add(key, 0, window)
    try:
        attempts = cache.incr(key)
    except ValueError:  # the key expired between add and incr
        cache.set(key, 1, window)
        attempts = 1
    if attempts > max_attempts:
        raise HttpError(429, "Too many attempts; try again later")
    return attempts


def refund(scope: str, ident: str) -> None:
    """Give back one attempt taken by `hit` (the guarded check succeeded), never going below zero."""
    key = _key(scope, ident)
    try:
        if cache.decr(key) < 0:
            cache.set(key, 0, WINDOW)
    except ValueError:  # the window already expired
        pass
