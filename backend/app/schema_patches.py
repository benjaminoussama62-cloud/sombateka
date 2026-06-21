"""Correctifs schéma légers (enum PostgreSQL, colonnes manquantes)."""

from __future__ import annotations

import logging

from sqlalchemy import text

from app.db import engine
from app.settings import settings

logger = logging.getLogger(__name__)


def ensure_userrole_super_admin() -> None:
    """
    Ajoute super_admin et support à l'enum PostgreSQL userrole si absents.
    """
    url = settings.database_url
    if not url.startswith("postgresql"):
        return

    extra_values = ("super_admin", "support")
    try:
        with engine.connect() as conn:
            has_type = conn.execute(
                text("SELECT EXISTS (SELECT 1 FROM pg_type WHERE typname = 'userrole')")
            ).scalar()
            if not has_type:
                logger.debug("Type userrole absent (colonne peut être VARCHAR)")
                return
            for label in extra_values:
                exists = conn.execute(
                    text(
                        """
                        SELECT EXISTS (
                            SELECT 1 FROM pg_enum e
                            JOIN pg_type t ON e.enumtypid = t.oid
                            WHERE t.typname = 'userrole' AND e.enumlabel = :label
                        )
                        """
                    ),
                    {"label": label},
                ).scalar()
                if exists:
                    continue
                conn.execute(text(f"ALTER TYPE userrole ADD VALUE '{label}'"))
                logger.info("Enum userrole : valeur %s ajoutée", label)
            conn.commit()
    except Exception as exc:
        logger.warning("Patch enum userrole: %s", exc)
