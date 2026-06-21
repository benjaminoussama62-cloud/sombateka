"""Recherche visuelle équilibrée (Google Lens / Wildberries).

Même type de produit + couleurs proches, sans exiger la même photo,
et sans afficher des articles visuellement sans rapport.
"""

from __future__ import annotations

import io
import logging
from dataclasses import dataclass

import imagehash
from PIL import Image, ImageOps

from app.services.storage import UPLOAD_DIR

logger = logging.getLogger(__name__)

HASH_SIZE = 12
MAX_RESULTS = 18
MAX_CANDIDATES = 600
MAX_IMAGES_PER_LISTING = 6

# Seuils équilibrés : produits similaires visibles, hors-sujet filtré
MIN_SHAPE = 0.70
MIN_EDGE = 0.68
MIN_COLOR = 0.52
MIN_COMBINED = 0.68
MIN_BEST_MATCH = 0.66
RELATIVE_GAP = 0.10


@dataclass
class ImageFingerprints:
    phash: imagehash.ImageHash
    dhash: imagehash.ImageHash
    whash: imagehash.ImageHash
    colorhash: imagehash.ImageHash
    histogram: tuple[float, ...]


def _open_rgb(data: bytes) -> Image.Image:
    img = Image.open(io.BytesIO(data))
    img = ImageOps.exif_transpose(img)
    return img.convert("RGB")


def _rgb_histogram(img: Image.Image, bins: int = 14) -> tuple[float, ...]:
    small = img.resize((180, 180), Image.Resampling.LANCZOS)
    pixels = list(small.getdata())
    n = bins * bins * bins
    hist = [0.0] * n
    step = 256 // bins
    for r, g, b in pixels:
        ri = min(bins - 1, r // step)
        gi = min(bins - 1, g // step)
        bi = min(bins - 1, b // step)
        idx = ri * bins * bins + gi * bins + bi
        hist[idx] += 1.0
    total = float(len(pixels)) or 1.0
    return tuple(v / total for v in hist)


def _center_crop(img: Image.Image, ratio: float = 0.82) -> Image.Image:
    """Focus produit (comme recadrage auto Lens / marketplaces)."""
    w, h = img.size
    nw, nh = int(w * ratio), int(h * ratio)
    left = (w - nw) // 2
    top = (h - nh) // 2
    return img.crop((left, top, left + nw, top + nh))


def fingerprints_from_bytes(data: bytes) -> ImageFingerprints:
    img = _open_rgb(data)
    img = _center_crop(img)
    img.thumbnail((512, 512), Image.Resampling.LANCZOS)
    return ImageFingerprints(
        phash=imagehash.phash(img, hash_size=HASH_SIZE),
        dhash=imagehash.dhash(img, hash_size=HASH_SIZE),
        whash=imagehash.whash(img, hash_size=HASH_SIZE),
        colorhash=imagehash.colorhash(img),
        histogram=_rgb_histogram(img),
    )


def _hash_similarity(a: imagehash.ImageHash, b: imagehash.ImageHash) -> float:
    max_bits = float(a.hash.size ** 2)
    dist = float(a - b)
    return max(0.0, 1.0 - dist / max_bits)


def _histogram_similarity(h1: tuple[float, ...], h2: tuple[float, ...]) -> float:
    if len(h1) != len(h2):
        return 0.0
    return round(sum(min(a, b) for a, b in zip(h1, h2)), 4)


def combined_similarity(query: ImageFingerprints, candidate: ImageFingerprints) -> float | None:
    shape = _hash_similarity(query.phash, candidate.phash)
    edge = _hash_similarity(query.dhash, candidate.dhash)
    wave = _hash_similarity(query.whash, candidate.whash)
    palette_hash = _hash_similarity(query.colorhash, candidate.colorhash)
    palette_hist = _histogram_similarity(query.histogram, candidate.histogram)
    color = palette_hash * 0.42 + palette_hist * 0.58
    structure = (shape + edge + wave) / 3.0

    # Sans rapport évident (ex. robe vs voiture)
    if color < 0.34 and structure < 0.52:
        return None
    if shape < 0.44 and edge < 0.44 and wave < 0.44 and color < 0.40:
        return None

    # Même fond blanc mais objet différent
    if color >= 0.62 and structure < 0.56:
        return None

    # Couleur ET silhouette doivent être crédibles (pas seulement l'un des deux)
    if color < MIN_COLOR or structure < 0.58:
        return None
    if shape < MIN_SHAPE - 0.08 and edge < MIN_EDGE - 0.08 and wave < MIN_EDGE - 0.08:
        return None

    score = shape * 0.28 + edge * 0.22 + wave * 0.10 + color * 0.40
    if score < MIN_COMBINED:
        return None

    strong_signals = sum(
        [
            shape >= MIN_SHAPE,
            edge >= MIN_EDGE,
            wave >= MIN_EDGE - 0.02,
            color >= MIN_COLOR + 0.06,
        ]
    )
    if strong_signals < 2:
        return None

    return round(min(score, 0.93), 3)


def _filter_relative(scored: list[tuple[float, object]]) -> list[tuple[float, object]]:
    if not scored:
        return []
    scored.sort(key=lambda x: x[0], reverse=True)
    best = scored[0][0]
    if best < MIN_BEST_MATCH:
        return []
    floor = max(MIN_COMBINED, best - RELATIVE_GAP)
    return [(s, item) for s, item in scored if s >= floor][:MAX_RESULTS]


def load_local_image_bytes(storage_key: str) -> bytes | None:
    path = UPLOAD_DIR.joinpath(*storage_key.split("/"))
    if not path.is_file():
        return None
    try:
        return path.read_bytes()
    except OSError as e:
        logger.debug("Cannot read image %s: %s", storage_key, e)
        return None


def fingerprints_from_key(storage_key: str) -> ImageFingerprints | None:
    raw = load_local_image_bytes(storage_key)
    if not raw:
        return None
    try:
        return fingerprints_from_bytes(raw)
    except Exception as e:
        logger.debug("Fingerprint failed for %s: %s", storage_key, e)
        return None


def best_similarity(query_fp: ImageFingerprints, image_keys: list[str]) -> float | None:
    best: float | None = None
    for key in image_keys[:MAX_IMAGES_PER_LISTING]:
        cand_fp = fingerprints_from_key(key)
        if not cand_fp:
            continue
        sim = combined_similarity(query_fp, cand_fp)
        if sim is not None and (best is None or sim > best):
            best = sim
    return best


def best_image_similarity_keys(query_key: str, candidate_keys: list[str]) -> float | None:
    q_raw = load_local_image_bytes(query_key)
    if not q_raw:
        return None
    try:
        q = fingerprints_from_bytes(q_raw)
    except Exception:
        return None
    return best_similarity(q, candidate_keys)


def find_similar_listings(
    query_bytes: bytes,
    candidates: list[tuple[object, list[str]]],
) -> list[tuple[float, object]]:
    try:
        query_fp = fingerprints_from_bytes(query_bytes)
    except Exception as e:
        logger.warning("Query image invalid: %s", e)
        return []

    scored: list[tuple[float, object]] = []
    for listing, keys in candidates[:MAX_CANDIDATES]:
        if not keys:
            continue
        sim = best_similarity(query_fp, keys)
        if sim is not None:
            scored.append((sim, listing))

    return _filter_relative(scored)
