"""Helpers SEO / Merchant Center — parsing annonces & schéma Product."""

from __future__ import annotations

import json
import re
from typing import Any

_SLUG_RE = re.compile(r"[^a-z0-9]+")

# États FR → schema.org / Google Merchant
_CONDITION_MAP: dict[str, tuple[str, str]] = {
    "neuf": ("https://schema.org/NewCondition", "new"),
    "new": ("https://schema.org/NewCondition", "new"),
    "très bon état": ("https://schema.org/UsedCondition", "used"),
    "tres bon etat": ("https://schema.org/UsedCondition", "used"),
    "bon état": ("https://schema.org/UsedCondition", "used"),
    "bon etat": ("https://schema.org/UsedCondition", "used"),
    "état correct": ("https://schema.org/UsedCondition", "used"),
    "etat correct": ("https://schema.org/UsedCondition", "used"),
    "occasion": ("https://schema.org/UsedCondition", "used"),
    "used": ("https://schema.org/UsedCondition", "used"),
    "reconditionné": ("https://schema.org/RefurbishedCondition", "refurbished"),
    "reconditionne": ("https://schema.org/RefurbishedCondition", "refurbished"),
}

# Approximation google_product_category (IDs numériques Google)
_GPC_HINTS: list[tuple[str, str]] = [
    ("chaussure", "187"),
    ("basket", "187"),
    ("sneaker", "187"),
    ("sandale", "187"),
    ("soulier", "187"),
    ("pantalon", "204"),
    ("jean", "204"),
    ("robe", "2271"),
    ("jupe", "1581"),
    ("chemise", "212"),
    ("veste", "203"),
    ("manteau", "203"),
    ("sport", "499979"),
    ("accessoire", "167"),
    ("sac", "3032"),
    ("bébé", "537"),
    ("bebe", "537"),
    ("enfant", "537"),
    ("mode", "166"),
    ("vêtement", "166"),
    ("vetement", "166"),
    ("téléphone", "267"),
    ("telephone", "267"),
    ("phone", "267"),
    ("électronique", "222"),
    ("electronique", "222"),
    ("voiture", "916"),
    ("auto", "916"),
    ("moto", "919"),
    ("immobilier", "1035"),
    ("maison", "1035"),
    ("meuble", "436"),
]


def slugify(text: str, max_len: int = 60) -> str:
    s = (text or "").strip().lower()
    for a, b in (
        ("àâä", "a"),
        ("éèêë", "e"),
        ("îï", "i"),
        ("ôö", "o"),
        ("ùûü", "u"),
        ("ç", "c"),
    ):
        for ch in a:
            s = s.replace(ch, b)
    s = _SLUG_RE.sub("-", s).strip("-")
    return (s[:max_len].rstrip("-") or "item")


def category_slug(cat) -> str:
    """Slug stable pour Category (colonne slug ou dérivé du nom)."""
    raw = (getattr(cat, "slug", None) or "").strip()
    if raw:
        return slugify(raw, 80)
    return slugify(getattr(cat, "name", "") or f"categorie-{getattr(cat, 'id', 0)}", 80)


def parse_attributes(raw: str | None) -> dict[str, Any]:
    if not raw or not str(raw).strip():
        return {}
    try:
        data = json.loads(raw)
        return data if isinstance(data, dict) else {}
    except Exception:
        return {}


def attr_str(attrs: dict[str, Any], *keys: str) -> str | None:
    for k in keys:
        v = attrs.get(k)
        if v is None:
            continue
        s = str(v).strip()
        if s:
            return s
    return None


def map_condition(label: str | None) -> tuple[str, str]:
    """Retourne (schema.org URL, merchant condition)."""
    if not label:
        return ("https://schema.org/UsedCondition", "used")
    key = label.strip().lower()
    if key in _CONDITION_MAP:
        return _CONDITION_MAP[key]
    if "neuf" in key:
        return ("https://schema.org/NewCondition", "new")
    if "recond" in key:
        return ("https://schema.org/RefurbishedCondition", "refurbished")
    return ("https://schema.org/UsedCondition", "used")


def stock_from_attrs(attrs: dict[str, Any]) -> int | None:
    variants = attrs.get("variants")
    if isinstance(variants, list) and variants:
        total = 0
        found = False
        for v in variants:
            if not isinstance(v, dict):
                continue
            if "stock" in v:
                found = True
                try:
                    total += max(0, int(v.get("stock") or 0))
                except (TypeError, ValueError):
                    pass
        if found:
            return total
    return None


def availability(listing_status: str, attrs: dict[str, Any]) -> tuple[str, str, str]:
    """
    Retourne (schema.org URL, merchant availability, label FR).
    """
    st = (listing_status or "").lower()
    if st in {"sold", "deleted", "hidden"}:
        return (
            "https://schema.org/SoldOut",
            "out_of_stock",
            "Indisponible",
        )
    stock = stock_from_attrs(attrs)
    if stock is not None and stock <= 0:
        return (
            "https://schema.org/OutOfStock",
            "out_of_stock",
            "Rupture de stock",
        )
    return (
        "https://schema.org/InStock",
        "in_stock",
        "En stock",
    )


def google_product_category(category_name: str | None) -> str | None:
    if not category_name:
        return None
    low = category_name.lower()
    for hint, gpc in _GPC_HINTS:
        if hint in low:
            return gpc
    return "166"  # Apparel & Accessories fallback for marketplace fashion


def format_price_cdf(price: int | None) -> str:
    if price is None:
        return "Prix sur demande"
    return f"{price:,}".replace(",", " ") + " CDF"


def merchant_price(price: int | None) -> str | None:
    if price is None or price < 0:
        return None
    return f"{price} CDF"


def truncate(text: str, n: int) -> str:
    t = re.sub(r"\s+", " ", (text or "").strip())
    if len(t) <= n:
        return t
    return t[: n - 1].rstrip() + "…"
