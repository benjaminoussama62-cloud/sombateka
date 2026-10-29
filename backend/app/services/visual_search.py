"""Pipeline recherche visuelle — précision type Google/Wildberries (pas de faux positifs)."""

from __future__ import annotations

import io
import json
import logging
import re
from typing import Any

from PIL import Image, ImageOps
from sqlalchemy.orm import Session

from app.services.image_search import find_similar_listings
from app.services.visual_features import cosine_similarity, extract_from_bytes
from app.services.visual_index import index_listing_image, load_vectors_for_listings

logger = logging.getLogger(__name__)

MAX_VECTOR_CANDIDATES = 1200
VECTOR_TOP_K = 48
FINAL_TOP_K = 24

# Seuils stricts — mieux 0 résultat que des faux positifs
MIN_ACCEPT = 0.65          # en dessous = pas assez similaire
MIN_EXACT = 0.85
MIN_CLOSE = 0.72
RELATIVE_GAP = 0.08        # fenêtre serrée autour du meilleur
MIN_VECTOR_FOR_SHORTLIST = 0.55
MIN_LEGACY_SIGNAL = 0.42   # hash/ORB obligatoire (les vecteurs couleur seuls mentent)
MIN_QUERY_EDGE = 0.012     # aplats / écran noir (~0.0) ; photos produit ~0.03–0.05
MIN_CATEGORY_PEER_VEC = 0.72  # après un match fort : peers même catégorie + tokens
_TOKEN_RE = re.compile(r"[a-z0-9àâäéèêëïîôùûüç]+", re.I)


def _query_edge_density(data: bytes) -> float:
    """Densité de contours 0–1 : rejette captures vides / aplats sans objet."""
    try:
        img = ImageOps.exif_transpose(Image.open(io.BytesIO(data))).convert("L")
        img = img.resize((128, 128), Image.Resampling.BILINEAR)
        px = list(img.getdata())
        if len(px) < 16:
            return 0.0
        # Gradient simple horizontal + vertical
        w, h = 128, 128
        edges = 0.0
        n = 0
        for y in range(h - 1):
            row = y * w
            for x in range(w - 1):
                i = row + x
                dx = abs(px[i] - px[i + 1])
                dy = abs(px[i] - px[i + w])
                edges += dx + dy
                n += 2
        return min(1.0, (edges / max(n, 1)) / 255.0)
    except Exception:
        return 0.5  # en doute, laisser passer


def _tokenize(text: str | None) -> set[str]:
    if not text:
        return set()
    return {t.lower() for t in _TOKEN_RE.findall(text) if len(t) >= 2}


def _parse_attrs(raw: Any) -> dict[str, str]:
    if not raw:
        return {}
    try:
        if isinstance(raw, dict):
            data = raw
        else:
            data = json.loads(raw)
        if not isinstance(data, dict):
            return {}
        return {str(k).lower(): str(v).lower() for k, v in data.items() if v is not None and str(v).strip()}
    except Exception:
        return {}


def _attr_bonus(query_attrs: dict[str, str], listing: Any) -> float:
    cand = _parse_attrs(getattr(listing, "attributes", None))
    if not query_attrs or not cand:
        return 0.0
    score = 0.0
    for key, weight in (("color", 0.05), ("brand", 0.07), ("size", 0.03), ("material", 0.03)):
        qv = query_attrs.get(key)
        cv = cand.get(key)
        if qv and cv and (qv == cv or qv in cv or cv in qv):
            score += weight
    return score


def _text_overlap(query_tokens: set[str], listing: Any) -> float:
    if not query_tokens:
        return 0.0
    title = getattr(listing, "title", "") or ""
    attrs = getattr(listing, "attributes", None)
    blob = title
    if attrs:
        blob += " " + (attrs if isinstance(attrs, str) else json.dumps(attrs, ensure_ascii=False))
    lt = _tokenize(blob)
    if not lt:
        return 0.0
    inter = len(query_tokens & lt)
    return min(1.0, inter / max(1, min(len(query_tokens), 6)))


def _category_bonus(listing: Any, predicted_category_id: int | None) -> float:
    if predicted_category_id is None:
        return 0.0
    cid = getattr(listing, "category_id", None)
    if cid is None:
        return 0.0
    return 0.08 if int(cid) == int(predicted_category_id) else -0.04


def _best_vector_score(query_vec: list[float], image_vectors: list[tuple[int, list[float], str | None]]) -> float:
    best = 0.0
    for _, vec, _ in image_vectors:
        if vec:
            best = max(best, cosine_similarity(query_vec, vec))
    return best


def _ensure_vectors(
    db: Session,
    candidates: list[tuple[Any, list[str]]],
    listing_image_map: dict[int, list[tuple[int, list[float], str | None]]],
) -> dict[int, list[tuple[int, list[float], str | None]]]:
    from sqlalchemy import select

    from app.models import ListingImage

    missing: list[int] = []
    for listing, _keys in candidates[:MAX_VECTOR_CANDIDATES]:
        lid = getattr(listing, "id", None)
        if lid is None:
            continue
        rows = listing_image_map.get(lid, [])
        needs = not rows or all(not v for _, v, _ in rows)
        if not needs:
            continue
        imgs = db.scalars(select(ListingImage).where(ListingImage.listing_id == lid)).all()
        for im in imgs:
            missing.append(im.id)

    for img_id in missing[:60]:
        try:
            index_listing_image(db, img_id)
        except Exception as e:
            logger.debug("on-demand index failed %s: %s", img_id, e)

    if missing:
        ids = [getattr(l, "id", None) for l, _ in candidates if getattr(l, "id", None)]
        listing_image_map = load_vectors_for_listings(db, [i for i in ids if i])
    return listing_image_map


def _precision_filter(scored: list[tuple[float, Any]]) -> list[tuple[float, Any]]:
    """Ne garder que les vrais similaires — style Google Lens / Wildberries."""
    if not scored:
        return []
    scored = sorted(scored, key=lambda x: x[0], reverse=True)
    best = scored[0][0]
    if best < MIN_ACCEPT:
        logger.info("Image search: best=%.3f < MIN_ACCEPT=%.2f → 0 result (precision)", best, MIN_ACCEPT)
        return []

    floor = max(MIN_ACCEPT, best - RELATIVE_GAP)
    # Si le top est très fort, fenêtre encore plus serrée
    if best >= MIN_EXACT:
        floor = max(MIN_CLOSE, best - 0.08)
    elif best >= MIN_CLOSE:
        floor = max(MIN_ACCEPT, best - 0.09)

    out = [(s, l) for s, l in scored if s >= floor]
    return out[:FINAL_TOP_K]


def search_by_image_bytes(
    query_bytes: bytes,
    candidates: list[tuple[Any, list[str]]],
    *,
    db: Session | None = None,
) -> list[tuple[float, Any]]:
    """Retrieval vectoriel + reranking — précision avant recall."""
    if not candidates:
        return []

    edge = _query_edge_density(query_bytes)
    if edge < MIN_QUERY_EDGE:
        logger.info("Image search: query too flat (edge=%.4f) → 0 result", edge)
        return []

    try:
        query_pack = extract_from_bytes(query_bytes)
        query_vec = query_pack.vector
    except Exception as e:
        logger.warning("visual query extract failed: %s", e)
        legacy = find_similar_listings(query_bytes, candidates)
        return _precision_filter([(s, l) for s, l in legacy if s >= MIN_ACCEPT])

    listing_ids = [getattr(l, "id", None) for l, _ in candidates]
    listing_ids = [i for i in listing_ids if i is not None]

    vector_map: dict[int, list[tuple[int, list[float], str | None]]] = {}
    if db is not None and listing_ids:
        vector_map = load_vectors_for_listings(db, listing_ids)
        vector_map = _ensure_vectors(db, candidates, vector_map)

    vector_scored: list[tuple[float, Any]] = []
    for listing, _keys in candidates[:MAX_VECTOR_CANDIDATES]:
        lid = getattr(listing, "id", None)
        if lid is None:
            continue
        score = _best_vector_score(query_vec, vector_map.get(lid, []))
        if score >= MIN_VECTOR_FOR_SHORTLIST:
            vector_scored.append((score, listing))

    vector_scored.sort(key=lambda x: x[0], reverse=True)
    shortlist = vector_scored[:VECTOR_TOP_K]

    # Shortlist vectorielle pour accélérer ; legacy reste le juge de vérité
    if shortlist:
        shortlist_ids = {getattr(l, "id", None) for _, l in shortlist}
        shortlist_listings = [(l, k) for l, k in candidates if getattr(l, "id", None) in shortlist_ids]
        # Toujours inclure un échantillon large pour ne pas rater un match structurel
        extra = [(l, k) for l, k in candidates if getattr(l, "id", None) not in shortlist_ids]
        shortlist_listings = shortlist_listings + extra[: max(0, 40 - len(shortlist_listings))]
    else:
        shortlist_listings = candidates[: min(80, len(candidates))]

    legacy = find_similar_listings(query_bytes, shortlist_listings)
    legacy_map = {getattr(l, "id", None): s for s, l in legacy}
    vec_map_score = {getattr(l, "id", None): s for s, l in vector_scored}
    # Compléter les scores vecteur pour l’expansion catégorie
    for listing, _keys in candidates:
        lid = getattr(listing, "id", None)
        if lid is None or lid in vec_map_score:
            continue
        score = _best_vector_score(query_vec, vector_map.get(lid, []))
        if score > 0:
            vec_map_score[lid] = score

    # Seed texte/catégorie uniquement depuis un match hash confirmé (pas un faux positif couleur)
    seed = legacy[0][1] if legacy else None

    query_tokens = _tokenize(getattr(seed, "title", "") if seed else "")
    predicted_category = getattr(seed, "category_id", None) if seed else None
    query_attrs = _parse_attrs(getattr(seed, "attributes", None) if seed else None)

    fused: list[tuple[float, Any]] = []
    seen: set[int | None] = set()

    # Pool = candidats confirmés par hash/ORB (+ vecteur pour ranking)
    for lid, visual_s in list(legacy_map.items()):
        if lid is None or lid in seen:
            continue
        if visual_s < MIN_LEGACY_SIGNAL:
            continue
        listing = next((l for l, _ in shortlist_listings if getattr(l, "id", None) == lid), None)
        if listing is None:
            listing = next((l for l, _ in candidates if getattr(l, "id", None) == lid), None)
        if listing is None:
            continue
        seen.add(lid)
        vec_score = float(vec_map_score.get(lid, 0.0))
        text = _text_overlap(query_tokens, listing)
        cat = _category_bonus(listing, predicted_category)
        attrs = _attr_bonus(query_attrs, listing)
        # Hash/ORB mène ; vecteur affine le rang ; bonus texte plafonnés
        if vec_score > 0:
            final = visual_s * 0.58 + vec_score * 0.32 + text * 0.04 + min(0.06, cat + attrs)
        else:
            final = visual_s * 0.90 + text * 0.04 + min(0.06, cat + attrs)
        final = round(min(0.98, max(0.0, final)), 3)
        if final >= MIN_ACCEPT * 0.92:
            fused.append((final, listing))

    # Style Google/Wildberries : après un vrai match, proposer d’autres produits
    # de la même catégorie proches en vecteur (maillot → autres maillots).
    fused = _precision_filter(fused)
    if fused and fused[0][0] >= MIN_CLOSE:
        seed_listing = fused[0][1]
        seed_cat = getattr(seed_listing, "category_id", None)
        seed_tokens = _tokenize(getattr(seed_listing, "title", "") or "")
        seed_attrs = _parse_attrs(getattr(seed_listing, "attributes", None))
        if seed_cat is not None:
            peers: list[tuple[float, Any]] = []
            for listing, _keys in candidates:
                lid = getattr(listing, "id", None)
                if lid is None or lid in seen:
                    continue
                if getattr(listing, "category_id", None) != seed_cat:
                    continue
                title_tokens = _tokenize(getattr(listing, "title", "") or "")
                token_hit = bool(seed_tokens & title_tokens)
                attr_hit = _attr_bonus(seed_attrs, listing) >= 0.05
                # Mot en commun OU attribut fort (marque/couleur)
                if not token_hit and not attr_hit:
                    continue
                vec_score = float(vec_map_score.get(lid, 0.0))
                if vec_score < MIN_CATEGORY_PEER_VEC:
                    continue
                peer = round(
                    min(
                        fused[0][0] - 0.05,
                        0.52 + (vec_score - MIN_CATEGORY_PEER_VEC) * 1.35 + (0.04 if token_hit else 0),
                    ),
                    3,
                )
                if peer >= 0.52:
                    peers.append((peer, listing))
            peers.sort(key=lambda x: x[0], reverse=True)
            for peer, listing in peers[:12]:
                lid = getattr(listing, "id", None)
                seen.add(lid)
                fused.append((peer, listing))
            fused.sort(key=lambda x: x[0], reverse=True)
            fused = fused[:FINAL_TOP_K]

    return fused
