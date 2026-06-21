import logging

from sqlalchemy import delete, select, text

from app.constants import DEMO_SELLER_PHONE, DEV_ADMIN_PHONE
from app.db import Base, SessionLocal, engine
from app.models import Category, Listing, User, UserRole
from app.schema_patches import ensure_userrole_super_admin
from app.services.team_outreach import get_or_create_team_user
from app.settings import settings

logger = logging.getLogger(__name__)


def _ensure_column(table: str, column: str, ddl: str) -> None:
    try:
        with engine.connect() as conn:
            conn.execute(text(f"ALTER TABLE {table} ADD COLUMN {column} {ddl}"))
            conn.commit()
    except Exception:
        pass


def _ensure_user_avatar_column() -> None:
    _ensure_column("users", "avatar_key", "VARCHAR(255)")


def _ensure_user_email_columns() -> None:
    _ensure_column("users", "email", "VARCHAR(255)")
    _ensure_column("users", "email_verified", "BOOLEAN DEFAULT 0")


def _migrate_order_statuses() -> None:
    try:
        with engine.connect() as conn:
            conn.execute(text("UPDATE orders SET status='en_attente' WHERE status='pending'"))
            conn.execute(text("UPDATE orders SET status='sequestre' WHERE status='paid'"))
            conn.commit()
    except Exception:
        pass


def _ensure_schema_patches() -> None:
    _ensure_user_email_columns()
    _ensure_column("listings", "delivery_method", "VARCHAR(32)")
    _ensure_column("listings", "auto_hidden_at", "DATETIME")
    _ensure_column("listings", "auto_hidden_reason", "VARCHAR(64)")
    for col, ddl in (
        ("escrow_started_at", "DATETIME"),
        ("delivery_deadline_at", "DATETIME"),
        ("completed_at", "DATETIME"),
        ("refunded_at", "DATETIME"),
        ("deadline_alert_sent", "BOOLEAN DEFAULT 0"),
    ):
        _ensure_column("orders", col, ddl)
    _migrate_order_statuses()
    _ensure_column("users", "privacy_profile_public", "BOOLEAN DEFAULT 1")
    _ensure_column("users", "privacy_show_phone", "BOOLEAN DEFAULT 0")
    _ensure_column("users", "privacy_allow_messages", "BOOLEAN DEFAULT 1")
    _ensure_column("users", "admin_password_hash", "VARCHAR(255)")
    _ensure_column("cart_items", "variant_size", "VARCHAR(32)")
    _ensure_column("cart_items", "variant_color", "VARCHAR(64)")
    _ensure_column("listings", "buyer_id", "INTEGER")
    _ensure_column("listings", "sold_at", "DATETIME")
    _ensure_column("messages", "kind", "VARCHAR(32) DEFAULT 'text'")
    for col, ddl in (
        ("category", "VARCHAR(80)"),
        ("rccm", "VARCHAR(80)"),
        ("tax_id", "VARCHAR(80)"),
        ("legal_representative", "VARCHAR(120)"),
        ("business_address", "VARCHAR(255)"),
        ("contact_phone", "VARCHAR(32)"),
        ("applicant_note", "TEXT"),
        ("internal_review_note", "VARCHAR(500)"),
    ):
        _ensure_column("kyc_applications", col, ddl)


def _ensure_fashion_categories(db) -> None:
    """Ajoute les catégories mode détaillées si absentes."""
    names = [
        ("Mode & Vêtements", "shirt"),
        ("Chaussures", "shoe"),
        ("Baskets & Sneakers", "shoe"),
        ("Souliers", "shoe"),
        ("Sandales", "shoe"),
        ("Pantalons", "pants"),
        ("Jeans", "pants"),
        ("Chemises & Hauts", "shirt"),
        ("Robes & Jupes", "dress"),
        ("Vestes & Manteaux", "coat"),
        ("Sportswear", "sport"),
        ("Accessoires mode", "bag"),
        ("Bébé & Enfants", "baby"),
    ]
    for name, icon in names:
        if not db.scalar(select(Category).where(Category.name == name)):
            db.add(Category(name=name, icon_key=icon))
    db.commit()


def _purge_demo_listings() -> None:
    """Supprime les annonces du compte démo (ne doivent pas apparaître en prod/dev UI)."""
    db = SessionLocal()
    try:
        dev = db.scalar(select(User).where(User.phone_e164 == DEMO_SELLER_PHONE))
        if dev:
            db.execute(delete(Listing).where(Listing.seller_id == dev.id))
            db.commit()
            logger.info("Annonces démo supprimées pour %s", DEMO_SELLER_PHONE)
    except Exception as e:
        logger.warning("Purge annonces démo: %s", e)
        db.rollback()
    finally:
        db.close()


def _ensure_dev_admin_user() -> None:
    """Compte admin pour le panneau /admin (dev uniquement)."""
    if settings.is_production:
        return
    db = SessionLocal()
    try:
        admin = db.scalar(select(User).where(User.phone_e164 == DEV_ADMIN_PHONE))
        if not admin:
            admin = User(
                phone_e164=DEV_ADMIN_PHONE,
                role=UserRole.super_admin,
                display_name="Super administrateur SombaTeka",
                is_phone_verified=True,
            )
            db.add(admin)
            db.commit()
            logger.info("Compte super_admin créé: %s", DEV_ADMIN_PHONE)
        elif admin.role not in (UserRole.super_admin, UserRole.admin, UserRole.moderator):
            admin.role = UserRole.super_admin
            admin.is_phone_verified = True
            db.commit()
    except Exception as e:
        logger.warning("Admin dev seed: %s", e)
        db.rollback()
    finally:
        db.close()


def _ensure_team_support_user() -> None:
    db = SessionLocal()
    try:
        get_or_create_team_user(db)
        db.commit()
    except Exception as e:
        logger.warning("Compte support: %s", e)
        db.rollback()
    finally:
        db.close()


def init_database() -> None:
    ensure_userrole_super_admin()
    _ensure_team_support_user()
    if settings.auto_create_tables:
        from app.models import OrderDispute  # noqa: F401 — enregistre la table

        Base.metadata.create_all(bind=engine)
        _ensure_user_avatar_column()
        _ensure_schema_patches()
        logger.info("Database tables ensured")

    _purge_demo_listings()
    _ensure_dev_admin_user()

    db = SessionLocal()
    try:
        _ensure_fashion_categories(db)
    except Exception as e:
        logger.warning("Fashion categories: %s", e)
    finally:
        db.close()

    if not settings.seed_dev_data or settings.is_production:
        return

    db = SessionLocal()
    try:
        if not db.scalar(select(Category)):
            db.add_all(
                [
                    Category(name="Électronique", icon_key="mobile-screen"),
                    Category(name="Mode", icon_key="shirt"),
                    Category(name="Maison", icon_key="house"),
                    Category(name="Véhicules", icon_key="car"),
                    Category(name="Emplois", icon_key="briefcase"),
                    Category(name="Immobilier", icon_key="building"),
                    Category(name="Location / Allocation", icon_key="key"),
                ]
            )
            db.commit()
    except Exception as e:
        logger.exception("Startup seeding failed: %s", e)
    finally:
        db.close()
