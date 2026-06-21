import json

from fastapi import Depends, Header, HTTPException, Request
from sqlalchemy import select
from sqlalchemy.orm import Session

from app.db import get_db
from app.deps import get_current_user
from app.middleware import json_dumps
from app.models import IdempotencyKey, User


def require_idempotency_key(
    request: Request,
    x_idempotency_key: str | None = Header(default=None),
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
) -> tuple[str, User, Session]:
    if request.method.upper() not in {"POST", "PUT", "PATCH"}:
        return ("", current_user, db)

    # For write endpoints we enforce it; clients can re-send safely.
    key = (x_idempotency_key or "").strip()
    if len(key) < 8 or len(key) > 128:
        raise HTTPException(status_code=400, detail="Missing/invalid X-Idempotency-Key")

    existing = db.scalar(select(IdempotencyKey).where(IdempotencyKey.user_id == current_user.id, IdempotencyKey.key == key))
    if existing:
        # replay existing response
        body = json.loads(existing.response_body_json)
        raise HTTPException(status_code=409, detail={"idempotent_replay": True, "status_code": existing.status_code, "response": body})

    return (key, current_user, db)


def save_idempotency_response(
    *,
    db: Session,
    user_id: int,
    key: str,
    method: str,
    path: str,
    status_code: int,
    response_body: dict,
) -> None:
    rec = IdempotencyKey(
        user_id=user_id,
        key=key,
        method=method.upper(),
        path=path,
        status_code=status_code,
        response_body_json=json_dumps(response_body),
    )
    db.add(rec)
    db.commit()

