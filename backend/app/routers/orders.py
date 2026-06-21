import secrets
from datetime import datetime, timezone

from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy import select
from sqlalchemy.orm import Session, selectinload

from app.db import get_db
from app.deps import get_current_user
from app.models import (
    DisputeStatus,
    Listing,
    Order,
    OrderDispute,
    OrderStatus,
    PaymentProvider,
    User,
    UserRole,
)
from app.schemas import (
    AdminOrderResolveRequest,
    OrderCreateRequest,
    OrderDisputeCreateRequest,
    OrderPublic,
    PayOrderRequest,
    PaymentInitResponse,
)
from app.services.escrow import (
    CHAT_VISIBLE_STATUSES,
    CHAT_WRITABLE_STATUSES,
    ESCROW_ACTIVE_STATUSES,
    refund_buyer,
    release_to_seller,
    status_label_fr,
)
from app.services.listing_catalog import (
    catalog_variants,
    find_variant,
    is_official_catalog,
)
from app.services.notifications import push_notification
from app.services.payments import payment_service
from app.settings import settings

router = APIRouter(prefix="/orders", tags=["orders"])


def _order_public(order: Order) -> OrderPublic:
    st = order.status if isinstance(order.status, OrderStatus) else OrderStatus(order.status.value)
    return OrderPublic(
        id=order.id,
        listing_id=order.listing_id,
        buyer_id=order.buyer_id,
        amount_cdf=order.amount_cdf,
        status=st.value,
        status_label=status_label_fr(st),
        payment_reference=order.payment_reference,
        handover_code=order.handover_code,
        delivery_deadline_at=order.delivery_deadline_at,
        escrow_started_at=order.escrow_started_at,
        completed_at=order.completed_at,
        refunded_at=order.refunded_at,
        chat_locked=st not in CHAT_WRITABLE_STATUSES,
        created_at=order.created_at,
        paid_at=order.paid_at,
    )


@router.get("/mine")
def list_my_orders(
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
) -> dict:
    rows = db.scalars(
        select(Order)
        .where(Order.buyer_id == current_user.id)
        .order_by(Order.created_at.desc())
        .limit(50)
    ).all()
    return {
        "items": [
            {
                "id": o.id,
                "listing_id": o.listing_id,
                "amount_cdf": o.amount_cdf,
                "status": o.status.value if hasattr(o.status, "value") else str(o.status),
                "status_label": status_label_fr(
                    o.status if isinstance(o.status, OrderStatus) else OrderStatus(o.status)
                ),
                "handover_code": o.handover_code,
                "delivery_deadline_at": o.delivery_deadline_at.isoformat() if o.delivery_deadline_at else None,
                "created_at": o.created_at.isoformat() if o.created_at else None,
                "paid_at": o.paid_at.isoformat() if o.paid_at else None,
            }
            for o in rows
        ]
    }


@router.post("/", response_model=OrderPublic)
def create_order(
    payload: OrderCreateRequest,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
) -> OrderPublic:
    listing = db.get(Listing, payload.listing_id)
    if not listing:
        raise HTTPException(status_code=404, detail="Listing not found")

    seller = db.get(User, listing.seller_id)
    if not seller or seller.role != UserRole.official_seller:
        raise HTTPException(status_code=400, detail="Paiement in-app réservé aux vendeurs officiels")

    if not listing.delivery_method:
        raise HTTPException(status_code=400, detail="Annonce sans mode de livraison configuré")

    if listing.seller_id == current_user.id:
        raise HTTPException(status_code=400, detail="Cannot buy your own listing")

    quantity = payload.quantity
    payment_channel = payload.payment_channel or "mobile_money"
    variant_size = (payload.variant_size or "").strip() or None
    variant_color = (payload.variant_color or "").strip() or None
    unit_price = listing.price_cdf or 0

    if payment_channel == "in_store":
        dm_val = str(listing.delivery_method or "")
        if dm_val != "pickup_store":
            raise HTTPException(
                status_code=400,
                detail="Paiement sur place disponible uniquement pour retrait en boutique",
            )

    if is_official_catalog(listing, seller):
        variants = catalog_variants(listing)
        if len(variants) > 1 and not variant_size:
            raise HTTPException(status_code=400, detail="Choisissez une taille pour ce produit")
        variant = find_variant(listing, size=variant_size, color=variant_color)
        if not variant:
            raise HTTPException(status_code=400, detail="Variante introuvable")
        stock = int(variant.get("stock") or 0)
        if stock < quantity:
            raise HTTPException(status_code=400, detail="Stock insuffisant pour cette variante")
        unit_price = int(variant.get("price_cdf") or unit_price)
        variant_size = variant.get("size")
        variant_color = variant.get("color")
    else:
        quantity = 1
        variant_size = None
        variant_color = None
        if listing.buyer_id is not None:
            raise HTTPException(status_code=400, detail="Annonce déjà vendue")

    order = Order(
        listing_id=listing.id,
        buyer_id=current_user.id,
        amount_cdf=unit_price * quantity,
        quantity=quantity,
        variant_size=variant_size,
        variant_color=variant_color,
        payment_channel=payment_channel,
        status=OrderStatus.en_attente,
        created_at=datetime.now(timezone.utc),
    )
    db.add(order)
    if payment_channel == "in_store":
        from app.services.listing_catalog import consume_catalog_stock

        consume_catalog_stock(
            listing,
            seller,
            quantity=quantity,
            size=variant_size,
            color=variant_color,
        )
    db.commit()
    db.refresh(order)
    return _order_public(order)


@router.post("/{order_id}/pay", response_model=PaymentInitResponse)
async def pay_order(
    order_id: int,
    payload: PayOrderRequest,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
) -> PaymentInitResponse:
    order = db.scalar(
        select(Order).options(selectinload(Order.listing)).where(Order.id == order_id)
    )
    if not order or order.buyer_id != current_user.id:
        raise HTTPException(status_code=404, detail="Order not found")

    if (order.payment_channel or "mobile_money") == "in_store":
        raise HTTPException(
            status_code=400,
            detail="Cette commande est en paiement sur place — pas de Mobile Money",
        )

    if order.status in (OrderStatus.sequestre, OrderStatus.succes):
        return PaymentInitResponse(
            transaction_id=0,
            external_id=order.payment_reference or "",
            provider_reference=order.payment_reference or "",
            status=order.status.value,
        )

    try:
        provider = PaymentProvider(payload.provider)
    except ValueError:
        raise HTTPException(status_code=400, detail="Invalid provider")

    tx, result = await payment_service.initiate_order_payment(
        db, order=order, buyer=current_user, provider=provider
    )

    if settings.payment_sandbox_mode:
        payment_service.complete_payment(
            db,
            external_id=tx.external_id,
            provider_reference=result.provider_reference,
            success=True,
        )

    order = db.get(Order, order_id)
    return PaymentInitResponse(
        transaction_id=tx.id,
        external_id=tx.external_id,
        provider_reference=tx.provider_reference or result.provider_reference,
        checkout_url=result.checkout_url,
        ussd_code=result.ussd_code,
        status=order.status.value if order else "en_attente",
    )


@router.get("/{order_id}", response_model=OrderPublic)
def get_order(
    order_id: int,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
) -> OrderPublic:
    order = db.get(Order, order_id)
    if not order:
        raise HTTPException(status_code=404, detail="Order not found")
    listing = db.get(Listing, order.listing_id)
    if order.buyer_id != current_user.id and (not listing or listing.seller_id != current_user.id):
        raise HTTPException(status_code=404, detail="Order not found")
    return _order_public(order)


@router.post("/{order_id}/cancel")
def cancel_order(
    order_id: int,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
) -> OrderPublic:
    order = db.scalar(
        select(Order).options(selectinload(Order.listing)).where(Order.id == order_id)
    )
    if not order or order.buyer_id != current_user.id:
        raise HTTPException(status_code=404, detail="Order not found")
    if order.status == OrderStatus.cancelled:
        return _order_public(order)
    if order.status in ESCROW_ACTIVE_STATUSES | {OrderStatus.succes, OrderStatus.rembourse}:
        raise HTTPException(status_code=400, detail="Impossible d'annuler une commande payée")

    order.status = OrderStatus.cancelled
    db.commit()
    db.refresh(order)

    listing_title = order.listing.title if order.listing else "votre commande"
    push_notification(
        db,
        user_id=current_user.id,
        type="payment_cancelled",
        title="Paiement annulé",
        body=f"La commande pour « {listing_title} » a été annulée. Aucun débit effectué.",
        order_id=order.id,
        listing_id=order.listing_id,
    )
    return _order_public(order)


@router.post("/{order_id}/confirm-receipt", response_model=OrderPublic)
def confirm_receipt(
    order_id: int,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
) -> OrderPublic:
    """Acheteur valide l'essayage → SUCCÈS + reversement vendeur."""
    order = db.scalar(
        select(Order).options(selectinload(Order.listing)).where(Order.id == order_id)
    )
    if not order or order.buyer_id != current_user.id:
        raise HTTPException(status_code=404, detail="Order not found")
    if order.status != OrderStatus.sequestre:
        raise HTTPException(status_code=400, detail="Commande non éligible à la validation")
    listing = order.listing
    if not listing:
        raise HTTPException(status_code=404, detail="Listing not found")

    release_to_seller(db, order=order, listing=listing)
    db.commit()
    db.refresh(order)
    return _order_public(order)


@router.post("/{order_id}/dispute", response_model=dict)
def open_dispute(
    order_id: int,
    payload: OrderDisputeCreateRequest,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
) -> dict:
    order = db.scalar(
        select(Order).options(selectinload(Order.listing)).where(Order.id == order_id)
    )
    if not order:
        raise HTTPException(status_code=404, detail="Order not found")
    listing = order.listing
    if current_user.id not in {order.buyer_id, listing.seller_id if listing else None}:
        raise HTTPException(status_code=403, detail="Forbidden")
    if order.status != OrderStatus.sequestre:
        raise HTTPException(status_code=400, detail="Litige possible uniquement en séquestre")

    existing = db.scalar(select(OrderDispute).where(OrderDispute.order_id == order.id))
    if existing:
        raise HTTPException(status_code=409, detail="Litige déjà ouvert")

    dispute = OrderDispute(
        order_id=order.id,
        opened_by_id=current_user.id,
        reason=payload.reason.strip(),
        details=payload.details,
        status=DisputeStatus.open,
    )
    db.add(dispute)
    db.commit()

    from app.services.email import notify_admin_alert

    notify_admin_alert(
        subject=f"Litige commande #{order.id}",
        body=f"Raison : {payload.reason}\nCommande #{order.id} — annonce #{order.listing_id}",
    )
    return {"ok": True, "dispute_id": dispute.id}


@router.get("/{order_id}/handover")
def get_handover_code(
    order_id: int,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
) -> dict:
    order = db.get(Order, order_id)
    if not order or order.status not in CHAT_VISIBLE_STATUSES:
        raise HTTPException(status_code=404, detail="Order not found")
    listing = db.get(Listing, order.listing_id)
    if not listing:
        raise HTTPException(status_code=404, detail="Listing not found")
    if current_user.id not in {order.buyer_id, listing.seller_id}:
        raise HTTPException(status_code=403, detail="Forbidden")
    if not order.handover_code:
        order.handover_code = secrets.token_hex(4).upper()
        db.commit()
    return {
        "handover_code": order.handover_code,
        "order_id": order.id,
        "status": order.status.value,
        "delivery_deadline_at": order.delivery_deadline_at.isoformat() if order.delivery_deadline_at else None,
    }
