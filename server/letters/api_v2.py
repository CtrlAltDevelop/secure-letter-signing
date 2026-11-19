"""Routers of letters v2 that live outside `/letters`: mounted once, at the API root, from `core/api.py`."""
from ninja import Router

from .api_referrals import referrals_router
from .api_secretariat import router as secretariat_router

router = Router()
router.add_router("/referrals", referrals_router)
router.add_router("/secretariat", secretariat_router)
