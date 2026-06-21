from __future__ import annotations

import logging

import httpx

from app.settings import settings

logger = logging.getLogger(__name__)


def send_otp_sms(phone_e164: str, code: str) -> bool:
    message = f"SombaTeka — votre code: {code}. Valide 10 min. Ne le partagez pas."
    provider = (settings.sms_provider or "log").lower()

    if provider == "log" or settings.environment == "dev":
        logger.info("SMS [%s]: %s", phone_e164, message)
        return True

    if provider == "africas_talking":
        return _send_africas_talking(phone_e164, message)
    if provider == "twilio":
        return _send_twilio(phone_e164, message)

    logger.warning("Unknown SMS provider %s — logging only", provider)
    logger.info("SMS [%s]: %s", phone_e164, message)
    return True


def _africas_talking_messaging_url() -> str:
    if (settings.sms_username or "").strip().lower() == "sandbox":
        return "https://api.sandbox.africastalking.com/version1/messaging"
    return "https://api.africastalking.com/version1/messaging"


def _send_africas_talking(phone: str, message: str) -> bool:
    if not settings.sms_api_key or not settings.sms_username:
        logger.error("Africa's Talking credentials missing")
        return False
    url = _africas_talking_messaging_url()
    headers = {"apiKey": settings.sms_api_key, "Accept": "application/json"}
    data = {
        "username": settings.sms_username,
        "to": phone,
        "message": message,
        "from": settings.sms_sender_id,
    }
    try:
        with httpx.Client(timeout=15.0) as client:
            r = client.post(url, headers=headers, data=data)
            r.raise_for_status()
        return True
    except Exception as e:
        logger.exception("Africa's Talking SMS failed: %s", e)
        return False


def _send_twilio(phone: str, message: str) -> bool:
    if not settings.sms_api_key or not settings.sms_username:
        logger.error("Twilio credentials missing (api_key=sid, username=token)")
        return False
    account_sid = settings.sms_username
    auth_token = settings.sms_api_key
    from_number = settings.sms_sender_id
    url = f"https://api.twilio.com/2010-04-01/Accounts/{account_sid}/Messages.json"
    try:
        with httpx.Client(timeout=15.0) as client:
            r = client.post(
                url,
                auth=(account_sid, auth_token),
                data={"To": phone, "From": from_number, "Body": message},
            )
            r.raise_for_status()
        return True
    except Exception as e:
        logger.exception("Twilio SMS failed: %s", e)
        return False
