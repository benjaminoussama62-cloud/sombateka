"""Salons de chat internes entre administrateurs."""

from alembic import op
import sqlalchemy as sa


revision = "009_admin_chat"
down_revision = "008_trash_corbeille"
branch_labels = None
depends_on = None

GENERAL_ROOM_NAME = "Équipe général"


def upgrade() -> None:
    op.create_table(
        "admin_chat_rooms",
        sa.Column("id", sa.Integer(), primary_key=True),
        sa.Column("name", sa.String(length=120), nullable=True),
        sa.Column("room_kind", sa.String(length=16), nullable=False),
        sa.Column("dm_key", sa.String(length=32), nullable=True),
        sa.Column("created_by_id", sa.Integer(), sa.ForeignKey("users.id"), nullable=True),
        sa.Column("created_at", sa.DateTime(timezone=True), nullable=False),
    )
    op.create_index("ix_admin_chat_rooms_room_kind", "admin_chat_rooms", ["room_kind"])
    op.create_index("ix_admin_chat_rooms_dm_key", "admin_chat_rooms", ["dm_key"], unique=True)

    op.create_table(
        "admin_chat_members",
        sa.Column("id", sa.Integer(), primary_key=True),
        sa.Column("room_id", sa.Integer(), sa.ForeignKey("admin_chat_rooms.id"), nullable=False),
        sa.Column("user_id", sa.Integer(), sa.ForeignKey("users.id"), nullable=False),
        sa.Column("joined_at", sa.DateTime(timezone=True), nullable=False),
        sa.Column("last_read_at", sa.DateTime(timezone=True), nullable=True),
        sa.UniqueConstraint("room_id", "user_id", name="uq_admin_chat_member"),
    )
    op.create_index("ix_admin_chat_members_room_id", "admin_chat_members", ["room_id"])
    op.create_index("ix_admin_chat_members_user_id", "admin_chat_members", ["user_id"])

    op.create_table(
        "admin_chat_messages",
        sa.Column("id", sa.Integer(), primary_key=True),
        sa.Column("room_id", sa.Integer(), sa.ForeignKey("admin_chat_rooms.id"), nullable=False),
        sa.Column("sender_id", sa.Integer(), sa.ForeignKey("users.id"), nullable=False),
        sa.Column("content", sa.Text(), nullable=False),
        sa.Column("created_at", sa.DateTime(timezone=True), nullable=False),
    )
    op.create_index("ix_admin_chat_messages_room_id", "admin_chat_messages", ["room_id"])
    op.create_index("ix_admin_chat_messages_created_at", "admin_chat_messages", ["created_at"])

    op.execute(
        f"INSERT INTO admin_chat_rooms (name, room_kind, dm_key, created_by_id, created_at) "
        f"VALUES ('{GENERAL_ROOM_NAME}', 'general', NULL, NULL, NOW() AT TIME ZONE 'UTC')"
    )


def downgrade() -> None:
    op.drop_index("ix_admin_chat_messages_created_at", table_name="admin_chat_messages")
    op.drop_index("ix_admin_chat_messages_room_id", table_name="admin_chat_messages")
    op.drop_table("admin_chat_messages")
    op.drop_index("ix_admin_chat_members_user_id", table_name="admin_chat_members")
    op.drop_index("ix_admin_chat_members_room_id", table_name="admin_chat_members")
    op.drop_table("admin_chat_members")
    op.drop_index("ix_admin_chat_rooms_dm_key", table_name="admin_chat_rooms")
    op.drop_index("ix_admin_chat_rooms_room_kind", table_name="admin_chat_rooms")
    op.drop_table("admin_chat_rooms")
