from __future__ import annotations

import hashlib
import hmac
import uuid

import httpx

from app.services.payments.provider import PaymentInitResult, PaymentProvider
from app.settings import settings


class OrangeMoneyProvider(PaymentProvider):
    name = "orange"

    async def initiate_collection(
        self,
        *,
        amount_cdf: int,
        payer_phone: str,
        external_id: str,
        description: str,
    ) -> PaymentInitResult:
        if not settings.orange_money_api_url or settings.payment_sandbox_mode:
            ref = f"ORA-SBX-{uuid.uuid4().hex[:12].upper()}"
            return PaymentInitResult(
                provider_reference=ref,
                ussd_code="#144# puis valider (sandbox)",
                raw={"sandbox": True, "external_id": external_id},
            )

        payload = {
            "merchant_id": settings.orange_money_merchant_id,
            "amount": amount_cdf,
            "currency": "CDF",
            "order_id": external_id,
            "subscriber_msisdn": payer_phone.lstrip("+"),
            "description": description[:160],
        }
        headers = {"Authorization": f"Bearer {settings.orange_money_api_key}"}
        url = f"{settings.orange_money_api_url.rstrip('/')}/payment/init"
        async with httpx.AsyncClient(timeout=30.0) as client:
            r = await client.post(url, json=payload, headers=headers)
            r.raise_for_status()
            data = r.json()

        return PaymentInitResult(
            provider_reference=data.get("pay_token", external_id),
            checkout_url=data.get("payment_url"),
            raw=data,
        )

    def verify_webhook_signature(self, body: bytes, signature: str | None) -> bool:
        secret = settings.orange_money_callback_secret
        if not secret:
            return settings.payment_sandbox_mode
        if not signature:
            return False
        expected = hmac.new(secret.encode(), body, hashlib.sha256).hexdigest()
        return hmac.compare_digest(expected, signature)
