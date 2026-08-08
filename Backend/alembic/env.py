"""Alembic environment.

The authoritative schema lives in ``Database/SQL`` scripts which are executed
by ``scripts/setup_database.bat``. This environment lets Alembic generate
future migrations from the ORM models and compare against the live database.

Workflow for first-time environments:
    alembic upgrade head            # after a baseline exists
or for a fresh schema controlled entirely by Alembic:
    alembic revision --autogenerate -m "baseline"
    alembic upgrade head
"""

from __future__ import annotations

import os
from logging.config import fileConfig

from sqlalchemy import engine_from_config, pool

from alembic import context

# Import all models so they are registered on Base.metadata.
from app import models  # noqa: F401
from app.core.config import get_settings
from app.database.base import Base

config = context.config

if config.config_file_name is not None:
    fileConfig(config.config_file_name)

# Resolve the connection URL from settings unless one was passed explicitly.
config.set_main_option("sqlalchemy.url", os.environ.get("DATABASE_URL") or get_settings().sqlalchemy_database_uri)

target_metadata = Base.metadata


def run_migrations_offline() -> None:
    """Run migrations in 'offline' mode (emit SQL without a DB connection)."""
    url = config.get_main_option("sqlalchemy.url")
    context.configure(
        url=url,
        target_metadata=target_metadata,
        literal_binds=True,
        dialect_opts={"paramstyle": "named"},
    )
    with context.begin_transaction():
        context.run_migrations()


def run_migrations_online() -> None:
    """Run migrations in 'online' mode against the live database."""
    connectable = engine_from_config(
        config.get_section(config.config_ini_section, {}),
        prefix="sqlalchemy.",
        poolclass=pool.NullPool,
    )
    with connectable.connect() as connection:
        context.configure(connection=connection, target_metadata=target_metadata)
        with context.begin_transaction():
            context.run_migrations()


if context.is_offline_mode():
    run_migrations_offline()
else:
    run_migrations_online()
