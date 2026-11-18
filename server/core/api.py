from typing import Any

from ninja import NinjaAPI

from accounts.api_auth import router as auth_router
from accounts.api_manager import router as manager_router
from accounts.api_me import router as me_router

from keys.api import router as keys_router
from letters.api import router as letters_router

from .brand import load_brand

api = NinjaAPI(title="Letter Signing API", version="0.2.0")
api.add_router("/auth", auth_router)
api.add_router("/me", me_router)
api.add_router("/manage", manager_router)
api.add_router("/keys", keys_router)
api.add_router("/letters", letters_router)


@api.get("/health", auth=None)
def health(request) -> dict[str, str]:
    return {"status": "ok"}


@api.get("/brand", auth=None)
def brand(request) -> dict[str, Any]:
    """Public brand info (name, colors, feature switches) for the app's splash/login."""
    return load_brand()
