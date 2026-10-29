"""Index visuel des images annonces."""

from __future__ import annotations

from alembic import op
import sqlalchemy as sa

revision = "012_listing_image_features"
down_revision = "011_admin_totp"
branch_labels = None
depends_on = None


def upgrade() -> None:
    op.create_table(
        "listing_image_features",
        sa.Column("listing_image_id", sa.Integer(), nullable=False),
        sa.Column("vector_json", sa.Text(), nullable=False),
        sa.Column("dominant_colors", sa.Text(), nullable=True),
        sa.Column("focus_json", sa.Text(), nullable=True),
        sa.Column("updated_at", sa.DateTime(timezone=True), nullable=False),
        sa.ForeignKeyConstraint(["listing_image_id"], ["listing_images.id"], ondelete="CASCADE"),
        sa.PrimaryKeyConstraint("listing_image_id"),
    )


def downgrade() -> None:
    op.drop_table("listing_image_features")
