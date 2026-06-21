"""Order variant columns for official catalog checkout."""

from alembic import op
import sqlalchemy as sa

revision = "006"
down_revision = "005"
branch_labels = None
depends_on = None


def upgrade() -> None:
    op.add_column("orders", sa.Column("variant_size", sa.String(32), nullable=True))
    op.add_column("orders", sa.Column("variant_color", sa.String(64), nullable=True))
    op.add_column("orders", sa.Column("quantity", sa.Integer(), nullable=False, server_default="1"))


def downgrade() -> None:
    op.drop_column("orders", "quantity")
    op.drop_column("orders", "variant_color")
    op.drop_column("orders", "variant_size")
