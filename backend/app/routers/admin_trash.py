"""Corbeille admin — accès super administrateur uniquement."""

from __future__ import annotations

import json

from fastapi import APIRouter, Depends, HTTPException, Query, Request
from sqlalchemy.orm import Session

from app.db import get_db
from app.deps_admin import client_ip, require_super_admin
from app.models import TrashItem, User
from app.services.admin_audit import log_admin_action
from app.services.trash_service import (
    TRASH_CONVERSATION,
    TRASH_LISTING,
    TRASH_PUBLICATION,
    list_trash,
    purge_trash_item,
    restore_trash_item,
)

router = APIRouter(prefix="/admin/trash", tags=["admin-trash"])


def _serialize(item: TrashItem) -> dict:
    detail = None
    if item.detail_json:
        try:
            detail = json.loads(item.detail_json)
        except json.JSONDecodeError:
            detail = {"raw": item.detail_json}
    return {
        "id": item.id,
        "entity_type": item.entity_type,
        "entity_key": item.entity_key,
        "title": item.title,
        "detail": detail,
        "deleted_by_user_id": item.deleted_by_user_id,
        "deleted_at": item.deleted_at,
    }


@router.get("")
def list_trash_items(
    entity_type: str | None = Query(default=None),
    limit: int = Query(default=100, ge=1, le=200),
    offset: int = Query(default=0, ge=0),
    _staff: User = Depends(require_super_admin),
    db: Session = Depends(get_db),
) -> dict:
    allowed = {TRASH_LISTING, TRASH_PUBLICATION, TRASH_CONVERSATION}
    if entity_type and entity_type not in allowed:
        raise HTTPException(status_code=400, detail="Type invalide")
    items = list_trash(db, entity_type=entity_type, limit=limit, offset=offset)
    return {"items": [_serialize(i) for i in items]}


@router.post("/{trash_id}/restore")
def restore_item(
    trash_id: int,
    request: Request,
    staff: User = Depends(require_super_admin),
    db: Session = Depends(get_db),
) -> dict:
    item = db.get(TrashItem, trash_id)
    if not item:
        raise HTTPException(status_code=404, detail="Introuvable")
    try:
        restore_trash_item(db, item)
    except ValueError as e:
        raise HTTPException(status_code=400, detail=str(e)) from e
    log_admin_action(
        db,
        actor=staff,
        action="trash.restore",
        resource_type=item.entity_type,
        resource_id=item.id,
        detail={"entity_key": item.entity_key},
        ip_address=client_ip(request),
    )
    db.commit()
    return {"ok": True}


@router.post("/{trash_id}/purge")
def purge_item(
    trash_id: int,
    request: Request,
    staff: User = Depends(require_super_admin),
    db: Session = Depends(get_db),
) -> dict:
    item = db.get(TrashItem, trash_id)
    if not item:
        raise HTTPException(status_code=404, detail="Introuvable")
    try:
        purge_trash_item(db, item)
    except ValueError as e:
        raise HTTPException(status_code=400, detail=str(e)) from e
    log_admin_action(
        db,
        actor=staff,
        action="trash.purge",
        resource_type=item.entity_type,
        resource_id=item.id,
        detail={"entity_key": item.entity_key},
        ip_address=client_ip(request),
    )
    db.commit()
    return {"ok": True}


@router.post("/reset-beta-data")
def reset_beta_data(
    request: Request,
    staff: User = Depends(require_super_admin),
    db: Session = Depends(get_db),
) -> dict:
    from app.services.data_reset import reset_all_except_super_admins

    summary = reset_all_except_super_admins(db)
    log_admin_action(
        db,
        actor=staff,
        action="data.reset_beta",
        resource_type="system",
        resource_id=None,
        detail=summary,
        ip_address=client_ip(request),
    )
    db.commit()
    return {"ok": True, "summary": summary}
