"""Notification moteurs de recherche à la publication (IndexNow).

Google Search n'offre PAS d'API d'indexation instantanée pour les fiches produit
(uniquement JobPosting / livestream). On notifie Bing/Yandex/etc. via IndexNow
et on s'appuie sur le sitemap dynamique + Merchant feed pour Google.
"""

from __future__ import annotations

import logging
import threading
from urllib import error, request

from app.services.seo_catalog import slugify
from app.settings import settings

logger = logging.getLogger(__name__)

_INDEXNOW_ENDPOINT = "https://api.indexnow.org/indexnow"


def listing_public_url(listing_id: int, title: str) -> str:
    base = (settings.public_base_url or "https://sombatekaonline.com").rstrip("/")
    return f"{base}/annonce/{listing_id}-{slugify(title)}"


def notify_url_updated(url: str) -> None:
    """Fire-and-forget : IndexNow (Bing, Yandex, …)."""
    if not (settings.indexnow_enabled and settings.indexnow_key):
        return
    threading.Thread(
        target=_submit_indexnow,
        args=([url],),
        kwargs={"deleted": False},
        daemon=True,
        name="indexnow-update",
    ).start()


def notify_url_deleted(url: str) -> None:
    if not (settings.indexnow_enabled and settings.indexnow_key):
        return
    threading.Thread(
        target=_submit_indexnow,
        args=([url],),
        kwargs={"deleted": True},
        daemon=True,
        name="indexnow-delete",
    ).start()


def notify_listing_updated(listing_id: int, title: str) -> None:
    notify_url_updated(listing_public_url(listing_id, title))


def notify_listing_deleted(listing_id: int, title: str) -> None:
    notify_url_deleted(listing_public_url(listing_id, title))


def _submit_indexnow(urls: list[str], *, deleted: bool = False) -> None:
    key = (settings.indexnow_key or "").strip()
    if not key or not urls:
        return
    host = (settings.public_base_url or "https://sombatekaonline.com").rstrip("/")
    host = host.replace("https://", "").replace("http://", "").split("/")[0]
    key_location = f"https://{host}/{key}.txt"
    # IndexNow : même payload pour update ; les URLs retirées sont aussi pingées
    # pour forcer un re-crawl (les moteurs retirent si 404 / noindex).
    payload = {
        "host": host,
        "key": key,
        "keyLocation": key_location,
        "urlList": urls[:100],
    }
    import json

    body = json.dumps(payload).encode("utf-8")
    req = request.Request(
        _INDEXNOW_ENDPOINT,
        data=body,
        headers={"Content-Type": "application/json; charset=utf-8"},
        method="POST",
    )
    try:
        with request.urlopen(req, timeout=8) as resp:
            logger.info(
                "IndexNow %s urls=%s status=%s deleted=%s",
                host,
                len(urls),
                getattr(resp, "status", "?"),
                deleted,
            )
    except error.HTTPError as exc:
        # 202/200 = OK ; 422 = clé invalide
        logger.warning("IndexNow HTTP %s: %s", exc.code, exc.read()[:200])
    except Exception as exc:  # noqa: BLE001
        logger.warning("IndexNow failed: %s", exc)
