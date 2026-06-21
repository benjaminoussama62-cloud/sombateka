from __future__ import annotations

import hashlib
import hmac
import uuid

import httpx

from app.services.payments.provider import PaymentInitResult, PaymentProvider
from app.settings import settings


class MtnMoneyProvider(PaymentProvider):
    name = "mtn"

    async def initiate_collection(
        self,
        *,
        amount_cdf: int,
        payer_phone: str,
        external_id: str,
        description: str,
    ) -> PaymentInitResult:
        if not settings.mtn_money_api_url or settings.payment_sandbox_mode:
            ref = f"MTN-SBX-{uuid.uuid4().hex[:12].upper()}"
            return PaymentInitResult(
                provider_reference=ref,
                ussd_code="*126# puis valider le paiement (sandbox)",
                raw={"sandbox": True, "external_id": external_id},
            )

        headers = {
            "Ocp-Apim-Subscription-Key": settings.mtn_money_subscription_key,
            "X-Reference-Id": external_id,
            "X-Target-Environment": "mtncongo",
            "Content-Type": "application/json",
        }
        if settings.mtn_money_api_key:
            headers["Authorization"] = f"Bearer {settings.mtn_money_api_key}"

        payload = {
            "amount": str(amount_cdf),
            "currency": "CDF",
            "externalId": external_id,
            "payer": {"partyIdType": "MSISDN", "partyId": payer_phone.lstrip("+")},
            "payerMessage": description[:160],
            "payeeNote": "SombaTeka",
        }
        url = f"{settings.mtn_money_api_url.rstrip('/')}/collection/v1_0/requesttopay"
        async with httpx.AsyncClient(timeout=30.0) as client:
            r = await client.post(url, json=payload, headers=headers)
            r.raise_for_status()

        return PaymentInitResult(provider_reference=external_id, raw={"status": "pending"})

    def verify_webhook_signature(self, body: bytes, signature: str | None) -> bool:
        secret = settings.mtn_money_callback_secret
        if not secret:
            return settings.payment_sandbox_mode
        if not signature:
            return False
        expected = hmac.new(secret.encode(), body, hashlib.sha256).hexdigest()
        return hmac.compare_digest(expected, signature)
