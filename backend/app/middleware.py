import json
import time
from collections import defaultdict, deque
from typing import Deque

from fastapi import Request
from starlette.middleware.base import BaseHTTPMiddleware
from starlette.responses import JSONResponse

from app.services.redis_client import get_redis
from app.settings import settings


class RedisRateLimitMiddleware(BaseHTTPMiddleware):
    """Distributed sliding-window rate limit (Redis) with in-memory fallback."""

    def __init__(self, app) -> None:
        super().__init__(app)
        self._fallback: dict[str, Deque[float]] = defaultdict(deque)

    async def dispatch(self, request: Request, call_next):
        if request.method == "OPTIONS":
            return await call_next(request)
        if request.url.path.startswith("/admin"):
            return await call_next(request)
        if request.url.path == "/admin/bootstrap-config":
            return await call_next(request)
        if request.url.path == "/api/auth/admin/login":
            ip = (request.client.host if request.client else "unknown") or "unknown"
            key = f"rl:admin_login:{ip}:{int(time.time()) // 60}"
            limit = max(3, int(settings.admin_login_rate_limit_per_minute))
            redis = get_redis() if settings.use_redis_rate_limit else None
            if redis:
                try:
                    count = redis.incr(key)
                    if count == 1:
                        redis.expire(key, 65)
                    if count > limit:
                        return JSONResponse({"detail": "Trop de tentatives. Réessayez plus tard."}, status_code=429)
                except Exception:
                    pass
            return await call_next(request)
        if request.url.path in {"/healthz", "/health", "/docs", "/openapi.json", "/redoc", "/api/auth/admin/config"}:
            return await call_next(request)

        ip = (request.client.host if request.client else "unknown") or "unknown"
        user_key = request.headers.get("x-user-id") or ip
        key = f"rl:{user_key}:{int(time.time()) // 60}"
        limit = max(30, int(settings.rate_limit_per_minute))

        redis = get_redis() if settings.use_redis_rate_limit else None
        if redis:
            try:
                count = redis.incr(key)
                if count == 1:
                    redis.expire(key, 65)
                if count > limit:
                    return JSONResponse({"detail": "Rate limit exceeded"}, status_code=429)
                return await call_next(request)
            except Exception:
                pass

        now = time.time()
        window = 60.0
        q = self._fallback[ip]
        while q and q[0] < now - window:
            q.popleft()
        if len(q) >= limit:
            return JSONResponse({"detail": "Rate limit exceeded"}, status_code=429)
        q.append(now)
        return await call_next(request)


def json_dumps(obj) -> str:
    return json.dumps(obj, ensure_ascii=False, separators=(",", ":"), default=str)
