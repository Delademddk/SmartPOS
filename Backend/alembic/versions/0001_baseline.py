"""baseline

Schema baseline.

The authoritative SmartPOS schema is created by the SQL scripts under
``Database/SQL`` (executed by ``scripts/setup_database.bat``). This baseline
migration records that state so Alembic can track subsequent changes.

For a fresh database controlled entirely by Alembic, replace this file with
``alembic revision --autogenerate -m \"baseline\"`` output instead.

Revision ID: 0001
Revises:
Create Date: 2026-08-07
"""

from __future__ import annotations

from collections.abc import Sequence

import sqlalchemy as sa
from alembic import op

# revision identifiers, used by Alembic.
revision: str = "0001"
down_revision: str | None = None
branch_labels: str | Sequence[str] | None = None
depends_on: str | Sequence[str] | None = None


def upgrade() -> None:
    # Schema is installed from Database/SQL scripts; nothing to execute.
    pass


def downgrade() -> None:
    pass
