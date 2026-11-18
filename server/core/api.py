from typing import Any

from ninja import NinjaAPI

from .brand import load_brand

api = NinjaAPI(title="Letter Signing API", version="0.1.0")


@api.get("/health", auth=None)
def health(request) -> dict[str, str]:
    return {"status": "ok"}


@api.get("/brand", auth=None)
def brand(request) -> dict[str, Any]:
    """Public brand info (name, colors, feature switches) for the app's splash/login."""
    return load_brand()
