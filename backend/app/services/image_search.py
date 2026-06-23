"""Recherche visuelle SombaTeka — empreintes perceptuelles + correspondance ORB (IA légère)."""

from __future__ import annotations

import io
import logging
from dataclasses import dataclass
from functools import lru_cache

import imagehash
from PIL import Image, ImageEnhance, ImageOps

from app.services.storage import UPLOAD_DIR, load_image_bytes

logger = logging.getLogger(__name__)

try:
    import cv2
    import numpy as np

    HAS_CV = True
except ImportError:
    HAS_CV = False
    cv2 = None  # type: ignore
    np = None  # type: ignore

HASH_SIZE = 12
MAX_RESULTS = 30
MAX_CANDIDATES = 1200
MAX_IMAGES_PER_LISTING = 12

MIN_SHAPE = 0.48
MIN_EDGE = 0.46
MIN_COLOR = 0.35
MIN_COMBINED = 0.42
MIN_BEST_MATCH = 0.32
RELATIVE_GAP = 0.22
EXACT_PHASH = 0.88

QUERY_CROP_RATIOS = (1.0, 0.92, 0.82, 0.72, 0.62)


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


def _enhance_query(img: Image.Image) -> Image.Image:
    """Légère amélioration pour photos mobile floues/sombres."""
    img = ImageEnhance.Contrast(img).enhance(1.08)
    img = ImageEnhance.Sharpness(img).enhance(1.12)
    return img


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
    if ratio >= 0.999:
        return img
    w, h = img.size
    nw, nh = int(w * ratio), int(h * ratio)
    left = (w - nw) // 2
    top = (h - nh) // 2
    return img.crop((left, top, left + nw, top + nh))


def fingerprints_from_image(img: Image.Image, *, crop_ratio: float = 0.82) -> ImageFingerprints:
    cropped = _center_crop(img, crop_ratio)
    cropped.thumbnail((512, 512), Image.Resampling.LANCZOS)
    return ImageFingerprints(
        phash=imagehash.phash(cropped, hash_size=HASH_SIZE),
        dhash=imagehash.dhash(cropped, hash_size=HASH_SIZE),
        whash=imagehash.whash(cropped, hash_size=HASH_SIZE),
        colorhash=imagehash.colorhash(cropped),
        histogram=_rgb_histogram(cropped),
    )


def fingerprints_from_bytes(data: bytes) -> ImageFingerprints:
    img = _enhance_query(_open_rgb(data))
    return fingerprints_from_image(img, crop_ratio=0.82)


def query_fingerprints_multi(data: bytes) -> list[ImageFingerprints]:
    img = _enhance_query(_open_rgb(data))
    fps: list[ImageFingerprints] = []
    for ratio in QUERY_CROP_RATIOS:
        try:
            fps.append(fingerprints_from_image(img, crop_ratio=ratio))
        except Exception as e:
            logger.debug("Query crop %.2f failed: %s", ratio, e)
    return fps or [fingerprints_from_bytes(data)]


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
    color = palette_hash * 0.40 + palette_hist * 0.60
    structure = (shape + edge + wave) / 3.0

    if color < 0.26 and structure < 0.44:
        return None
    if shape < 0.34 and edge < 0.34 and wave < 0.34 and color < 0.32:
        return None
    if color >= 0.68 and structure < 0.46:
        return None
    if color < MIN_COLOR and structure < 0.48:
        return None
    if structure < 0.48 and color < MIN_COLOR + 0.04:
        return None
    if shape < MIN_SHAPE - 0.12 and edge < MIN_EDGE - 0.12 and wave < MIN_EDGE - 0.12:
        return None

    score = shape * 0.22 + edge * 0.18 + wave * 0.10 + color * 0.50
    if score < MIN_COMBINED:
        return None

    strong_signals = sum(
        [
            shape >= MIN_SHAPE,
            edge >= MIN_EDGE,
            wave >= MIN_EDGE - 0.04,
            color >= MIN_COLOR,
        ]
    )
    if strong_signals < 1 and score < MIN_COMBINED + 0.05:
        return None

    return round(min(score, 0.95), 3)


def _best_query_match(query_fps: list[ImageFingerprints], candidate_fp: ImageFingerprints) -> float | None:
    best: float | None = None
    for q in query_fps:
        sim = combined_similarity(q, candidate_fp)
        if sim is not None and (best is None or sim > best):
            best = sim
    return best


@lru_cache(maxsize=512)
def _orb_descriptors_cached(storage_key: str) -> tuple[bytes, bytes] | None:
    if not HAS_CV:
        return None
    raw = load_image_bytes(storage_key)
    if not raw:
        return None
    try:
        arr = np.frombuffer(raw, dtype=np.uint8)
        img = cv2.imdecode(arr, cv2.IMREAD_COLOR)
        if img is None:
            return None
        gray = cv2.cvtColor(img, cv2.COLOR_BGR2GRAY)
        gray = cv2.resize(gray, (480, 480), interpolation=cv2.INTER_AREA)
        orb = cv2.ORB_create(nfeatures=600)
        _, des = orb.detectAndCompute(gray, None)
        if des is None or len(des) < 8:
            return None
        return (des.tobytes(), np.array(des.shape, dtype=np.int32).tobytes())
    except Exception as e:
        logger.debug("ORB cache failed %s: %s", storage_key, e)
        return None


def _orb_from_bytes(data: bytes) -> np.ndarray | None:
    if not HAS_CV:
        return None
    try:
        arr = np.frombuffer(data, dtype=np.uint8)
        img = cv2.imdecode(arr, cv2.IMREAD_COLOR)
        if img is None:
            return None
        gray = cv2.cvtColor(img, cv2.COLOR_BGR2GRAY)
        gray = cv2.resize(gray, (480, 480), interpolation=cv2.INTER_AREA)
        orb = cv2.ORB_create(nfeatures=600)
        _, des = orb.detectAndCompute(gray, None)
        return des
    except Exception:
        return None


def _orb_similarity(query_des: np.ndarray | None, key: str) -> float | None:
    if query_des is None or not HAS_CV:
        return None
    cached = _orb_descriptors_cached(key)
    if not cached:
        return None
    des_bytes, shape_bytes = cached
    shape = np.frombuffer(shape_bytes, dtype=np.int32)
    cand_des = np.frombuffer(des_bytes, dtype=np.uint8).reshape(int(shape[0]), int(shape[1]))
    if len(cand_des) < 8:
        return None
    bf = cv2.BFMatcher(cv2.NORM_HAMMING, crossCheck=False)
    matches = bf.knnMatch(query_des, cand_des, k=2)
    good = 0
    for pair in matches:
        if len(pair) < 2:
            continue
        m, n = pair
        if m.distance < 0.78 * n.distance:
            good += 1
    denom = max(len(query_des), len(cand_des), 1)
    ratio = good / denom
    if ratio < 0.04:
        return None
    return round(min(0.92, ratio * 2.8), 3)


def _filter_relative(scored: list[tuple[float, object]]) -> list[tuple[float, object]]:
    if not scored:
        return []
    scored.sort(key=lambda x: x[0], reverse=True)
    best = scored[0][0]
    if best < MIN_BEST_MATCH:
        return []
    if best >= EXACT_PHASH:
        return scored[: min(12, MAX_RESULTS)]
    floor = max(MIN_COMBINED - 0.08, best - RELATIVE_GAP)
    return [(s, item) for s, item in scored if s >= floor][:MAX_RESULTS]


def load_local_image_bytes(storage_key: str) -> bytes | None:
    return load_image_bytes(storage_key)


@lru_cache(maxsize=2048)
def _fingerprints_from_key_cached(storage_key: str) -> ImageFingerprints | None:
    raw = load_image_bytes(storage_key)
    if not raw:
        return None
    try:
        return fingerprints_from_bytes(raw)
    except Exception as e:
        logger.debug("Fingerprint failed for %s: %s", storage_key, e)
        return None


def fingerprints_from_key(storage_key: str) -> ImageFingerprints | None:
    return _fingerprints_from_key_cached(storage_key)


def best_similarity(
    query_fps: list[ImageFingerprints],
    image_keys: list[str],
    *,
    query_orb: np.ndarray | None = None,
) -> float | None:
    best: float | None = None
    for key in image_keys[:MAX_IMAGES_PER_LISTING]:
        cand_fp = fingerprints_from_key(key)
        hash_score: float | None = None
        if cand_fp:
            hash_score = _best_query_match(query_fps, cand_fp)
        orb_score = _orb_similarity(query_orb, key) if query_orb is not None else None

        if hash_score is None and orb_score is None:
            continue

        if hash_score is not None and orb_score is not None:
            fused = hash_score * 0.62 + orb_score * 0.38
        elif hash_score is not None:
            fused = hash_score
        else:
            fused = (orb_score or 0) * 0.88

        if best is None or fused > best:
            best = round(fused, 3)
    return best


def best_image_similarity_keys(query_key: str, candidate_keys: list[str]) -> float | None:
    q_raw = load_image_bytes(query_key)
    if not q_raw:
        return None
    try:
        q_fps = query_fingerprints_multi(q_raw)
        q_orb = _orb_from_bytes(q_raw)
    except Exception:
        return None
    return best_similarity(q_fps, candidate_keys, query_orb=q_orb)


def find_similar_listings(
    query_bytes: bytes,
    candidates: list[tuple[object, list[str]]],
) -> list[tuple[float, object]]:
    try:
        query_fps = query_fingerprints_multi(query_bytes)
        query_orb = _orb_from_bytes(query_bytes)
    except Exception as e:
        logger.warning("Query image invalid: %s", e)
        return []

    scored: list[tuple[float, object]] = []
    tried = 0
    for listing, keys in candidates[:MAX_CANDIDATES]:
        if not keys:
            continue
        tried += 1
        sim = best_similarity(query_fps, keys, query_orb=query_orb)
        if sim is not None:
            scored.append((sim, listing))

    if tried and not scored:
        logger.warning(
            "Image search: %d listings with images but 0 hash/ORB matches (check S3/URL load)",
            tried,
        )

    return _filter_relative(scored)
