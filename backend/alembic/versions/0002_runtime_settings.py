"""runtime_settings for admin-configurable LLM keys

Revision ID: 0002_runtime_settings
Revises: 0001_init
Create Date: 2026-04-02
"""

from __future__ import annotations

import sqlalchemy as sa
from alembic import op

revision = "0002_runtime_settings"
down_revision = "0001_init"
branch_labels = None
depends_on = None


def upgrade() -> None:
    op.create_table(
        "runtime_settings",
        sa.Column("key", sa.String(length=64), nullable=False),
        sa.Column("value", sa.Text(), server_default="", nullable=False),
        sa.Column("updated_at", sa.DateTime(timezone=True), server_default=sa.text("now()"), nullable=False),
        sa.PrimaryKeyConstraint("key"),
    )


def downgrade() -> None:
    op.drop_table("runtime_settings")
