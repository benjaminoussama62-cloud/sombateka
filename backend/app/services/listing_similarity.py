"""Produits similaires — visuel + catégorie + attributs (équilibre Wildberries)."""

from __future__ import annotations

import json
import re
from typing import Any

from app.services.image_search import MIN_COMBINED, best_image_similarity_keys

MIN_SCORE = 0.56
MIN_IMAGE = 0.58
MIN_IMAGE_CROSS_CATEGORY = 0.66
MAX_RESULTS = 24


def _parse_attrs(raw: str | None) -> dict[str, str]:
    if not raw:
        return {}
    try:
        m = json.loads(raw)
        if isinstance(m, dict):
            return {str(k).lower(): str(v).lower() for k, v in m.items() if v}
    except json.JSONDecodeError:
        pass
    return {}


def _title_tokens(title: str | None) -> set[str]:
    if not title:
        return set()
    words = re.findall(r"[a-zA-Zàâäéèêëïîôùûüç0-9]{3,}", title.lower())
    stop = {"pour", "avec", "dans", "une", "des", "les", "the", "and"}
    return {w for w in words if w not in stop}


def _text_overlap(a: set[str], b: set[str]) -> float:
    if not a or not b:
        return 0.0
    inter = len(a & b)
    union = len(a | b)
    return inter / union if union else 0.0


def score_pair(
    source_listing: Any,
    source_key: str | None,
    source_cat_id: int | None,
    candidate: Any,
    candidate_keys: list[str],
    candidate_cat_id: int | None,
) -> float | None:
    if not source_key or not candidate_keys:
        return None

    img = best_image_similarity_keys(source_key, candidate_keys)
    if img is None or img < MIN_IMAGE:
        return None

    same_cat = bool(
        source_cat_id and candidate_cat_id and source_cat_id == candidate_cat_id
    )
    if not same_cat and img < MIN_IMAGE_CROSS_CATEGORY:
        return None

    src_attrs = _parse_attrs(getattr(source_listing, "attributes", None))
    cand_attrs = _parse_attrs(getattr(candidate, "attributes", None))

    color_match = 0.0
    if src_attrs.get("color") and cand_attrs.get("color"):
        color_match = 1.0 if src_attrs["color"] == cand_attrs["color"] else 0.0

    size_match = 0.0
    if src_attrs.get("size") and cand_attrs.get("size"):
        size_match = 1.0 if src_attrs["size"] == cand_attrs["size"] else 0.0

    title_sim = _text_overlap(
        _title_tokens(getattr(source_listing, "title", None)),
        _title_tokens(getattr(candidate, "title", None)),
    )
    desc_sim = _text_overlap(
        _title_tokens(getattr(source_listing, "description", None)),
        _title_tokens(getattr(candidate, "description", None)),
    )
    text_sim = max(title_sim, desc_sim * 0.85)

    parts: list[tuple[float, float]] = [
        (img, 0.50),
        (1.0 if same_cat else 0.0, 0.16),
        (color_match, 0.12),
        (size_match, 0.05),
        (text_sim, 0.10),
    ]

    score = sum(s * w for s, w in parts) / sum(w for _, w in parts)
    if score < MIN_SCORE or img < MIN_COMBINED - 0.04:
        return None
    return round(min(score, 0.93), 3)


def find_similar_to_listing(
    source_listing: Any,
    source_image_key: str | None,
    candidates: list[tuple[Any, list[str]]],
    exclude_id: int | None = None,
) -> list[tuple[float, Any]]:
    src_id = getattr(source_listing, "id", None)
    src_cat = getattr(source_listing, "category_id", None)

    scored: list[tuple[float, Any]] = []
    for listing, keys in candidates:
        lid = getattr(listing, "id", None)
        if lid == exclude_id or lid == src_id or not keys:
            continue
        sim = score_pair(
            source_listing,
            source_image_key,
            src_cat,
            listing,
            keys,
            getattr(listing, "category_id", None),
        )
        if sim is not None:
            scored.append((sim, listing))

    scored.sort(key=lambda x: x[0], reverse=True)
    if scored:
        best = scored[0][0]
        floor = max(MIN_SCORE, best - 0.10)
        scored = [(s, l) for s, l in scored if s >= floor]
    return scored[:MAX_RESULTS]
