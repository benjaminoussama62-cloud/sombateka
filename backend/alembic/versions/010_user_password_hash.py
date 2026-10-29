"""Colonne password_hash pour inscription email/mot de passe."""

from alembic import op


revision = "010_user_password_hash"
down_revision = "009_admin_chat"
branch_labels = None
depends_on = None


def upgrade() -> None:
    op.execute(
        "ALTER TABLE users ADD COLUMN IF NOT EXISTS password_hash VARCHAR(255)"
    )
    op.execute(
        "ALTER TABLE users ADD COLUMN IF NOT EXISTS phone_linked_at TIMESTAMPTZ"
    )


def downgrade() -> None:
    op.execute("ALTER TABLE users DROP COLUMN IF EXISTS phone_linked_at")
    op.execute("ALTER TABLE users DROP COLUMN IF EXISTS password_hash")
