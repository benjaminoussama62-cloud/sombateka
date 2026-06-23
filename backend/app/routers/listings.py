import json
import os
import uuid
from datetime import datetime, timezone

from fastapi import APIRouter, Depends, File, HTTPException, Query, UploadFile
from sqlalchemy import desc, func, or_, select
from sqlalchemy.orm import Session, selectinload

from app.db import get_db
from app.deps import get_current_user
from app.idempotency import require_idempotency_key, save_idempotency_response
from app.constants import DEMO_SELLER_PHONE
from app.models import Category, Listing, ListingImage, ListingStatus, Message, Review, User, UserRole
from app.schemas import (
    ListingCreateRequest,
    ListingDetailPublic,
    ListingImagePublic,
    OfficialCatalogCreateRequest,
    OfficialCollectionCreateRequest,
)
from app.services.storage import UPLOAD_DIR, public_url, save_image

router = APIRouter(prefix="/listings", tags=["listings"])

UPLOAD_DIR.mkdir(parents=True, exist_ok=True)

from app.services.image_mime import normalize_image_content_type

_ALLOWED_IMAGE_TYPES = {"image/jpeg", "image/png", "image/webp"}


def _public_upload_url(key: str) -> str:
    return public_url(key)


def _attr_json_match(key: str, value: str):
    """Filtre sur attribut JSON stocké en texte (ex. "commune": "Gombe")."""
    val = value.strip()
    if not val:
        return None
    return or_(
        Listing.attributes.ilike(f'%"{key}": "{val}%'),
        Listing.attributes.ilike(f'%"{key.lower()}": "{val}%'),
    )


def _gender_key(label: str) -> str:
    l = label.strip().lower()
    if l in ("masculin", "homme"):
        return "masculin"
    if l in ("féminin", "feminin", "femme"):
        return "feminin"
    if l == "mixte":
        return "mixte"
    return "unisexe"


def _audience_key(label: str) -> str:
    l = label.strip().lower()
    if "bébé" in l or "bebe" in l:
        return "bebe"
    if "enfant" in l:
        return "enfant"
    return "adulte"


def _parse_catalog_variants(raw_variants: list[dict]) -> tuple[list[dict], list[int]]:
    variants: list[dict] = []
    prices: list[int] = []
    for raw in raw_variants:
        size = str(raw.get("size") or "").strip()
        price = int(raw.get("price_cdf") or 0)
        stock = int(raw.get("stock") or 0)
        if not size or price <= 0:
            continue
        entry: dict = {"size": size, "price_cdf": price, "stock": max(0, stock)}
        color = str(raw.get("color") or "").strip()
        if color:
            entry["color"] = color
        variants.append(entry)
        prices.append(price)
    return variants, prices


def _build_catalog_attrs(
    *,
    brand: str,
    gender: str,
    audience: str,
    variants: list[dict],
    condition: str | None = None,
    default_color: str | None = None,
    commune: str | None = None,
    quartier: str | None = None,
    province: str | None = None,
    avenue: str | None = None,
    numero: str | None = None,
    publication_id: str | None = None,
    publication_title: str | None = None,
    product_index: int | None = None,
) -> dict:
    sizes = [v["size"] for v in variants]
    colors = list({v["color"] for v in variants if v.get("color")})
    attrs: dict = {
        "catalog": True,
        "brand": brand.strip(),
        "gender": _gender_key(gender),
        "audience": _audience_key(audience),
        "variants": variants,
        "available_sizes": sizes,
        "available_colors": colors,
    }
    if condition:
        attrs["condition"] = condition.strip()
    if default_color:
        attrs["color"] = default_color.strip()
    if commune:
        attrs["commune"] = commune.strip()
    if quartier:
        attrs["quartier"] = quartier.strip()
    if province:
        attrs["province"] = province.strip()
    if avenue:
        attrs["avenue"] = avenue.strip()
    if numero:
        attrs["numero"] = numero.strip()
    if publication_id:
        attrs["publication_id"] = publication_id
    if publication_title:
        attrs["publication_title"] = publication_title
    if product_index is not None:
        attrs["product_index"] = product_index
    return attrs


@router.post("/")
def create_listing(
    payload: ListingCreateRequest,
    idem: tuple[str, User, Session] = Depends(require_idempotency_key),
) -> dict:
    idem_key, current_user, db = idem

    from app.services.moderation import assert_content_allowed

    title = payload.title.strip()
    description = payload.description.strip() if payload.description else None
    assert_content_allowed(title=title, description=description)

    if current_user.role == UserRole.official_seller and not payload.delivery_method:
        raise HTTPException(
            status_code=400,
            detail="Choisissez un mode de livraison : own_courier ou pickup_store",
        )

    listing = Listing(
        title=title,
        description=description,
        city=payload.city.strip(),
        price_cdf=payload.price_cdf,
        category_id=payload.category_id,
        attributes=payload.attributes,
        delivery_method=payload.delivery_method,
        status=ListingStatus.active,
        seller_id=current_user.id,
        updated_at=datetime.utcnow(),
    )
    db.add(listing)
    try:
        db.commit()
        db.refresh(listing)
        resp = {"id": listing.id}
        save_idempotency_response(
            db=db,
            user_id=current_user.id,
            key=idem_key,
            method="POST",
            path="/listings",
            status_code=200,
            response_body=resp,
        )
        return resp
    except Exception:
        db.rollback()
        raise


@router.post("/official-catalog")
def create_official_catalog(
    payload: OfficialCatalogCreateRequest,
    idem: tuple[str, User, Session] = Depends(require_idempotency_key),
) -> dict:
    """Publication catalogue officielle — plusieurs tailles / variantes (style Wildberries)."""
    idem_key, current_user, db = idem
    if current_user.role != UserRole.official_seller and not current_user.is_verified_seller:
        raise HTTPException(status_code=403, detail="Compte officiel requis")

    variants, prices = _parse_catalog_variants(payload.variants)
    if not variants:
        raise HTTPException(status_code=400, detail="Ajoutez au moins une variante (taille + prix)")

    from app.services.moderation import assert_content_allowed

    title = payload.title.strip()
    description = payload.description.strip() if payload.description else None
    assert_content_allowed(title=title, description=description)

    attrs = _build_catalog_attrs(
        brand=payload.brand,
        gender=payload.gender,
        audience=payload.audience,
        variants=variants,
        condition=payload.condition,
        default_color=payload.default_color,
        commune=payload.commune,
        quartier=payload.quartier,
        province=payload.province,
        avenue=payload.avenue,
        numero=payload.numero,
    )

    listing = Listing(
        title=title,
        description=description,
        city=payload.city.strip(),
        price_cdf=min(prices),
        category_id=payload.category_id,
        attributes=json.dumps(attrs, ensure_ascii=False),
        delivery_method=payload.delivery_method,
        status=ListingStatus.active,
        seller_id=current_user.id,
        updated_at=datetime.utcnow(),
    )
    db.add(listing)
    try:
        db.commit()
        db.refresh(listing)
        resp = {"id": listing.id, "variant_count": len(variants)}
        save_idempotency_response(
            db=db,
            user_id=current_user.id,
            key=idem_key,
            method="POST",
            path="/listings/official-catalog",
            status_code=200,
            response_body=resp,
        )
        return resp
    except Exception:
        db.rollback()
        raise


@router.post("/official-collection")
def create_official_collection(
    payload: OfficialCollectionCreateRequest,
    idem: tuple[str, User, Session] = Depends(require_idempotency_key),
) -> dict:
    """Publication multi-produits Wildberries — chaque produit devient une annonce au fil."""
    idem_key, current_user, db = idem
    if current_user.role != UserRole.official_seller and not current_user.is_verified_seller:
        raise HTTPException(status_code=403, detail="Compte officiel requis")

    from app.services.moderation import assert_content_allowed

    pub_title = payload.publication_title.strip()
    assert_content_allowed(title=pub_title, description=None)
    publication_id = str(uuid.uuid4())

    listing_ids: list[int] = []
    for idx, product in enumerate(payload.products):
        variants, prices = _parse_catalog_variants(product.variants)
        if not variants:
            raise HTTPException(
                status_code=400,
                detail=f"Produit « {product.title.strip()} » : ajoutez au moins une taille avec prix",
            )
        title = product.title.strip()
        description = product.description.strip() if product.description else None
        assert_content_allowed(title=title, description=description)

        attrs = _build_catalog_attrs(
            brand=payload.brand,
            gender=payload.gender,
            audience=payload.audience,
            variants=variants,
            condition=product.condition,
            default_color=product.default_color,
            commune=payload.commune,
            quartier=payload.quartier,
            province=payload.province,
            avenue=payload.avenue,
            numero=payload.numero,
            publication_id=publication_id,
            publication_title=pub_title,
            product_index=idx,
        )
        listing = Listing(
            title=title,
            description=description,
            city=payload.city.strip(),
            price_cdf=min(prices),
            category_id=payload.category_id,
            attributes=json.dumps(attrs, ensure_ascii=False),
            delivery_method=payload.delivery_method,
            status=ListingStatus.active,
            seller_id=current_user.id,
            updated_at=datetime.utcnow(),
        )
        db.add(listing)
        db.flush()
        listing_ids.append(listing.id)

    try:
        db.commit()
        resp = {
            "publication_id": publication_id,
            "publication_title": pub_title,
            "listing_ids": listing_ids,
            "product_count": len(listing_ids),
        }
        save_idempotency_response(
            db=db,
            user_id=current_user.id,
            key=idem_key,
            method="POST",
            path="/listings/official-collection",
            status_code=200,
            response_body=resp,
        )
        return resp
    except Exception:
        db.rollback()
        raise


@router.get("")
def list_listings(
    q: str | None = Query(default=None, max_length=80),
    city: str | None = Query(default=None, max_length=80),
    category_id: int | None = Query(default=None),
    min_price: float | None = Query(default=None),
    max_price: float | None = Query(default=None),
    is_official: bool | None = Query(default=None),
    size: str | None = Query(default=None, max_length=16),
    color: str | None = Query(default=None, max_length=40),
    condition: str | None = Query(default=None, max_length=40),
    brand: str | None = Query(default=None, max_length=80),
    gender: str | None = Query(default=None, max_length=20),
    audience: str | None = Query(default=None, max_length=20),
    commune: str | None = Query(default=None, max_length=80),
    quartier: str | None = Query(default=None, max_length=80),
    province: str | None = Query(default=None, max_length=80),
    min_rating: float | None = Query(default=None, ge=1, le=5),
    mix_promoted: bool = Query(default=False, description="Fil accueil : intercale les comptes officiels promus"),
    limit: int = Query(default=30, ge=1, le=100),
    offset: int = Query(default=0, ge=0, le=10000),
    db: Session = Depends(get_db),
) -> dict:
    primary_key = (
        select(ListingImage.key)
        .where(ListingImage.listing_id == Listing.id)
        .order_by(ListingImage.id.asc())
        .limit(1)
        .scalar_subquery()
    )

    stmt = (
        select(
            Listing.id,
            Listing.title,
            Listing.city,
            Listing.price_cdf,
            Listing.seller_id,
            Listing.created_at,
            Listing.category_id,
            Listing.attributes,
            primary_key.label("primary_image_key"),
            User.is_verified_seller,
            User.role
        )
        .join(User, Listing.seller_id == User.id)
        .where(Listing.status == ListingStatus.active)
        .where(User.phone_e164 != DEMO_SELLER_PHONE)
    )

    if city:
        stmt = stmt.where(Listing.city.ilike(f"%{city.strip()}%"))

    if commune:
        c = _attr_json_match("commune", commune)
        if c is not None:
            stmt = stmt.where(c)

    if quartier:
        qz = _attr_json_match("quartier", quartier)
        if qz is not None:
            stmt = stmt.where(qz)

    if province:
        p = province.strip()
        if p:
            stmt = stmt.where(
                or_(
                    Listing.attributes.ilike(f'%"province"%{p}%'),
                    Listing.city.ilike(f"%{p}%"),
                )
            )

    if category_id:
        stmt = stmt.where(Listing.category_id == category_id)

    if min_price is not None:
        stmt = stmt.where(Listing.price_cdf >= min_price)
    
    if max_price is not None:
        stmt = stmt.where(Listing.price_cdf <= max_price)

    if is_official is True:
        stmt = stmt.where(
            or_(
                User.is_verified_seller.is_(True),
                User.role == UserRole.official_seller,
            )
        )

    if q:
        qq = q.strip()
        if qq:
            stmt = stmt.where(or_(Listing.title.ilike(f"%{qq}%"), Listing.description.ilike(f"%{qq}%")))

    if size:
        sz = size.strip()
        if sz:
            stmt = stmt.where(Listing.attributes.ilike(f"%{sz}%"))

    if color:
        c = _attr_json_match("color", color)
        if c is not None:
            stmt = stmt.where(or_(c, Listing.attributes.ilike(f'%"available_colors"%{color.strip()}%')))

    if condition:
        cnd = _attr_json_match("condition", condition)
        if cnd is not None:
            stmt = stmt.where(cnd)

    if brand:
        br = _attr_json_match("brand", brand)
        if br is not None:
            stmt = stmt.where(br)

    if gender:
        g = _attr_json_match("gender", _gender_key(gender))
        if g is not None:
            stmt = stmt.where(g)

    if audience:
        a = _attr_json_match("audience", _audience_key(audience))
        if a is not None:
            stmt = stmt.where(a)

    if min_rating is not None and min_rating > 0:
        rating_subq = (
            select(
                Review.reviewee_id.label("uid"),
                func.avg(Review.rating).label("avg_rating"),
            )
            .group_by(Review.reviewee_id)
            .subquery()
        )
        stmt = stmt.join(rating_subq, User.id == rating_subq.c.uid)
        stmt = stmt.where(rating_subq.c.avg_rating >= min_rating)

    stmt = stmt.order_by(desc(Listing.created_at))
    fetch_limit = limit
    fetch_offset = offset
    if mix_promoted:
        fetch_limit = min(200, max(limit * 4, 80))
        fetch_offset = 0

    stmt = stmt.offset(fetch_offset).limit(fetch_limit)
    rows = db.execute(stmt).all()

    seller_ids = {r.seller_id for r in rows}
    rating_map: dict[int, float] = {}
    if seller_ids:
        rating_rows = db.execute(
            select(Review.reviewee_id, func.avg(Review.rating), func.count(Review.id)).where(
                Review.reviewee_id.in_(seller_ids)
            ).group_by(Review.reviewee_id)
        ).all()
        for uid, avg_r, _cnt in rating_rows:
            rating_map[int(uid)] = round(float(avg_r or 0), 1)

    cat_ids = {r.category_id for r in rows if r.category_id}
    cat_map: dict[int, str] = {}
    if cat_ids:
        for cat in db.scalars(select(Category).where(Category.id.in_(cat_ids))).all():
            cat_map[cat.id] = cat.name

    listing_ids = [r.id for r in rows]
    images_map: dict[int, list[str]] = {}
    if listing_ids:
        img_rows = db.execute(
            select(ListingImage.listing_id, ListingImage.key)
            .where(ListingImage.listing_id.in_(listing_ids))
            .order_by(ListingImage.listing_id.asc(), ListingImage.id.asc())
        ).all()
        for lid, key in img_rows:
            bucket = images_map.setdefault(int(lid), [])
            if len(bucket) < 12:
                bucket.append(_public_upload_url(key))

    items = [
        {
            "id": r.id,
            "title": r.title,
            "city": r.city,
            "price_cdf": r.price_cdf,
            "seller_id": r.seller_id,
            "created_at": r.created_at,
            "category_id": r.category_id,
            "category_name": cat_map.get(r.category_id) if r.category_id else None,
            "attributes": r.attributes,
            "is_official": bool(r.is_verified_seller) or r.role == UserRole.official_seller,
            "seller_rating": rating_map.get(r.seller_id, 0.0),
            "primary_image_url": (_public_upload_url(r.primary_image_key) if r.primary_image_key else None),
            "image_urls": images_map.get(r.id) or (
                [_public_upload_url(r.primary_image_key)] if r.primary_image_key else []
            ),
        }
        for r in rows
    ]

    if mix_promoted:
        from app.services.feed_mix import mix_promoted_feed

        items = mix_promoted_feed(items, limit=limit, offset=offset)

    return {"items": items}


@router.get("/mine")
def my_listings(
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
) -> dict:
    """Annonces du vendeur connecté (tous statuts)."""
    primary_key = (
        select(ListingImage.key)
        .where(ListingImage.listing_id == Listing.id)
        .order_by(ListingImage.id.asc())
        .limit(1)
        .scalar_subquery()
    )
    stmt = (
        select(
            Listing.id,
            Listing.title,
            Listing.city,
            Listing.price_cdf,
            Listing.status,
            Listing.category_id,
            Listing.attributes,
            Listing.created_at,
            Listing.updated_at,
            primary_key.label("primary_image_key"),
        )
        .where(Listing.seller_id == current_user.id)
        .order_by(desc(Listing.updated_at))
        .limit(200)
    )
    rows = db.execute(stmt).all()
    return {
        "items": [
            {
                "id": r.id,
                "title": r.title,
                "city": r.city,
                "price_cdf": r.price_cdf,
                "seller_id": current_user.id,
                "status": r.status.value if hasattr(r.status, "value") else str(r.status),
                "category_id": r.category_id,
                "attributes": r.attributes,
                "created_at": r.created_at,
                "updated_at": r.updated_at,
                "primary_image_url": (_public_upload_url(r.primary_image_key) if r.primary_image_key else None),
            }
            for r in rows
        ]
    }


@router.post("/search-by-image")
async def search_by_image(
    file: UploadFile = File(...),
    db: Session = Depends(get_db),
) -> dict:
    from app.services.image_search import find_similar_listings
    from app.services.storage import load_image_bytes

    data = await file.read()
    if len(data) < 50:
        raise HTTPException(status_code=400, detail="Image trop petite")

    stmt = (
        select(Listing)
        .join(User, Listing.seller_id == User.id)
        .options(selectinload(Listing.images))
        .where(Listing.status == ListingStatus.active)
        .where(User.phone_e164 != DEMO_SELLER_PHONE)
    )
    listings = db.scalars(stmt).all()

    candidates: list[tuple[Listing, list[str]]] = []
    loadable = 0
    for listing in listings:
        if not listing.images:
            continue
        keys = [img.key for img in sorted(listing.images, key=lambda i: i.id)]
        candidates.append((listing, keys))
        if keys and load_image_bytes(keys[0]):
            loadable += 1

    top = find_similar_listings(data, candidates)

    items = []
    for sim, listing in top:
        images_sorted = sorted(listing.images, key=lambda i: i.id)
        primary = _public_upload_url(images_sorted[0].key) if images_sorted else None
        cat = db.get(Category, listing.category_id) if listing.category_id else None
        items.append(
            {
                "id": listing.id,
                "title": listing.title,
                "price_cdf": listing.price_cdf,
                "city": listing.city,
                "primary_image_url": primary,
                "category_name": cat.name if cat else None,
                "attributes": listing.attributes,
                "similarity": sim,
            }
        )

    return {
        "items": items,
        "message": None
        if items
        else "Aucun article similaire pour cette photo. Cadrez un seul produit, lumière naturelle, fond neutre — SombaTeka IA analyse forme et couleurs.",
    }


@router.get("/{listing_id}/similar")
def similar_listings(listing_id: int, db: Session = Depends(get_db)) -> dict:
    from app.services.listing_similarity import find_similar_to_listing

    source = db.scalar(
        select(Listing)
        .options(selectinload(Listing.images))
        .where(Listing.id == listing_id, Listing.status == ListingStatus.active)
    )
    if not source:
        raise HTTPException(status_code=404, detail="Annonce introuvable")

    stmt = (
        select(Listing)
        .join(User, Listing.seller_id == User.id)
        .options(selectinload(Listing.images))
        .where(Listing.status == ListingStatus.active)
        .where(Listing.id != listing_id)
        .where(User.phone_e164 != DEMO_SELLER_PHONE)
    )
    others = db.scalars(stmt).all()
    candidates: list[tuple[Listing, list[str]]] = []
    for listing in others:
        if not listing.images:
            continue
        keys = [img.key for img in sorted(listing.images, key=lambda i: i.id)]
        candidates.append((listing, keys))

    source_imgs = sorted(source.images, key=lambda i: i.id) if source.images else []
    source_key = source_imgs[0].key if source_imgs else None
    top = find_similar_to_listing(source, source_key, candidates, exclude_id=listing_id)

    items = []
    for sim, listing in top:
        images_sorted = sorted(listing.images, key=lambda i: i.id)
        primary = _public_upload_url(images_sorted[0].key) if images_sorted else None
        cat = db.get(Category, listing.category_id) if listing.category_id else None
        items.append(
            {
                "id": listing.id,
                "title": listing.title,
                "price_cdf": listing.price_cdf,
                "city": listing.city,
                "primary_image_url": primary,
                "category_name": cat.name if cat else None,
                "attributes": listing.attributes,
                "similarity": sim,
            }
        )

    return {
        "items": items,
        "source": {
            "id": source.id,
            "title": source.title,
            "primary_image_url": _public_upload_url(source_key) if source_key else None,
        },
        "message": None
        if items
        else "Aucun produit suffisamment proche trouvé pour cette annonce.",
    }


@router.get("/{listing_id}", response_model=ListingDetailPublic)
def get_listing(listing_id: int, db: Session = Depends(get_db)) -> ListingDetailPublic:
    listing = db.scalar(
        select(Listing).options(selectinload(Listing.images)).where(Listing.id == listing_id, Listing.status == ListingStatus.active)
    )
    if not listing:
        raise HTTPException(status_code=404, detail="Listing not found")

    images_sorted = sorted(listing.images, key=lambda i: i.id)
    primary = _public_upload_url(images_sorted[0].key) if images_sorted else None

    from app.services.escrow import delivery_method_label

    seller = db.get(User, listing.seller_id)
    is_official = bool(seller and seller.role == UserRole.official_seller)

    return ListingDetailPublic(
        id=listing.id,
        title=listing.title,
        city=listing.city,
        price_cdf=listing.price_cdf,
        seller_id=listing.seller_id,
        created_at=listing.created_at,
        primary_image_url=primary,
        category_id=listing.category_id,
        is_official=is_official,
        description=listing.description,
        attributes=listing.attributes,
        delivery_method=listing.delivery_method,
        delivery_method_label=delivery_method_label(listing.delivery_method),
        images=[ListingImagePublic(id=img.id, url=_public_upload_url(img.key)) for img in images_sorted],
    )


@router.post("/{listing_id}/images")
async def upload_listing_image(
    listing_id: int,
    file: UploadFile = File(...),
    idem: tuple[str, User, Session] = Depends(require_idempotency_key),
) -> dict:
    idem_key, current_user, db = idem

    listing = db.get(Listing, listing_id)
    if not listing or listing.status != ListingStatus.active:
        raise HTTPException(status_code=404, detail="Listing not found")
    if listing.seller_id != current_user.id:
        raise HTTPException(status_code=403, detail="Not your listing")

    data = await file.read()
    if not data:
        raise HTTPException(status_code=400, detail="Fichier image vide")

    content_type = normalize_image_content_type(file.content_type, file.filename, data)
    if content_type not in _ALLOWED_IMAGE_TYPES:
        raise HTTPException(status_code=400, detail="Type d'image non supporté (JPEG, PNG, WebP)")

    if len(data) > 6 * 1024 * 1024:
        raise HTTPException(status_code=400, detail="File too large (max 6MB)")

    from app.services.moderation import assert_image_allowed

    assert_image_allowed(data)

    key = await save_image(listing_id=listing.id, content_type=content_type, data=data)

    img = ListingImage(listing_id=listing.id, key=key)
    db.add(img)
    try:
        db.commit()
        resp = {"ok": True, "key": key, "url": _public_upload_url(key)}
        save_idempotency_response(
            db=db,
            user_id=current_user.id,
            key=idem_key,
            method="POST",
            path=f"/listings/{listing_id}/images",
            status_code=200,
            response_body=resp,
        )
        return resp
    except Exception:
        db.rollback()
        raise


@router.post("/{listing_id}/republish")
def republish_listing(
    listing_id: int,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
) -> dict:
    listing = db.get(Listing, listing_id)
    if not listing:
        raise HTTPException(status_code=404, detail="Listing not found")
    if listing.seller_id != current_user.id:
        raise HTTPException(status_code=403, detail="Not your listing")

    from app.services.moderation import assert_content_allowed

    assert_content_allowed(title=listing.title, description=listing.description)

    now = datetime.now(timezone.utc)
    listing.status = ListingStatus.active
    listing.auto_hidden_at = None
    listing.auto_hidden_reason = None
    listing.created_at = now
    listing.updated_at = now
    db.commit()
    return {"ok": True, "created_at": now.isoformat()}


@router.get("/{listing_id}/inquirers")
def list_listing_inquirers(
    listing_id: int,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
) -> dict:
    listing = db.get(Listing, listing_id)
    if not listing:
        raise HTTPException(status_code=404, detail="Listing not found")
    if listing.seller_id != current_user.id:
        raise HTTPException(status_code=403, detail="Not your listing")

    msgs = db.scalars(
        select(Message).where(Message.listing_id == listing_id).order_by(Message.created_at.desc())
    ).all()
    seen: set[int] = set()
    items = []
    for m in msgs:
        peer_id = m.sender_id if m.sender_id != current_user.id else m.recipient_id
        if peer_id == current_user.id or peer_id in seen:
            continue
        peer = db.get(User, peer_id)
        if not peer:
            continue
        seen.add(peer_id)
        items.append(
            {
                "user_id": peer_id,
                "name": peer.display_name or peer.official_name or peer.phone_e164,
                "avatar_url": _public_upload_url(peer.avatar_key) if peer.avatar_key else None,
            }
        )
    return {"items": items}


@router.post("/{listing_id}/sold")
def mark_listing_sold(
    listing_id: int,
    payload: dict | None = None,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
) -> dict:
    listing = db.get(Listing, listing_id)
    if not listing:
        raise HTTPException(status_code=404, detail="Listing not found")
    if listing.seller_id != current_user.id:
        raise HTTPException(status_code=403, detail="Not your listing")

    buyer_id = None
    if payload and payload.get("buyer_id") is not None:
        buyer_id = int(payload["buyer_id"])
        buyer = db.get(User, buyer_id)
        if not buyer:
            raise HTTPException(status_code=404, detail="Acheteur introuvable")

    now = datetime.now(timezone.utc)
    listing.status = ListingStatus.sold
    listing.buyer_id = buyer_id
    listing.sold_at = now
    listing.updated_at = now

    review_message_id = None
    if buyer_id:
        title = listing.title or "votre achat"
        content = (
            f"🎉 Merci pour votre achat « {title} » ! "
            f"Laissez un avis pour aider la communauté SombaTeka."
        )
        msg = Message(
            sender_id=current_user.id,
            recipient_id=buyer_id,
            listing_id=listing_id,
            content=content,
            kind="review_request",
            created_at=now,
            updated_at=now,
        )
        db.add(msg)
        db.flush()
        review_message_id = msg.id

        if current_user.role != UserRole.official_seller and not current_user.is_verified_seller:
            buyer = db.get(User, buyer_id)
            buyer_name = (buyer.display_name if buyer else None) or "l'acheteur"
            seller_msg = Message(
                sender_id=buyer_id,
                recipient_id=current_user.id,
                listing_id=listing_id,
                content=(
                    f"✅ Vente confirmée à {buyer_name}. "
                    f"Laissez un avis sur cet acheteur pour aider la communauté."
                ),
                kind="seller_review_request",
                created_at=now,
                updated_at=now,
            )
            db.add(seller_msg)

    db.commit()
    return {"ok": True, "buyer_id": buyer_id, "review_message_id": review_message_id}


@router.delete("/{listing_id}")
def delete_listing(
    listing_id: int,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
) -> dict:
    listing = db.get(Listing, listing_id)
    if not listing:
        raise HTTPException(status_code=404, detail="Listing not found")
    if listing.seller_id != current_user.id and current_user.role.value not in {
        "super_admin",
        "admin",
        "moderator",
    }:
        raise HTTPException(status_code=403, detail="Not your listing")
    listing.status = ListingStatus.hidden
    listing.updated_at = datetime.now(timezone.utc)
    db.commit()
    return {"ok": True}
