"""brave settings + chat realtime_meta

Revision ID: 0003_brave_realtime
Revises: 0002_runtime_settings
Create Date: 2026-04-02
"""

from __future__ import annotations

import sqlalchemy as sa
from alembic import op
from sqlalchemy.dialects import postgresql

revision = "0003_brave_realtime"
down_revision = "0002_runtime_settings"
branch_labels = None
depends_on = None


def upgrade() -> None:
    op.create_table(
        "brave_settings",
        sa.Column("id", sa.Integer(), nullable=False),
        sa.Column("brave_enabled", sa.Boolean(), server_default=sa.text("false"), nullable=False),
        sa.Column("api_key_encrypted", sa.Text(), nullable=True),
        sa.Column("base_url", sa.String(length=256), server_default="https://api.search.brave.com", nullable=False),
        sa.Column("web_search_enabled", sa.Boolean(), server_default=sa.text("true"), nullable=False),
        sa.Column("news_search_enabled", sa.Boolean(), server_default=sa.text("true"), nullable=False),
        sa.Column("llm_context_enabled", sa.Boolean(), server_default=sa.text("false"), nullable=False),
        sa.Column("default_result_count", sa.Integer(), server_default="8", nullable=False),
        sa.Column("timeout_seconds", sa.Integer(), server_default="15", nullable=False),
        sa.Column("country", sa.String(length=8), server_default="cn", nullable=False),
        sa.Column("search_lang", sa.String(length=16), server_default="zh-hans", nullable=False),
        sa.Column("cache_enabled", sa.Boolean(), server_default=sa.text("false"), nullable=False),
        sa.Column("updated_at", sa.DateTime(timezone=True), server_default=sa.text("now()"), nullable=False),
        sa.Column("last_test_at", sa.DateTime(timezone=True), nullable=True),
        sa.Column("last_test_ok", sa.Boolean(), nullable=True),
        sa.Column("last_test_message", sa.Text(), nullable=True),
        sa.PrimaryKeyConstraint("id"),
    )
    op.execute(sa.text("INSERT INTO brave_settings (id) VALUES (1)"))

    op.add_column(
        "chat_messages",
        sa.Column("realtime_meta", postgresql.JSONB(astext_type=sa.Text()), nullable=True),
    )


def downgrade() -> None:
    op.drop_column("chat_messages", "realtime_meta")
    op.drop_table("brave_settings")
