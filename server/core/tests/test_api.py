import pytest
from django.test import Client


@pytest.fixture
def client() -> Client:
    return Client()


def test_health_returns_ok(client: Client) -> None:
    response = client.get("/api/health")
    assert response.status_code == 200
    assert response.json() == {"status": "ok"}


def test_brand_returns_configured_brand(client: Client) -> None:
    response = client.get("/api/brand")
    assert response.status_code == 200
    body = response.json()
    assert body["id"] == "demo"
    assert body["colors"]["primary"].startswith("#")


def test_brand_missing_config_raises(settings) -> None:
    from core.brand import load_brand

    settings.BRAND = "does-not-exist"
    with pytest.raises(RuntimeError, match="Brand config not found"):
        load_brand()
