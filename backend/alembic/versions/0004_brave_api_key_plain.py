"""brave_settings.api_key_plain — 明文存 Brave Key（家庭内网简化，可选兼容旧 Fernet 密文）

Revision ID: 0004_brave_plain_key
Revises: 0003_brave_realtime
"""

from __future__ import annotations

import sqlalchemy as sa
from alembic import op

revision = "0004_brave_plain_key"
down_revision = "0003_brave_realtime"
branch_labels = None
depends_on = None


def upgrade() -> None:
    op.add_column("brave_settings", sa.Column("api_key_plain", sa.Text(), nullable=True))


def downgrade() -> None:
    op.drop_column("brave_settings", "api_key_plain")
