"""Envoi d'emails transactionnels (log / SMTP / Resend)."""

from __future__ import annotations

import logging
import re
import smtplib
from email.mime.multipart import MIMEMultipart
from email.mime.text import MIMEText

import httpx

from app.settings import settings

logger = logging.getLogger(__name__)

_EMAIL_RE = re.compile(r"^[^@\s]+@[^@\s]+\.[^@\s]+$")


def normalize_email(value: str) -> str:
    email = value.strip().lower()
    if not _EMAIL_RE.match(email):
        raise ValueError("Adresse email invalide")
    return email


def _html_wrapper(title: str, body_html: str) -> str:
    return f"""<!DOCTYPE html>
<html lang="fr">
<head><meta charset="utf-8"><title>{title}</title></head>
<body style="font-family:Segoe UI,Arial,sans-serif;line-height:1.5;color:#111827;max-width:560px;margin:0 auto;padding:24px">
  <div style="border-bottom:3px solid #2563eb;padding-bottom:12px;margin-bottom:20px">
    <strong style="font-size:18px;color:#1e3a8a">SombaTeka</strong>
  </div>
  {body_html}
  <p style="margin-top:32px;font-size:12px;color:#6b7280">
    Cet email a été envoyé automatiquement. Ne répondez pas directement à cette adresse.
  </p>
</body>
</html>"""


def send_email(
    to: str,
    subject: str,
    text_body: str,
    *,
    html_body: str | None = None,
) -> bool:
    """Envoie un email. Retourne True si l'envoi a réussi (ou simulé en dev)."""
    try:
        recipient = normalize_email(to)
    except ValueError:
        logger.warning("Invalid email address: %s", to)
        return False

    provider = (settings.email_provider or "log").lower()
    html = html_body or _html_wrapper(subject, f"<p>{text_body.replace(chr(10), '<br>')}</p>")

    if provider == "log":
        logger.info("EMAIL [%s] subject=%s\n%s", recipient, subject, text_body)
        return True

    if provider == "smtp":
        return _send_smtp(recipient, subject, text_body, html)
    if provider == "resend":
        return _send_resend(recipient, subject, text_body, html)

    logger.warning("Unknown email provider %s — logging only", provider)
    logger.info("EMAIL [%s] subject=%s\n%s", recipient, subject, text_body)
    return True


def send_otp_email(email: str, code: str) -> bool:
    subject = "SombaTeka — votre code de connexion"
    text = (
        f"Votre code SombaTeka : {code}\n\n"
        f"Valide 10 minutes. Ne le partagez avec personne.\n\n"
        f"— Équipe SombaTeka"
    )
    html = _html_wrapper(
        subject,
        f"<p>Votre code de connexion :</p>"
        f'<p style="font-size:28px;font-weight:700;letter-spacing:4px;color:#2563eb">{code}</p>'
        f"<p>Valide <strong>10 minutes</strong>. Ne le partagez avec personne.</p>",
    )
    return send_email(email, subject, text, html_body=html)


def send_user_notification_email(
    *,
    email: str,
    title: str,
    body: str,
) -> bool:
    subject = f"SombaTeka — {title}"
    html = _html_wrapper(
        subject,
        f"<h2 style='color:#1e3a8a;margin-top:0'>{title}</h2>"
        f"<p>{body.replace(chr(10), '<br>')}</p>"
        f'<p><a href="{settings.public_base_url}" style="color:#2563eb">Ouvrir SombaTeka</a></p>',
    )
    return send_email(email, subject, body, html_body=html)


def notify_admin_alert(*, subject: str, body: str) -> int:
    """Envoie une alerte aux emails admin configurés. Retourne le nombre d'envois réussis."""
    recipients = settings.admin_alert_email_list()
    if not recipients:
        logger.debug("No admin alert emails configured — skipping: %s", subject)
        return 0

    sent = 0
    panel_url = f"{settings.public_base_url.rstrip('/')}/admin/dashboard"
    full_body = f"{body.strip()}\n\nPanneau admin : {panel_url}"
    html = _html_wrapper(
        subject,
        f"<p>{body.strip().replace(chr(10), '<br>')}</p>"
        f'<p><a href="{panel_url}" style="color:#2563eb">Ouvrir le panneau admin</a></p>',
    )
    for addr in recipients:
        if send_email(addr, f"[Admin SombaTeka] {subject}", full_body, html_body=html):
            sent += 1
    return sent


def _send_smtp(to: str, subject: str, text_body: str, html_body: str) -> bool:
    if not settings.smtp_host:
        logger.error("SMTP host missing")
        return False
    msg = MIMEMultipart("alternative")
    msg["Subject"] = subject
    msg["From"] = settings.email_from
    msg["To"] = to
    msg.attach(MIMEText(text_body, "plain", "utf-8"))
    msg.attach(MIMEText(html_body, "html", "utf-8"))
    try:
        if settings.smtp_use_ssl:
            with smtplib.SMTP_SSL(settings.smtp_host, settings.smtp_port, timeout=20) as server:
                if settings.smtp_user:
                    server.login(settings.smtp_user, settings.smtp_password)
                server.sendmail(settings.email_from, [to], msg.as_string())
        else:
            with smtplib.SMTP(settings.smtp_host, settings.smtp_port, timeout=20) as server:
                if settings.smtp_use_tls:
                    server.starttls()
                if settings.smtp_user:
                    server.login(settings.smtp_user, settings.smtp_password)
                server.sendmail(settings.email_from, [to], msg.as_string())
        return True
    except Exception as exc:
        logger.exception("SMTP email failed: %s", exc)
        return False


def _send_resend(to: str, subject: str, text_body: str, html_body: str) -> bool:
    if not settings.resend_api_key:
        logger.error("Resend API key missing")
        return False
    payload = {
        "from": settings.email_from,
        "to": [to],
        "subject": subject,
        "text": text_body,
        "html": html_body,
    }
    try:
        with httpx.Client(timeout=20.0) as client:
            r = client.post(
                "https://api.resend.com/emails",
                headers={
                    "Authorization": f"Bearer {settings.resend_api_key}",
                    "Content-Type": "application/json",
                },
                json=payload,
            )
            r.raise_for_status()
        return True
    except Exception as exc:
        logger.exception("Resend email failed: %s", exc)
        return False
