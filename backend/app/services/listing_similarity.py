"""Produits similaires — vecteurs + hashes + catégorie + attributs (style Wildberries)."""

from __future__ import annotations

import json
import re
from typing import Any

from sqlalchemy.orm import Session

from app.services.image_search import MIN_COMBINED, best_image_similarity_keys
from app.services.visual_features import cosine_similarity
from app.services.visual_index import load_vectors_for_listings

MIN_SCORE = 0.38
MIN_IMAGE = 0.28
MIN_IMAGE_CROSS_CATEGORY = 0.38
MAX_RESULTS = 24


def _parse_attrs(raw: str | None) -> dict[str, str]:
    if not raw:
        return {}
    try:
        m = json.loads(raw) if isinstance(raw, str) else raw
        if isinstance(m, dict):
            return {str(k).lower(): str(v).lower() for k, v in m.items() if v}
    except (json.JSONDecodeError, TypeError):
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


def _best_vec(a: list[float], rows: list[tuple[int, list[float], str | None]]) -> float:
    best = 0.0
    for _, vec, _ in rows:
        if vec:
            best = max(best, cosine_similarity(a, vec))
    return best


def score_pair(
    source_listing: Any,
    source_key: str | None,
    source_cat_id: int | None,
    candidate: Any,
    candidate_keys: list[str],
    candidate_cat_id: int | None,
    *,
    source_vec: list[float] | None = None,
    cand_vecs: list[tuple[int, list[float], str | None]] | None = None,
) -> float | None:
    if not source_key or not candidate_keys:
        return None

    img = best_image_similarity_keys(source_key, candidate_keys)
    vec_score = 0.0
    if source_vec and cand_vecs:
        vec_score = _best_vec(source_vec, cand_vecs)

    fused_visual = img or 0.0
    if vec_score > 0 and img is not None:
        fused_visual = 0.45 * vec_score + 0.55 * img
    elif vec_score > 0:
        fused_visual = vec_score * 0.92

    if fused_visual < MIN_IMAGE:
        return None

    same_cat = bool(
        source_cat_id and candidate_cat_id and source_cat_id == candidate_cat_id
    )
    if not same_cat and fused_visual < MIN_IMAGE_CROSS_CATEGORY:
        return None

    src_attrs = _parse_attrs(getattr(source_listing, "attributes", None))
    cand_attrs = _parse_attrs(getattr(candidate, "attributes", None))

    color_match = 0.0
    if src_attrs.get("color") and cand_attrs.get("color"):
        color_match = 1.0 if src_attrs["color"] == cand_attrs["color"] else 0.0

    brand_match = 0.0
    if src_attrs.get("brand") and cand_attrs.get("brand"):
        brand_match = 1.0 if src_attrs["brand"] == cand_attrs["brand"] else 0.0

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
        (fused_visual, 0.55),
        (1.0 if same_cat else 0.0, 0.12),
        (color_match, 0.10),
        (brand_match, 0.08),
        (size_match, 0.03),
        (text_sim, 0.08),
    ]

    score = sum(s * w for s, w in parts) / sum(w for _, w in parts)
    if score < MIN_SCORE or fused_visual < MIN_COMBINED - 0.06:
        return None
    return round(min(score, 0.95), 3)


def find_similar_to_listing(
    source_listing: Any,
    source_image_key: str | None,
    candidates: list[tuple[Any, list[str]]],
    exclude_id: int | None = None,
    *,
    db: Session | None = None,
) -> list[tuple[float, Any]]:
    src_id = getattr(source_listing, "id", None)
    src_cat = getattr(source_listing, "category_id", None)

    source_vec: list[float] | None = None
    vector_map: dict[int, list[tuple[int, list[float], str | None]]] = {}
    if db is not None:
        ids = [src_id] + [getattr(l, "id", None) for l, _ in candidates]
        ids = [i for i in ids if i is not None]
        vector_map = load_vectors_for_listings(db, ids)
        if src_id is not None:
            for _, vec, _ in vector_map.get(src_id, []):
                if vec:
                    source_vec = vec
                    break

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
            source_vec=source_vec,
            cand_vecs=vector_map.get(lid) if lid is not None else None,
        )
        if sim is not None:
            scored.append((sim, listing))

    scored.sort(key=lambda x: x[0], reverse=True)
    if scored:
        best = scored[0][0]
        floor = max(MIN_SCORE - 0.04, best - 0.14)
        scored = [(s, l) for s, l in scored if s >= floor]
    return scored[:MAX_RESULTS]
