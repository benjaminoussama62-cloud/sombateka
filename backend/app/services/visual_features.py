"""Extraction de features visuelles — slots couleur / structure / hash (style Lens)."""

from __future__ import annotations

import io
import logging
from dataclasses import dataclass

import imagehash
import numpy as np
from PIL import Image, ImageEnhance, ImageOps

logger = logging.getLogger(__name__)

try:
    import cv2

    HAS_CV = True
except ImportError:
    HAS_CV = False
    cv2 = None  # type: ignore

VECTOR_DIM = 384
COLOR_DIM = 128
STRUCT_DIM = 192
HASH_DIM = 64
HASH_SIZE = 16
FEATURE_VERSION = 3
FEATURE_VERSION_TAG = "v3"


@dataclass
class VisualFeaturePack:
    vector: list[float]
    dominant_colors: list[str]
    focus: tuple[int, int, int, int] | None


def _open_rgb(data: bytes) -> Image.Image:
    img = Image.open(io.BytesIO(data))
    img = ImageOps.exif_transpose(img)
    return img.convert("RGB")


def _enhance(img: Image.Image) -> Image.Image:
    img = ImageEnhance.Contrast(img).enhance(1.08)
    img = ImageEnhance.Sharpness(img).enhance(1.10)
    return img


def _pil_to_bgr(img: Image.Image) -> np.ndarray:
    rgb = np.asarray(img.convert("RGB"))
    return cv2.cvtColor(rgb, cv2.COLOR_RGB2BGR)


def _focus_bbox(bgr: np.ndarray) -> tuple[int, int, int, int] | None:
    if not HAS_CV:
        return None
    try:
        gray = cv2.cvtColor(bgr, cv2.COLOR_BGR2GRAY)
        gray = cv2.GaussianBlur(gray, (5, 5), 0)
        # Salience légère : contours + centre
        gx = cv2.Sobel(gray, cv2.CV_32F, 1, 0, ksize=3)
        gy = cv2.Sobel(gray, cv2.CV_32F, 0, 1, ksize=3)
        mag = cv2.magnitude(gx, gy)
        h, w = gray.shape
        if h < 8 or w < 8:
            return None
        yy, xx = np.mgrid[0:h, 0:w]
        cy0, cx0 = h / 2.0, w / 2.0
        center_w = np.exp(-(((yy - cy0) / (h * 0.45)) ** 2 + ((xx - cx0) / (w * 0.45)) ** 2))
        score = mag * (0.55 + 0.45 * center_w.astype(np.float32))
        cy, cx = np.unravel_index(int(np.argmax(score)), score.shape)
        side = int(min(h, w) * 0.78)
        side = max(side, min(h, w) // 3)
        x1 = max(0, cx - side // 2)
        y1 = max(0, cy - side // 2)
        x2 = min(w, x1 + side)
        y2 = min(h, y1 + side)
        if x2 - x1 < 24 or y2 - y1 < 24:
            return None
        return (int(x1), int(y1), int(x2 - x1), int(y2 - y1))
    except Exception as e:
        logger.debug("focus_bbox failed: %s", e)
        return None


def _crop_pil(img: Image.Image, box: tuple[int, int, int, int] | None) -> Image.Image:
    if box is None:
        return img
    x, y, w, h = box
    return img.crop((x, y, x + w, y + h))


def _key_crops(img: Image.Image, focus: tuple[int, int, int, int] | None) -> list[Image.Image]:
    """Crops utiles sans explosion de dims — full + focus + centres."""
    w, h = img.size
    crops: list[Image.Image] = [img]
    if focus:
        crops.append(_crop_pil(img, focus))
    for r in (0.82, 0.64, 0.48):
        nw, nh = int(w * r), int(h * r)
        left = (w - nw) // 2
        top = (h - nh) // 2
        crops.append(img.crop((left, top, left + nw, top + nh)))
    return crops[:5]


def _hsv_hist(img: Image.Image, bins: int = 5) -> np.ndarray:
    if not HAS_CV:
        small = img.resize((80, 80), Image.Resampling.BILINEAR)
        arr = np.asarray(small, dtype=np.float32) / 255.0
        return arr.reshape(-1)[:125]
    bgr = _pil_to_bgr(img.resize((160, 160), Image.Resampling.BILINEAR))
    hsv = cv2.cvtColor(bgr, cv2.COLOR_BGR2HSV)
    hist = cv2.calcHist([hsv], [0, 1, 2], None, [bins, bins, bins], [0, 180, 0, 256, 0, 256])
    hist = hist.flatten().astype(np.float32)
    total = float(hist.sum()) or 1.0
    return hist / total


def _gray_grid(img: Image.Image, size: int = 12) -> np.ndarray:
    gray = np.asarray(img.convert("L").resize((size, size), Image.Resampling.BILINEAR), dtype=np.float32)
    gray /= 255.0
    return gray.flatten()


def _edge_grid(img: Image.Image, grid: int = 6) -> np.ndarray:
    if not HAS_CV:
        return np.zeros(grid * grid, dtype=np.float32)
    bgr = _pil_to_bgr(img.resize((256, 256), Image.Resampling.BILINEAR))
    gray = cv2.cvtColor(bgr, cv2.COLOR_BGR2GRAY)
    clahe = cv2.createCLAHE(clipLimit=2.0, tileGridSize=(8, 8))
    gray = clahe.apply(gray)
    gx = cv2.Sobel(gray, cv2.CV_32F, 1, 0, ksize=3)
    gy = cv2.Sobel(gray, cv2.CV_32F, 0, 1, ksize=3)
    mag = cv2.magnitude(gx, gy)
    h, w = mag.shape
    gh, gw = h // grid, w // grid
    out = np.zeros(grid * grid, dtype=np.float32)
    idx = 0
    for gy_i in range(grid):
        for gx_i in range(grid):
            patch = mag[gy_i * gh : (gy_i + 1) * gh, gx_i * gw : (gx_i + 1) * gw]
            out[idx] = float(patch.mean()) if patch.size else 0.0
            idx += 1
    mx = float(out.max()) or 1.0
    return out / mx


def _hash_bits(img: Image.Image) -> np.ndarray:
    small = img.copy()
    small.thumbnail((256, 256), Image.Resampling.LANCZOS)
    ph = imagehash.phash(small, hash_size=HASH_SIZE)
    dh = imagehash.dhash(small, hash_size=HASH_SIZE)
    wh = imagehash.whash(small, hash_size=min(HASH_SIZE, 16))
    bits = np.concatenate([ph.hash.flatten(), dh.hash.flatten(), wh.hash.flatten()]).astype(np.float32)
    return bits


def _fit_dim(vec: np.ndarray, dim: int) -> np.ndarray:
    v = vec.astype(np.float32).flatten()
    if v.size == dim:
        return v
    if v.size > dim:
        # average-pool vers dim (conserve l’info multi-crop)
        chunk = v.size / dim
        out = np.zeros(dim, dtype=np.float32)
        for i in range(dim):
            a = int(i * chunk)
            b = int((i + 1) * chunk)
            out[i] = float(v[a:b].mean()) if b > a else 0.0
        return out
    return np.pad(v, (0, dim - v.size))


def _l2(vec: np.ndarray) -> np.ndarray:
    n = float(np.linalg.norm(vec)) or 1.0
    return (vec / n).astype(np.float32)


def _mean_stack(parts: list[np.ndarray]) -> np.ndarray:
    if not parts:
        return np.zeros(1, dtype=np.float32)
    # Aligner sur la plus petite taille commune
    m = min(p.size for p in parts)
    stacked = np.stack([p.flatten()[:m] for p in parts], axis=0)
    return stacked.mean(axis=0).astype(np.float32)


def _dominant_colors(img: Image.Image, k: int = 4) -> list[str]:
    if not HAS_CV:
        return []
    try:
        bgr = _pil_to_bgr(img.resize((120, 120), Image.Resampling.BILINEAR))
        pixels = bgr.reshape(-1, 3).astype(np.float32)
        if len(pixels) < k:
            return []
        criteria = (cv2.TERM_CRITERIA_EPS + cv2.TERM_CRITERIA_MAX_ITER, 12, 1.0)
        _, labels, centers = cv2.kmeans(pixels, k, None, criteria, 3, cv2.KMEANS_PP_CENTERS)
        counts = np.bincount(labels.flatten(), minlength=k)
        order = np.argsort(-counts)
        names: list[str] = []
        for i in order[:k]:
            b, g, r = (float(centers[i][0]), float(centers[i][1]), float(centers[i][2]))
            names.append(f"{int(r)}:{int(g)}:{int(b)}")
        return names
    except Exception:
        return []


def _pack_slots(color: np.ndarray, struct: np.ndarray, hash_vec: np.ndarray) -> list[float]:
    """Chaque slot est L2-normalisé — la structure (192d) pèse plus que la couleur."""
    packed = np.concatenate(
        [
            _l2(_fit_dim(color, COLOR_DIM)),
            _l2(_fit_dim(struct, STRUCT_DIM)),
            _l2(_fit_dim(hash_vec, HASH_DIM)),
        ]
    )
    assert packed.size == VECTOR_DIM
    return [float(round(float(x), 6)) for x in packed]


def split_slots(vec: list[float] | np.ndarray) -> tuple[np.ndarray, np.ndarray, np.ndarray]:
    v = np.asarray(vec, dtype=np.float32).flatten()
    if v.size < VECTOR_DIM:
        v = np.pad(v, (0, VECTOR_DIM - v.size))
    color = v[:COLOR_DIM]
    struct = v[COLOR_DIM : COLOR_DIM + STRUCT_DIM]
    hash_v = v[COLOR_DIM + STRUCT_DIM : VECTOR_DIM]
    return color, struct, hash_v


def slot_cosine(a: np.ndarray, b: np.ndarray) -> float:
    denom = float(np.linalg.norm(a) * np.linalg.norm(b)) or 1.0
    return float(max(0.0, min(1.0, float(np.dot(a, b)) / denom)))


def fused_similarity(a: list[float], b: list[float]) -> float:
    """Score Google-like : structure d’abord, couleur ensuite, hash en confirmation."""
    if not a or not b or len(a) != len(b):
        return 0.0
    ca, sa, ha = split_slots(a)
    cb, sb, hb = split_slots(b)
    color_s = slot_cosine(ca, cb)
    struct_s = slot_cosine(sa, sb)
    hash_s = slot_cosine(ha, hb)
    # Couleur seule sans structure → rejet / score faible
    if struct_s < 0.38 and hash_s < 0.42:
        return round(struct_s * 0.55 + hash_s * 0.35 + color_s * 0.10, 4)
    score = struct_s * 0.50 + hash_s * 0.30 + color_s * 0.20
    # Bonus alignement structure+hash (même objet)
    if struct_s >= 0.55 and hash_s >= 0.50:
        score = min(0.98, score + 0.06)
    return round(float(score), 4)


def extract_from_bytes(data: bytes) -> VisualFeaturePack:
    img = _enhance(_open_rgb(data))
    bgr = _pil_to_bgr(img) if HAS_CV else None
    focus = _focus_bbox(bgr) if bgr is not None else None
    crops = _key_crops(img, focus)

    color_parts = [_hsv_hist(c) for c in crops]
    struct_parts = [np.concatenate([_gray_grid(c, 12), _edge_grid(c, 6)]) for c in crops]
    hash_parts = [_hash_bits(c) for c in crops[:2]]  # full + focus

    color = _mean_stack(color_parts)
    struct = _mean_stack(struct_parts)
    hash_vec = _mean_stack(hash_parts)

    colors = _dominant_colors(crops[0])
    return VisualFeaturePack(
        vector=_pack_slots(color, struct, hash_vec),
        dominant_colors=colors,
        focus=focus,
    )


def cosine_similarity(a: list[float], b: list[float]) -> float:
    """Compat : utilise le score fusionné slots (plus discriminant que cosine global)."""
    return fused_similarity(a, b)
