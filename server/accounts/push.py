"""Title-only push via FCM HTTP v1. Never carries content; no-op unless FCM_PROJECT_ID and FCM_SERVICE_ACCOUNT_FILE are set."""
import logging
import os

from .models import DeviceToken

logger = logging.getLogger(__name__)
FCM_SCOPE = "https://www.googleapis.com/auth/firebase.messaging"
FCM_TIMEOUT = 10


class FcmSender:
    """Lazy-imports google-auth; returns the tokens FCM reports as unregistered."""

    def __init__(self, project_id: str, service_account_file: str) -> None:
        self.project_id, self.service_account_file, self._session = project_id, service_account_file, None

    def _http(self):
        if self._session is None:
            from google.auth.transport.requests import AuthorizedSession
            from google.oauth2 import service_account

            creds = service_account.Credentials.from_service_account_file(self.service_account_file, scopes=[FCM_SCOPE])
            self._session = AuthorizedSession(creds)
        return self._session

    def send(self, tokens: list[str], title: str) -> list[str]:
        dead = []
        url = f"https://fcm.googleapis.com/v1/projects/{self.project_id}/messages:send"
        for token in tokens:
            resp = self._http().post(url, json={"message": {"token": token, "notification": {"title": title}}},
                                     timeout=FCM_TIMEOUT)
            if resp.status_code == 404 or "UNREGISTERED" in resp.text:
                dead.append(token)
            elif resp.status_code >= 400:
                logger.error("FCM push failed: HTTP %s", resp.status_code)
        return dead


_sender = None


def get_sender():
    global _sender
    project, key_file = os.environ.get("FCM_PROJECT_ID"), os.environ.get("FCM_SERVICE_ACCOUNT_FILE")
    if _sender is None and project and key_file:
        _sender = FcmSender(project, key_file)
    return _sender


def push_title(user, title: str, sender=None) -> None:
    """Best effort: never raises. Guests and inactive users get nothing."""
    sender = sender or get_sender()
    if sender is None or user.is_guest or not user.is_active:
        return
    tokens = list(DeviceToken.objects.filter(user=user).values_list("token", flat=True))
    if not tokens:
        return
    try:
        dead = sender.send(tokens, title)
    except Exception:  # noqa: BLE001  a push outage must not break delivery
        logger.exception("Push to user %s failed", user.id)
        return
    if dead:
        DeviceToken.objects.filter(token__in=dead).delete()
