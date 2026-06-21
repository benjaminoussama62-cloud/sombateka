import hashlib
import random
from datetime import datetime, timedelta, timezone

from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy import select, update
from sqlalchemy.orm import Session

from app.db import get_db
from app.models import EmailOtp, PhoneOtp, User, UserRole
from app.schemas import (
    DevLoginRequest,
    EmailOtpSendRequest,
    EmailOtpVerifyRequest,
    MeResponse,
    OtpSendRequest,
    OtpSendResponse,
    OtpVerifyRequest,
    SocialLoginRequest,
    TokenResponse,
)
from app.security import create_access_token
from app.deps import get_current_user
from app.constants import DEV_ADMIN_PHONE
from app.settings import settings

router = APIRouter(prefix="/auth", tags=["auth"])


def _normalize_phone(phone_e164: str) -> str:
    p = phone_e164.strip().replace(" ", "")
    if not p.startswith("+"):
        raise HTTPException(status_code=400, detail="phone_e164 must be in E.164 format, e.g. +243...")
    if len(p) < 8 or len(p) > 32:
        raise HTTPException(status_code=400, detail="Invalid phone length")
    return p


def _normalize_email(email: str) -> str:
    from app.services.email import normalize_email

    try:
        return normalize_email(email)
    except ValueError as exc:
        raise HTTPException(status_code=400, detail=str(exc)) from exc


def _synthetic_phone_for_email(email: str) -> str:
    digest = hashlib.sha256(email.encode()).hexdigest()[:12]
    return f"+999{digest}"


def _verify_otp_code(raw_code: str) -> str:
    if not raw_code.strip():
        raise HTTPException(status_code=400, detail="Missing code")
    digits = "".join(c for c in raw_code if c.isdigit())
    if not digits:
        raise HTTPException(status_code=400, detail="Invalid code format")
    return digits.zfill(6)[-6:]


@router.post("/otp/send", response_model=OtpSendResponse)
def send_otp(payload: OtpSendRequest, db: Session = Depends(get_db)) -> OtpSendResponse:
    phone = _normalize_phone(payload.phone_e164)
    code = f"{random.randint(0, 999999):06d}"

    now = datetime.now(timezone.utc)
    expires_at = now + timedelta(minutes=10)

    user = db.scalar(select(User).where(User.phone_e164 == phone))
    if not user:
        user = User(phone_e164=phone, role=UserRole.user)
        db.add(user)
        db.flush()

    # Un seul code actif : invalide les OTP précédents non utilisés.
    db.execute(
        update(PhoneOtp)
        .where(
            PhoneOtp.phone_e164 == phone,
            PhoneOtp.purpose == "login",
            PhoneOtp.consumed_at.is_(None),
        )
        .values(consumed_at=now)
    )

    otp = PhoneOtp(
        phone_e164=phone,
        purpose="login",
        code=code,
        attempts=0,
        user_id=user.id,
        expires_at=expires_at,
    )
    db.add(otp)
    db.commit()

    from app.services.sms import send_otp_sms

    sms_sent = send_otp_sms(phone, code)
    dev_code = code if settings.expose_otp_in_response else None
    return OtpSendResponse(dev_code=dev_code, expires_at=expires_at, sms_sent=sms_sent)


@router.post("/otp/verify", response_model=TokenResponse)
def verify_otp(payload: OtpVerifyRequest, db: Session = Depends(get_db)) -> TokenResponse:
    phone = _normalize_phone(payload.phone_e164)
    code = _verify_otp_code(payload.code)

    now = datetime.now(timezone.utc)
    otp = db.scalar(
        select(PhoneOtp)
        .where(
            PhoneOtp.phone_e164 == phone,
            PhoneOtp.purpose == "login",
            PhoneOtp.consumed_at.is_(None),
        )
        .order_by(PhoneOtp.id.desc())
    )
    if not otp:
        raise HTTPException(status_code=400, detail="Invalid or expired code")
    exp = otp.expires_at
    if exp.tzinfo is None:
        exp = exp.replace(tzinfo=timezone.utc)
    if exp < now:
        raise HTTPException(status_code=400, detail="Invalid or expired code")
    if otp.code != code:
        otp.attempts = (otp.attempts or 0) + 1
        db.commit()
        raise HTTPException(status_code=400, detail="Invalid or expired code")

    otp.consumed_at = now

    user = db.get(User, otp.user_id) if otp.user_id else None
    if not user:
        raise HTTPException(status_code=400, detail="User not found")
    if user.is_banned:
        raise HTTPException(status_code=403, detail="User banned")

    user.is_phone_verified = True
    user.updated_at = datetime.utcnow()
    db.commit()

    token = create_access_token(user_id=user.id, role=str(user.role.value))
    return TokenResponse(access_token=token)


@router.post("/email/otp/send", response_model=OtpSendResponse)
def send_email_otp(payload: EmailOtpSendRequest, db: Session = Depends(get_db)) -> OtpSendResponse:
    email = _normalize_email(payload.email)
    code = f"{random.randint(0, 999999):06d}"
    now = datetime.now(timezone.utc)
    expires_at = now + timedelta(minutes=10)

    user = db.scalar(select(User).where(User.email == email))
    if not user:
        phone = _synthetic_phone_for_email(email)
        existing_phone = db.scalar(select(User).where(User.phone_e164 == phone))
        if existing_phone:
            user = existing_phone
            user.email = email
        else:
            user = User(
                phone_e164=phone,
                email=email,
                role=UserRole.user,
                display_name=payload.display_name.strip() if payload.display_name else None,
            )
            db.add(user)
            db.flush()
    elif payload.display_name and not user.display_name:
        user.display_name = payload.display_name.strip() or None

    db.execute(
        update(EmailOtp)
        .where(
            EmailOtp.email == email,
            EmailOtp.purpose == "login",
            EmailOtp.consumed_at.is_(None),
        )
        .values(consumed_at=now)
    )

    otp = EmailOtp(
        email=email,
        purpose="login",
        code=code,
        attempts=0,
        user_id=user.id,
        expires_at=expires_at,
    )
    db.add(otp)
    db.commit()

    from app.services.email import send_otp_email

    email_sent = send_otp_email(email, code)
    dev_code = code if settings.expose_otp_in_response else None
    return OtpSendResponse(
        dev_code=dev_code,
        expires_at=expires_at,
        sms_sent=False,
        email_sent=email_sent,
    )


@router.post("/email/otp/verify", response_model=TokenResponse)
def verify_email_otp(payload: EmailOtpVerifyRequest, db: Session = Depends(get_db)) -> TokenResponse:
    email = _normalize_email(payload.email)
    code = _verify_otp_code(payload.code)
    now = datetime.now(timezone.utc)

    otp = db.scalar(
        select(EmailOtp)
        .where(
            EmailOtp.email == email,
            EmailOtp.purpose == "login",
            EmailOtp.consumed_at.is_(None),
        )
        .order_by(EmailOtp.id.desc())
    )
    if not otp:
        raise HTTPException(status_code=400, detail="Invalid or expired code")
    exp = otp.expires_at
    if exp.tzinfo is None:
        exp = exp.replace(tzinfo=timezone.utc)
    if exp < now:
        raise HTTPException(status_code=400, detail="Invalid or expired code")
    if otp.code != code:
        otp.attempts = (otp.attempts or 0) + 1
        db.commit()
        raise HTTPException(status_code=400, detail="Invalid or expired code")

    otp.consumed_at = now
    user = db.get(User, otp.user_id) if otp.user_id else None
    if not user:
        raise HTTPException(status_code=400, detail="User not found")
    if user.is_banned:
        raise HTTPException(status_code=403, detail="User banned")

    user.email = email
    user.email_verified = True
    user.updated_at = datetime.now(timezone.utc)
    db.commit()

    token = create_access_token(user_id=user.id, role=str(user.role.value))
    return TokenResponse(access_token=token)


def _social_phone(provider: str, subject: str) -> str:
    digest = hashlib.sha256(f"{provider}:{subject}".encode()).hexdigest()[:12]
    return f"+888{digest}"


@router.post("/social/login", response_model=TokenResponse)
def social_login(payload: SocialLoginRequest, db: Session = Depends(get_db)) -> TokenResponse:
    """Connexion Google / Apple (compte synthétique +888… en base)."""
    if settings.environment != "dev":
        raise HTTPException(status_code=404, detail="Not found")

    phone = _social_phone(payload.provider, payload.subject.strip())
    normalized_email = None
    if payload.email:
        try:
            normalized_email = _normalize_email(payload.email)
        except HTTPException:
            normalized_email = None

    user = db.scalar(select(User).where(User.phone_e164 == phone))
    if not user:
        user = User(
            phone_e164=phone,
            role=UserRole.user,
            display_name=payload.display_name or payload.email or f"Utilisateur {payload.provider.title()}",
            email=normalized_email,
            email_verified=bool(normalized_email),
        )
        db.add(user)
        db.flush()
    elif payload.display_name and not user.display_name:
        user.display_name = payload.display_name
    if normalized_email:
        user.email = normalized_email
        user.email_verified = True

    user.is_phone_verified = True
    user.updated_at = datetime.utcnow()
    db.commit()

    token = create_access_token(user_id=user.id, role=str(user.role.value))
    return TokenResponse(access_token=token)


@router.post("/dev/login", response_model=TokenResponse)
def dev_login(payload: DevLoginRequest, db: Session = Depends(get_db)) -> TokenResponse:
    """
    DEV ONLY: bypass SMS OTP. Disabled unless explicitly allowed in settings.
    """
    if settings.environment != "dev" or not settings.allow_dev_password_login:
        raise HTTPException(status_code=404, detail="Not found")

    if payload.password != settings.dev_login_password:
        raise HTTPException(status_code=401, detail="Invalid password")

    phone = _normalize_phone(payload.phone_e164)
    user = db.scalar(select(User).where(User.phone_e164 == phone))
    if not user:
        user = User(phone_e164=phone, role=UserRole.user)
        db.add(user)
        db.flush()

    user.is_phone_verified = True
    user.updated_at = datetime.utcnow()
    db.commit()

    token = create_access_token(user_id=user.id, role=str(user.role.value))
    return TokenResponse(access_token=token)


@router.post("/admin/login", response_model=TokenResponse)
def admin_panel_login(payload: DevLoginRequest, db: Session = Depends(get_db)) -> TokenResponse:
    """
    Connexion panneau /admin — mot de passe individuel par membre staff.
    Secours super_admin : ADMIN_PANEL_PASSWORD si aucun hash en base.
    """
    from app.admin_rbac import is_staff
    from app.services.admin_passwords import verify_admin_password

    phone = _normalize_phone(payload.phone_e164)
    user = db.scalar(select(User).where(User.phone_e164 == phone))
    if not user:
        raise HTTPException(status_code=401, detail="Identifiants invalides")

    if user.is_banned:
        raise HTTPException(status_code=403, detail="Compte suspendu")

    if not is_staff(user.role):
        raise HTTPException(status_code=403, detail="Accès réservé aux administrateurs")

    password_ok = False
    if user.admin_password_hash:
        password_ok = verify_admin_password(payload.password, user.admin_password_hash)
    elif user.role == UserRole.super_admin:
        global_pwd = settings.admin_panel_password.strip() or settings.dev_login_password
        if settings.is_production and not settings.admin_panel_password.strip():
            raise HTTPException(status_code=503, detail="ADMIN_PANEL_PASSWORD requis en production")
        password_ok = bool(global_pwd) and payload.password == global_pwd

    if not password_ok:
        if settings.environment == "dev" and not user.admin_password_hash:
            raise HTTPException(
                status_code=401,
                detail="Mot de passe incorrect ou compte sans mot de passe admin. Lancez: python scripts/ensure-admin.py",
            )
        raise HTTPException(status_code=401, detail="Identifiants invalides")

    user.is_phone_verified = True
    user.updated_at = datetime.now(timezone.utc)
    db.commit()

    token = create_access_token(
        user_id=user.id,
        role=str(user.role.value),
        minutes=settings.admin_session_minutes,
    )
    return TokenResponse(access_token=token)


@router.get("/admin/config")
def admin_panel_config() -> dict:
    """Config publique minimale pour l'UI admin (sans secret)."""
    return {
        "environment": settings.environment,
        "allow_password_login": bool(settings.admin_panel_password or settings.allow_dev_password_login),
        "session_minutes": settings.admin_session_minutes,
    }


@router.get("/me", response_model=MeResponse)
def me(
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
) -> MeResponse:
    from app.services.user_public import user_to_public

    return MeResponse(user=user_to_public(current_user, db))

