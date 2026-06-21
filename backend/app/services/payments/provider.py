from __future__ import annotations

from abc import ABC, abstractmethod
from dataclasses import dataclass


@dataclass
class PaymentInitResult:
    provider_reference: str
    checkout_url: str | None = None
    ussd_code: str | None = None
    raw: dict | None = None


class PaymentProvider(ABC):
    name: str

    @abstractmethod
    async def initiate_collection(
        self,
        *,
        amount_cdf: int,
        payer_phone: str,
        external_id: str,
        description: str,
    ) -> PaymentInitResult:
        ...

    @abstractmethod
    def verify_webhook_signature(self, body: bytes, signature: str | None) -> bool:
        ...
