"""Journal d'audit des actions administrateurs."""

from __future__ import annotations

import json
from typing import Any

from sqlalchemy.orm import Session

from app.models import AdminAuditLog, User


def log_admin_action(
    db: Session,
    *,
    actor: User,
    action: str,
    resource_type: str,
    resource_id: int | None = None,
    detail: dict[str, Any] | None = None,
    ip_address: str | None = None,
) -> AdminAuditLog:
    entry = AdminAuditLog(
        actor_id=actor.id,
        action=action,
        resource_type=resource_type,
        resource_id=resource_id,
        detail_json=json.dumps(detail or {}, ensure_ascii=False) if detail else None,
        ip_address=ip_address,
    )
    db.add(entry)
    db.flush()
    return entry


def audit_to_dict(entry: AdminAuditLog, actor_phone: str | None = None) -> dict:
    detail: dict[str, Any] = {}
    if entry.detail_json:
        try:
            detail = json.loads(entry.detail_json)
        except json.JSONDecodeError:
            detail = {"raw": entry.detail_json}
    return {
        "id": entry.id,
        "actor_id": entry.actor_id,
        "actor_phone": actor_phone,
        "action": entry.action,
        "resource_type": entry.resource_type,
        "resource_id": entry.resource_id,
        "detail": detail,
        "ip_address": entry.ip_address,
        "created_at": entry.created_at.isoformat() if entry.created_at else None,
    }
