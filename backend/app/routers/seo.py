"""Pages publiques SEO professionnelles : produits, catégories, sitemaps, feed Merchant."""

from __future__ import annotations

import html
import json
from datetime import datetime, timedelta, timezone
from xml.sax.saxutils import escape as xml_escape

from fastapi import APIRouter, Depends, HTTPException, Query, Request
from fastapi.responses import HTMLResponse, RedirectResponse, Response
from sqlalchemy import func, select
from sqlalchemy.orm import Session, selectinload

from app.db import get_db
from app.models import Category, Listing, ListingStatus, User, UserRole
from app.services.seo_catalog import (
    attr_str,
    availability,
    category_slug,
    format_price_cdf,
    google_product_category,
    map_condition,
    merchant_price,
    parse_attributes,
    slugify,
    truncate,
)
from app.services.storage import public_url
from app.settings import settings

router = APIRouter(tags=["seo"])

_BRAND = "SombaTeka"
_NAVY = "#0D1B4B"
_GOLD = "#FBBF24"


def _base_url() -> str:
    return (settings.public_base_url or "https://sombatekaonline.com").rstrip("/")


def _img_url(key: str | None) -> str | None:
    if not key:
        return None
    return public_url(key)


def _listing_path(listing_id: int, title: str) -> str:
    return f"/annonce/{listing_id}-{slugify(title)}"


def _listing_url(listing_id: int, title: str) -> str:
    return f"{_base_url()}{_listing_path(listing_id, title)}"


def _cat_url(cat: Category) -> str:
    return f"{_base_url()}/categorie/{category_slug(cat)}"


def _city_url(city: str) -> str:
    return f"{_base_url()}/ville/{slugify(city, 60)}"


def _active_cities(db: Session) -> list[tuple[str, int]]:
    rows = db.execute(
        select(Listing.city, func.count())
        .where(
            Listing.status == ListingStatus.active,
            Listing.deleted_at.is_(None),
            Listing.city.is_not(None),
            func.length(func.trim(Listing.city)) > 0,
        )
        .group_by(Listing.city)
        .order_by(func.count().desc())
    ).all()
    return [(str(c), int(n)) for c, n in rows if c]


def _org_jsonld() -> dict:
    base = _base_url()
    return {
        "@context": "https://schema.org",
        "@type": "Organization",
        "name": _BRAND,
        "url": base,
        "logo": f"{base}/icons/Icon-512.png",
        "image": f"{base}/assets/og-image.png",
        "sameAs": [],
        "email": "support@sombatekaonline.com",
        "areaServed": [
            {"@type": "Country", "name": "Democratic Republic of the Congo"},
            {"@type": "City", "name": "Kinshasa"},
        ],
        "description": "Marketplace premium de la République Démocratique du Congo",
        "geo": {"@type": "GeoCoordinates", "latitude": -4.3276, "longitude": 15.3136},
    }


def _website_jsonld() -> dict:
    base = _base_url()
    return {
        "@context": "https://schema.org",
        "@type": "WebSite",
        "name": _BRAND,
        "url": base,
        "inLanguage": "fr-CD",
        "potentialAction": {
            "@type": "SearchAction",
            "target": {
                "@type": "EntryPoint",
                "urlTemplate": f"{base}/?q={{search_term_string}}",
            },
            "query-input": "required name=search_term_string",
        },
    }


def _css() -> str:
    return f"""
@import url('https://fonts.googleapis.com/css2?family=Plus+Jakarta+Sans:wght@500;600;700;800&display=swap');
:root {{ --navy:{_NAVY}; --navy-deep:#07102e; --gold:{_GOLD}; --ink:#0f172a; --muted:#64748b; --line:rgba(13,27,75,.1); --bg:#eef1f8; }}
* {{ box-sizing:border-box; }}
body {{ margin:0; font-family:"Plus Jakarta Sans",system-ui,sans-serif; color:var(--ink); background:
  radial-gradient(1000px 420px at 8% -8%, rgba(59,130,246,.12), transparent 55%),
  linear-gradient(180deg,#e8ecf6 0%,#f7f8fc 40%,#eef1f8 100%); line-height:1.55; -webkit-font-smoothing:antialiased; }}
a {{ color:var(--navy); }}
.top {{ background:linear-gradient(180deg,rgba(6,13,36,.98),rgba(13,27,75,.96)); color:#fff; border-bottom:1px solid rgba(251,191,36,.18); box-shadow:0 10px 40px rgba(0,0,0,.28); position:sticky; top:0; z-index:40; }}
.top-inner {{ max-width:1120px; margin:0 auto; padding:14px 20px; display:flex; align-items:center; justify-content:space-between; gap:16px; }}
.brand {{ display:inline-flex; align-items:center; gap:.7rem; text-decoration:none; color:#fff; font-weight:800; font-size:1.25rem; letter-spacing:-.03em; }}
.brand img {{ width:40px; height:40px; display:block; filter:drop-shadow(0 4px 12px rgba(251,191,36,.25)); }}
.brand span {{ color:#fff; }}
.nav a {{ color:rgba(255,255,255,.88); text-decoration:none; margin-left:14px; font-size:.9rem; font-weight:600; }}
.nav a:hover {{ color:var(--gold); }}
.nav .cta {{ display:inline-flex; margin-left:16px; padding:.5rem 1rem; border-radius:999px; background:linear-gradient(135deg,#fcd34d,var(--gold)); color:var(--navy-deep) !important; font-weight:800; }}
.wrap {{ max-width:1120px; margin:0 auto; padding:28px 20px 48px; }}
.crumbs {{ font-size:.85rem; color:var(--muted); margin-bottom:18px; }}
.crumbs a {{ color:var(--muted); text-decoration:none; }}
.crumbs a:hover {{ color:var(--navy); }}
.grid {{ display:grid; grid-template-columns:1.2fr .8fr; gap:28px; }}
@media (max-width:840px) {{ .grid {{ grid-template-columns:1fr; }} }}
.gallery img {{ width:100%; border-radius:14px; display:block; background:#fff; border:1px solid var(--line); }}
.thumbs {{ display:grid; grid-template-columns:repeat(auto-fill,minmax(72px,1fr)); gap:8px; margin-top:10px; }}
.thumbs img {{ aspect-ratio:1; object-fit:cover; border-radius:10px; border:1px solid var(--line); }}
h1 {{ font-size:clamp(1.7rem,3.5vw,2.45rem); line-height:1.12; margin:0 0 12px; font-weight:800; letter-spacing:-.03em; color:var(--navy); }}
.price {{ font-size:1.65rem; font-weight:800; color:var(--navy); margin:0 0 10px; }}
.meta {{ font-size:.92rem; color:var(--muted); margin:0 0 8px; }}
.badge {{ display:inline-block; font-size:.72rem; font-weight:800; letter-spacing:.04em; text-transform:uppercase; background:#ecfdf5; color:#047857; padding:4px 10px; border-radius:999px; margin-right:8px; }}
.badge.warn {{ background:#fff7ed; color:#c2410c; }}
.panel {{ background:#fff; border:1px solid var(--line); padding:22px; border-radius:16px; box-shadow:0 12px 36px rgba(13,27,75,.06); }}
.btn {{ display:inline-block; font-weight:800; background:var(--navy); color:#fff !important; text-decoration:none; padding:14px 22px; border-radius:999px; }}
.btn.alt {{ background:#fff; color:var(--navy) !important; border:2px solid var(--navy); }}
.desc {{ white-space:pre-wrap; font-size:1.02rem; color:#334155; }}
.section-title {{ font-size:1rem; font-weight:800; margin:40px 0 16px; letter-spacing:.08em; text-transform:uppercase; color:var(--navy); }}
.cards {{ display:grid; grid-template-columns:repeat(auto-fill,minmax(200px,1fr)); gap:16px; }}
.card {{ background:#fff; border:1px solid var(--line); border-radius:16px; overflow:hidden; text-decoration:none; color:inherit; display:block; transition:transform .15s, box-shadow .15s; box-shadow:0 8px 24px rgba(13,27,75,.05); }}
.card:hover {{ transform:translateY(-2px); box-shadow:0 16px 40px rgba(13,27,75,.1); }}
.card-media {{ position:relative; overflow:hidden; }}
.card-media img {{ width:100%; aspect-ratio:1; object-fit:cover; background:#e2e8f0; display:block; transition:transform .35s ease; }}
.card:hover .card-media img {{ transform:scale(1.05); }}
.card-price {{ position:absolute; left:10px; bottom:10px; padding:5px 12px; border-radius:999px; background:rgba(13,27,75,.88); backdrop-filter:blur(6px); -webkit-backdrop-filter:blur(6px); color:#fff; font-weight:800; font-size:.82rem; box-shadow:0 4px 14px rgba(0,0,0,.25); }}
.card .body {{ padding:14px; }}
.card .t {{ font-weight:700; font-size:.92rem; margin:0; display:-webkit-box; -webkit-line-clamp:2; line-clamp:2; -webkit-box-orient:vertical; overflow:hidden; min-height:2.6em; line-height:1.3; }}
.card .p {{ font-weight:800; color:var(--navy); margin:0; font-size:.95rem; }}
.hero-cat {{ padding:12px 0 8px; }}
.hero-cat p {{ color:var(--muted); max-width:52ch; }}
.pager {{ display:flex; gap:12px; margin-top:28px; }}
.apps-band {{ margin:36px 20px 0; max-width:1120px; margin-left:auto; margin-right:auto; padding:22px 22px; border-radius:18px; background:linear-gradient(145deg,var(--navy-deep),var(--navy) 55%,#152a6e); color:#fff; border:1px solid rgba(251,191,36,.22); display:grid; grid-template-columns:1.3fr .7fr; gap:18px; align-items:center; }}
@media (max-width:720px) {{ .apps-band {{ grid-template-columns:1fr; margin:28px 16px 0; }} }}
.apps-band h2 {{ margin:0 0 8px; font-size:1.2rem; font-weight:800; letter-spacing:-.02em; }}
.apps-band p {{ margin:0; color:rgba(255,255,255,.8); font-size:.95rem; }}
.store-badges {{ display:flex; gap:14px; flex-wrap:wrap; align-items:center; }}
.store-badge-link {{ display:inline-block; border-radius:10px; transition:transform .18s,filter .18s; }}
.store-badge-link:hover {{ transform:translateY(-2px); filter:brightness(1.1); }}
.store-badge-link img {{ display:block; height:44px; width:auto; }}
.store-badge-soon {{ position:relative; display:inline-block; }}
.store-badge-soon img {{ display:block; height:44px; width:auto; opacity:.8; }}
.store-badge-tag {{ position:absolute; top:-9px; right:-9px; padding:2px 9px; border-radius:999px; background:var(--gold); color:var(--navy-deep); font-size:.62rem; font-weight:800; letter-spacing:.08em; text-transform:uppercase; box-shadow:0 2px 10px rgba(0,0,0,.4); }}
/* Footer — strictement identique au site vitrine (.site-footer) */
.footer {{ margin-top:0; background:var(--bg-signature); color:rgba(255,255,255,.78); border-top:1px solid rgba(251,191,36,.22); padding:3.5rem 20px 1.75rem; }}
.footer-inner {{ max-width:1120px; margin:0 auto 2.25rem; display:grid; grid-template-columns:1.3fr 1fr 1fr; gap:2rem; }}
@media (max-width:800px) {{ .footer-inner {{ grid-template-columns:1fr; }} }}
.footer-brand {{ display:flex; gap:1rem; align-items:flex-start; }}
.footer-brand img {{ width:56px; height:56px; flex-shrink:0; filter:drop-shadow(0 8px 20px rgba(251,191,36,.25)); }}
.footer-brand strong {{ display:block; color:#fff; font-size:1.35rem; font-weight:800; letter-spacing:-0.03em; margin-bottom:0.35rem; }}
.footer-brand p {{ margin:0; font-size:.95rem; line-height:1.55; color:rgba(255,255,255,.7); max-width:28ch; }}
.footer h3 {{ margin:0 0 .85rem; font-size:.75rem; font-weight:800; letter-spacing:.14em; text-transform:uppercase; color:var(--gold); }}
.footer a {{ color:rgba(255,255,255,.82); text-decoration:none; font-weight:600; font-size:.92rem; display:block; margin-bottom:.55rem; }}
.footer a:hover {{ color:#fde68a; }}
.footer-bottom {{ max-width:1120px; margin:0 auto; padding-top:1.35rem; border-top:1px solid rgba(255,255,255,.1); display:flex; flex-wrap:wrap; justify-content:space-between; gap:.75rem; font-size:.85rem; color:rgba(255,255,255,.55); }}
"""


def _shell(title: str, description: str, canonical: str, body: str, json_lds: list[dict], extra_head: str = "") -> str:
    base = html.escape(_base_url())
    scripts = "\n".join(
        f'<script type="application/ld+json">{json.dumps(j, ensure_ascii=False)}</script>' for j in json_lds
    )
    return f"""<!DOCTYPE html>
<html lang="fr-CD">
<head>
  <meta charset="UTF-8" />
  <meta name="viewport" content="width=device-width, initial-scale=1" />
  <title>{html.escape(title)}</title>
  <meta name="description" content="{html.escape(description)}" />
  <meta name="robots" content="index, follow, max-image-preview:large, max-snippet:-1" />
  <meta name="theme-color" content="{_NAVY}" />
  <link rel="canonical" href="{html.escape(canonical)}" />
  <link rel="alternate" hreflang="fr-CD" href="{html.escape(canonical)}" />
  <link rel="alternate" hreflang="x-default" href="{html.escape(canonical)}" />
  <link rel="icon" type="image/png" href="{base}/icons/Icon-192.png" />
  {extra_head}
  {scripts}
  <style>{_css()}</style>
</head>
<body>
  <header class="top">
    <div class="top-inner">
      <a class="brand" href="{base}/" aria-label="{_BRAND}">
        <img src="{base}/assets/logo-mark.svg" width="40" height="40" alt="Logo {_BRAND}" />
        <span>{_BRAND}</span>
      </a>
      <nav class="nav" aria-label="Navigation">
        <a href="{base}/catalogue">Catalogue</a>
        <a href="{base}/about">À propos</a>
        <a class="cta" href="{base}/">Ouvrir l'app web</a>
      </nav>
    </div>
  </header>
  {body}
  <section class="apps-band" aria-label="Applications mobiles">
    <div>
      <h2>Disponible sur Android — iOS bientôt</h2>
      <p>L’app SombaTeka est publiée sur Google Play. La version iPhone arrive bientôt sur l’App Store. L’app web reste disponible sur sombatekaonline.com.</p>
    </div>
    <div class="store-badges">
      <a class="store-badge-link" href="https://play.google.com/store/apps/details?id=com.sombateka.st" target="_blank" rel="noopener" aria-label="Télécharger SombaTeka sur Google Play">
        <img src="{base}/assets/stores/google-play-badge-fr.png" alt="Disponible sur Google Play" />
      </a>
      <div class="store-badge-soon" role="img" aria-label="Bientôt sur l’App Store">
        <img src="{base}/assets/stores/app-store-badge-fr.svg" alt="Bientôt sur l’App Store" />
        <span class="store-badge-tag">Bientôt</span>
      </div>
    </div>
  </section>
  <footer class="footer">
    <div class="footer-inner">
      <div class="footer-brand">
        <img src="{base}/assets/logo-mark.svg" width="52" height="52" alt="Logo {_BRAND}" />
        <div>
          <strong>{_BRAND}</strong>
          <p>Marketplace premium de la République Démocratique du Congo.</p>
        </div>
      </div>
      <div>
        <h3>Explorer</h3>
        <a href="{base}/">App web</a>
        <a href="{base}/catalogue">Catalogue</a>
        <a href="{base}/marketplace-rdc">Marketplace RDC</a>
        <a href="{base}/kinshasa">Kinshasa</a>
        <a href="{base}/about">À propos</a>
        <a href="mailto:support@sombatekaonline.com">Support</a>
      </div>
      <div>
        <h3>Légal</h3>
        <a href="{base}/privacy">Confidentialité</a>
        <a href="{base}/terms">CGU</a>
        <a href="{base}/account-deletion">Suppression de compte</a>
      </div>
    </div>
    <div class="footer-bottom">
      <span>© 2026 {_BRAND} — République Démocratique du Congo</span>
      <span>Conçu et développé par devalpha1</span>
    </div>
  </footer>
</body>
</html>"""


def _active_listing_stmt():
    return select(Listing).where(
        Listing.status == ListingStatus.active,
        Listing.deleted_at.is_(None),
    )


def _load_listing(db: Session, listing_id: int) -> Listing | None:
    return db.scalar(
        _active_listing_stmt()
        .options(selectinload(Listing.images), selectinload(Listing.category))
        .where(Listing.id == listing_id)
    )


def _related(db: Session, listing: Listing, limit: int = 8) -> list[Listing]:
    stmt = (
        _active_listing_stmt()
        .options(selectinload(Listing.images))
        .where(Listing.id != listing.id)
        .order_by(Listing.updated_at.desc())
        .limit(limit)
    )
    if listing.category_id:
        stmt = stmt.where(Listing.category_id == listing.category_id)
    return list(db.scalars(stmt).all())


def _card_html(listing: Listing) -> str:
    imgs = sorted(listing.images, key=lambda i: i.id)
    img = _img_url(imgs[0].key) if imgs else f"{_base_url()}/icons/Icon-512.png"
    url = _listing_url(listing.id, listing.title)
    return f"""
    <a class="card" href="{html.escape(url)}">
      <div class="card-media">
        <img src="{html.escape(img or '')}" alt="{html.escape(listing.title)}" loading="lazy" width="400" height="400" />
        <span class="card-price">{html.escape(format_price_cdf(listing.price_cdf))}</span>
      </div>
      <div class="body">
        <p class="t">{html.escape(listing.title)}</p>
      </div>
    </a>"""


@router.get("/annonce/{listing_ref}", response_class=HTMLResponse)
def public_listing_page(listing_ref: str, request: Request, db: Session = Depends(get_db)) -> Response:
    raw_id = listing_ref.split("-", 1)[0]
    try:
        listing_id = int(raw_id)
    except ValueError as exc:
        raise HTTPException(status_code=404, detail="Annonce introuvable") from exc

    listing = _load_listing(db, listing_id)
    if not listing:
        raise HTTPException(status_code=404, detail="Annonce introuvable")

    canonical = _listing_url(listing.id, listing.title)
    # Canonical slug redirect (évite le contenu dupliqué)
    expected_path = _listing_path(listing.id, listing.title)
    if request.url.path.rstrip("/") != expected_path:
        return RedirectResponse(url=canonical, status_code=301)

    attrs = parse_attributes(listing.attributes)
    brand = attr_str(attrs, "brand") or _BRAND
    condition_label = attr_str(attrs, "condition")
    schema_cond, merch_cond = map_condition(condition_label)
    avail_schema, merch_avail, avail_label = availability(listing.status.value, attrs)
    province = attr_str(attrs, "province")
    color = attr_str(attrs, "color")
    material = attr_str(attrs, "material")

    images_sorted = sorted(listing.images, key=lambda i: i.id)
    all_imgs = [u for u in (_img_url(i.key) for i in images_sorted) if u]
    primary = all_imgs[0] if all_imgs else f"{_base_url()}/icons/Icon-512.png"

    seller = db.get(User, listing.seller_id)
    seller_name = "Vendeur SombaTeka"
    if seller:
        seller_name = (
            (seller.official_name or seller.display_name or seller.phone_e164 or seller_name).strip()
            or seller_name
        )

    cat = listing.category
    cat_name = cat.name if cat else None
    desc_raw = truncate(
        listing.description or f"{listing.title} à {listing.city} — {_BRAND} marketplace RDC",
        320,
    )
    page_title = f"{listing.title} — {format_price_cdf(listing.price_cdf)} | {_BRAND}"

    offer: dict = {
        "@type": "Offer",
        "url": canonical,
        "availability": avail_schema,
        "itemCondition": schema_cond,
        "priceCurrency": "CDF",
        "priceValidUntil": (datetime.now(timezone.utc) + timedelta(days=90)).strftime("%Y-%m-%d"),
        "seller": {
            "@type": (
                "Organization"
                if seller
                and (
                    seller.role == UserRole.official_seller
                    or seller.is_verified_seller
                )
                else "Person"
            ),
            "name": seller_name,
        },
    }
    if listing.price_cdf is not None and listing.price_cdf >= 0:
        offer["price"] = str(listing.price_cdf)

    product: dict = {
        "@context": "https://schema.org",
        "@type": "Product",
        "name": listing.title,
        "description": desc_raw,
        "sku": str(listing.id),
        "productID": str(listing.id),
        "mpn": str(listing.id),
        "url": canonical,
        "brand": {"@type": "Brand", "name": brand},
        "offers": offer,
        "image": all_imgs if len(all_imgs) > 1 else primary,
    }
    if cat_name:
        product["category"] = cat_name
    if color:
        product["color"] = color
    if material:
        product["material"] = material
    if listing.city:
        product["areaServed"] = {
            "@type": "Place",
            "name": listing.city,
            "address": {
                "@type": "PostalAddress",
                "addressLocality": listing.city,
                "addressRegion": province or listing.city,
                "addressCountry": "CD",
            },
        }

    crumbs = [
        {"@type": "ListItem", "position": 1, "name": "Accueil", "item": f"{_base_url()}/"},
        {"@type": "ListItem", "position": 2, "name": "Catalogue", "item": f"{_base_url()}/catalogue"},
    ]
    pos = 3
    if cat:
        crumbs.append(
            {"@type": "ListItem", "position": pos, "name": cat.name, "item": _cat_url(cat)}
        )
        pos += 1
    crumbs.append({"@type": "ListItem", "position": pos, "name": listing.title, "item": canonical})
    breadcrumb = {"@context": "https://schema.org", "@type": "BreadcrumbList", "itemListElement": crumbs}

    related = _related(db, listing)
    related_cards = "".join(_card_html(r) for r in related)
    item_list = None
    if related:
        item_list = {
            "@context": "https://schema.org",
            "@type": "ItemList",
            "name": f"Annonces similaires — {cat_name or _BRAND}",
            "itemListElement": [
                {
                    "@type": "ListItem",
                    "position": i + 1,
                    "url": _listing_url(r.id, r.title),
                    "name": r.title,
                }
                for i, r in enumerate(related)
            ],
        }

    og = f"""
  <meta property="og:type" content="product" />
  <meta property="og:site_name" content="{_BRAND}" />
  <meta property="og:title" content="{html.escape(listing.title)}" />
  <meta property="og:description" content="{html.escape(desc_raw)}" />
  <meta property="og:url" content="{html.escape(canonical)}" />
  <meta property="og:image" content="{html.escape(primary)}" />
  <meta property="og:locale" content="fr_CD" />
  <meta property="product:brand" content="{html.escape(brand)}" />
  <meta property="product:availability" content="{html.escape(merch_avail)}" />
  <meta property="product:condition" content="{html.escape(merch_cond)}" />
  <meta property="product:retailer_item_id" content="{listing.id}" />
  {"<meta property='product:price:amount' content='" + str(listing.price_cdf) + "' />" if listing.price_cdf is not None else ""}
  {"<meta property='product:price:currency' content='CDF' />" if listing.price_cdf is not None else ""}
  <meta name="twitter:card" content="summary_large_image" />
  <meta name="twitter:title" content="{html.escape(listing.title)}" />
  <meta name="twitter:description" content="{html.escape(desc_raw)}" />
  <meta name="twitter:image" content="{html.escape(primary)}" />
  <link rel="preload" as="image" href="{html.escape(primary)}" />
"""

    thumbs = ""
    for u in all_imgs[1:6]:
        thumbs += f'<img src="{html.escape(u)}" alt="{html.escape(listing.title)}" loading="lazy" width="120" height="120" />'

    place_bits = [listing.city]
    if province and province.lower() not in (listing.city or "").lower():
        place_bits.insert(0, province)
    place = " · ".join(p for p in place_bits if p)

    crumbs_html = (
        f'<a href="{html.escape(_base_url())}/">Accueil</a> › '
        f'<a href="{html.escape(_base_url())}/catalogue">Catalogue</a>'
    )
    if cat:
        crumbs_html += f' › <a href="{html.escape(_cat_url(cat))}">{html.escape(cat.name)}</a>'
    crumbs_html += f" › <span>{html.escape(listing.title)}</span>"

    badge_cls = "badge" if merch_avail == "in_stock" else "badge warn"
    cond_show = html.escape(condition_label or ("Neuf" if merch_cond == "new" else "Occasion"))

    json_lds = [_org_jsonld(), _website_jsonld(), product, breadcrumb]
    if item_list:
        json_lds.append(item_list)

    body = f"""
  <main class="wrap">
    <nav class="crumbs" aria-label="Fil d'Ariane">{crumbs_html}</nav>
    <div class="grid">
      <div class="gallery">
        <img src="{html.escape(primary)}" alt="{html.escape(listing.title)}" width="800" height="800" />
        {"<div class='thumbs'>" + thumbs + "</div>" if thumbs else ""}
      </div>
      <aside class="panel">
        <p class="meta"><span class="{badge_cls}">{html.escape(avail_label)}</span>{cond_show}</p>
        <h1>{html.escape(listing.title)}</h1>
        <p class="price">{html.escape(format_price_cdf(listing.price_cdf))}</p>
        <p class="meta">{html.escape(place)} · {html.escape(cat_name or "Marketplace")}</p>
        <p class="meta">Marque : <strong>{html.escape(brand)}</strong> · Vendeur : {html.escape(seller_name)}</p>
        <p style="margin:22px 0 10px;">
          <a class="btn" href="{html.escape(_base_url())}/?listing={listing.id}">Acheter sur {_BRAND}</a>
        </p>
        <p><a class="btn alt" href="{html.escape(_base_url())}/catalogue">Voir le catalogue</a></p>
      </aside>
    </div>
    <h2 class="section-title">Description</h2>
    <div class="panel desc">{html.escape(listing.description or desc_raw)}</div>
    {"<h2 class='section-title'>Aussi dans cette catégorie</h2><div class='cards'>" + related_cards + "</div>" if related_cards else ""}
  </main>
"""
    page = _shell(page_title, desc_raw, canonical, body, json_lds, extra_head=og)
    return HTMLResponse(content=page, headers={"Cache-Control": "public, max-age=300"})


@router.get("/categorie/{cat_ref}", response_class=HTMLResponse)
def category_page(
    cat_ref: str,
    db: Session = Depends(get_db),
    page: int = Query(1, ge=1, le=500),
) -> HTMLResponse:
    cats = list(db.scalars(select(Category).order_by(Category.name)).all())
    cat = None
    for c in cats:
        if category_slug(c) == cat_ref or str(c.id) == cat_ref:
            cat = c
            break
    if not cat:
        # Essai id-slug
        raw_id = cat_ref.split("-", 1)[0]
        if raw_id.isdigit():
            cat = db.get(Category, int(raw_id))
    if not cat:
        raise HTTPException(status_code=404, detail="Catégorie introuvable")

    per_page = 48
    offset = (page - 1) * per_page
    total = db.scalar(
        select(func.count())
        .select_from(Listing)
        .where(
            Listing.status == ListingStatus.active,
            Listing.deleted_at.is_(None),
            Listing.category_id == cat.id,
        )
    ) or 0
    rows = list(
        db.scalars(
            _active_listing_stmt()
            .options(selectinload(Listing.images))
            .where(Listing.category_id == cat.id)
            .order_by(Listing.updated_at.desc())
            .offset(offset)
            .limit(per_page)
        ).all()
    )

    canonical = _cat_url(cat)
    if page > 1:
        canonical = f"{canonical}?page={page}"
    desc = truncate(
        f"Achetez {cat.name} sur {_BRAND} — {total} annonces actives en RDC. Marketplace premium congo.",
        280,
    )
    title = f"{cat.name} — Annonces RDC | {_BRAND}"
    if page > 1:
        title = f"{cat.name} (page {page}) | {_BRAND}"

    cards = "".join(_card_html(r) for r in rows) or "<p>Aucune annonce active dans cette catégorie pour le moment.</p>"

    item_list = {
        "@context": "https://schema.org",
        "@type": "CollectionPage",
        "name": cat.name,
        "url": _cat_url(cat),
        "description": desc,
        "isPartOf": {"@type": "WebSite", "name": _BRAND, "url": _base_url()},
        "mainEntity": {
            "@type": "ItemList",
            "numberOfItems": total,
            "itemListElement": [
                {
                    "@type": "ListItem",
                    "position": offset + i + 1,
                    "url": _listing_url(r.id, r.title),
                    "name": r.title,
                }
                for i, r in enumerate(rows)
            ],
        },
    }
    breadcrumb = {
        "@context": "https://schema.org",
        "@type": "BreadcrumbList",
        "itemListElement": [
            {"@type": "ListItem", "position": 1, "name": "Accueil", "item": f"{_base_url()}/"},
            {"@type": "ListItem", "position": 2, "name": "Catalogue", "item": f"{_base_url()}/catalogue"},
            {"@type": "ListItem", "position": 3, "name": cat.name, "item": _cat_url(cat)},
        ],
    }

    pager = ""
    if page > 1:
        prev = f"{_cat_url(cat)}" if page == 2 else f"{_cat_url(cat)}?page={page - 1}"
        pager += f'<a class="btn alt" href="{html.escape(prev)}">← Précédent</a>'
    if offset + per_page < total:
        pager += f'<a class="btn" href="{html.escape(_cat_url(cat))}?page={page + 1}">Suivant →</a>'

    other_cats = "".join(
        f'<a class="card" href="{html.escape(_cat_url(c))}"><div class="body"><p class="t">{html.escape(c.name)}</p></div></a>'
        for c in cats
        if c.id != cat.id
    )

    body = f"""
  <main class="wrap">
    <nav class="crumbs"><a href="{html.escape(_base_url())}/">Accueil</a> › <a href="{html.escape(_base_url())}/catalogue">Catalogue</a> › <span>{html.escape(cat.name)}</span></nav>
    <div class="hero-cat">
      <h1>{html.escape(cat.name)}</h1>
      <p>{html.escape(desc)}</p>
      <p class="meta">{total} produit{"s" if total != 1 else ""}</p>
    </div>
    <div class="cards">{cards}</div>
    {"<div class='pager'>" + pager + "</div>" if pager else ""}
    <h2 class="section-title">Autres catégories</h2>
    <div class="cards">{other_cats}</div>
  </main>
"""
    og = f"""
  <meta property="og:type" content="website" />
  <meta property="og:title" content="{html.escape(title)}" />
  <meta property="og:description" content="{html.escape(desc)}" />
  <meta property="og:url" content="{html.escape(canonical)}" />
  <meta property="og:site_name" content="{_BRAND}" />
  <meta property="og:locale" content="fr_CD" />
"""
    page_html = _shell(title, desc, canonical, body, [_org_jsonld(), _website_jsonld(), item_list, breadcrumb], og)
    return HTMLResponse(content=page_html, headers={"Cache-Control": "public, max-age=300"})


@router.get("/ville/{city_slug}", response_class=HTMLResponse)
def city_page(
    city_slug: str,
    db: Session = Depends(get_db),
    page: int = Query(1, ge=1, le=500),
) -> HTMLResponse:
    cities = _active_cities(db)
    city = next((c for c, _ in cities if slugify(c, 60) == city_slug), None)
    if not city:
        raise HTTPException(status_code=404, detail="Ville introuvable")

    per_page = 48
    offset = (page - 1) * per_page
    total = db.scalar(
        select(func.count())
        .select_from(Listing)
        .where(
            Listing.status == ListingStatus.active,
            Listing.deleted_at.is_(None),
            Listing.city == city,
        )
    ) or 0
    rows = list(
        db.scalars(
            _active_listing_stmt()
            .options(selectinload(Listing.images))
            .where(Listing.city == city)
            .order_by(Listing.updated_at.desc())
            .offset(offset)
            .limit(per_page)
        ).all()
    )

    canonical = _city_url(city)
    if page > 1:
        canonical = f"{canonical}?page={page}"
    desc = truncate(
        f"{total} annonces actives à {city} — achetez et vendez localement sur {_BRAND}, le marketplace premium de la RDC.",
        280,
    )
    title = f"Annonces à {city} — RDC | {_BRAND}" if page == 1 else f"Annonces à {city} (page {page}) | {_BRAND}"

    cards = "".join(_card_html(r) for r in rows)

    item_list = {
        "@context": "https://schema.org",
        "@type": "CollectionPage",
        "name": f"Annonces à {city}",
        "url": _city_url(city),
        "description": desc,
        "about": {"@type": "City", "name": city},
        "isPartOf": {"@type": "WebSite", "name": _BRAND, "url": _base_url()},
        "mainEntity": {
            "@type": "ItemList",
            "numberOfItems": total,
            "itemListElement": [
                {
                    "@type": "ListItem",
                    "position": offset + i + 1,
                    "url": _listing_url(r.id, r.title),
                    "name": r.title,
                }
                for i, r in enumerate(rows)
            ],
        },
    }
    breadcrumb = {
        "@context": "https://schema.org",
        "@type": "BreadcrumbList",
        "itemListElement": [
            {"@type": "ListItem", "position": 1, "name": "Accueil", "item": f"{_base_url()}/"},
            {"@type": "ListItem", "position": 2, "name": "Catalogue", "item": f"{_base_url()}/catalogue"},
            {"@type": "ListItem", "position": 3, "name": city, "item": _city_url(city)},
        ],
    }

    pager = ""
    if page > 1:
        prev = _city_url(city) if page == 2 else f"{_city_url(city)}?page={page - 1}"
        pager += f'<a class="btn alt" href="{html.escape(prev)}">← Précédent</a>'
    if offset + per_page < total:
        pager += f'<a class="btn" href="{html.escape(_city_url(city))}?page={page + 1}">Suivant →</a>'

    other_cities = "".join(
        f'<a class="card" href="{html.escape(_city_url(c))}"><div class="body"><p class="t">{html.escape(c)}</p></div></a>'
        for c, _ in cities
        if c != city
    )

    body = f"""
  <main class="wrap">
    <nav class="crumbs"><a href="{html.escape(_base_url())}/">Accueil</a> › <a href="{html.escape(_base_url())}/catalogue">Catalogue</a> › <span>{html.escape(city)}</span></nav>
    <div class="hero-cat">
      <h1>Annonces à {html.escape(city)}</h1>
      <p>{html.escape(desc)}</p>
      <p class="meta">{total} produit{"s" if total != 1 else ""}</p>
    </div>
    <div class="cards">{cards}</div>
    {"<div class='pager'>" + pager + "</div>" if pager else ""}
    {"<h2 class='section-title'>Autres villes</h2><div class='cards'>" + other_cities + "</div>" if other_cities else ""}
  </main>
"""
    og = f"""
  <meta property="og:type" content="website" />
  <meta property="og:title" content="{html.escape(title)}" />
  <meta property="og:description" content="{html.escape(desc)}" />
  <meta property="og:url" content="{html.escape(canonical)}" />
  <meta property="og:site_name" content="{_BRAND}" />
  <meta property="og:locale" content="fr_CD" />
"""
    return HTMLResponse(
        content=_shell(title, desc, canonical, body, [_org_jsonld(), _website_jsonld(), item_list, breadcrumb], og),
        headers={"Cache-Control": "public, max-age=300"},
    )


@router.get("/catalogue", response_class=HTMLResponse)
def catalogue_page(
    db: Session = Depends(get_db),
    page: int = Query(1, ge=1, le=500),
) -> HTMLResponse:
    per_page = 48
    offset = (page - 1) * per_page
    total = db.scalar(
        select(func.count())
        .select_from(Listing)
        .where(Listing.status == ListingStatus.active, Listing.deleted_at.is_(None))
    ) or 0
    rows = list(
        db.scalars(
            _active_listing_stmt()
            .options(selectinload(Listing.images))
            .order_by(Listing.updated_at.desc())
            .offset(offset)
            .limit(per_page)
        ).all()
    )
    cats = list(db.scalars(select(Category).order_by(Category.name)).all())
    cities = _active_cities(db)

    canonical = f"{_base_url()}/catalogue" + (f"?page={page}" if page > 1 else "")
    desc = truncate(
        f"Catalogue {_BRAND} — {total} annonces actives en RDC. Mode, électronique, maison et plus.",
        280,
    )
    title = f"Catalogue produits RDC | {_BRAND}" if page == 1 else f"Catalogue (page {page}) | {_BRAND}"

    cat_links = "".join(
        f'<a class="card" href="{html.escape(_cat_url(c))}"><div class="body"><p class="t">{html.escape(c.name)}</p></div></a>'
        for c in cats
    )
    city_links = "".join(
        f'<a class="card" href="{html.escape(_city_url(c))}"><div class="body"><p class="t">{html.escape(c)}</p></div></a>'
        for c, _ in cities
    )
    cards = "".join(_card_html(r) for r in rows)

    item_list = {
        "@context": "https://schema.org",
        "@type": "CollectionPage",
        "name": f"Catalogue {_BRAND}",
        "url": f"{_base_url()}/catalogue",
        "mainEntity": {
            "@type": "ItemList",
            "numberOfItems": total,
            "itemListElement": [
                {
                    "@type": "ListItem",
                    "position": offset + i + 1,
                    "url": _listing_url(r.id, r.title),
                    "name": r.title,
                }
                for i, r in enumerate(rows)
            ],
        },
    }

    pager = ""
    if page > 1:
        prev = f"{_base_url()}/catalogue" if page == 2 else f"{_base_url()}/catalogue?page={page - 1}"
        pager += f'<a class="btn alt" href="{html.escape(prev)}">← Précédent</a>'
    if offset + per_page < total:
        pager += f'<a class="btn" href="{html.escape(_base_url())}/catalogue?page={page + 1}">Suivant →</a>'

    body = f"""
  <main class="wrap">
    <nav class="crumbs"><a href="{html.escape(_base_url())}/">Accueil</a> › <span>Catalogue</span></nav>
    <div class="hero-cat">
      <h1>Catalogue {_BRAND}</h1>
      <p>{html.escape(desc)}</p>
    </div>
    <h2 class="section-title">Catégories</h2>
    <div class="cards">{cat_links}</div>
    {"<h2 class='section-title'>Villes</h2><div class='cards'>" + city_links + "</div>" if city_links else ""}
    <h2 class="section-title">Dernières annonces</h2>
    <div class="cards">{cards}</div>
    {"<div class='pager'>" + pager + "</div>" if pager else ""}
  </main>
"""
    og = f"""
  <meta property="og:type" content="website" />
  <meta property="og:title" content="{html.escape(title)}" />
  <meta property="og:description" content="{html.escape(desc)}" />
  <meta property="og:url" content="{html.escape(canonical)}" />
  <meta property="og:locale" content="fr_CD" />
"""
    return HTMLResponse(
        content=_shell(title, desc, canonical, body, [_org_jsonld(), _website_jsonld(), item_list], og),
        headers={"Cache-Control": "public, max-age=300"},
    )


def _sitemap_url_entry(loc: str, lastmod: datetime | None = None, priority: str = "0.8", images: list[str] | None = None) -> str:
    parts = [f"<url><loc>{xml_escape(loc)}</loc>"]
    if lastmod:
        lm = lastmod.astimezone(timezone.utc) if lastmod.tzinfo else lastmod.replace(tzinfo=timezone.utc)
        parts.append(f"<lastmod>{lm.strftime('%Y-%m-%d')}</lastmod>")
    parts.append(f"<changefreq>daily</changefreq><priority>{priority}</priority>")
    for img in images or []:
        parts.append(
            f"<image:image><image:loc>{xml_escape(img)}</image:loc></image:image>"
        )
    parts.append("</url>")
    return "".join(parts)


@router.api_route("/sitemap-products.xml", methods=["GET", "HEAD"])
def sitemap_products(db: Session = Depends(get_db)) -> Response:
    rows = list(
        db.scalars(
            _active_listing_stmt()
            .options(selectinload(Listing.images))
            .order_by(Listing.updated_at.desc())
            .limit(5000)
        ).all()
    )
    parts = [
        '<?xml version="1.0" encoding="UTF-8"?>',
        '<urlset xmlns="http://www.sitemaps.org/schemas/sitemap/0.9" '
        'xmlns:image="http://www.google.com/schemas/sitemap-image/1.1">',
    ]
    for listing in rows:
        imgs = [_img_url(i.key) for i in sorted(listing.images, key=lambda x: x.id)[:8]]
        imgs = [u for u in imgs if u]
        parts.append(
            _sitemap_url_entry(
                _listing_url(listing.id, listing.title),
                listing.updated_at or listing.created_at,
                "0.9",
                imgs,
            )
        )
    parts.append("</urlset>")
    return Response(
        content="\n".join(parts),
        media_type="application/xml",
        headers={"Cache-Control": "public, max-age=120"},
    )


@router.api_route("/sitemap-categories.xml", methods=["GET", "HEAD"])
def sitemap_categories(db: Session = Depends(get_db)) -> Response:
    # Uniquement les catégories avec au moins une annonce active
    # (les pages vides nuisent au crawl budget et restent non indexées)
    cats = list(
        db.scalars(
            select(Category)
            .join(Listing, Listing.category_id == Category.id)
            .where(
                Listing.status == ListingStatus.active,
                Listing.deleted_at.is_(None),
            )
            .distinct()
            .order_by(Category.name)
        ).all()
    )
    parts = [
        '<?xml version="1.0" encoding="UTF-8"?>',
        '<urlset xmlns="http://www.sitemaps.org/schemas/sitemap/0.9">',
        _sitemap_url_entry(f"{_base_url()}/catalogue", priority="0.95"),
    ]
    for cat in cats:
        parts.append(_sitemap_url_entry(_cat_url(cat), priority="0.85"))
    parts.append("</urlset>")
    return Response(
        content="\n".join(parts),
        media_type="application/xml",
        headers={"Cache-Control": "public, max-age=120"},
    )


@router.api_route("/sitemap-cities.xml", methods=["GET", "HEAD"])
def sitemap_cities(db: Session = Depends(get_db)) -> Response:
    parts = [
        '<?xml version="1.0" encoding="UTF-8"?>',
        '<urlset xmlns="http://www.sitemaps.org/schemas/sitemap/0.9">',
    ]
    for city, _ in _active_cities(db):
        parts.append(_sitemap_url_entry(_city_url(city), priority="0.85"))
    parts.append("</urlset>")
    return Response(
        content="\n".join(parts),
        media_type="application/xml",
        headers={"Cache-Control": "public, max-age=120"},
    )


@router.api_route("/sitemap-index.xml", methods=["GET", "HEAD"])
def sitemap_index() -> Response:
    base = _base_url()
    body = f"""<?xml version="1.0" encoding="UTF-8"?>
<sitemapindex xmlns="http://www.sitemaps.org/schemas/sitemap/0.9">
  <sitemap><loc>{xml_escape(base)}/sitemap.xml</loc></sitemap>
  <sitemap><loc>{xml_escape(base)}/sitemap-products.xml</loc></sitemap>
  <sitemap><loc>{xml_escape(base)}/sitemap-categories.xml</loc></sitemap>
  <sitemap><loc>{xml_escape(base)}/sitemap-cities.xml</loc></sitemap>
</sitemapindex>
"""
    return Response(content=body, media_type="application/xml", headers={"Cache-Control": "public, max-age=120"})


@router.api_route("/feeds/google-merchant.xml", methods=["GET", "HEAD"])
def google_merchant_feed(db: Session = Depends(get_db)) -> Response:
    """Flux XML Google Merchant Center (listings Shopping gratuits)."""
    from app.services.google_merchant import build_rss, load_active_products

    products = load_active_products(db)
    body = build_rss(products)
    return Response(
        content=body,
        media_type="application/xml; charset=utf-8",
        headers={"Cache-Control": "public, max-age=300"},
    )


@router.api_route("/feeds/google-merchant.tsv", methods=["GET", "HEAD"])
def google_merchant_feed_tsv(db: Session = Depends(get_db)) -> Response:
    """Flux TSV Google Merchant Center (alternative recommandée)."""
    from app.services.google_merchant import build_tsv, load_active_products

    products = load_active_products(db)
    body = build_tsv(products)
    return Response(
        content=body,
        media_type="text/tab-separated-values; charset=utf-8",
        headers={"Cache-Control": "public, max-age=300"},
    )
