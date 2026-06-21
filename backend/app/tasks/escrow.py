"""Alertes séquestre (délai 48h) et litiges."""

import logging
from datetime import datetime, timezone

from sqlalchemy import select

from app.celery_app import celery_app
from app.db import SessionLocal
from app.models import Listing, Order, OrderStatus, User
from app.services.email import notify_admin_alert
from app.services.notifications import push_notification

logger = logging.getLogger(__name__)


@celery_app.task(name="app.tasks.escrow.check_escrow_deadlines")
def check_escrow_deadlines() -> dict:
    """Alerte admin + vendeur si délai de préparation dépassé sans action."""
    now = datetime.now(timezone.utc)
    db = SessionLocal()
    alerted = 0
    try:
        orders = db.scalars(
            select(Order).where(
                Order.status == OrderStatus.sequestre,
                Order.delivery_deadline_at.isnot(None),
                Order.delivery_deadline_at <= now,
                Order.deadline_alert_sent.is_(False),
            )
        ).all()
        for order in orders:
            listing = db.get(Listing, order.listing_id)
            if not listing:
                continue
            order.deadline_alert_sent = True
            alerted += 1
            notify_admin_alert(
                subject=f"Délai dépassé — commande #{order.id}",
                body=(
                    f"Commande #{order.id} en séquestre depuis le {order.escrow_started_at}.\n"
                    f"Annonce : {listing.title}\n"
                    f"Acheteur #{order.buyer_id} / Vendeur #{listing.seller_id}\n"
                    f"Ouvrez le panneau Litiges pour trancher."
                ),
            )
            push_notification(
                db,
                user_id=listing.seller_id,
                type="escrow_deadline",
                title="Délai de préparation dépassé",
                body=f"Commande #{order.id} : contactez l'acheteur ou attendez la modération.",
                listing_id=listing.id,
                order_id=order.id,
                commit=False,
            )
            push_notification(
                db,
                user_id=order.buyer_id,
                type="escrow_deadline",
                title="Commande en attente",
                body="Le délai est dépassé. Validez l'article ou ouvrez un litige.",
                listing_id=listing.id,
                order_id=order.id,
                commit=False,
            )
        db.commit()
    except Exception as exc:
        db.rollback()
        logger.exception("Escrow deadline check failed: %s", exc)
        raise
    finally:
        db.close()
    return {"alerted": alerted}
