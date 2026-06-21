from app.services.email import normalize_email, send_email, send_otp_email, notify_admin_alert
from app.settings import settings


def test_normalize_email():
    assert normalize_email("  User@Example.COM ") == "user@example.com"


def test_send_email_log_provider(monkeypatch):
    monkeypatch.setattr(settings, "email_provider", "log")
    assert send_email("test@example.com", "Test", "Hello") is True


def test_send_otp_email_log(monkeypatch):
    monkeypatch.setattr(settings, "email_provider", "log")
    assert send_otp_email("test@example.com", "123456") is True


def test_admin_alert_skips_when_empty(monkeypatch):
    monkeypatch.setattr(settings, "admin_alert_emails", "")
    assert notify_admin_alert(subject="Test", body="Body") == 0


def test_admin_alert_sends(monkeypatch):
    monkeypatch.setattr(settings, "admin_alert_emails", "admin@example.com")
    monkeypatch.setattr(settings, "email_provider", "log")
    assert notify_admin_alert(subject="Test", body="Body") == 1
