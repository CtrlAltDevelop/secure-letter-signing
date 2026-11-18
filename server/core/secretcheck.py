"""Start-up checks for deployment secrets (imported by settings, so it must not import Django settings)."""
import logging

MIN_SECRET_LENGTH = 32
GENERATE_HINT = 'python -c "import secrets;print(secrets.token_urlsafe(48))"'


def validate_secrets(data_key: str, seal_seed: str, dev_fallbacks: tuple[str, ...]) -> None:
    """Refuse weak production secrets: too short, equal to each other, or equal to the dev fallbacks."""
    for name, value in (("DJANGO_DATA_KEY", data_key), ("DJANGO_SEAL_SEED", seal_seed)):
        if value in dev_fallbacks:
            raise RuntimeError(f"{name} is a development fallback value; generate one with: {GENERATE_HINT}")
        if len(value) < MIN_SECRET_LENGTH:
            raise RuntimeError(f"{name} must be at least {MIN_SECRET_LENGTH} characters; generate one with: {GENERATE_HINT}")
    if data_key == seal_seed:
        raise RuntimeError("DJANGO_DATA_KEY and DJANGO_SEAL_SEED must differ from each other")


def warn_if_limits_are_per_process(*, debug: bool, redis_url: str) -> None:
    if debug or redis_url:
        return
    logging.getLogger("config").warning(
        "REDIS_URL is not set: PIN and login rate limits are per-process (in-memory), so they are weakened with "
        "several workers and reset on restart. Set REDIS_URL in production.")
