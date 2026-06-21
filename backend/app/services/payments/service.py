from __future__ import annotations

import uuid
from datetime import datetime, timezone

from sqlalchemy import select
from sqlalchemy.orm import Session

from app.models import (
    Listing,
    Order,
    OrderStatus,
    PaymentProvider,
    PaymentStatus,
    PaymentTransaction,
    User,
)
from app.services.escrow import enter_sequestre
from app.services.payments.mtn import MtnMoneyProvider
from app.services.payments.orange import OrangeMoneyProvider
from app.services.payments.provider import PaymentInitResult
from app.settings import settings


class PaymentService:
    def __init__(self) -> None:
        self._providers = {
            PaymentProvider.mtn: MtnMoneyProvider(),
            PaymentProvider.orange: OrangeMoneyProvider(),
        }

    async def initiate_order_payment(
        self,
        db: Session,
        *,
        order: Order,
        buyer: User,
        provider: PaymentProvider,
    ) -> tuple[PaymentTransaction, PaymentInitResult]:
        external_id = f"ST-{order.id}-{uuid.uuid4().hex[:8]}"
        prov = self._providers[provider]

        listing = order.listing
        description = f"SombaTeka #{order.id} — {listing.title[:40]}"

        result = await prov.initiate_collection(
            amount_cdf=order.amount_cdf,
            payer_phone=buyer.phone_e164,
            external_id=external_id,
            description=description,
        )

        tx = PaymentTransaction(
            order_id=order.id,
            buyer_id=buyer.id,
            provider=provider,
            amount_cdf=order.amount_cdf,
            status=PaymentStatus.pending,
            external_id=external_id,
            provider_reference=result.provider_reference,
            raw_response=str(result.raw) if result.raw else None,
        )
        db.add(tx)
        db.commit()
        db.refresh(tx)
        return tx, result

    def complete_payment(
        self,
        db: Session,
        *,
        external_id: str,
        provider_reference: str | None = None,
        success: bool = True,
    ) -> PaymentTransaction | None:
        tx = db.scalar(
            select(PaymentTransaction).where(PaymentTransaction.external_id == external_id)
        )
        if not tx:
            return None
        if tx.status == PaymentStatus.completed:
            return tx

        order = db.get(Order, tx.order_id)
        if not order:
            return None

        listing = db.get(Listing, order.listing_id) if order else None
        if success and not listing:
            return None

        if success:
            tx.status = PaymentStatus.completed
            tx.completed_at = datetime.now(timezone.utc)
            if provider_reference:
                tx.provider_reference = provider_reference

            enter_sequestre(
                db,
                order=order,
                listing=listing,
                payment_reference=tx.provider_reference,
            )
        else:
            tx.status = PaymentStatus.failed
            order.status = OrderStatus.cancelled

        db.commit()
        db.refresh(tx)
        return tx

    def get_provider(self, name: PaymentProvider):
        return self._providers[name]
