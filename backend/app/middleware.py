import json
import time
from collections import defaultdict, deque
from typing import Deque

from fastapi import Request
from starlette.middleware.base import BaseHTTPMiddleware
from starlette.responses import JSONResponse

from app.services.redis_client import get_redis
from app.settings import settings


def json_dumps(obj) -> str:
    return json.dumps(obj, ensure_ascii=False, separators=(",", ":"), default=str)


def _client_ip(request: Request) -> str:
    """Client IP trusted from the edge proxy only.

    nginx sets X-Real-IP / X-Forwarded-For to $remote_addr (not client-controlled).
    Prefer X-Real-IP; never trust the first XFF hop from a raw client.
    """
    real_ip = (request.headers.get("x-real-ip") or "").strip()
    if real_ip and real_ip.lower() != "unknown":
        return real_ip

    forwarded = (request.headers.get("x-forwarded-for") or "").strip()
    if forwarded:
        # Last hop is the one appended by our edge (or the only value when nginx overwrites).
        hop = forwarded.split(",")[-1].strip()
        if hop:
            return hop

    if request.client and request.client.host:
        return request.client.host
    return "unknown"


def _ip_allowed(ip: str, allowlist: list[str]) -> bool:
    if not allowlist:
        return True
    if ip in allowlist:
        return True
    # Support simple CIDR-less prefix notes are not needed; exact match only for safety.
    return False


class RedisRateLimitMiddleware(BaseHTTPMiddleware):
    """Distributed sliding-window rate limit (Redis) with in-memory fallback."""

    def __init__(self, app) -> None:
        super().__init__(app)
        self._fallback: dict[str, Deque[float]] = defaultdict(deque)

    async def dispatch(self, request: Request, call_next):
        if request.method == "OPTIONS":
            return await call_next(request)

        path = request.url.path
        ip = _client_ip(request)

        # Optional admin IP allowlist (empty = public with auth + rate limits)
        allowlist = settings.admin_ip_allowlist_list()
        if allowlist and (
            path.startswith("/admin")
            or path.startswith("/api/auth/admin")
        ):
            if not _ip_allowed(ip, allowlist):
                return JSONResponse({"detail": "Accès admin refusé"}, status_code=403)

        if path == "/api/auth/admin/login":
            key = f"rl:admin_login:{ip}:{int(time.time()) // 60}"
            limit = max(3, int(settings.admin_login_rate_limit_per_minute))
            blocked = await self._hit(key, f"admin:{ip}", limit, "Trop de tentatives. Réessayez plus tard.")
            if blocked is not None:
                return blocked
            return await call_next(request)

        if path in {
            "/api/auth/admin/2fa/verify",
            "/api/auth/admin/2fa/confirm-setup",
        }:
            key = f"rl:admin_2fa:{ip}:{int(time.time()) // 60}"
            limit = max(5, int(settings.admin_login_rate_limit_per_minute))
            blocked = await self._hit(key, f"admin2fa:{ip}", limit, "Trop de tentatives 2FA.")
            if blocked is not None:
                return blocked
            return await call_next(request)

        if path in {
            "/api/auth/login",
            "/api/auth/register",
            "/api/auth/password/forgot",
            "/api/auth/password/reset",
        }:
            key = f"rl:auth_pwd:{path}:{ip}:{int(time.time()) // 60}"
            limit = 8
            blocked = await self._hit(
                key, f"auth:{ip}:{path}", limit, "Trop de tentatives. Réessayez dans une minute."
            )
            if blocked is not None:
                return blocked
            return await call_next(request)

        if path in {
            "/api/auth/email/otp/send",
            "/api/auth/email/otp/verify",
        }:
            suffix = "send" if path.endswith("/send") else "verify"
            key = f"rl:email_otp:{suffix}:{ip}:{int(time.time()) // 60}"
            limit = max(3, int(settings.email_otp_rate_limit_per_minute))
            blocked = await self._hit(
                key,
                f"email_otp:{suffix}:{ip}",
                limit,
                "Trop de tentatives email. Réessayez dans une minute.",
            )
            if blocked is not None:
                return blocked
            return await call_next(request)

        # Static admin assets: light rate limit (nginx also limits /admin/)
        if path.startswith("/admin"):
            key = f"rl:admin_static:{ip}:{int(time.time()) // 60}"
            blocked = await self._hit(key, f"admin_static:{ip}", 120, "Rate limit exceeded")
            if blocked is not None:
                return blocked
            return await call_next(request)

        if path in {"/healthz", "/health", "/docs", "/openapi.json", "/redoc", "/api/auth/admin/config"}:
            return await call_next(request)
        # SEO / Googlebot — pages catalogue, produits, sitemaps & feed Merchant
        if (
            path.startswith("/annonce/")
            or path.startswith("/categorie/")
            or path.startswith("/feeds/")
            or path in {
                "/catalogue",
                "/sitemap-products.xml",
                "/sitemap-categories.xml",
                "/sitemap-index.xml",
            }
        ):
            return await call_next(request)

        key = f"rl:{ip}:{int(time.time()) // 60}"
        limit = max(30, int(settings.rate_limit_per_minute))
        blocked = await self._hit(key, ip, limit, "Rate limit exceeded")
        if blocked is not None:
            return blocked
        return await call_next(request)

    async def _hit(self, redis_key: str, fb_key: str, limit: int, detail: str) -> JSONResponse | None:
        redis = get_redis() if settings.use_redis_rate_limit else None
        if redis:
            try:
                count = redis.incr(redis_key)
                if count == 1:
                    redis.expire(redis_key, 65)
                if count > limit:
                    return JSONResponse({"detail": detail}, status_code=429)
                return None
            except Exception:
                pass

        now = time.time()
        q = self._fallback[fb_key]
        while q and q[0] < now - 60.0:
            q.popleft()
        if len(q) >= limit:
            return JSONResponse({"detail": detail}, status_code=429)
        q.append(now)
        return None
