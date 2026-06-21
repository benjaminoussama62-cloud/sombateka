from fastapi.testclient import TestClient

from app.main import app

client = TestClient(app)


def test_otp_flow_dev():
    phone = "+243999888777"
    send = client.post("/api/auth/otp/send", json={"phone_e164": phone})
    assert send.status_code == 200
    data = send.json()
    assert data.get("dev_code") or data.get("sms_sent")

    code = data.get("dev_code") or "000000"
    if not data.get("dev_code"):
        return

    verify = client.post(
        "/api/auth/otp/verify",
        json={"phone_e164": phone, "code": code},
    )
    assert verify.status_code == 200
    assert "access_token" in verify.json()


def test_email_otp_flow_dev():
    email = "test.user@example.com"
    send = client.post("/api/auth/email/otp/send", json={"email": email, "display_name": "Test"})
    assert send.status_code == 200
    data = send.json()
    assert data.get("email_sent") is True
    code = data.get("dev_code")
    if not code:
        return

    verify = client.post(
        "/api/auth/email/otp/verify",
        json={"email": email, "code": code},
    )
    assert verify.status_code == 200
    assert "access_token" in verify.json()
