"""Mélange du fil d'accueil : comptes officiels promus (rotation équitable type Meta Ads)."""

from __future__ import annotations

from collections import defaultdict
from datetime import datetime
from typing import Any


PROMOTE_INTERVAL = 3  # 1 annonce officielle toutes les N cartes


def _created_ts(item: dict[str, Any]) -> float:
    raw = item.get("created_at")
    if raw is None:
        return 0.0
    if isinstance(raw, datetime):
        return raw.timestamp()
    try:
        return datetime.fromisoformat(str(raw).replace("Z", "+00:00")).timestamp()
    except (TypeError, ValueError):
        return 0.0


def round_robin_official(official_items: list[dict[str, Any]]) -> list[dict[str, Any]]:
    """Rotation équitable entre vendeurs officiels (même logique qu'une campagne multi-annonceur)."""
    if not official_items:
        return []
    by_seller: dict[int, list[dict[str, Any]]] = defaultdict(list)
    for item in official_items:
        sid = int(item.get("seller_id") or 0)
        by_seller[sid].append(item)
    for bucket in by_seller.values():
        bucket.sort(key=_created_ts, reverse=True)

    sellers = sorted(by_seller.keys())
    queues = [by_seller[s] for s in sellers]
    out: list[dict[str, Any]] = []
    while any(queues):
        for q in queues:
            if q:
                out.append(q.pop(0))
    return out


def mix_promoted_feed(
    items: list[dict[str, Any]],
    *,
    limit: int,
    offset: int = 0,
) -> list[dict[str, Any]]:
    """Intercale les produits officiels dans le fil principal."""
    official = [i for i in items if i.get("is_official")]
    regular = [i for i in items if not i.get("is_official")]
    official.sort(key=_created_ts, reverse=True)
    regular.sort(key=_created_ts, reverse=True)

    promoted = round_robin_official(official)
    merged: list[dict[str, Any]] = []
    pi, ri = 0, 0
    slot = 0

    while len(merged) < limit + offset and (pi < len(promoted) or ri < len(regular)):
        use_official = (
            promoted
            and pi < len(promoted)
            and (slot % PROMOTE_INTERVAL == 0 or ri >= len(regular))
        )
        if use_official:
            merged.append({**promoted[pi], "promoted": True})
            pi += 1
        elif ri < len(regular):
            merged.append(regular[ri])
            ri += 1
        elif pi < len(promoted):
            merged.append({**promoted[pi], "promoted": True})
            pi += 1
        slot += 1

    return merged[offset : offset + limit]
