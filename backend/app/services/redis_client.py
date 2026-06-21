from __future__ import annotations

import redis
from redis import Redis

from app.settings import settings

_client: Redis | None = None


def get_redis() -> Redis | None:
    global _client
    if _client is not None:
        return _client
    try:
        _client = redis.from_url(settings.redis_url, decode_responses=True, socket_connect_timeout=2)
        _client.ping()
        return _client
    except Exception:
        _client = None
        return None
