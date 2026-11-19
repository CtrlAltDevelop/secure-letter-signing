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
    modules = brand.get("modules")
    if modules is not None and not (isinstance(modules, list) and all(isinstance(m, str) for m in modules)):
        raise RuntimeError(f"Brand config {path}: 'modules' must be a list of module codes")
    return brand


def brand_modules() -> list[str] | None:
    """The optional `"modules"` list of brand.json (enabled module codes); None when absent (= every module)."""
    return load_brand().get("modules")
