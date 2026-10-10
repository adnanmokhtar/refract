"""Drop reports.legacy_format (the v1 export path is gone).

Revision ID: 20261001_drop_legacy_format
Revises: 20260915_add_export_bucket
"""
from alembic import op

revision = "20261001_drop_legacy_format"
down_revision = "20260915_add_export_bucket"


def upgrade() -> None:
    op.execute("ALTER TABLE reports DROP COLUMN legacy_format")


def downgrade() -> None:
    op.execute("ALTER TABLE reports ADD COLUMN legacy_format text")
