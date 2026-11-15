"""Webhook mails entrants — POST /api/mail/inbound (worker Cloudflare Email).

Le worker `sombateka-mail-inbound` envoie le MIME brut avec :
  x-mail-secret : secret partagé (comparaison constant-time)
  x-mail-from   : expéditeur enveloppe
  x-mail-to     : destinataire enveloppe
"""

from __future__ import annotations

import hmac
import logging
from email import policy
from email.parser import BytesParser
from email.utils import parseaddr

from fastapi import APIRouter, Depends, HTTPException, Request
from sqlalchemy.orm import Session

from app.db import get_db
from app.services.mail_threads import record_inbound
from app.settings import settings

logger = logging.getLogger(__name__)
router = APIRouter()

_MAX_MIME_BYTES = 15 * 1024 * 1024


def _norm_addr(value: str | None) -> str:
    return (parseaddr(value or "")[1] or "").strip().lower()


def _extract_bodies(msg) -> tuple[str | None, str | None]:
    text_part: str | None = None
    html_part: str | None = None
    parts = msg.walk() if msg.is_multipart() else [msg]
    for part in parts:
        if part.get_content_disposition() == "attachment":
            continue
        ctype = part.get_content_type()
        if ctype not in ("text/plain", "text/html"):
            continue
        try:
            content = part.get_content()
        except Exception:
            try:
                content = part.get_payload(decode=True).decode("utf-8", errors="replace")
            except Exception:
                continue
        if ctype == "text/plain" and text_part is None:
            text_part = content
        elif ctype == "text/html" and html_part is None:
            html_part = content
    return text_part, html_part


@router.post("/mail/inbound")
async def receive_inbound(request: Request, db: Session = Depends(get_db)) -> dict:
    secret = settings.mail_inbound_secret
    if not secret:
        raise HTTPException(status_code=503, detail="Inbound mail non configuré")
    given = request.headers.get("x-mail-secret", "")
    if not hmac.compare_digest(given, secret):
        raise HTTPException(status_code=401, detail="Non autorisé")

    raw = await request.body()
    if not raw:
        raise HTTPException(status_code=400, detail="Corps vide")
    if len(raw) > _MAX_MIME_BYTES:
        raise HTTPException(status_code=413, detail="Mail trop volumineux")

    try:
        msg = BytesParser(policy=policy.default).parsebytes(raw)
    except Exception:
        raise HTTPException(status_code=400, detail="MIME illisible")

    env_from = _norm_addr(request.headers.get("x-mail-from"))
    env_to = _norm_addr(request.headers.get("x-mail-to"))

    from_header = msg.get("From", "")
    from_name, from_addr = parseaddr(str(from_header))
    from_addr = env_from or _norm_addr(from_addr)
    if not from_addr:
        raise HTTPException(status_code=400, detail="Expéditeur manquant")

    to_addr = env_to or _norm_addr(str(msg.get("To", ""))) or "support@sombatekaonline.com"
    subject = str(msg.get("Subject", "") or "")[:300]
    rfc_id = (str(msg.get("Message-ID", "") or "").strip() or None)
    in_reply_to = (str(msg.get("In-Reply-To", "") or "").strip() or None)
    references = str(msg.get("References", "") or "").split()

    text_part, html_part = _extract_bodies(msg)

    thread = record_inbound(
        db,
        remote_addr=from_addr,
        remote_name=(from_name or "").strip()[:200] or None,
        local_addr=to_addr,
        subject=subject,
        text=text_part,
        html=html_part,
        rfc_message_id=rfc_id,
        in_reply_to=in_reply_to,
        refs=references,
    )
    db.commit()
    logger.info("mail inbound: thread=%s from=%s to=%s", thread.id, from_addr, to_addr)
    return {"success": True, "threadId": thread.id}
