"""Application configuration.

All configurable values are read from environment variables (optionally
loaded from a local ``.env`` file). Nothing is hardcoded.
"""

from __future__ import annotations

import secrets
from functools import lru_cache
from pathlib import Path

from pydantic_settings import BaseSettings, SettingsConfigDict

BASE_DIR = Path(__file__).resolve().parent.parent.parent
ENV_FILE = BASE_DIR / ".env"


class Settings(BaseSettings):
    """Typed application settings backed by environment variables."""

    model_config = SettingsConfigDict(
        env_file=str(ENV_FILE),
        env_file_encoding="utf-8",
        case_sensitive=False,
        extra="ignore",
    )

    # Application
    app_name: str = "SmartPOS API"
    app_version: str = "1.0.0"
    app_env: str = "development"
    app_host: str = "127.0.0.1"
    app_port: int = 8000
    debug: bool = False
    log_level: str = "INFO"
    api_v1_prefix: str = "/api/v1"

    # SQL Server database
    db_server: str = "localhost"
    db_port: int = 1433
    db_database: str = "SmartPOS"
    db_username: str = ""
    db_password: str = ""
    db_driver: str = "ODBC Driver 18 for SQL Server"
    database_url: str | None = None

    # Security / JWT
    jwt_secret_key: str = ""
    jwt_algorithm: str = "HS256"
    jwt_access_token_expire_minutes: int = 15
    jwt_refresh_token_expire_days: int = 7
    bcrypt_rounds: int = 12
    lockout_threshold: int = 5

    # CORS
    frontend_url: str = "http://localhost:5173"

    # Rate limiting
    login_rate_limit: int = 5
    login_rate_window_seconds: int = 900
    general_rate_limit: int = 1000
    general_rate_window_seconds: int = 60

    # Logging
    log_dir: str = "logs"
    enable_access_log: bool = True
    enable_audit_log: bool = True
    enable_notifications: bool = True

    # Image storage (Phase 03A - product images)
    # STORAGE_PROVIDER: local (development) | s3 (future production)
    storage_provider: str = "local"
    # Project-relative directory used by the local provider.
    local_upload_dir: str = "uploads/products"
    max_product_image_size: int = 2097152
    # Comma-separated list of accepted MIME types.
    allowed_product_image_types: str = "image/jpeg,image/png,image/webp"
    # Longest side (pixels) oversized images are resized down to.
    product_image_max_dimension: int = 1600

    # S3 storage (future production - empty until AWS is provisioned)
    s3_bucket_name: str = ""
    s3_region: str = ""
    s3_access_key_id: str = ""
    s3_secret_access_key: str = ""

    # ------------------------------------------------------------------
    # Derived helpers
    # ------------------------------------------------------------------
    @property
    def is_production(self) -> bool:
        return self.app_env.lower() == "production"

    @property
    def sqlalchemy_database_uri(self) -> str:
        """Resolve the SQLAlchemy connection string.

        A full ``DATABASE_URL`` takes precedence. Otherwise a pyodbc URL is
        built from the individual SQL Server settings.
        """
        if self.database_url:
            return self.database_url
        return (
            "mssql+pyodbc://{username}:{password}@{server}:{port}/{database}"
            "?driver={driver}&encrypt=no&TrustServerCertificate=yes"
        ).format(
            username=self.db_username,
            password=self.db_password,
            server=self.db_server,
            port=self.db_port,
            database=self.db_database,
            driver=self.db_driver.replace(" ", "+"),
        )

    @property
    def jwt_secret(self) -> str:
        """Return the JWT secret, refusing to run in production without one."""
        if not self.jwt_secret_key:
            if self.is_production:
                raise RuntimeError("JWT_SECRET_KEY must be set in production.")
            return secrets.token_urlsafe(64)
        return self.jwt_secret_key

    @property
    def cors_origins(self) -> list[str]:
        return [origin.strip() for origin in self.frontend_url.split(",") if origin.strip()]

    @property
    def allowed_image_types_list(self) -> list[str]:
        return [item.strip() for item in self.allowed_product_image_types.split(",") if item.strip()]


@lru_cache
def get_settings() -> Settings:
    return Settings()
