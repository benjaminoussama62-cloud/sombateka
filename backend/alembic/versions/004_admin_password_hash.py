"""Staff admin password hash (connexion individuelle /admin)."""

from alembic import op
import sqlalchemy as sa

revision = "004"
down_revision = "003"
branch_labels = None
depends_on = None


def upgrade() -> None:
    op.add_column("users", sa.Column("admin_password_hash", sa.String(255), nullable=True))


def downgrade() -> None:
    op.drop_column("users", "admin_password_hash")
