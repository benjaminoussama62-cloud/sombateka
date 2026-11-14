import logging
from datetime import datetime, timezone

from sqlalchemy import select

from app.celery_app import celery_app
from app.db import SessionLocal
from app.models import (
    LedgerEntry,
    LedgerEntryType,
    Listing,
    Order,
    OrderStatus,
    PayoutStatus,
    SellerPayout,
    User,
)

logger = logging.getLogger(__name__)


@celery_app.task(name="app.tasks.payments.process_scheduled_payouts")
def process_scheduled_payouts() -> dict:
    """Release seller payouts T+1 (batch, idempotent)."""
    now = datetime.now(timezone.utc)
    db = SessionLocal()
    processed = 0
    try:
        rows = db.scalars(
            select(SellerPayout).where(
                SellerPayout.status == PayoutStatus.scheduled,
                SellerPayout.scheduled_at <= now,
            )
        ).all()
        for payout in rows:
            order = db.get(Order, payout.order_id)
            if not order or order.status != OrderStatus.succes:
                continue
            payout.status = PayoutStatus.completed
            payout.completed_at = now
            db.add(
                LedgerEntry(
                    user_id=payout.seller_id,
                    order_id=payout.order_id,
                    entry_type=LedgerEntryType.payout_debit,
                    amount_cdf=payout.amount_cdf,
                    description=f"Reversement commande #{payout.order_id}",
                )
            )
            try:
                seller = db.get(User, payout.seller_id)
                listing = db.get(Listing, order.listing_id) if order else None
                if seller:
                    from app.services.notifications import push_notification
                    from app.services.transactional import send_payout_completed

                    ref = f"ST-{payout.order_id:06d}"
                    push_notification(
                        db,
                        user_id=seller.id,
                        type="payout_completed",
                        title="Reversement effectué",
                        body=f"{payout.amount_cdf} FC reversés pour la commande {ref}.",
                        order_id=payout.order_id,
                        commit=False,
                    )
                    send_payout_completed(
                        seller,
                        amount_cdf=payout.amount_cdf,
                        order_ref=ref,
                        title=listing.title if listing else f"commande {ref}",
                    )
            except Exception:
                logger.exception("payout notification/email failed (payout=%s)", payout.id)
            processed += 1
        db.commit()
    except Exception as e:
        db.rollback()
        logger.exception("Payout batch failed: %s", e)
        raise
    finally:
        db.close()
    return {"processed": processed}
