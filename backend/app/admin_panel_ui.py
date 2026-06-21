"""Panneau admin : pages login + dashboard (routes enregistrées directement sur l'app)."""

from __future__ import annotations

import logging
from pathlib import Path

from fastapi import FastAPI, HTTPException
from fastapi.responses import FileResponse, JSONResponse, RedirectResponse

from app.settings import settings

logger = logging.getLogger(__name__)

ADMIN_UI_VERSION = "10-catalog-carousel"


def resolve_admin_panel_dir() -> Path | None:
    app_dir = Path(__file__).resolve().parent
    backend_dir = app_dir.parent
    repo_root = backend_dir.parent
    for candidate in (
        backend_dir / "admin-panel",
        repo_root / "admin-panel",
    ):
        if candidate.is_dir() and (candidate / "login.html").is_file():
            return candidate
    return None


ADMIN_PANEL_DIR = resolve_admin_panel_dir()
if ADMIN_PANEL_DIR:
    logger.info("Panneau admin: %s", ADMIN_PANEL_DIR)
else:
    logger.warning("Panneau admin: dossier introuvable (backend/admin-panel)")


def _safe_file(base: Path, *parts: str) -> Path:
    target = (base.joinpath(*parts)).resolve()
    base_resolved = base.resolve()
    if base_resolved not in target.parents and target != base_resolved:
        raise HTTPException(status_code=404, detail="Not Found")
    if not target.is_file():
        raise HTTPException(status_code=404, detail="Not Found")
    return target


def _html_file(name: str) -> FileResponse:
    if not ADMIN_PANEL_DIR:
        raise HTTPException(status_code=503, detail="Panneau admin non installé")
    return FileResponse(_safe_file(ADMIN_PANEL_DIR, name), media_type="text/html; charset=utf-8")


def admin_bootstrap_config() -> JSONResponse:
    return JSONResponse(
        {
            "environment": settings.environment,
            "session_minutes": settings.admin_session_minutes,
            "ui_version": ADMIN_UI_VERSION,
        }
    )


def admin_login_page() -> FileResponse:
    return _html_file("login.html")


def admin_dashboard_page() -> FileResponse:
    return _html_file("dashboard.html")


def admin_assets(asset_path: str) -> FileResponse:
    if not ADMIN_PANEL_DIR:
        raise HTTPException(status_code=503, detail="Panneau admin non installé")
    path = _safe_file(ADMIN_PANEL_DIR, "assets", asset_path)
    suffix = path.suffix.lower()
    media = "application/octet-stream"
    if suffix == ".css":
        media = "text/css; charset=utf-8"
    elif suffix == ".js":
        media = "text/javascript; charset=utf-8"
    elif suffix == ".png":
        media = "image/png"
    elif suffix == ".ico":
        media = "image/x-icon"
    elif suffix == ".svg":
        media = "image/svg+xml"
    return FileResponse(path, media_type=media)


def admin_ping() -> dict:
    return {
        "ok": True,
        "ui_version": ADMIN_UI_VERSION,
        "panel_dir": str(ADMIN_PANEL_DIR) if ADMIN_PANEL_DIR else None,
    }


def mount_admin_panel(app: FastAPI) -> None:
    """Enregistre toutes les routes /admin/* sur l'application FastAPI."""
    routes = [
        ("/admin/ping", admin_ping, ["GET"]),
        ("/admin/bootstrap-config", admin_bootstrap_config, ["GET"]),
        ("/admin", lambda: RedirectResponse(url="/admin/login", status_code=307), ["GET"]),
        ("/admin/", lambda: RedirectResponse(url="/admin/login", status_code=307), ["GET"]),
        ("/admin/login", admin_login_page, ["GET"]),
        ("/admin/dashboard", admin_dashboard_page, ["GET"]),
        ("/admin/assets/{asset_path:path}", admin_assets, ["GET"]),
    ]
    for path, endpoint, methods in routes:
        app.add_api_route(path, endpoint, methods=methods, include_in_schema=False)
    logger.info("Routes admin montées (version %s)", ADMIN_UI_VERSION)


# Compatibilité : ancien import router
router = FastAPI().router  # placeholder vide ; utiliser mount_admin_panel(app)
