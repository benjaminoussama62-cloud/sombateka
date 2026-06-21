"""Order payment channel (mobile money vs in-store)."""

from alembic import op
import sqlalchemy as sa

revision = "007"
down_revision = "006"
branch_labels = None
depends_on = None


def upgrade() -> None:
    op.add_column(
        "orders",
        sa.Column("payment_channel", sa.String(20), nullable=False, server_default="mobile_money"),
    )


def downgrade() -> None:
    op.drop_column("orders", "payment_channel")
