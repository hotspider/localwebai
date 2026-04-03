"""chat_messages.attachment_ids — 用户消息关联的附件 id 列表（JSONB）

Revision ID: 0005_msg_attachment_ids
Revises: 0004_brave_plain_key
"""

from __future__ import annotations

import sqlalchemy as sa
from alembic import op
from sqlalchemy.dialects.postgresql import JSONB

revision = "0005_msg_attachment_ids"
down_revision = "0004_brave_plain_key"
branch_labels = None
depends_on = None


def upgrade() -> None:
    op.add_column("chat_messages", sa.Column("attachment_ids", JSONB(astext_type=sa.Text()), nullable=True))


def downgrade() -> None:
    op.drop_column("chat_messages", "attachment_ids")
