"""Chat interne staff — panneau admin."""

from __future__ import annotations

from fastapi import APIRouter, Depends, HTTPException, Query, Request
from pydantic import BaseModel, Field
from sqlalchemy.orm import Session

from app.admin_rbac import PERM_CHAT_SEND, PERM_CHAT_VIEW
from app.db import get_db
from app.deps_admin import client_ip, get_admin_staff, require_permission, require_super_admin
from app.models import User
from app.services.admin_audit import log_admin_action
from app.services.admin_chat import (
    create_group_room,
    get_or_create_dm_room,
    list_room_messages,
    list_rooms_for_user,
    list_staff_users,
    mark_room_read,
    send_room_message,
)

router = APIRouter(prefix="/admin/chat", tags=["admin-chat"])


class ChatMessageCreate(BaseModel):
    content: str = Field(min_length=1, max_length=4000)


class ChatGroupCreate(BaseModel):
    name: str = Field(min_length=1, max_length=120)
    member_ids: list[int] = Field(min_length=1)


class ChatDmCreate(BaseModel):
    user_id: int


@router.get("/rooms")
def chat_list_rooms(
    staff: User = Depends(require_permission(PERM_CHAT_VIEW)),
    db: Session = Depends(get_db),
) -> dict:
    items = list_rooms_for_user(db, staff)
    db.commit()
    return {"items": items}


@router.get("/staff")
def chat_list_staff(
    staff: User = Depends(require_permission(PERM_CHAT_VIEW)),
    db: Session = Depends(get_db),
) -> dict:
    users = list_staff_users(db, exclude_id=staff.id)
    from app.admin_rbac import ROLE_LABELS

    return {
        "items": [
            {
                "id": u.id,
                "display_name": u.display_name or u.phone_e164,
                "role": u.role.value,
                "role_label": ROLE_LABELS.get(u.role, u.role.value),
            }
            for u in users
        ]
    }


@router.get("/rooms/{room_id}/messages")
def chat_room_messages(
    room_id: int,
    before_id: int | None = Query(default=None),
    limit: int = Query(default=80, ge=1, le=200),
    staff: User = Depends(require_permission(PERM_CHAT_VIEW)),
    db: Session = Depends(get_db),
) -> dict:
    try:
        data = list_room_messages(db, staff, room_id, limit=limit, before_id=before_id)
    except ValueError as e:
        raise HTTPException(status_code=404, detail=str(e)) from e
    mark_room_read(db, staff, room_id)
    db.commit()
    return data


@router.post("/rooms/{room_id}/messages")
def chat_send_message(
    room_id: int,
    payload: ChatMessageCreate,
    staff: User = Depends(require_permission(PERM_CHAT_SEND)),
    db: Session = Depends(get_db),
) -> dict:
    try:
        msg = send_room_message(db, staff, room_id, payload.content)
    except ValueError as e:
        raise HTTPException(status_code=400, detail=str(e)) from e
    db.commit()
    return {
        "id": msg.id,
        "room_id": msg.room_id,
        "content": msg.content,
        "created_at": msg.created_at,
    }


@router.post("/rooms/{room_id}/read")
def chat_mark_read(
    room_id: int,
    staff: User = Depends(require_permission(PERM_CHAT_VIEW)),
    db: Session = Depends(get_db),
) -> dict:
    try:
        mark_room_read(db, staff, room_id)
    except ValueError as e:
        raise HTTPException(status_code=404, detail=str(e)) from e
    db.commit()
    return {"ok": True}


@router.post("/groups")
def chat_create_group(
    payload: ChatGroupCreate,
    request: Request,
    staff: User = Depends(require_super_admin),
    db: Session = Depends(get_db),
) -> dict:
    try:
        room = create_group_room(db, staff, name=payload.name, member_ids=payload.member_ids)
    except ValueError as e:
        raise HTTPException(status_code=400, detail=str(e)) from e
    log_admin_action(
        db,
        actor=staff,
        action="chat.group_create",
        resource_type="admin_chat_room",
        resource_id=room.id,
        detail={"name": room.name, "member_ids": payload.member_ids},
        ip_address=client_ip(request),
    )
    db.commit()
    return {"id": room.id, "name": room.name, "room_kind": room.room_kind}


@router.post("/dm")
def chat_open_dm(
    payload: ChatDmCreate,
    staff: User = Depends(require_permission(PERM_CHAT_VIEW)),
    db: Session = Depends(get_db),
) -> dict:
    try:
        room = get_or_create_dm_room(db, staff, payload.user_id)
    except ValueError as e:
        raise HTTPException(status_code=400, detail=str(e)) from e
    db.commit()
    return {"id": room.id, "room_kind": room.room_kind}
