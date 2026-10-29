"""Colonne 2FA TOTP pour le panneau admin."""

from alembic import op


revision = "011_admin_totp"
down_revision = "010_user_password_hash"
branch_labels = None
depends_on = None


def upgrade() -> None:
    op.execute(
        "ALTER TABLE users ADD COLUMN IF NOT EXISTS admin_totp_secret VARCHAR(64)"
    )
    op.execute(
        "ALTER TABLE users ADD COLUMN IF NOT EXISTS admin_totp_enabled BOOLEAN DEFAULT FALSE"
    )
    op.execute(
        "ALTER TABLE users ADD COLUMN IF NOT EXISTS admin_totp_confirmed_at TIMESTAMPTZ"
    )


def downgrade() -> None:
    op.execute("ALTER TABLE users DROP COLUMN IF EXISTS admin_totp_confirmed_at")
    op.execute("ALTER TABLE users DROP COLUMN IF EXISTS admin_totp_enabled")
    op.execute("ALTER TABLE users DROP COLUMN IF EXISTS admin_totp_secret")
