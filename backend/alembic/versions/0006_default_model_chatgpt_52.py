"""users/chat_sessions.default_model 库级默认值改为 chatgpt-5.2（与业务默认一致；不修改已有行数据）

Revision ID: 0006_default_model_52
Revises: 0005_msg_attachment_ids
"""

from __future__ import annotations

import sqlalchemy as sa
from alembic import op

revision = "0006_default_model_52"
down_revision = "0005_msg_attachment_ids"
branch_labels = None
depends_on = None


def upgrade() -> None:
    op.alter_column(
        "users",
        "default_model",
        server_default=sa.text("'chatgpt-5.2'"),
        existing_type=sa.String(length=32),
        existing_nullable=False,
    )
    op.alter_column(
        "chat_sessions",
        "default_model",
        server_default=sa.text("'chatgpt-5.2'"),
        existing_type=sa.String(length=32),
        existing_nullable=False,
    )


def downgrade() -> None:
    op.alter_column(
        "users",
        "default_model",
        server_default=sa.text("'chatgpt'"),
        existing_type=sa.String(length=32),
        existing_nullable=False,
    )
    op.alter_column(
        "chat_sessions",
        "default_model",
        server_default=sa.text("'chatgpt'"),
        existing_type=sa.String(length=32),
        existing_nullable=False,
    )
