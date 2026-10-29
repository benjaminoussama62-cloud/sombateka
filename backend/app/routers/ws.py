import json
import time
from typing import Any

from fastapi import APIRouter, WebSocket, WebSocketDisconnect
from jose import jwt
from sqlalchemy import select

from app.db import SessionLocal
from app.models import Message, User
from app.services.privacy import can_message_user
from app.settings import settings

router = APIRouter(tags=["websocket"])

_connections: dict[int, set[WebSocket]] = {}
# Simple per-user message rate (in-process; nginx also limits /ws/)
_msg_timestamps: dict[int, list[float]] = {}
_MAX_WS_MESSAGES_PER_MINUTE = 60


def _user_id_from_token(token: str) -> int | None:
    try:
        payload = jwt.decode(
            token,
            settings.jwt_secret,
            algorithms=["HS256"],
            audience=settings.jwt_audience,
            issuer=settings.jwt_issuer,
        )
        return int(payload["sub"])
    except Exception:
        return None


def _extract_token(websocket: WebSocket) -> str | None:
    """Prefer Authorization / Sec-WebSocket-Protocol; query token only hors prod."""
    auth = websocket.headers.get("authorization") or ""
    if auth.lower().startswith("bearer "):
        token = auth[7:].strip()
        if token:
            return token

    proto = websocket.headers.get("sec-websocket-protocol") or ""
    if proto:
        parts = [p.strip() for p in proto.split(",") if p.strip()]
        if len(parts) >= 2 and parts[0].lower() in {"bearer", "access_token", "jwt"}:
            return parts[1]
        if len(parts) == 1 and parts[0].count(".") >= 2:
            return parts[0]

    # Legacy ?token= — disabled in production (leaks in access logs / Referer)
    if not settings.is_production:
        q = (websocket.query_params.get("token") or "").strip()
        if q:
            return q
    return None


def _rate_ok(user_id: int) -> bool:
    now = time.time()
    bucket = _msg_timestamps.setdefault(user_id, [])
    _msg_timestamps[user_id] = [t for t in bucket if t > now - 60.0]
    if len(_msg_timestamps[user_id]) >= _MAX_WS_MESSAGES_PER_MINUTE:
        return False
    _msg_timestamps[user_id].append(now)
    return True


def _can_ws_message(sender_id: int, recipient_id: int) -> bool:
    if recipient_id <= 0 or recipient_id == sender_id:
        return False
    db = SessionLocal()
    try:
        sender = db.get(User, sender_id)
        recipient = db.get(User, recipient_id)
        if not sender or not recipient:
            return False
        if sender.is_banned or recipient.is_banned:
            return False
        if not can_message_user(db, sender, recipient):
            return False
        # Require an existing conversation thread OR allow first contact only if privacy allows
        # (can_message_user already covers privacy + blocks). Extra: prefer known peers.
        prior = db.scalar(
            select(Message.id)
            .where(
                (
                    (Message.sender_id == sender_id) & (Message.recipient_id == recipient_id)
                )
                | (
                    (Message.sender_id == recipient_id) & (Message.recipient_id == sender_id)
                )
            )
            .limit(1)
        )
        # First contact still allowed if privacy permits (matches REST create).
        return True if prior is not None or recipient.privacy_allow_messages else False
    finally:
        db.close()


@router.websocket("/ws/chat")
async def chat_ws(websocket: WebSocket):
    token = _extract_token(websocket)
    user_id = _user_id_from_token(token or "")
    if not user_id:
        # Reject handshake without accepting (no unauthenticated socket)
        await websocket.close(code=4401)
        return

    await websocket.accept()
    _connections.setdefault(user_id, set()).add(websocket)
    try:
        while True:
            raw = await websocket.receive_text()
            if not _rate_ok(user_id):
                await websocket.send_json({"type": "error", "detail": "rate_limit"})
                continue
            try:
                data: dict[str, Any] = json.loads(raw)
            except json.JSONDecodeError:
                await websocket.send_json({"type": "error", "detail": "invalid_json"})
                continue

            try:
                recipient_id = int(data.get("recipient_id") or 0)
            except (TypeError, ValueError):
                await websocket.send_json({"type": "error", "detail": "invalid_recipient"})
                continue

            if not _can_ws_message(user_id, recipient_id):
                await websocket.send_json({"type": "error", "detail": "forbidden"})
                continue

            content = data.get("content", "")
            if not isinstance(content, str):
                content = str(content)
            content = content[:4000]

            payload = {
                "type": "message",
                "sender_id": user_id,
                "content": content,
                "listing_id": data.get("listing_id"),
            }
            for peer_ws in list(_connections.get(recipient_id, set())):
                try:
                    await peer_ws.send_json(payload)
                except Exception:
                    _connections.get(recipient_id, set()).discard(peer_ws)
            await websocket.send_json({"type": "ack", "ok": True})
    except WebSocketDisconnect:
        pass
    finally:
        _connections.get(user_id, set()).discard(websocket)
