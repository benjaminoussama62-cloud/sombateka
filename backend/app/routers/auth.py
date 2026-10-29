import hashlib
import logging
import secrets
from datetime import datetime, timedelta, timezone

from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy import select, update
from sqlalchemy.exc import IntegrityError, SQLAlchemyError
from sqlalchemy.orm import Session

from app.db import get_db
from app.models import EmailOtp, PhoneOtp, User, UserRole
from app.schemas import (
    Admin2FAConfirmSetupRequest,
    Admin2FAVerifyRequest,
    AdminLoginResponse,
    DevLoginRequest,
    EmailOtpSendRequest,
    EmailOtpVerifyRequest,
    LoginRequest,
    MeResponse,
    OtpSendRequest,
    OtpSendResponse,
    OtpVerifyRequest,
    PasswordForgotRequest,
    PasswordResetRequest,
    PhoneLinkSendRequest,
    PhoneLinkVerifyRequest,
    RegisterRequest,
    SocialLoginRequest,
    TokenResponse,
)
from app.security import create_access_token, create_admin_2fa_challenge, decode_admin_2fa_challenge
from app.deps import get_current_user
from app.constants import DEV_ADMIN_PHONE
from app.services.phone_identity import is_synthetic_phone
from app.services.redis_client import get_redis
from app.settings import settings

router = APIRouter(prefix="/auth", tags=["auth"])

logger = logging.getLogger(__name__)

OTP_MAX_ATTEMPTS = 5
OTP_SEND_LIMIT_PER_HOUR = 5


def _phone_otp_enabled() -> bool:
    return bool(settings.allow_phone_otp) and not settings.is_production


def _reject_phone_otp() -> None:
    raise HTTPException(
        status_code=410,
        detail="Connexion par SMS indisponible. Utilisez e-mail, Google ou Apple.",
    )


def _reject_passwordless_email_otp() -> None:
    raise HTTPException(
        status_code=410,
        detail="Connexion par code e-mail indisponible. Utilisez e-mail + mot de passe, Google ou Apple.",
    )


def _otp_send_rate_key(kind: str, identifier: str) -> str:
    hour = int(datetime.now(timezone.utc).timestamp()) // 3600
    return f"rl:otp_send:{kind}:{identifier}:{hour}"


def _enforce_otp_send_rate(kind: str, identifier: str) -> None:
    if not settings.use_redis_rate_limit:
        return
    redis = get_redis()
    if not redis:
        return
    key = _otp_send_rate_key(kind, identifier)
    try:
        count = redis.incr(key)
        if count == 1:
            redis.expire(key, 3700)
        if count > OTP_SEND_LIMIT_PER_HOUR:
            raise HTTPException(
                status_code=429,
                detail="Trop de codes envoyés. Réessayez dans une heure.",
            )
    except HTTPException:
        raise
    except Exception:
        pass


def _otp_codes_match(stored: str, provided: str) -> bool:
    return secrets.compare_digest(stored.strip(), provided.strip())


def _generate_otp_code() -> str:
    return f"{secrets.randbelow(1_000_000):06d}"


def _normalize_phone(phone_e164: str) -> str:
    p = phone_e164.strip().replace(" ", "")
    if not p.startswith("+"):
        raise HTTPException(status_code=400, detail="phone_e164 must be in E.164 format, e.g. +243...")
    if len(p) < 8 or len(p) > 32:
        raise HTTPException(status_code=400, detail="Invalid phone length")
    return p


def _normalize_email(email: str, *, require_real: bool = False) -> str:
    from app.services.identity_validation import normalize_and_validate_email
    from app.services.email import normalize_email

    try:
        if require_real:
            return normalize_and_validate_email(email)
        return normalize_email(email)
    except ValueError as exc:
        raise HTTPException(status_code=400, detail=str(exc)) from exc


def _normalize_rdc_phone(phone_e164: str) -> str:
    from app.services.identity_validation import validate_rdc_mobile

    try:
        return validate_rdc_mobile(phone_e164.strip().replace(" ", ""))
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


def _phone_account_ready(user: User | None) -> bool:
    return user is not None and bool(user.is_phone_verified)


def _email_account_ready(user: User | None) -> bool:
    return (
        user is not None
        and bool(user.email_verified)
        and bool(user.password_hash)
    )


def _validate_password_strength(password: str) -> None:
    if len(password.strip()) < 8:
        raise HTTPException(status_code=400, detail="Mot de passe : 8 caractères minimum.")
    if password.strip() != password:
        raise HTTPException(status_code=400, detail="Mot de passe invalide.")


def _verify_and_consume_email_otp(
    db: Session,
    *,
    email: str,
    purpose: str,
    code: str,
) -> None:
    normalized = _verify_otp_code(code)
    now = datetime.now(timezone.utc)
    otp = db.scalar(
        select(EmailOtp)
        .where(
            EmailOtp.email == email,
            EmailOtp.purpose == purpose,
            EmailOtp.consumed_at.is_(None),
        )
        .order_by(EmailOtp.id.desc())
    )
    if not otp:
        raise HTTPException(status_code=400, detail="Code invalide ou expiré.")
    exp = otp.expires_at
    if exp.tzinfo is None:
        exp = exp.replace(tzinfo=timezone.utc)
    if exp < now:
        raise HTTPException(status_code=400, detail="Code invalide ou expiré.")
    if (otp.attempts or 0) >= OTP_MAX_ATTEMPTS:
        raise HTTPException(status_code=429, detail="Trop de tentatives. Demandez un nouveau code.")
    if not _otp_codes_match(otp.code, normalized):
        otp.attempts = (otp.attempts or 0) + 1
        db.commit()
        raise HTTPException(status_code=400, detail="Code invalide ou expiré.")
    otp.consumed_at = now


def _send_email_otp_record(
    db: Session,
    *,
    email: str,
    purpose: str,
    user_id: int | None = None,
) -> tuple[str, datetime, bool]:
    """Crée un OTP e-mail et l'envoie. Retourne (code, expires_at, email_sent)."""
    from app.services.email import send_otp_email

    code = _generate_otp_code()
    now = datetime.now(timezone.utc)
    expires_at = now + timedelta(minutes=10)

    db.execute(
        update(EmailOtp)
        .where(
            EmailOtp.email == email,
            EmailOtp.purpose == purpose,
            EmailOtp.consumed_at.is_(None),
        )
        .values(consumed_at=now)
    )

    otp = EmailOtp(
        email=email,
        purpose=purpose,
        code=code,
        attempts=0,
        user_id=user_id,
        expires_at=expires_at,
    )
    db.add(otp)
    db.commit()

    email_sent = send_otp_email(email, code, purpose=purpose)
    if not email_sent and settings.is_production and not settings.expose_otp_in_response:
        raise HTTPException(
            status_code=503,
            detail="Impossible d'envoyer l'e-mail pour le moment. Réessayez dans quelques minutes.",
        )
    return code, expires_at, email_sent


@router.post("/register", response_model=TokenResponse)
def register_account(payload: RegisterRequest, db: Session = Depends(get_db)) -> TokenResponse:
    """Inscription email + mot de passe + téléphone (sans SMS)."""
    from app.startup import ensure_register_schema

    try:
        ensure_register_schema()

        email = _normalize_email(payload.email, require_real=True)
        phone = _normalize_rdc_phone(payload.phone_e164)
        if is_synthetic_phone(phone):
            raise HTTPException(status_code=400, detail="Numéro de téléphone invalide.")
        _validate_password_strength(payload.password)

        from app.services.admin_passwords import hash_admin_password

        now = datetime.now(timezone.utc)
        display = payload.display_name.strip()
        pwd_hash = hash_admin_password(payload.password)

        existing_email = db.scalar(select(User).where(User.email == email))
        if existing_email:
            raise HTTPException(
                status_code=409,
                detail="Cet e-mail est déjà associé à un compte. Connectez-vous ou utilisez une autre adresse.",
            )

        existing_phone = db.scalar(select(User).where(User.phone_e164 == phone))
        if existing_phone:
            raise HTTPException(
                status_code=409,
                detail="Ce numéro est déjà associé à un compte. Utilisez un autre numéro ou connectez-vous.",
            )

        user = User(
            phone_e164=phone,
            email=email,
            display_name=display,
            role=UserRole.user,
            password_hash=pwd_hash,
            email_verified=False,
            is_phone_verified=True,
            phone_linked_at=now,
            created_at=now,
            updated_at=now,
        )
        db.add(user)

        db.commit()
        db.refresh(user)
        role = user.role.value if isinstance(user.role, UserRole) else str(user.role)
        token = create_access_token(user_id=user.id, role=role)
        return TokenResponse(access_token=token)
    except HTTPException:
        db.rollback()
        raise
    except IntegrityError as exc:
        db.rollback()
        raise HTTPException(status_code=409, detail="Compte déjà existant.") from exc
    except SQLAlchemyError as exc:
        db.rollback()
        logger.exception("register_account db error: %s", exc)
        detail = "Inscription impossible. Réessayez."
        err = str(getattr(exc, "orig", exc)).lower()
        if "password_hash" in err and "does not exist" in err:
            detail = "Inscription impossible : base de données à mettre à jour (password_hash). Relancez fix-register-prod.ps1."
        elif "email" in err and "does not exist" in err:
            detail = "Inscription impossible : base de données à mettre à jour (email). Relancez fix-register-prod.ps1."
        raise HTTPException(status_code=500, detail=detail) from exc
    except Exception as exc:
        db.rollback()
        logger.exception("register_account unexpected error")
        raise HTTPException(status_code=500, detail="Inscription impossible. Réessayez.") from exc


@router.post("/login", response_model=TokenResponse)
def login_with_password(payload: LoginRequest, db: Session = Depends(get_db)) -> TokenResponse:
    """Connexion par e-mail et mot de passe."""
    email = _normalize_email(payload.email)
    user = db.scalar(select(User).where(User.email == email))
    if not user:
        raise HTTPException(
            status_code=404,
            detail="Aucun compte avec cet e-mail. Créez un compte d'abord.",
        )
    if not user.password_hash:
        raise HTTPException(
            status_code=403,
            detail="Ce compte utilise Google ou Apple. Connectez-vous avec ce service, puis finalisez votre compte dans Paramètres.",
        )
    if user.is_banned:
        raise HTTPException(status_code=403, detail="Compte suspendu.")

    from app.services.admin_passwords import verify_admin_password

    if not verify_admin_password(payload.password, user.password_hash):
        raise HTTPException(status_code=401, detail="E-mail ou mot de passe incorrect.")

    token = create_access_token(user_id=user.id, role=str(user.role.value))
    return TokenResponse(access_token=token)


@router.post("/password/forgot", response_model=OtpSendResponse)
def password_forgot(payload: PasswordForgotRequest, db: Session = Depends(get_db)) -> OtpSendResponse:
    """Envoie un code de réinitialisation par e-mail."""
    email = _normalize_email(payload.email, require_real=True)
    _enforce_otp_send_rate("email_reset", email)

    user = db.scalar(select(User).where(User.email == email))
    if not user or not user.password_hash:
        raise HTTPException(
            status_code=404,
            detail="Aucun compte avec mot de passe pour cet e-mail. Créez un compte ou utilisez Google/Apple.",
        )
    if user.is_banned:
        raise HTTPException(status_code=403, detail="Compte suspendu.")

    code, expires_at, email_sent = _send_email_otp_record(
        db, email=email, purpose="reset_password", user_id=user.id
    )
    dev_code = code if settings.expose_otp_in_response else None
    return OtpSendResponse(
        dev_code=dev_code,
        expires_at=expires_at,
        sms_sent=False,
        email_sent=email_sent,
    )


@router.post("/password/reset", response_model=TokenResponse)
def password_reset(payload: PasswordResetRequest, db: Session = Depends(get_db)) -> TokenResponse:
    """Réinitialise le mot de passe avec le code reçu par e-mail."""
    email = _normalize_email(payload.email, require_real=True)
    _validate_password_strength(payload.new_password)
    _verify_and_consume_email_otp(db, email=email, purpose="reset_password", code=payload.code)

    user = db.scalar(select(User).where(User.email == email))
    if not user:
        raise HTTPException(status_code=404, detail="Compte introuvable.")
    if user.is_banned:
        raise HTTPException(status_code=403, detail="Compte suspendu.")

    from app.services.admin_passwords import hash_admin_password

    user.password_hash = hash_admin_password(payload.new_password)
    user.updated_at = datetime.now(timezone.utc)
    db.commit()
    db.refresh(user)

    role = user.role.value if isinstance(user.role, UserRole) else str(user.role)
    token = create_access_token(user_id=user.id, role=role)
    return TokenResponse(access_token=token)


@router.post("/otp/send", response_model=OtpSendResponse)
def send_otp(payload: OtpSendRequest, db: Session = Depends(get_db)) -> OtpSendResponse:
    if not _phone_otp_enabled():
        _reject_phone_otp()
    phone = _normalize_phone(payload.phone_e164)
    if is_synthetic_phone(phone):
        raise HTTPException(status_code=400, detail="Numéro invalide")
    _enforce_otp_send_rate("phone", phone)
    purpose = payload.purpose or "login"
    code = _generate_otp_code()

    now = datetime.now(timezone.utc)
    expires_at = now + timedelta(minutes=10)

    user = db.scalar(select(User).where(User.phone_e164 == phone))
    if purpose == "login":
        if not _phone_account_ready(user):
            raise HTTPException(
                status_code=404,
                detail="Aucun compte avec ce numéro. Créez un compte d'abord.",
            )
    else:
        if _phone_account_ready(user):
            raise HTTPException(
                status_code=409,
                detail="Un compte existe déjà avec ce numéro. Connectez-vous.",
            )
        if not user:
            user = User(
                phone_e164=phone,
                role=UserRole.user,
                display_name=payload.display_name.strip() if payload.display_name else None,
            )
            db.add(user)
            db.flush()
        elif payload.display_name and not user.display_name:
            user.display_name = payload.display_name.strip() or None

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
    if not sms_sent and settings.is_production and not settings.expose_otp_in_response:
        raise HTTPException(
            status_code=503,
            detail="Impossible d'envoyer le SMS pour le moment. Réessayez dans quelques minutes.",
        )
    dev_code = code if settings.expose_otp_in_response else None
    return OtpSendResponse(dev_code=dev_code, expires_at=expires_at, sms_sent=sms_sent)


@router.post("/otp/verify", response_model=TokenResponse)
def verify_otp(payload: OtpVerifyRequest, db: Session = Depends(get_db)) -> TokenResponse:
    if not _phone_otp_enabled():
        _reject_phone_otp()
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
    if (otp.attempts or 0) >= OTP_MAX_ATTEMPTS:
        raise HTTPException(status_code=429, detail="Too many attempts. Request a new code.")
    if not _otp_codes_match(otp.code, code):
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
    purpose = payload.purpose or "login"
    # Passwordless login/register via OTP désactivé — Resend sert verify email + reset password.
    if purpose in {"login", "register"}:
        _reject_passwordless_email_otp()
    require_real = purpose in {"register", "reset_password"}
    email = _normalize_email(payload.email, require_real=require_real)
    _enforce_otp_send_rate("email", email)

    user = db.scalar(select(User).where(User.email == email))
    user_id: int | None = None

    if purpose == "login":
        if not _email_account_ready(user):
            raise HTTPException(
                status_code=404,
                detail="Aucun compte avec cet e-mail. Créez un compte d'abord.",
            )
        user_id = user.id if user else None
    elif purpose == "register":
        if user and user.password_hash and user.email_verified:
            raise HTTPException(
                status_code=409,
                detail="Un compte existe déjà avec cet e-mail. Connectez-vous.",
            )
        user_id = None
    elif purpose == "reset_password":
        if not user or not user.password_hash:
            raise HTTPException(
                status_code=404,
                detail="Aucun compte avec mot de passe pour cet e-mail.",
            )
        user_id = user.id
    elif purpose == "verify_email":
        raise HTTPException(
            status_code=400,
            detail="Utilisez Paramètres → Vérifier mon compte dans l'application.",
        )
    else:
        raise HTTPException(status_code=400, detail="Purpose OTP invalide.")

    code, expires_at, email_sent = _send_email_otp_record(
        db, email=email, purpose=purpose, user_id=user_id
    )
    dev_code = code if settings.expose_otp_in_response else None
    return OtpSendResponse(
        dev_code=dev_code,
        expires_at=expires_at,
        sms_sent=False,
        email_sent=email_sent,
    )


@router.post("/email/otp/verify", response_model=TokenResponse)
def verify_email_otp(payload: EmailOtpVerifyRequest, db: Session = Depends(get_db)) -> TokenResponse:
    _reject_passwordless_email_otp()
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
    if (otp.attempts or 0) >= OTP_MAX_ATTEMPTS:
        raise HTTPException(status_code=429, detail="Too many attempts. Request a new code.")
    if not _otp_codes_match(otp.code, code):
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


def _upsert_social_user(
    db: Session,
    *,
    provider: str,
    subject: str,
    email: str | None,
    display_name: str | None,
) -> User:
    phone = _social_phone(provider, subject)
    normalized_email = None
    if email:
        try:
            normalized_email = _normalize_email(email)
        except HTTPException:
            normalized_email = None

    user = db.scalar(select(User).where(User.phone_e164 == phone))
    if not user and normalized_email:
        user = db.scalar(select(User).where(User.email == normalized_email))

    if not user:
        user = User(
            phone_e164=phone,
            role=UserRole.user,
            display_name=display_name or (normalized_email.split("@")[0] if normalized_email else f"Utilisateur {provider.title()}"),
            email=normalized_email,
            email_verified=bool(normalized_email),
        )
        db.add(user)
        db.flush()
    else:
        if is_synthetic_phone(user.phone_e164):
            user.phone_e164 = phone
        if display_name and not user.display_name:
            user.display_name = display_name
        if normalized_email:
            user.email = normalized_email
            user.email_verified = True

    if is_synthetic_phone(user.phone_e164):
        user.is_phone_verified = False
    user.updated_at = datetime.now(timezone.utc)
    db.commit()
    return user


@router.get("/social/status")
def social_auth_status() -> dict:
    raw = (settings.google_oauth_client_ids or "").strip()
    google_ids = [p.strip() for p in raw.split(",") if p.strip()]
    apple_id = (settings.apple_oauth_client_id or "").strip()
    enabled = bool(settings.enable_social_login and (google_ids or apple_id))
    return {
        "enabled": enabled,
        "google": bool(google_ids),
        "apple": bool(apple_id),
    }


@router.post("/social/login", response_model=TokenResponse)
def social_login(payload: SocialLoginRequest, db: Session = Depends(get_db)) -> TokenResponse:
    """Connexion Google / Apple — id_token vérifié en production."""
    from app.services.social_oauth import (
        SocialTokenError,
        fetch_apple_email_from_token,
        social_login_enabled,
        verify_apple_id_token,
        verify_google_access_token,
        verify_google_id_token,
    )

    if settings.environment == "dev" and not payload.id_token:
        if not payload.subject:
            raise HTTPException(status_code=400, detail="subject requis en mode dev")
        user = _upsert_social_user(
            db,
            provider=payload.provider,
            subject=payload.subject.strip(),
            email=payload.email,
            display_name=payload.display_name,
        )
        token = create_access_token(user_id=user.id, role=str(user.role.value))
        return TokenResponse(access_token=token)

    if not social_login_enabled():
        raise HTTPException(status_code=503, detail="Connexion Google/Apple non disponible")
    if not payload.id_token and not payload.access_token:
        raise HTTPException(status_code=400, detail="id_token ou access_token requis")

    try:
        if payload.provider == "google":
            if payload.id_token:
                claims = verify_google_id_token(payload.id_token)
            else:
                claims = verify_google_access_token(payload.access_token or "")
            subject = str(claims["sub"])
            email = claims.get("email") if isinstance(claims.get("email"), str) else payload.email
            name = claims.get("name") if isinstance(claims.get("name"), str) else payload.display_name
        else:
            claims = verify_apple_id_token(payload.id_token)
            subject = str(claims["sub"])
            email = claims.get("email") if isinstance(claims.get("email"), str) else payload.email
            if not email:
                email = fetch_apple_email_from_token(payload.id_token)
            given = payload.display_name
            if not given and isinstance(claims.get("email"), str):
                given = claims["email"].split("@")[0]
            name = given
    except SocialTokenError as exc:
        raise HTTPException(status_code=401, detail=str(exc)) from exc

    try:
        user = _upsert_social_user(
            db,
            provider=payload.provider,
            subject=subject,
            email=email,
            display_name=name,
        )
    except IntegrityError as exc:
        db.rollback()
        raise HTTPException(
            status_code=409,
            detail="Compte déjà lié à un autre identifiant. Connectez-vous par téléphone ou email.",
        ) from exc
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


@router.post("/admin/login", response_model=AdminLoginResponse)
def admin_panel_login(payload: DevLoginRequest, db: Session = Depends(get_db)) -> AdminLoginResponse:
    """
    Connexion panneau /admin — étape 1 (mot de passe).
    2FA TOTP obligatoire : setup à la 1ère connexion, puis code Authenticator.
    """
    from app.admin_rbac import is_staff
    from app.services.admin_passwords import verify_admin_password
    from app.services import admin_totp

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
        password_ok = False
        if global_pwd and isinstance(payload.password, str):
            if len(payload.password) == len(global_pwd):
                password_ok = secrets.compare_digest(payload.password, global_pwd)

    if not password_ok:
        if settings.environment == "dev" and not user.admin_password_hash:
            raise HTTPException(
                status_code=401,
                detail="Mot de passe incorrect ou compte sans mot de passe admin. Lancez: python scripts/ensure-admin.py",
            )
        raise HTTPException(status_code=401, detail="Identifiants invalides")

    user.is_phone_verified = True
    user.updated_at = datetime.now(timezone.utc)
    role = str(user.role.value)

    if user.admin_totp_enabled and user.admin_totp_secret:
        db.commit()
        challenge = create_admin_2fa_challenge(
            user_id=user.id,
            role=role,
            purpose="verify",
            minutes=10,
        )
        return AdminLoginResponse(
            status="needs_2fa",
            challenge_token=challenge,
            message="Entrez le code de votre application Authenticator",
        )

    secret = admin_totp.generate_secret()
    account = user.phone_e164 or f"admin-{user.id}"
    uri = admin_totp.provisioning_uri(secret=secret, account_name=account)
    qr = admin_totp.qr_data_url(uri)
    db.commit()
    challenge = create_admin_2fa_challenge(
        user_id=user.id,
        role=role,
        purpose="setup",
        totp_secret=secret,
        minutes=15,
    )
    return AdminLoginResponse(
        status="needs_2fa_setup",
        challenge_token=challenge,
        otpauth_uri=uri,
        totp_secret=secret,
        qr_data_url=qr,
        message="Scannez le QR avec Google Authenticator / Authy, puis entrez le code à 6 chiffres",
    )


@router.post("/admin/2fa/verify", response_model=AdminLoginResponse)
def admin_2fa_verify(payload: Admin2FAVerifyRequest, db: Session = Depends(get_db)) -> AdminLoginResponse:
    """Étape 2 — valider le code TOTP (connexion habituelle)."""
    from app.admin_rbac import is_staff
    from app.services import admin_totp

    try:
        claims = decode_admin_2fa_challenge(payload.challenge_token)
    except Exception:
        raise HTTPException(status_code=401, detail="Session 2FA expirée — reconnectez-vous") from None
    if claims.get("purpose") != "verify":
        raise HTTPException(status_code=400, detail="Challenge invalide")
    user = db.get(User, int(claims["sub"]))
    if not user or user.is_banned or not is_staff(user.role):
        raise HTTPException(status_code=401, detail="Identifiants invalides")
    if not user.admin_totp_enabled or not user.admin_totp_secret:
        raise HTTPException(status_code=400, detail="2FA non configuré")
    if not admin_totp.verify_code(user.admin_totp_secret, payload.code):
        raise HTTPException(status_code=401, detail="Code 2FA invalide")
    token = create_access_token(
        user_id=user.id,
        role=str(user.role.value),
        minutes=settings.admin_session_minutes,
        amr=["pwd", "otp"],
    )
    return AdminLoginResponse(status="ok", access_token=token)


@router.post("/admin/2fa/confirm-setup", response_model=AdminLoginResponse)
def admin_2fa_confirm_setup(
    payload: Admin2FAConfirmSetupRequest, db: Session = Depends(get_db)
) -> AdminLoginResponse:
    """Première activation 2FA — confirme le scan QR + code."""
    from app.admin_rbac import is_staff
    from app.services import admin_totp

    try:
        claims = decode_admin_2fa_challenge(payload.challenge_token)
    except Exception:
        raise HTTPException(status_code=401, detail="Session 2FA expirée — reconnectez-vous") from None
    if claims.get("purpose") != "setup":
        raise HTTPException(status_code=400, detail="Challenge invalide")
    secret = claims.get("totp_secret")
    if not secret:
        raise HTTPException(status_code=400, detail="Secret 2FA manquant")
    user = db.get(User, int(claims["sub"]))
    if not user or user.is_banned or not is_staff(user.role):
        raise HTTPException(status_code=401, detail="Identifiants invalides")
    if not admin_totp.verify_code(secret, payload.code):
        raise HTTPException(status_code=401, detail="Code 2FA invalide — vérifiez l'heure du téléphone")
    user.admin_totp_secret = secret
    user.admin_totp_enabled = True
    user.admin_totp_confirmed_at = datetime.now(timezone.utc)
    user.updated_at = datetime.now(timezone.utc)
    db.commit()
    token = create_access_token(
        user_id=user.id,
        role=str(user.role.value),
        minutes=settings.admin_session_minutes,
        amr=["pwd", "otp"],
    )
    return AdminLoginResponse(
        status="ok",
        access_token=token,
        message="2FA activé — conservez votre application Authenticator",
    )


@router.get("/admin/config")
def admin_panel_config() -> dict:
    """Config publique minimale pour l'UI admin (sans secret)."""
    return {
        "environment": settings.environment,
        "allow_password_login": bool(settings.admin_panel_password or settings.allow_dev_password_login),
        "session_minutes": settings.admin_session_minutes,
        "require_2fa": True,
    }


@router.post("/phone/link/send", response_model=OtpSendResponse)
def send_phone_link_otp(
    payload: PhoneLinkSendRequest,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
) -> OtpSendResponse:
    """Ajouter ou remplacer un numéro réel (comptes email / Google / Apple)."""
    if not _phone_otp_enabled():
        _reject_phone_otp()
    phone = _normalize_phone(payload.phone_e164)
    if is_synthetic_phone(phone):
        raise HTTPException(status_code=400, detail="Numéro invalide")
    _enforce_otp_send_rate("phone_link", f"{current_user.id}:{phone}")

    existing = db.scalar(select(User).where(User.phone_e164 == phone, User.id != current_user.id))
    if existing and _phone_account_ready(existing):
        raise HTTPException(status_code=409, detail="Ce numéro est déjà utilisé par un autre compte.")

    code = _generate_otp_code()
    now = datetime.now(timezone.utc)
    expires_at = now + timedelta(minutes=10)

    db.execute(
        update(PhoneOtp)
        .where(
            PhoneOtp.phone_e164 == phone,
            PhoneOtp.purpose == "link",
            PhoneOtp.consumed_at.is_(None),
        )
        .values(consumed_at=now)
    )

    otp = PhoneOtp(
        phone_e164=phone,
        purpose="link",
        code=code,
        attempts=0,
        user_id=current_user.id,
        expires_at=expires_at,
    )
    db.add(otp)
    db.commit()

    from app.services.sms import send_otp_sms

    sms_sent = send_otp_sms(phone, code)
    if not sms_sent and settings.is_production and not settings.expose_otp_in_response:
        raise HTTPException(status_code=503, detail="Impossible d'envoyer le SMS pour le moment.")
    dev_code = code if settings.expose_otp_in_response else None
    return OtpSendResponse(dev_code=dev_code, expires_at=expires_at, sms_sent=sms_sent)


@router.post("/phone/link/verify", response_model=MeResponse)
def verify_phone_link(
    payload: PhoneLinkVerifyRequest,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
) -> MeResponse:
    if not _phone_otp_enabled():
        _reject_phone_otp()
    phone = _normalize_phone(payload.phone_e164)
    code = _verify_otp_code(payload.code)
    now = datetime.now(timezone.utc)

    otp = db.scalar(
        select(PhoneOtp)
        .where(
            PhoneOtp.phone_e164 == phone,
            PhoneOtp.purpose == "link",
            PhoneOtp.user_id == current_user.id,
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
    if (otp.attempts or 0) >= OTP_MAX_ATTEMPTS:
        raise HTTPException(status_code=429, detail="Too many attempts. Request a new code.")
    if not _otp_codes_match(otp.code, code):
        otp.attempts = (otp.attempts or 0) + 1
        db.commit()
        raise HTTPException(status_code=400, detail="Invalid or expired code")

    conflict = db.scalar(select(User).where(User.phone_e164 == phone, User.id != current_user.id))
    if conflict and _phone_account_ready(conflict):
        raise HTTPException(status_code=409, detail="Ce numéro est déjà utilisé.")

    otp.consumed_at = now
    current_user.phone_e164 = phone
    current_user.is_phone_verified = True
    current_user.updated_at = now
    db.commit()
    db.refresh(current_user)

    from app.services.user_public import user_to_public

    return MeResponse(user=user_to_public(current_user, db))


@router.get("/me", response_model=MeResponse)
def me(
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
) -> MeResponse:
    from app.services.user_public import user_to_public

    return MeResponse(user=user_to_public(current_user, db))

