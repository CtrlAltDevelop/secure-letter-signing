"""Load the brand config for this deployment (one company per deployment)."""
import json
from typing import Any

from django.conf import settings

REQUIRED_KEYS = ("id", "name", "colors")


def load_brand() -> dict[str, Any]:
    path = settings.BRANDS_DIR / settings.BRAND / "brand.json"
    try:
        brand = json.loads(path.read_text(encoding="utf-8"))
    except FileNotFoundError as exc:
        raise RuntimeError(f"Brand config not found: {path}") from exc
    missing = [k for k in REQUIRED_KEYS if k not in brand]
    if missing:
        raise RuntimeError(f"Brand config {path} is missing keys: {missing}")
    return brand
