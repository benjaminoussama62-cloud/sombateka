import json
import logging

from fastapi import APIRouter, Depends, Header, HTTPException, Request
from sqlalchemy.orm import Session

from app.db import get_db
from app.models import PaymentProvider
from app.services.payments import payment_service

logger = logging.getLogger(__name__)
router = APIRouter(prefix="/webhooks", tags=["webhooks"])


@router.post("/mtn")
async def mtn_webhook(
    request: Request,
    db: Session = Depends(get_db),
    x_signature: str | None = Header(default=None, alias="X-Signature"),
):
    body = await request.body()
    provider = payment_service.get_provider(PaymentProvider.mtn)
    if not provider.verify_webhook_signature(body, x_signature):
        raise HTTPException(status_code=401, detail="Invalid signature")

    data = json.loads(body.decode() or "{}")
    external_id = data.get("externalId") or data.get("external_id")
    status = (data.get("status") or "").upper()
    success = status in {"SUCCESSFUL", "SUCCESS", "COMPLETED"}

    if not external_id:
        raise HTTPException(status_code=400, detail="Missing externalId")

    tx = payment_service.complete_payment(
        db,
        external_id=external_id,
        provider_reference=data.get("financialTransactionId"),
        success=success,
    )
    if not tx:
        raise HTTPException(status_code=404, detail="Transaction not found")
    return {"ok": True}


@router.post("/orange")
async def orange_webhook(
    request: Request,
    db: Session = Depends(get_db),
    x_signature: str | None = Header(default=None, alias="X-Orange-Signature"),
):
    body = await request.body()
    provider = payment_service.get_provider(PaymentProvider.orange)
    if not provider.verify_webhook_signature(body, x_signature):
        raise HTTPException(status_code=401, detail="Invalid signature")

    data = json.loads(body.decode() or "{}")
    external_id = data.get("order_id") or data.get("external_id")
    status = (data.get("status") or "").lower()
    success = status in {"success", "completed", "paid"}

    if not external_id:
        raise HTTPException(status_code=400, detail="Missing order_id")

    tx = payment_service.complete_payment(
        db,
        external_id=external_id,
        provider_reference=data.get("txnid"),
        success=success,
    )
    if not tx:
        raise HTTPException(status_code=404, detail="Transaction not found")
    return {"ok": True}
