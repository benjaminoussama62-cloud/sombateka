"""Add super_admin to userrole enum (PostgreSQL)

Revision ID: 002
Revises: 001
Create Date: 2026-05-30
"""

from alembic import op

revision = "002"
down_revision = "001"
branch_labels = None
depends_on = None


def upgrade() -> None:
    bind = op.get_bind()
    if bind.dialect.name != "postgresql":
        return
    # Les modèles utilisent native_enum=False (VARCHAR) — pas de type PG userrole sur deploy frais.
    op.execute(
        """
        DO $$
        BEGIN
            IF EXISTS (SELECT 1 FROM pg_type WHERE typname = 'userrole') THEN
                IF NOT EXISTS (
                    SELECT 1 FROM pg_enum e
                    JOIN pg_type t ON e.enumtypid = t.oid
                    WHERE t.typname = 'userrole' AND e.enumlabel = 'super_admin'
                ) THEN
                    ALTER TYPE userrole ADD VALUE 'super_admin';
                END IF;
            END IF;
        END $$;
        """
    )


def downgrade() -> None:
    pass
