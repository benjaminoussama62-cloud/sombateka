"""Initial production schema

Revision ID: 001
Revises:
Create Date: 2026-05-20
"""

from alembic import op
import sqlalchemy as sa

revision = "001"
down_revision = None
branch_labels = None
depends_on = None


def upgrade() -> None:
    # Tables are created via SQLAlchemy models; this revision marks baseline.
    # On fresh deploy with RUN_MIGRATIONS=true, use: alembic stamp head after create_all
    pass


def downgrade() -> None:
    pass
