"""Pytest fixtures: SQLite in-memory database, sessions and API client."""

from __future__ import annotations

import os
import shutil
import tempfile
from collections.abc import Generator
from pathlib import Path

import pytest
from fastapi.testclient import TestClient
from sqlalchemy import create_engine, event
from sqlalchemy.orm import Session, sessionmaker
from sqlalchemy.pool import StaticPool

TEST_UPLOAD_DIR = os.path.join(tempfile.gettempdir(), "smartpos-product-image-tests", "products")

os.environ.setdefault("DATABASE_URL", "sqlite+pysqlite:///:memory:")
os.environ.setdefault("JWT_SECRET_KEY", "test-secret-key-that-is-long-enough")
os.environ.setdefault("LOGIN_RATE_LIMIT", "100000")
os.environ.setdefault("GENERAL_RATE_LIMIT", "1000000")
os.environ.setdefault("LOCAL_UPLOAD_DIR", TEST_UPLOAD_DIR)
os.environ.setdefault("MAX_PRODUCT_IMAGE_SIZE", "100000")

from app.database.base import Base  # noqa: E402
from app.models import (  # noqa: E402, F401
    Permission,
    Role,
    RolePermission,
    User,
)
from app.main import app  # noqa: E402
from app.api.dependencies.database import get_db_session  # noqa: E402
from app.core.security import hash_password  # noqa: E402


@pytest.fixture(autouse=True)
def _clean_upload_dir() -> Generator[None, None, None]:
    """Reset the local product-image upload directory before each test."""
    shutil.rmtree(TEST_UPLOAD_DIR, ignore_errors=True)
    Path(TEST_UPLOAD_DIR).mkdir(parents=True, exist_ok=True)
    yield


@pytest.fixture()
def engine():
    engine = create_engine(
        "sqlite+pysqlite:///:memory:",
        connect_args={"check_same_thread": False},
        poolclass=StaticPool,
        future=True,
    )

    @event.listens_for(engine, "connect")
    def _pragma(dbapi_connection, _record):  # noqa: ANN001
        cursor = dbapi_connection.cursor()
        cursor.execute("PRAGMA foreign_keys=ON")
        cursor.close()

    Base.metadata.create_all(bind=engine)
    yield engine
    engine.dispose()


@pytest.fixture()
def session(engine) -> Generator[Session, None, None]:
    TestSession = sessionmaker(bind=engine, autoflush=False, expire_on_commit=False)
    with TestSession() as db:
        yield db


def _seed_base_data(db: Session) -> None:
    if db.query(Role).filter(Role.role_code == "ADMIN").first() is not None:
        return
    admin_role = Role(
        role_code="ADMIN",
        role_name="Administrator",
        is_system=True,
        is_active=True,
    )
    manager_role = Role(
        role_code="MANAGER",
        role_name="Manager",
        is_system=True,
        is_active=True,
    )
    cashier_role = Role(
        role_code="CASHIER",
        role_name="Cashier",
        is_system=True,
        is_active=True,
    )
    db.add_all([admin_role, manager_role, cashier_role])

    for code, name, module in (
        ("products.view", "View Products", "Products"),
        ("products.create", "Create Products", "Products"),
        ("sales.view", "View Sales", "Sales"),
        ("sales.create", "Create Sales", "Sales"),
        ("inventory.view", "View Inventory", "Inventory"),
        ("inventory.create", "Restock Inventory", "Inventory"),
        ("reports.view", "View Reports", "Reports"),
        ("users.view", "View Users", "Users"),
        ("users.create", "Create Users", "Users"),
    ):
        db.add(Permission(permission_code=code, permission_name=name, module_name=module))

    admin = User(
        username="admin",
        email="admin@smartpos.local",
        password_hash=hash_password("Admin@123"),
        full_name="System Administrator",
        role_id=1,
        is_active=True,
        is_locked=False,
    )
    cashier = User(
        username="cashier",
        email="cashier@smartpos.local",
        password_hash=hash_password("Cashier@123"),
        full_name="Test Cashier",
        role_id=3,
        is_active=True,
        is_locked=False,
    )
    db.add_all([admin, cashier])
    db.flush()

    db.add_all(
        [
            RolePermission(role_id=admin_role.role_id, permission_id=p.permission_id)
            for p in db.query(Permission).all()
        ]
    )
    db.add(
        RolePermission(
            role_id=cashier_role.role_id,
            permission_id=db.query(Permission)
            .filter(Permission.permission_code == "sales.create")
            .first()
            .permission_id,
        )
    )
    db.commit()


@pytest.fixture()
def db_session(engine) -> Generator[Session, None, None]:
    TestSession = sessionmaker(bind=engine, autoflush=False, expire_on_commit=False)
    with TestSession() as db:
        _seed_base_data(db)
        yield db


@pytest.fixture()
def client(engine) -> Generator[TestClient, None, None]:
    TestSession = sessionmaker(bind=engine, autoflush=False, expire_on_commit=False)

    def override_get_db() -> Generator[Session, None, None]:
        with TestSession() as db:
            _seed_base_data(db)
            yield db

    app.dependency_overrides[get_db_session] = override_get_db
    with TestClient(app) as test_client:
        yield test_client
    app.dependency_overrides.clear()


@pytest.fixture()
def admin_user(db_session: Session) -> User:
    return db_session.query(User).filter(User.username == "admin").first()
