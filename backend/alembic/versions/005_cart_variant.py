"""Cart variant columns for official catalog (Wildberries)."""

from alembic import op
import sqlalchemy as sa

revision = "005"
down_revision = "004"
branch_labels = None
depends_on = None


def upgrade() -> None:
    op.add_column("cart_items", sa.Column("variant_size", sa.String(32), nullable=True))
    op.add_column("cart_items", sa.Column("variant_color", sa.String(64), nullable=True))


def downgrade() -> None:
    op.drop_column("cart_items", "variant_color")
    op.drop_column("cart_items", "variant_size")
