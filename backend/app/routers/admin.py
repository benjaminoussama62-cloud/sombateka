from datetime import datetime, timezone

from fastapi import APIRouter, Depends, HTTPException, Query, Request
from pydantic import BaseModel, Field
from sqlalchemy import func, select
from sqlalchemy.orm import Session

from app.admin_rbac import (
    PERM_AUDIT_VIEW,
    PERM_DASHBOARD,
    PERM_ESCROW_RESOLVE,
    PERM_ESCROW_VIEW,
    PERM_KYC_VIEW,
    PERM_KYC_WRITE,
    PERM_LISTINGS_MODERATE,
    PERM_LISTINGS_VIEW,
    PERM_REPORTS_VIEW,
    PERM_REPORTS_WRITE,
    PERM_SUPPORT_REPLY,
    PERM_SUPPORT_VIEW,
    PERM_TEAM_MANAGE,
    PERM_TEAM_VIEW,
    PERM_USERS_BAN,
    PERM_USERS_PII,
    PERM_USERS_REVOKE_OFFICIAL,
    PERM_USERS_VIEW,
    ROLE_LABELS,
    STAFF_ROLES,
    has_permission,
    permissions_for,
)
from app.db import get_db
from app.deps_admin import client_ip, get_admin_staff, require_permission
from app.models import (
    AdminAuditLog,
    DisputeStatus,
    KycApplication,
    KycDocument,
    KycStatus,
    Listing,
    ListingImage,
    ListingStatus,
    Order,
    OrderDispute,
    OrderStatus,
    Report,
    ReportStatus,
    User,
    UserRole,
)
from app.schemas import AdminOrderResolveRequest, KycApplicationPublic, ReportPublic
from app.services.escrow import refund_buyer, release_to_seller, status_label_fr
from app.services.moderation import count_distinct_listing_reports
from app.services.kyc_service import (
    application_to_public,
    effective_kyc_fields,
    load_application_documents,
)
from app.services.admin_audit import audit_to_dict, log_admin_action
from app.services.admin_privacy import mask_phone, mask_user_dict, mask_user_row
from app.services.storage import public_url
from app.services.listing_catalog import (
    catalog_variants,
    is_official_catalog,
    replace_catalog_variants,
)
from app.services.support_inbox import (
    count_unread_support,
    get_support_thread,
    list_support_conversations,
    mark_support_read,
    send_support_reply,
)
from app.services.team_outreach import (
    notify_account_banned,
    notify_account_unbanned,
    notify_kyc_approved,
    notify_kyc_rejected,
    notify_listing_hidden,
    notify_official_revoked,
    notify_warning,
)

router = APIRouter(prefix="/admin", tags=["admin"])


class BanUserBody(BaseModel):
    reason: str | None = Field(default=None, max_length=500)


class WarnUserBody(BaseModel):
    message: str = Field(..., min_length=3, max_length=2000)


class RejectKycBody(BaseModel):
    note: str = Field(default="", max_length=500)
    internal_note: str | None = Field(default=None, max_length=500)


class ApproveKycBody(BaseModel):
    internal_note: str | None = Field(default=None, max_length=500)


class ListingModerateBody(BaseModel):
    action: str = Field(..., pattern="^(hide|restore)$")


class CatalogVariantItem(BaseModel):
    size: str = Field(..., min_length=1, max_length=32)
    color: str | None = Field(default=None, max_length=64)
    price_cdf: int = Field(default=0, ge=0)
    stock: int = Field(default=0, ge=0)


class CatalogStockUpdateBody(BaseModel):
    variants: list[CatalogVariantItem] = Field(..., min_length=1, max_length=80)


class TeamRoleUpdateBody(BaseModel):
    role: str = Field(..., pattern="^(moderator|admin|super_admin)$")


class TeamInviteBody(BaseModel):
    phone_e164: str
    display_name: str | None = Field(default=None, max_length=80)
    role: str = Field(..., pattern="^(moderator|admin|super_admin)$")
    password: str = Field(..., min_length=8, max_length=128)


class TeamPasswordBody(BaseModel):
    password: str = Field(..., min_length=8, max_length=128)


class SupportReplyBody(BaseModel):
    content: str = Field(..., min_length=1, max_length=4000)
    add_signature: bool = True


def _user_row(u: User, *, mask_pii: bool) -> dict:
    row = {
        "id": u.id,
        "phone_e164": u.phone_e164,
        "display_name": u.display_name,
        "official_name": u.official_name,
        "role": u.role.value,
        "is_verified_seller": u.is_verified_seller,
        "is_banned": u.is_banned,
        "created_at": u.created_at.isoformat() if u.created_at else None,
    }
    return mask_user_row(row) if mask_pii else row


def _can_reveal_pii(actor: User) -> bool:
    from app.admin_rbac import has_permission

    return has_permission(actor.role, PERM_USERS_PII)


def _should_mask(_actor: User) -> bool:
    """Les listes masquent toujours les téléphones ; révélation via bouton audité uniquement."""
    return True


@router.get("/me")
def admin_me(staff: User = Depends(get_admin_staff)) -> dict:
    return {
        "user": {
            "id": staff.id,
            "phone_e164": staff.phone_e164,
            "display_name": staff.display_name,
            "role": staff.role.value,
            "role_label": ROLE_LABELS.get(staff.role, staff.role.value),
        },
        "permissions": permissions_for(staff.role),
    }


@router.get("/stats")
def admin_stats(
    db: Session = Depends(get_db),
    staff: User = Depends(require_permission(PERM_DASHBOARD)),
) -> dict:
    out: dict = {}
    if has_permission(staff.role, PERM_USERS_VIEW):
        out["users_total"] = db.scalar(select(func.count()).select_from(User)) or 0
        out["users_banned"] = (
            db.scalar(select(func.count()).select_from(User).where(User.is_banned.is_(True))) or 0
        )
    if has_permission(staff.role, PERM_KYC_VIEW):
        out["official_sellers"] = (
            db.scalar(select(func.count()).select_from(User).where(User.role == UserRole.official_seller)) or 0
        )
        out["kyc_pending"] = (
            db.scalar(
                select(func.count()).select_from(KycApplication).where(KycApplication.status == KycStatus.pending)
            )
            or 0
        )
    if has_permission(staff.role, PERM_REPORTS_VIEW):
        out["reports_open"] = (
            db.scalar(select(func.count()).select_from(Report).where(Report.status == ReportStatus.open)) or 0
        )
        out["reports_reviewing"] = (
            db.scalar(select(func.count()).select_from(Report).where(Report.status == ReportStatus.reviewing)) or 0
        )
    if has_permission(staff.role, PERM_LISTINGS_VIEW):
        out["moderation_queue"] = (
            db.scalar(
                select(func.count())
                .select_from(Listing)
                .where(Listing.status == ListingStatus.hidden, Listing.auto_hidden_reason.isnot(None))
            )
            or 0
        )
        out["listings_active"] = (
            db.scalar(select(func.count()).select_from(Listing).where(Listing.status == ListingStatus.active)) or 0
        )
        out["listings_hidden"] = (
            db.scalar(select(func.count()).select_from(Listing).where(Listing.status == ListingStatus.hidden)) or 0
        )
    if has_permission(staff.role, PERM_ESCROW_VIEW):
        out["escrow_open"] = (
            db.scalar(select(func.count()).select_from(Order).where(Order.status == OrderStatus.sequestre)) or 0
        )
    if has_permission(staff.role, PERM_SUPPORT_VIEW):
        out["support_unread"] = count_unread_support(db)
    return out


@router.get("/activity")
def admin_activity(
    db: Session = Depends(get_db),
    staff: User = Depends(require_permission(PERM_DASHBOARD)),
    limit: int = Query(default=15, ge=1, le=50),
) -> dict:
    mask = _should_mask(staff)
    items: list[dict] = []
    if has_permission(staff.role, PERM_KYC_VIEW):
        for kyc in db.scalars(select(KycApplication).order_by(KycApplication.created_at.desc()).limit(limit)).all():
            user = db.get(User, kyc.user_id)
            phone = mask_phone(user.phone_e164) if user and mask else (user.phone_e164 if user else None)
            items.append(
                {
                    "type": "kyc",
                    "at": kyc.created_at.isoformat() if kyc.created_at else None,
                    "title": f"Demande pro : {kyc.business_name}",
                    "subtitle": phone or f"User #{kyc.user_id}",
                    "status": kyc.status.value,
                    "ref_id": kyc.id,
                }
            )
    if has_permission(staff.role, PERM_REPORTS_VIEW):
        for report in db.scalars(select(Report).order_by(Report.created_at.desc()).limit(limit)).all():
            items.append(
                {
                    "type": "report",
                    "at": report.created_at.isoformat() if report.created_at else None,
                    "title": f"Signalement : {report.reason}",
                    "subtitle": (report.details or "")[:80] or f"#{report.id}",
                    "status": report.status.value,
                    "ref_id": report.id,
                }
            )
    items.sort(key=lambda x: x["at"] or "", reverse=True)
    return {"items": items[:limit]}


@router.get("/support/conversations")
def admin_support_conversations(
    db: Session = Depends(get_db),
    staff: User = Depends(require_permission(PERM_SUPPORT_VIEW)),
) -> dict:
    return {"items": list_support_conversations(db, mask_pii=_should_mask(staff))}


@router.get("/support/conversations/{user_id}")
def admin_support_thread(
    user_id: int,
    db: Session = Depends(get_db),
    staff: User = Depends(require_permission(PERM_SUPPORT_VIEW)),
) -> dict:
    try:
        thread = get_support_thread(db, user_id, mask_pii=_should_mask(staff))
    except ValueError as exc:
        raise HTTPException(status_code=404, detail=str(exc)) from exc
    mark_support_read(db, user_id)
    db.commit()
    return thread


@router.post("/support/conversations/{user_id}/reply")
def admin_support_reply(
    user_id: int,
    body: SupportReplyBody,
    request: Request,
    db: Session = Depends(get_db),
    staff: User = Depends(require_permission(PERM_SUPPORT_REPLY)),
) -> dict:
    try:
        msg = send_support_reply(
            db,
            staff=staff,
            user_id=user_id,
            content=body.content,
            add_signature=body.add_signature,
        )
    except ValueError as exc:
        raise HTTPException(status_code=400, detail=str(exc)) from exc
    log_admin_action(
        db,
        actor=staff,
        action="support.reply",
        resource_type="user",
        resource_id=user_id,
        detail={"message_id": msg.id, "preview": body.content[:120]},
        ip_address=client_ip(request),
    )
    db.commit()
    return {"ok": True, "message_id": msg.id}


@router.post("/support/conversations/{user_id}/read")
def admin_support_mark_read(
    user_id: int,
    db: Session = Depends(get_db),
    staff: User = Depends(require_permission(PERM_SUPPORT_VIEW)),
) -> dict:
    count = mark_support_read(db, user_id)
    db.commit()
    return {"ok": True, "count": count}


@router.get("/audit")
def list_audit(
    request: Request,
    db: Session = Depends(get_db),
    staff: User = Depends(require_permission(PERM_AUDIT_VIEW)),
    limit: int = Query(default=50, ge=1, le=200),
) -> dict:
    rows = db.scalars(select(AdminAuditLog).order_by(AdminAuditLog.created_at.desc()).limit(limit)).all()
    items = []
    for entry in rows:
        actor = db.get(User, entry.actor_id)
        phone = actor.phone_e164 if actor else None
        items.append(audit_to_dict(entry, actor_phone=mask_phone(phone) if phone and _should_mask(staff) else phone))
    return {"items": items}


@router.get("/team")
def list_team(
    db: Session = Depends(get_db),
    staff: User = Depends(require_permission(PERM_TEAM_VIEW)),
) -> dict:
    rows = db.scalars(select(User).where(User.role.in_(STAFF_ROLES)).order_by(User.created_at.desc())).all()
    mask = _should_mask(staff)
    staff_ids = [u.id for u in rows]
    activity_map: dict[int, tuple[int, datetime | None]] = {}
    if staff_ids:
        for actor_id, cnt, last_at in db.execute(
            select(
                AdminAuditLog.actor_id,
                func.count(),
                func.max(AdminAuditLog.created_at),
            )
            .where(AdminAuditLog.actor_id.in_(staff_ids))
            .group_by(AdminAuditLog.actor_id)
        ).all():
            activity_map[int(actor_id)] = (int(cnt or 0), last_at)
    return {
        "items": [
            {
                "id": u.id,
                "phone_e164": mask_phone(u.phone_e164) if mask else u.phone_e164,
                "display_name": u.display_name,
                "role": u.role.value,
                "role_label": ROLE_LABELS.get(u.role, u.role.value),
                "is_banned": u.is_banned,
                "is_self": u.id == staff.id,
                "has_admin_password": bool(u.admin_password_hash),
                "activity_count": activity_map.get(u.id, (0, None))[0],
                "last_activity_at": (
                    activity_map.get(u.id, (0, None))[1].isoformat()
                    if activity_map.get(u.id, (0, None))[1]
                    else None
                ),
            }
            for u in rows
        ]
    }


@router.get("/team/activity")
def team_activity(
    db: Session = Depends(get_db),
    staff: User = Depends(require_permission(PERM_TEAM_VIEW)),
    actor_id: int | None = Query(default=None),
    limit: int = Query(default=50, ge=1, le=200),
) -> dict:
    staff_user_ids = list(
        db.scalars(select(User.id).where(User.role.in_(STAFF_ROLES))).all()
    )
    if not staff_user_ids:
        return {"items": []}

    q = select(AdminAuditLog).order_by(AdminAuditLog.created_at.desc())
    if actor_id is not None:
        target = db.get(User, actor_id)
        if not target or target.role not in STAFF_ROLES:
            raise HTTPException(status_code=404, detail="Membre introuvable")
        q = q.where(AdminAuditLog.actor_id == actor_id)
    else:
        q = q.where(AdminAuditLog.actor_id.in_(staff_user_ids))

    rows = db.scalars(q.limit(limit)).all()
    actor_ids = {e.actor_id for e in rows}
    actors = {
        u.id: u
        for u in db.scalars(select(User).where(User.id.in_(actor_ids))).all()
    } if actor_ids else {}
    mask = _should_mask(staff)
    items = []
    for entry in rows:
        actor = actors.get(entry.actor_id)
        phone = actor.phone_e164 if actor else None
        row = audit_to_dict(entry, actor_phone=mask_phone(phone) if phone and mask else phone)
        if actor:
            row["actor_name"] = actor.display_name
            row["actor_role"] = actor.role.value
        items.append(row)
    return {"items": items}


@router.post("/team/invite")
def invite_team_member(
    body: TeamInviteBody,
    request: Request,
    db: Session = Depends(get_db),
    actor: User = Depends(require_permission(PERM_TEAM_MANAGE)),
) -> dict:
    from app.routers.auth import _normalize_phone
    from app.services.admin_passwords import hash_admin_password

    if body.role == "super_admin" and actor.role != UserRole.super_admin:
        raise HTTPException(status_code=403, detail="Seul le super administrateur peut créer un super admin")

    phone = _normalize_phone(body.phone_e164)
    user = db.scalar(select(User).where(User.phone_e164 == phone))
    created = False
    if not user:
        user = User(
            phone_e164=phone,
            role=UserRole(body.role),
            display_name=body.display_name,
            is_phone_verified=True,
        )
        db.add(user)
        db.flush()
        created = True
    else:
        if user.role not in STAFF_ROLES and user.role != UserRole(body.role):
            user.role = UserRole(body.role)
        elif user.role in STAFF_ROLES and user.id != actor.id:
            user.role = UserRole(body.role)
        if body.display_name:
            user.display_name = body.display_name.strip()

    user.admin_password_hash = hash_admin_password(body.password)
    user.is_phone_verified = True
    user.is_banned = False
    user.updated_at = datetime.now(timezone.utc)
    log_admin_action(
        db,
        actor=actor,
        action="team.invite" if created else "team.password_reset",
        resource_type="user",
        resource_id=user.id,
        detail={"role": body.role, "created": created},
        ip_address=client_ip(request),
    )
    db.commit()
    return {
        "ok": True,
        "user_id": user.id,
        "phone_e164": phone,
        "role": user.role.value,
        "created": created,
    }


@router.post("/team/{user_id}/password")
def set_team_password(
    user_id: int,
    body: TeamPasswordBody,
    request: Request,
    db: Session = Depends(get_db),
    actor: User = Depends(require_permission(PERM_TEAM_MANAGE)),
) -> dict:
    from app.services.admin_passwords import hash_admin_password

    target = db.get(User, user_id)
    if not target or target.role not in STAFF_ROLES:
        raise HTTPException(status_code=404, detail="Membre introuvable")
    target.admin_password_hash = hash_admin_password(body.password)
    target.updated_at = datetime.now(timezone.utc)
    log_admin_action(
        db,
        actor=actor,
        action="team.password_reset",
        resource_type="user",
        resource_id=target.id,
        ip_address=client_ip(request),
    )
    db.commit()
    return {"ok": True}


@router.patch("/team/{user_id}")
def update_team_role(
    user_id: int,
    body: TeamRoleUpdateBody,
    request: Request,
    db: Session = Depends(get_db),
    actor: User = Depends(require_permission(PERM_TEAM_MANAGE)),
) -> dict:
    target = db.get(User, user_id)
    if not target or target.role not in STAFF_ROLES:
        raise HTTPException(status_code=404, detail="Membre introuvable")
    if target.id == actor.id:
        raise HTTPException(status_code=400, detail="Vous ne pouvez pas modifier votre propre rôle")
    if body.role == "super_admin" and actor.role != UserRole.super_admin:
        raise HTTPException(status_code=403, detail="Seul le super administrateur peut promouvoir un super admin")
    if target.role == UserRole.super_admin and body.role != "super_admin":
        super_count = db.scalar(
            select(func.count()).select_from(User).where(User.role == UserRole.super_admin)
        ) or 0
        if super_count <= 1:
            raise HTTPException(status_code=400, detail="Impossible de rétrograder le dernier super administrateur")
    old_role = target.role.value
    target.role = UserRole(body.role)
    target.updated_at = datetime.now(timezone.utc)
    log_admin_action(
        db,
        actor=actor,
        action="team.role_change",
        resource_type="user",
        resource_id=target.id,
        detail={"from": old_role, "to": body.role},
        ip_address=client_ip(request),
    )
    db.commit()
    return {"ok": True}


@router.post("/team/{user_id}/revoke-access")
def revoke_staff_access(
    user_id: int,
    request: Request,
    db: Session = Depends(get_db),
    actor: User = Depends(require_permission(PERM_TEAM_MANAGE)),
) -> dict:
    target = db.get(User, user_id)
    if not target or target.role not in STAFF_ROLES:
        raise HTTPException(status_code=404, detail="Membre introuvable")
    if target.id == actor.id:
        raise HTTPException(status_code=400, detail="Action impossible sur votre compte")
    if target.role == UserRole.super_admin:
        super_count = db.scalar(
            select(func.count()).select_from(User).where(User.role == UserRole.super_admin)
        ) or 0
        if super_count <= 1:
            raise HTTPException(status_code=400, detail="Impossible de révoquer le dernier super administrateur")
    old_role = target.role.value
    target.role = UserRole.user
    target.admin_password_hash = None
    target.updated_at = datetime.now(timezone.utc)
    log_admin_action(
        db,
        actor=actor,
        action="team.revoke_access",
        resource_type="user",
        resource_id=target.id,
        detail={"from": old_role},
        ip_address=client_ip(request),
    )
    db.commit()
    return {"ok": True}


@router.post("/users/{user_id}/reveal-pii")
def reveal_user_pii(
    user_id: int,
    request: Request,
    db: Session = Depends(get_db),
    staff: User = Depends(require_permission(PERM_USERS_PII)),
) -> dict:
    user = db.get(User, user_id)
    if not user:
        raise HTTPException(status_code=404, detail="Utilisateur introuvable")
    log_admin_action(
        db,
        actor=staff,
        action="users.pii_reveal",
        resource_type="user",
        resource_id=user.id,
        detail={"field": "phone_e164"},
        ip_address=client_ip(request),
    )
    db.commit()
    return {"phone_e164": user.phone_e164, "audited": True}


@router.get("/users")
def list_users(
    db: Session = Depends(get_db),
    staff: User = Depends(require_permission(PERM_USERS_VIEW)),
    q: str | None = Query(default=None, max_length=80),
    role: str | None = Query(default=None),
    banned: bool | None = Query(default=None),
    limit: int = Query(default=50, ge=1, le=200),
    offset: int = Query(default=0, ge=0),
) -> dict:
    stmt = select(User).order_by(User.created_at.desc())
    if q:
        like = f"%{q.strip()}%"
        stmt = stmt.where(
            (User.phone_e164.ilike(like))
            | (User.display_name.ilike(like))
            | (User.official_name.ilike(like))
        )
    if role:
        stmt = stmt.where(User.role == UserRole(role))
    if banned is not None:
        stmt = stmt.where(User.is_banned.is_(banned))
    count_stmt = select(func.count(User.id))
    if q:
        like = f"%{q.strip()}%"
        count_stmt = count_stmt.where(
            (User.phone_e164.ilike(like))
            | (User.display_name.ilike(like))
            | (User.official_name.ilike(like))
        )
    if role:
        count_stmt = count_stmt.where(User.role == UserRole(role))
    if banned is not None:
        count_stmt = count_stmt.where(User.is_banned.is_(banned))
    total = db.scalar(count_stmt) or 0
    rows = db.scalars(stmt.offset(offset).limit(limit)).all()
    mask = _should_mask(staff)
    return {"total": total, "items": [_user_row(u, mask_pii=mask) for u in rows], "pii_masked": mask}


@router.get("/users/{user_id}")
def get_user(
    user_id: int,
    db: Session = Depends(get_db),
    staff: User = Depends(require_permission(PERM_USERS_VIEW)),
) -> dict:
    user = db.get(User, user_id)
    if not user:
        raise HTTPException(status_code=404, detail="Utilisateur introuvable")
    mask = _should_mask(staff)
    listings_count = db.scalar(select(func.count()).select_from(Listing).where(Listing.seller_id == user_id)) or 0
    kyc = db.scalar(
        select(KycApplication).where(KycApplication.user_id == user_id).order_by(KycApplication.created_at.desc())
    )
    return {
        "user": _user_row(user, mask_pii=mask),
        "listings_count": listings_count,
        "can_reveal_pii": _can_reveal_pii(staff),
        "kyc": (
            KycApplicationPublic(
                id=kyc.id,
                status=kyc.status.value,
                business_name=kyc.business_name,
                business_type=kyc.business_type,
                created_at=kyc.created_at,
                reviewer_note=kyc.reviewer_note,
            ).model_dump()
            if kyc
            else None
        ),
    }


def _kyc_list_item(db: Session, r: KycApplication, *, mask: bool) -> dict:
    user = db.get(User, r.user_id)
    phone = mask_phone(user.phone_e164) if user and mask else (user.phone_e164 if user else None)
    fields = effective_kyc_fields(r)
    doc_count = db.scalar(
        select(func.count(KycDocument.id)).where(KycDocument.application_id == r.id)
    ) or 0
    pub = application_to_public(r, documents=[])
    return {
        **pub.model_dump(mode="json"),
        "user_id": r.user_id,
        "user_phone": phone,
        "user_display_name": user.display_name if user else None,
        "reviewer_note": r.reviewer_note,
        "reviewed_at": r.reviewed_at.isoformat() if r.reviewed_at else None,
        "document_count": doc_count,
        "category": fields["category"],
        "rccm": fields["rccm"],
        "tax_id": fields["tax_id"],
    }


@router.get("/kyc")
def list_kyc(
    db: Session = Depends(get_db),
    staff: User = Depends(require_permission(PERM_KYC_VIEW)),
    status: str | None = Query(default="pending"),
    limit: int = Query(default=50, ge=1, le=200),
) -> dict:
    stmt = select(KycApplication).order_by(KycApplication.created_at.desc()).limit(limit)
    if status:
        stmt = stmt.where(KycApplication.status == KycStatus(status))
    rows = db.scalars(stmt).all()
    mask = _should_mask(staff)
    return {"items": [_kyc_list_item(db, r, mask=mask) for r in rows]}


@router.get("/kyc/{application_id}")
def get_kyc_detail(
    application_id: int,
    request: Request,
    db: Session = Depends(get_db),
    staff: User = Depends(require_permission(PERM_KYC_VIEW)),
) -> dict:
    app_row = db.get(KycApplication, application_id)
    if not app_row:
        raise HTTPException(status_code=404, detail="Demande introuvable")
    user = db.get(User, app_row.user_id)
    if not user:
        raise HTTPException(status_code=404, detail="Utilisateur introuvable")
    mask = _should_mask(staff)
    docs = load_application_documents(db, app_row.id)
    listings_count = (
        db.scalar(select(func.count()).select_from(Listing).where(Listing.seller_id == user.id)) or 0
    )
    reports_count = (
        db.scalar(
            select(func.count()).select_from(Report).where(Report.target_user_id == user.id)
        )
        or 0
    )
    log_admin_action(
        db,
        actor=staff,
        action="kyc.view_detail",
        resource_type="kyc",
        resource_id=app_row.id,
        detail={"user_id": user.id, "document_count": len(docs)},
        ip_address=client_ip(request),
    )
    db.commit()
    application = application_to_public(app_row, documents=docs)
    return {
        "application": application.model_dump(mode="json"),
        "internal_review_note": app_row.internal_review_note,
        "reviewed_at": app_row.reviewed_at.isoformat() if app_row.reviewed_at else None,
        "user": {
            **_user_row(user, mask_pii=mask),
            "avatar_url": public_url(user.avatar_key) if user.avatar_key else None,
            "listings_count": listings_count,
            "reports_count": reports_count,
        },
        "checklist": {
            "has_rccm_number": bool(application.rccm),
            "has_tax_id": bool(application.tax_id),
            "has_rccm_document": any(d.doc_type == "rccm" for d in application.documents),
            "has_id_document": any(d.doc_type == "national_id" for d in application.documents),
            "has_tax_document": any(d.doc_type == "tax_certificate" for d in application.documents),
            "documents_complete": len(application.documents) >= 2,
        },
        "pii_masked": mask,
        "can_reveal_pii": _can_reveal_pii(staff),
    }


@router.post("/kyc/{application_id}/approve")
def approve_kyc(
    application_id: int,
    request: Request,
    body: ApproveKycBody = ApproveKycBody(),
    db: Session = Depends(get_db),
    staff: User = Depends(require_permission(PERM_KYC_WRITE)),
) -> dict:
    app_row = db.get(KycApplication, application_id)
    if not app_row or app_row.status != KycStatus.pending:
        raise HTTPException(status_code=404, detail="Demande introuvable")
    user = db.get(User, app_row.user_id)
    if not user:
        raise HTTPException(status_code=404, detail="Utilisateur introuvable")
    app_row.status = KycStatus.approved
    app_row.reviewed_at = datetime.now(timezone.utc)
    user.role = UserRole.official_seller
    user.is_verified_seller = True
    user.official_name = app_row.business_name
    user.updated_at = datetime.now(timezone.utc)
    log_admin_action(
        db,
        actor=staff,
        action="kyc.approve",
        resource_type="kyc",
        resource_id=app_row.id,
        detail={"user_id": user.id},
        ip_address=client_ip(request),
    )
    notify_kyc_approved(db, user_id=user.id, business_name=app_row.business_name)
    db.commit()
    return {"ok": True, "user_id": user.id}


@router.post("/kyc/{application_id}/reject")
def reject_kyc(
    application_id: int,
    body: RejectKycBody,
    request: Request,
    db: Session = Depends(get_db),
    staff: User = Depends(require_permission(PERM_KYC_WRITE)),
) -> dict:
    app_row = db.get(KycApplication, application_id)
    if not app_row or app_row.status != KycStatus.pending:
        raise HTTPException(status_code=404, detail="Demande introuvable")
    app_row.status = KycStatus.rejected
    app_row.reviewer_note = body.note or None
    if body.internal_note:
        app_row.internal_review_note = body.internal_note.strip()
    app_row.reviewed_at = datetime.now(timezone.utc)
    log_admin_action(
        db,
        actor=staff,
        action="kyc.reject",
        resource_type="kyc",
        resource_id=app_row.id,
        detail={"note": body.note},
        ip_address=client_ip(request),
    )
    notify_kyc_rejected(
        db,
        user_id=app_row.user_id,
        business_name=app_row.business_name,
        note=body.note,
    )
    db.commit()
    return {"ok": True}


@router.get("/reports")
def list_reports(
    db: Session = Depends(get_db),
    staff: User = Depends(require_permission(PERM_REPORTS_VIEW)),
    status: str | None = Query(default="open"),
    limit: int = Query(default=50, ge=1, le=200),
) -> dict:
    stmt = select(Report).order_by(Report.created_at.desc()).limit(limit)
    if status:
        stmt = stmt.where(Report.status == ReportStatus(status))
    rows = db.scalars(stmt).all()
    mask = _should_mask(staff)
    items = []
    for r in rows:
        reporter = db.get(User, r.reporter_id)
        target = db.get(User, r.target_user_id) if r.target_user_id else None
        listing = db.get(Listing, r.listing_id) if r.listing_id else None
        report_count = count_distinct_listing_reports(db, r.listing_id) if r.listing_id else 0
        item = {
            **ReportPublic(id=r.id, status=r.status.value, reason=r.reason, created_at=r.created_at).model_dump(),
            "reporter_id": r.reporter_id,
            "reporter_phone": reporter.phone_e164 if reporter else None,
            "target_user_id": r.target_user_id,
            "target_phone": target.phone_e164 if target else None,
            "target_display_name": target.display_name if target else None,
            "listing_id": r.listing_id,
            "listing_title": listing.title if listing else None,
            "listing_status": listing.status.value if listing else None,
            "auto_hidden": bool(listing and listing.auto_hidden_reason),
            "auto_hidden_at": listing.auto_hidden_at.isoformat() if listing and listing.auto_hidden_at else None,
            "report_count": report_count,
            "details": r.details,
        }
        if mask:
            item = mask_user_dict(item)
        items.append(item)
    return {"items": items}


@router.post("/reports/{report_id}/resolve")
def resolve_report(
    report_id: int,
    request: Request,
    db: Session = Depends(get_db),
    staff: User = Depends(require_permission(PERM_REPORTS_WRITE)),
) -> dict:
    report = db.get(Report, report_id)
    if not report:
        raise HTTPException(status_code=404, detail="Signalement introuvable")
    report.status = ReportStatus.closed
    log_admin_action(db, actor=staff, action="report.resolve", resource_type="report", resource_id=report.id, ip_address=client_ip(request))
    db.commit()
    return {"ok": True}


@router.post("/reports/{report_id}/reviewing")
def mark_report_reviewing(
    report_id: int,
    request: Request,
    db: Session = Depends(get_db),
    staff: User = Depends(require_permission(PERM_REPORTS_WRITE)),
) -> dict:
    report = db.get(Report, report_id)
    if not report:
        raise HTTPException(status_code=404, detail="Signalement introuvable")
    report.status = ReportStatus.reviewing
    log_admin_action(db, actor=staff, action="report.reviewing", resource_type="report", resource_id=report.id, ip_address=client_ip(request))
    db.commit()
    return {"ok": True}


@router.post("/users/{user_id}/ban")
def ban_user(
    user_id: int,
    body: BanUserBody,
    request: Request,
    db: Session = Depends(get_db),
    staff: User = Depends(require_permission(PERM_USERS_BAN)),
) -> dict:
    user = db.get(User, user_id)
    if not user:
        raise HTTPException(status_code=404, detail="Utilisateur introuvable")
    if user.role in STAFF_ROLES or user.role == UserRole.support:
        raise HTTPException(status_code=400, detail="Impossible de bannir ce compte")
    user.is_banned = True
    user.updated_at = datetime.now(timezone.utc)
    log_admin_action(
        db,
        actor=staff,
        action="user.ban",
        resource_type="user",
        resource_id=user.id,
        detail={"reason": body.reason},
        ip_address=client_ip(request),
    )
    notify_account_banned(db, user_id=user.id, reason=body.reason)
    db.commit()
    return {"ok": True}


@router.post("/users/{user_id}/unban")
def unban_user(
    user_id: int,
    request: Request,
    db: Session = Depends(get_db),
    staff: User = Depends(require_permission(PERM_USERS_BAN)),
) -> dict:
    user = db.get(User, user_id)
    if not user:
        raise HTTPException(status_code=404, detail="Utilisateur introuvable")
    user.is_banned = False
    user.updated_at = datetime.now(timezone.utc)
    log_admin_action(db, actor=staff, action="user.unban", resource_type="user", resource_id=user.id, ip_address=client_ip(request))
    notify_account_unbanned(db, user_id=user.id)
    db.commit()
    return {"ok": True}


@router.post("/users/{user_id}/warn")
def warn_user(
    user_id: int,
    body: WarnUserBody,
    request: Request,
    db: Session = Depends(get_db),
    staff: User = Depends(require_permission(PERM_USERS_VIEW)),
) -> dict:
    user = db.get(User, user_id)
    if not user:
        raise HTTPException(status_code=404, detail="Utilisateur introuvable")
    if user.role in STAFF_ROLES or user.role == UserRole.support:
        raise HTTPException(status_code=400, detail="Action impossible sur ce compte")
    log_admin_action(
        db,
        actor=staff,
        action="user.warn",
        resource_type="user",
        resource_id=user.id,
        detail={"message": body.message[:200]},
        ip_address=client_ip(request),
    )
    notify_warning(db, user_id=user.id, text=body.message)
    db.commit()
    return {"ok": True}


@router.post("/users/{user_id}/revoke-official")
def revoke_official(
    user_id: int,
    request: Request,
    db: Session = Depends(get_db),
    staff: User = Depends(require_permission(PERM_USERS_REVOKE_OFFICIAL)),
) -> dict:
    user = db.get(User, user_id)
    if not user:
        raise HTTPException(status_code=404, detail="Utilisateur introuvable")
    user.role = UserRole.user
    user.is_verified_seller = False
    user.official_name = None
    user.updated_at = datetime.now(timezone.utc)
    log_admin_action(db, actor=staff, action="user.revoke_official", resource_type="user", resource_id=user.id, ip_address=client_ip(request))
    notify_official_revoked(db, user_id=user.id)
    db.commit()
    return {"ok": True}


@router.get("/listings")
def list_listings_admin(
    db: Session = Depends(get_db),
    staff: User = Depends(require_permission(PERM_LISTINGS_VIEW)),
    status: str | None = Query(default=None),
    q: str | None = Query(default=None, max_length=120),
    limit: int = Query(default=50, ge=1, le=200),
) -> dict:
    stmt = select(Listing).order_by(Listing.created_at.desc()).limit(limit)
    if status:
        stmt = stmt.where(Listing.status == ListingStatus(status))
    if q:
        stmt = stmt.where(Listing.title.ilike(f"%{q.strip()}%"))
    rows = db.scalars(stmt).all()
    mask = _should_mask(staff)
    items = []
    for listing in rows:
        seller = db.get(User, listing.seller_id)
        phone = mask_phone(seller.phone_e164) if seller and mask else (seller.phone_e164 if seller else None)
        first_img = db.scalar(
            select(ListingImage).where(ListingImage.listing_id == listing.id).order_by(ListingImage.id.asc())
        )
        items.append(
            {
                "id": listing.id,
                "title": listing.title,
                "description": (listing.description or "")[:300],
                "city": listing.city,
                "price_cdf": listing.price_cdf,
                "status": listing.status.value,
                "seller_id": listing.seller_id,
                "seller_phone": phone,
                "seller_name": (seller.official_name or seller.display_name) if seller else None,
                "is_official_seller": seller.role == UserRole.official_seller if seller else False,
                "image_url": public_url(first_img.key) if first_img else None,
                "created_at": listing.created_at.isoformat() if listing.created_at else None,
            }
        )
    return {"items": items}


@router.get("/listings/{listing_id}")
def get_listing_admin(
    listing_id: int,
    db: Session = Depends(get_db),
    staff: User = Depends(require_permission(PERM_LISTINGS_VIEW)),
) -> dict:
    listing = db.get(Listing, listing_id)
    if not listing:
        raise HTTPException(status_code=404, detail="Annonce introuvable")
    seller = db.get(User, listing.seller_id)
    mask = _should_mask(staff)
    images = db.scalars(select(ListingImage).where(ListingImage.listing_id == listing_id)).all()
    official = bool(seller and seller.role == UserRole.official_seller)
    catalog = is_official_catalog(listing, seller) if seller else False
    return {
        "id": listing.id,
        "title": listing.title,
        "description": listing.description,
        "city": listing.city,
        "price_cdf": listing.price_cdf,
        "status": listing.status.value,
        "seller_id": listing.seller_id,
        "seller_phone": mask_phone(seller.phone_e164) if seller and mask else (seller.phone_e164 if seller else None),
        "is_official_seller": official,
        "is_catalog": catalog,
        "catalog_variants": catalog_variants(listing) if catalog else [],
        "images": [public_url(img.key) for img in images],
        "created_at": listing.created_at.isoformat() if listing.created_at else None,
    }


@router.patch("/listings/{listing_id}/catalog-stock")
def update_listing_catalog_stock(
    listing_id: int,
    body: CatalogStockUpdateBody,
    request: Request,
    db: Session = Depends(get_db),
    staff: User = Depends(require_permission(PERM_LISTINGS_MODERATE)),
) -> dict:
    listing = db.get(Listing, listing_id)
    if not listing:
        raise HTTPException(status_code=404, detail="Annonce introuvable")
    seller = db.get(User, listing.seller_id)
    if not seller or seller.role != UserRole.official_seller:
        raise HTTPException(status_code=400, detail="Stock catalogue réservé aux vendeurs officiels")
    try:
        variants = replace_catalog_variants(
            listing,
            [v.model_dump() for v in body.variants],
        )
    except ValueError as exc:
        raise HTTPException(status_code=400, detail=str(exc)) from exc
    listing.updated_at = datetime.now(timezone.utc)
    log_admin_action(
        db,
        actor=staff,
        action="listing.catalog_stock",
        resource_type="listing",
        resource_id=listing.id,
        ip_address=client_ip(request),
        detail={"variants": len(variants)},
    )
    db.commit()
    return {"ok": True, "variants": variants, "price_cdf": listing.price_cdf}


@router.post("/listings/{listing_id}/moderate")
def moderate_listing(
    listing_id: int,
    body: ListingModerateBody,
    request: Request,
    db: Session = Depends(get_db),
    staff: User = Depends(require_permission(PERM_LISTINGS_MODERATE)),
) -> dict:
    listing = db.get(Listing, listing_id)
    if not listing:
        raise HTTPException(status_code=404, detail="Annonce introuvable")
    listing.status = ListingStatus.hidden if body.action == "hide" else ListingStatus.active
    if body.action == "restore":
        listing.auto_hidden_at = None
        listing.auto_hidden_reason = None
        for r in db.scalars(
            select(Report).where(
                Report.listing_id == listing.id,
                Report.status == ReportStatus.reviewing,
            )
        ).all():
            r.status = ReportStatus.closed
    listing.updated_at = datetime.now(timezone.utc)
    log_admin_action(
        db,
        actor=staff,
        action=f"listing.{body.action}",
        resource_type="listing",
        resource_id=listing.id,
        ip_address=client_ip(request),
    )
    if body.action == "hide":
        notify_listing_hidden(
            db,
            user_id=listing.seller_id,
            listing_title=listing.title,
            listing_id=listing.id,
        )
    db.commit()
    return {"ok": True, "status": listing.status.value}


@router.post("/reports/{report_id}/hide-listing")
def hide_listing_from_report(
    report_id: int,
    request: Request,
    db: Session = Depends(get_db),
    staff: User = Depends(require_permission(PERM_REPORTS_WRITE)),
) -> dict:
    report = db.get(Report, report_id)
    if not report or not report.listing_id:
        raise HTTPException(status_code=404, detail="Annonce liée introuvable")
    listing = db.get(Listing, report.listing_id)
    if not listing:
        raise HTTPException(status_code=404, detail="Annonce introuvable")
    listing.status = ListingStatus.hidden
    listing.updated_at = datetime.now(timezone.utc)
    report.status = ReportStatus.closed
    log_admin_action(
        db,
        actor=staff,
        action="report.hide_listing",
        resource_type="report",
        resource_id=report.id,
        detail={"listing_id": listing.id},
        ip_address=client_ip(request),
    )
    notify_listing_hidden(
        db,
        user_id=listing.seller_id,
        listing_title=listing.title,
        listing_id=listing.id,
    )
    db.commit()
    return {"ok": True, "listing_id": listing.id}


@router.post("/reports/{report_id}/ban-and-resolve")
def ban_and_resolve_report(
    report_id: int,
    request: Request,
    db: Session = Depends(get_db),
    staff: User = Depends(require_permission(PERM_USERS_BAN)),
) -> dict:
    """Ban instantané + masque annonce + clôture signalement."""
    report = db.get(Report, report_id)
    if not report:
        raise HTTPException(status_code=404, detail="Signalement introuvable")
    if report.listing_id:
        listing = db.get(Listing, report.listing_id)
        if listing:
            listing.status = ListingStatus.hidden
            listing.updated_at = datetime.now(timezone.utc)
            notify_listing_hidden(
                db,
                user_id=listing.seller_id,
                listing_title=listing.title,
                listing_id=listing.id,
            )
    target_id = report.target_user_id
    if not target_id and report.listing_id:
        listing = db.get(Listing, report.listing_id)
        target_id = listing.seller_id if listing else None
    if target_id:
        user = db.get(User, target_id)
        if user and not user.is_banned:
            user.is_banned = True
            notify_account_banned(db, user_id=user.id, reason=report.reason)
    report.status = ReportStatus.closed
    log_admin_action(
        db,
        actor=staff,
        action="report.ban_and_resolve",
        resource_type="report",
        resource_id=report.id,
        ip_address=client_ip(request),
    )
    db.commit()
    return {"ok": True}


@router.get("/escrow/orders")
def list_escrow_orders(
    status: str | None = Query(default=None),
    db: Session = Depends(get_db),
    staff: User = Depends(require_permission(PERM_ESCROW_VIEW)),
) -> dict:
    q = select(Order).order_by(Order.created_at.desc()).limit(100)
    if status:
        try:
            q = q.where(Order.status == OrderStatus(status))
        except ValueError:
            pass
    else:
        q = q.where(
            Order.status.in_(
                (
                    OrderStatus.sequestre,
                    OrderStatus.succes,
                    OrderStatus.rembourse,
                    OrderStatus.en_attente,
                )
            )
        )
    orders = db.scalars(q).all()
    items = []
    for o in orders:
        listing = db.get(Listing, o.listing_id)
        buyer = db.get(User, o.buyer_id)
        seller = db.get(User, listing.seller_id) if listing else None
        dispute = db.scalar(select(OrderDispute).where(OrderDispute.order_id == o.id))
        deadline_passed = bool(
            o.delivery_deadline_at
            and o.delivery_deadline_at <= datetime.now(timezone.utc)
            and o.status == OrderStatus.sequestre
        )
        items.append(
            {
                "id": o.id,
                "status": o.status.value,
                "status_label": status_label_fr(o.status),
                "amount_cdf": o.amount_cdf,
                "listing_title": listing.title if listing else None,
                "buyer_phone": mask_phone(buyer.phone_e164) if buyer else None,
                "seller_phone": mask_phone(seller.phone_e164) if seller else None,
                "handover_code": o.handover_code,
                "delivery_deadline_at": o.delivery_deadline_at.isoformat() if o.delivery_deadline_at else None,
                "deadline_passed": deadline_passed,
                "dispute": (
                    {
                        "id": dispute.id,
                        "status": dispute.status.value,
                        "reason": dispute.reason,
                    }
                    if dispute
                    else None
                ),
            }
        )
    return {"items": items}


@router.post("/escrow/orders/{order_id}/release-seller")
def admin_release_seller(
    order_id: int,
    body: AdminOrderResolveRequest,
    request: Request,
    db: Session = Depends(get_db),
    staff: User = Depends(require_permission(PERM_ESCROW_RESOLVE)),
) -> dict:
    order = db.get(Order, order_id)
    if not order or order.status != OrderStatus.sequestre:
        raise HTTPException(status_code=400, detail="Commande non en séquestre")
    listing = db.get(Listing, order.listing_id)
    if not listing:
        raise HTTPException(status_code=404, detail="Annonce introuvable")
    release_to_seller(db, order=order, listing=listing)
    if order.dispute and order.dispute.status == DisputeStatus.open:
        order.dispute.status = DisputeStatus.resolved_payout
        order.dispute.resolved_at = datetime.now(timezone.utc)
        if body.note:
            order.dispute.admin_note = body.note[:500]
    log_admin_action(
        db,
        actor=staff,
        action="escrow.release_seller",
        resource_type="order",
        resource_id=order.id,
        ip_address=client_ip(request),
    )
    db.commit()
    return {"ok": True, "status": order.status.value}


@router.post("/escrow/orders/{order_id}/refund-buyer")
def admin_refund_buyer(
    order_id: int,
    body: AdminOrderResolveRequest,
    request: Request,
    db: Session = Depends(get_db),
    staff: User = Depends(require_permission(PERM_ESCROW_RESOLVE)),
) -> dict:
    order = db.get(Order, order_id)
    if not order or order.status not in (OrderStatus.sequestre, OrderStatus.succes):
        raise HTTPException(status_code=400, detail="Remboursement impossible")
    listing = db.get(Listing, order.listing_id)
    if not listing:
        raise HTTPException(status_code=404, detail="Annonce introuvable")
    refund_buyer(db, order=order, listing=listing, note=body.note)
    log_admin_action(
        db,
        actor=staff,
        action="escrow.refund_buyer",
        resource_type="order",
        resource_id=order.id,
        ip_address=client_ip(request),
    )
    db.commit()
    return {"ok": True, "status": order.status.value}
