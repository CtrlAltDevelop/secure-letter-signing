import logging

import pytest

from core import secretcheck

GOOD_A, GOOD_B = "a" * 40, "b" * 40
FALLBACKS = ("dev-only-insecure-data-key", "dev-only-insecure-seal-seed")


def test_good_secrets_pass():
    secretcheck.validate_secrets(GOOD_A, GOOD_B, FALLBACKS)


@pytest.mark.parametrize("data_key,seal_seed,fragment", [
    ("short", GOOD_B, "DJANGO_DATA_KEY"),
    (GOOD_A, "x" * 31, "DJANGO_SEAL_SEED"),
    (GOOD_A, GOOD_A, "differ"),
    ("dev-only-insecure-data-key" + "x" * 10, GOOD_B, "dev"),
])
def test_weak_secrets_are_refused_with_a_clear_message(data_key, seal_seed, fragment):
    if fragment == "dev":
        data_key = FALLBACKS[0]
    with pytest.raises(RuntimeError, match=fragment):
        secretcheck.validate_secrets(data_key, seal_seed, FALLBACKS)


def test_missing_redis_warns_loudly_outside_debug(caplog):
    with caplog.at_level(logging.WARNING, logger="config"):
        secretcheck.warn_if_limits_are_per_process(debug=False, redis_url="")
    assert "per-process" in caplog.text


def test_no_warning_with_redis_or_in_debug(caplog):
    with caplog.at_level(logging.WARNING, logger="config"):
        secretcheck.warn_if_limits_are_per_process(debug=False, redis_url="redis://r")
        secretcheck.warn_if_limits_are_per_process(debug=True, redis_url="")
    assert caplog.text == ""
