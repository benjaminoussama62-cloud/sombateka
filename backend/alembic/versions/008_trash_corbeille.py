"""Alembic migration — corbeille + statut listing deleted."""

from alembic import op
import sqlalchemy as sa


revision = "008_trash_corbeille"
down_revision = "007_order_payment_channel"
branch_labels = None
depends_on = None


def upgrade() -> None:
    op.add_column("listings", sa.Column("deleted_at", sa.DateTime(timezone=True), nullable=True))
    op.add_column("listings", sa.Column("deleted_by_user_id", sa.Integer(), nullable=True))
    op.create_foreign_key(
        "fk_listings_deleted_by_user",
        "listings",
        "users",
        ["deleted_by_user_id"],
        ["id"],
    )
    op.create_table(
        "trash_items",
        sa.Column("id", sa.Integer(), primary_key=True),
        sa.Column("entity_type", sa.String(length=32), nullable=False),
        sa.Column("entity_key", sa.String(length=128), nullable=False),
        sa.Column("title", sa.String(length=200), nullable=False),
        sa.Column("detail_json", sa.Text(), nullable=True),
        sa.Column("deleted_by_user_id", sa.Integer(), sa.ForeignKey("users.id"), nullable=True),
        sa.Column("deleted_at", sa.DateTime(timezone=True), nullable=False),
        sa.Column("restored_at", sa.DateTime(timezone=True), nullable=True),
        sa.Column("purged_at", sa.DateTime(timezone=True), nullable=True),
    )
    op.create_index("ix_trash_items_entity_type", "trash_items", ["entity_type"])
    op.create_index("ix_trash_items_entity_key", "trash_items", ["entity_key"])
    op.create_index("ix_trash_items_deleted_at", "trash_items", ["deleted_at"])


def downgrade() -> None:
    op.drop_index("ix_trash_items_deleted_at", table_name="trash_items")
    op.drop_index("ix_trash_items_entity_key", table_name="trash_items")
    op.drop_index("ix_trash_items_entity_type", table_name="trash_items")
    op.drop_table("trash_items")
    op.drop_constraint("fk_listings_deleted_by_user", "listings", type_="foreignkey")
    op.drop_column("listings", "deleted_by_user_id")
    op.drop_column("listings", "deleted_at")
