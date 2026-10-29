from fastapi.testclient import TestClient

from app.main import app

client = TestClient(app)


def test_healthz():
    r = client.get("/healthz")
    assert r.status_code == 200
    body = r.json()
    assert "ok" in body
    assert "db" in body


def test_openapi():
    r = client.get("/openapi.json")
    assert r.status_code == 200
