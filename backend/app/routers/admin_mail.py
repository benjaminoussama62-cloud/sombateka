"""Helpdesk email — endpoints staff /admin/mail/*.

L'équipe lit les mails entrants (threads) et répond depuis le panneau :
la réponse part de la boîte sollicitée (support@/privacy@...) avec le nom
de l'agent dans le From et les headers de threading RFC.

Fonctionnalités niveau service desk : filtres par statut, recherche,
indicateurs non lus, notes internes privées, assignation à un agent,
contexte client (compte SombaTeka lié à l'adresse expéditrice).
"""

from __future__ import annotations

import time
from datetime import datetime, timezone

from fastapi import APIRouter, Depends, HTTPException, Request
from pydantic import BaseModel, Field
from sqlalchemy import func, or_, select
from sqlalchemy.orm import Session

from app.admin_rbac import PERM_SUPPORT_REPLY, PERM_SUPPORT_VIEW, STAFF_ROLES
from app.db import get_db
from app.deps_admin import client_ip, require_permission
from app.models import MailThread, MailThreadMessage, User
from app.services.admin_audit import log_admin_action
from app.services.email import send_email_async
from app.services.mail_threads import (
    MAIL_STATUSES,
    agent_display_name,
    count_open_threads,
    customer_context,
    last_inbound_rfc,
    mark_thread_read,
    outbound_from_name,
    outbound_subject,
    record_note,
    record_outbound,
    sender_tag_for,
)

router = APIRouter()


class MailReplyBody(BaseModel):
    content: str = Field(..., min_length=1, max_length=10000)


class MailNoteBody(BaseModel):
    content: str = Field(..., min_length=1, max_length=5000)


class MailStatusBody(BaseModel):
    status: str = Field(..., pattern="^(open|in_progress|resolved|closed)$")


class MailAssignBody(BaseModel):
    admin_id: int | None = None  # null = désassigner


def _aware(dt: datetime | None) -> datetime | None:
    if dt is not None and dt.tzinfo is None:
        return dt.replace(tzinfo=timezone.utc)
    return dt


def _thread_summary(
    t: MailThread,
    counts: dict[int, int],
    previews: dict[int, tuple[str, str]],
    last_in: dict[int, datetime],
    assignees: dict[int, str],
) -> dict:
    li = _aware(last_in.get(t.id))
    ra = _aware(t.read_at)
    preview, last_dir = previews.get(t.id, ("", ""))
    return {
        "id": t.id,
        "remote_addr": t.remote_addr,
        "remote_name": t.remote_name,
        "local_addr": t.local_addr,
        "subject": t.subject,
        "status": t.status,
        "unread": bool(li and (ra is None or li > ra)),
        "message_count": counts.get(t.id, 0),
        "last_direction": last_dir,
        "last_preview": preview,
        "assigned_admin": assignees.get(t.assigned_admin_id or 0),
        "created_at": t.created_at.isoformat() if t.created_at else None,
        "updated_at": t.updated_at.isoformat() if t.updated_at else None,
    }


@router.get("/admin/mail/threads")
def list_mail_threads(
    status: str | None = None,
    q: str | None = None,
    db: Session = Depends(get_db),
    staff: User = Depends(require_permission(PERM_SUPPORT_VIEW)),
) -> dict:
    stmt = select(MailThread)
    if status in MAIL_STATUSES:
        stmt = stmt.where(MailThread.status == status)
    if q:
        like = f"%{q.strip()[:80]}%"
        stmt = stmt.where(
            or_(
                MailThread.remote_addr.ilike(like),
                MailThread.remote_name.ilike(like),
                MailThread.subject.ilike(like),
            )
        )
    threads = db.scalars(
        stmt.order_by(MailThread.updated_at.desc()).limit(200)
    ).all()
    ids = [t.id for t in threads]

    counts: dict[int, int] = {}
    previews: dict[int, tuple[str, str]] = {}
    last_in: dict[int, datetime] = {}
    if ids:
        for tid, cnt in db.execute(
            select(MailThreadMessage.thread_id, func.count())
            .where(MailThreadMessage.thread_id.in_(ids))
            .group_by(MailThreadMessage.thread_id)
        ):
            counts[tid] = int(cnt)
        for tid, ts in db.execute(
            select(
                MailThreadMessage.thread_id,
                func.max(MailThreadMessage.created_at),
            )
            .where(
                MailThreadMessage.thread_id.in_(ids),
                MailThreadMessage.direction == "in",
            )
            .group_by(MailThreadMessage.thread_id)
        ):
            last_in[tid] = ts
        for t in threads:
            row = db.execute(
                select(
                    func.substr(MailThreadMessage.text, 1, 160),
                    MailThreadMessage.direction,
                )
                .where(MailThreadMessage.thread_id == t.id)
                .order_by(MailThreadMessage.created_at.desc())
                .limit(1)
            ).first()
            previews[t.id] = (row[0] or "", row[1] or "") if row else ("", "")

    assignee_ids = {t.assigned_admin_id for t in threads if t.assigned_admin_id}
    assignees = {
        u.id: agent_display_name(u)
        for u in db.scalars(select(User).where(User.id.in_(assignee_ids))).all()
    } if assignee_ids else {}

    unread_count = sum(
        1
        for t in threads
        if (li := _aware(last_in.get(t.id)))
        and ((ra := _aware(t.read_at)) is None or li > ra)
    )
    return {
        "items": [
            _thread_summary(t, counts, previews, last_in, assignees)
            for t in threads
        ],
        "open_count": count_open_threads(db),
        "unread_count": unread_count,
    }


@router.get("/admin/mail/agents")
def list_mail_agents(
    db: Session = Depends(get_db),
    staff: User = Depends(require_permission(PERM_SUPPORT_VIEW)),
) -> dict:
    """Agents assignables — léger, accessible à tout le staff support."""
    rows = db.scalars(
        select(User).where(User.role.in_(STAFF_ROLES)).order_by(User.display_name)
    ).all()
    return {
        "items": [
            {"id": u.id, "name": agent_display_name(u), "role": u.role.value}
            for u in rows
        ]
    }


@router.get("/admin/mail/threads/{thread_id}")
def get_mail_thread(
    thread_id: int,
    db: Session = Depends(get_db),
    staff: User = Depends(require_permission(PERM_SUPPORT_VIEW)),
) -> dict:
    thread = db.get(MailThread, thread_id)
    if not thread:
        raise HTTPException(status_code=404, detail="Fil introuvable")

    sender_ids = {m.sender_id for m in thread.messages if m.sender_id}
    names = {
        u.id: agent_display_name(u)
        for u in db.scalars(select(User).where(User.id.in_(sender_ids))).all()
    } if sender_ids else {}

    assignee = (
        agent_display_name(db.get(User, thread.assigned_admin_id))
        if thread.assigned_admin_id
        else None
    )
    mark_thread_read(db, thread)
    db.commit()

    return {
        "thread": {
            "id": thread.id,
            "remote_addr": thread.remote_addr,
            "remote_name": thread.remote_name,
            "local_addr": thread.local_addr,
            "subject": thread.subject,
            "status": thread.status,
            "assigned_admin": assignee,
            "created_at": thread.created_at.isoformat() if thread.created_at else None,
        },
        "customer": customer_context(db, thread.remote_addr),
        "items": [
            {
                "id": m.id,
                "direction": m.direction,
                "from_addr": m.from_addr,
                "from_name": m.from_name or names.get(m.sender_id or 0),
                "agent": names.get(m.sender_id) if m.sender_id else None,
                "subject": m.subject,
                "text": m.text,
                "html": m.html,
                "created_at": m.created_at.isoformat() if m.created_at else None,
            }
            for m in thread.messages
        ],
    }


@router.post("/admin/mail/threads/{thread_id}/reply")
def reply_mail_thread(
    thread_id: int,
    body: MailReplyBody,
    request: Request,
    db: Session = Depends(get_db),
    staff: User = Depends(require_permission(PERM_SUPPORT_REPLY)),
) -> dict:
    thread = db.get(MailThread, thread_id)
    if not thread:
        raise HTTPException(status_code=404, detail="Fil introuvable")

    agent = agent_display_name(staff)
    in_reply_to = last_inbound_rfc(db, thread.id)
    out_rfc = f"<sombateka-thread-{thread.id}-{int(time.time() * 1000)}@sombatekaonline.com>"
    subject = outbound_subject(thread.subject, thread.id)

    content = body.content.strip()
    signed = (
        f"{content}\n\n— {agent} — SombaTeka Support\n"
        f"{thread.local_addr} · https://sombatekaonline.com"
    )

    msg = record_outbound(
        db,
        thread=thread,
        staff=staff,
        content=signed,
        rfc_message_id=out_rfc,
        in_reply_to=in_reply_to,
    )
    if thread.status == "open":
        thread.status = "in_progress"
    if not thread.assigned_admin_id:
        thread.assigned_admin_id = staff.id

    send_email_async(
        thread.remote_addr,
        subject,
        signed,
        email_type="mail",
        template_data={
            "sender": sender_tag_for(thread.local_addr),
            "fromName": outbound_from_name(staff)[:80],
            "inReplyTo": in_reply_to or "",
        },
        idempotency_key=f"mail-reply:{thread.id}:{msg.id}",
        reply_to=thread.local_addr,
    )

    log_admin_action(
        db,
        actor=staff,
        action="mail.reply",
        resource_type="mail_thread",
        resource_id=thread.id,
        detail={"to": thread.remote_addr, "preview": content[:120]},
        ip_address=client_ip(request),
    )
    db.commit()
    return {"ok": True, "message_id": msg.id}


@router.post("/admin/mail/threads/{thread_id}/note")
def add_mail_thread_note(
    thread_id: int,
    body: MailNoteBody,
    request: Request,
    db: Session = Depends(get_db),
    staff: User = Depends(require_permission(PERM_SUPPORT_REPLY)),
) -> dict:
    """Note interne — jamais envoyée au client, visible équipe seulement."""
    thread = db.get(MailThread, thread_id)
    if not thread:
        raise HTTPException(status_code=404, detail="Fil introuvable")
    msg = record_note(
        db, thread=thread, staff=staff, content=body.content.strip()
    )
    log_admin_action(
        db,
        actor=staff,
        action="mail.note",
        resource_type="mail_thread",
        resource_id=thread.id,
        detail={"preview": body.content.strip()[:120]},
        ip_address=client_ip(request),
    )
    db.commit()
    return {"ok": True, "message_id": msg.id}


@router.post("/admin/mail/threads/{thread_id}/assign")
def assign_mail_thread(
    thread_id: int,
    body: MailAssignBody,
    db: Session = Depends(get_db),
    staff: User = Depends(require_permission(PERM_SUPPORT_REPLY)),
) -> dict:
    thread = db.get(MailThread, thread_id)
    if not thread:
        raise HTTPException(status_code=404, detail="Fil introuvable")
    if body.admin_id is not None:
        target = db.get(User, body.admin_id)
        if not target or target.role not in STAFF_ROLES:
            raise HTTPException(status_code=404, detail="Agent introuvable")
    thread.assigned_admin_id = body.admin_id
    db.commit()
    return {"ok": True}


@router.post("/admin/mail/threads/{thread_id}/status")
def update_mail_thread_status(
    thread_id: int,
    body: MailStatusBody,
    db: Session = Depends(get_db),
    staff: User = Depends(require_permission(PERM_SUPPORT_REPLY)),
) -> dict:
    thread = db.get(MailThread, thread_id)
    if not thread:
        raise HTTPException(status_code=404, detail="Fil introuvable")
    thread.status = body.status
    db.commit()
    return {"ok": True}
