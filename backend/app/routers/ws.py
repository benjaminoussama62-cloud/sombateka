import json
from typing import Any

from fastapi import APIRouter, WebSocket, WebSocketDisconnect
from jose import jwt

from app.settings import settings

router = APIRouter(tags=["websocket"])

_connections: dict[int, set[WebSocket]] = {}


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


@router.websocket("/ws/chat")
async def chat_ws(websocket: WebSocket, token: str | None = None):
    await websocket.accept()
    user_id = _user_id_from_token(token or "")
    if not user_id:
        await websocket.close(code=4401)
        return

    _connections.setdefault(user_id, set()).add(websocket)
    try:
        while True:
            raw = await websocket.receive_text()
            data: dict[str, Any] = json.loads(raw)
            recipient_id = int(data.get("recipient_id", 0))
            payload = {
                "type": "message",
                "sender_id": user_id,
                "content": data.get("content", ""),
                "listing_id": data.get("listing_id"),
            }
            for peer_ws in _connections.get(recipient_id, set()):
                await peer_ws.send_json(payload)
            await websocket.send_json({"type": "ack", "ok": True})
    except WebSocketDisconnect:
        pass
    finally:
        _connections.get(user_id, set()).discard(websocket)
