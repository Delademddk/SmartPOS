"""Image storage abstraction for product images.

The product service depends only on the ``ImageStorageService`` interface, so
the backend can move from local disk storage (development) to Amazon S3
(future production) without touching product business logic.

    Product Router
        -> Product Service
            -> Image Storage Service
                -> LocalImageStorageService   (STORAGE_PROVIDER=local)
                -> S3ImageStorageService      (STORAGE_PROVIDER=s3, future)

Only the public, web-accessible URL/path is ever returned; filesystem paths
are never exposed to callers or stored in the database.
"""

from __future__ import annotations

import io
import uuid
from abc import ABC, abstractmethod
from functools import lru_cache
from pathlib import Path

from fastapi import UploadFile
from PIL import Image, UnidentifiedImageError

from app.core.config import get_settings
from app.core.logging import get_logger
from app.exceptions import ImageValidationError

logger = get_logger("services.image_storage")

# Detected image format -> (file extension, canonical MIME type)
_FORMAT_EXTENSION = {
    "JPEG": ("jpg", "image/jpeg"),
    "PNG": ("png", "image/png"),
    "WEBP": ("webp", "image/webp"),
}


class ImageStorageService(ABC):
    """Storage abstraction for product images (local now, S3 later)."""

    @abstractmethod
    def save_product_image(self, upload: UploadFile) -> str:
        """Validate and persist the uploaded image; return a public URL/path."""

    @abstractmethod
    def delete_product_image(self, public_url: str) -> None:
        """Remove the stored image referenced by ``public_url`` if it exists."""

    @abstractmethod
    def get_public_image_url(self, filename: str) -> str:
        """Return the web-accessible URL/path for a stored filename."""


def _validate_and_optimize(content: bytes, content_type: str | None) -> tuple[bytes, str]:
    """Validate an uploaded product image and return (bytes, extension).

    Enforces the configured size and MIME-type limits and refuses files that
    are not genuinely decodable JPEG/PNG/WebP images (magic bytes are checked
    by Pillow, not by trusting the client-supplied content type).
    """
    settings = get_settings()

    if len(content) == 0:
        raise ImageValidationError(
            "Uploaded image is empty.",
            [{"field": "image", "message": "No file content provided."}],
        )
    if len(content) > settings.max_product_image_size:
        raise ImageValidationError(
            f"Image exceeds the maximum size of {settings.max_product_image_size} bytes.",
            [{"field": "image", "message": "File too large."}],
        )
    if content_type and content_type not in settings.allowed_image_types_list:
        raise ImageValidationError(
            f"Image type '{content_type}' is not allowed.",
            [{"field": "image", "message": "Unsupported file type."}],
        )

    try:
        image = Image.open(io.BytesIO(content))
        image.load()
    except (UnidentifiedImageError, OSError, ValueError) as exc:
        raise ImageValidationError(
            "Uploaded file is not a valid image.",
            [{"field": "image", "message": "File is not a valid image."}],
        ) from exc

    fmt = image.format
    if fmt not in _FORMAT_EXTENSION:
        raise ImageValidationError(
            f"Image format '{fmt or 'unknown'}' is not allowed.",
            [{"field": "image", "message": "Unsupported image format."}],
        )

    max_dim = settings.product_image_max_dimension
    if max(image.size) > max_dim:
        image.thumbnail((max_dim, max_dim), Image.Resampling.LANCZOS)

    buffer = io.BytesIO()
    if fmt == "JPEG":
        if image.mode not in ("RGB", "L"):
            image = image.convert("RGB")
        image.save(buffer, format="JPEG", quality=85, optimize=True)
    elif fmt == "PNG":
        image.save(buffer, format="PNG", optimize=True)
    else:  # WEBP
        image.save(buffer, format="WEBP", quality=85, method=6)

    ext = _FORMAT_EXTENSION[fmt][0]
    return buffer.getvalue(), ext


class LocalImageStorageService(ImageStorageService):
    """Stores product images on the local filesystem (development)."""

    def __init__(self) -> None:
        settings = get_settings()
        self.upload_dir = Path(settings.local_upload_dir)
        self.public_path = "/uploads/products"
        self._ensure_upload_dir()

    def _ensure_upload_dir(self) -> None:
        self.upload_dir.mkdir(parents=True, exist_ok=True)

    def save_product_image(self, upload: UploadFile) -> str:
        content = upload.file.read() if upload.file is not None else b""
        processed, ext = _validate_and_optimize(content, upload.content_type)
        self._ensure_upload_dir()
        filename = f"{uuid.uuid4().hex}.{ext}"
        (self.upload_dir / filename).write_bytes(processed)
        return self.get_public_image_url(filename)

    def delete_product_image(self, public_url: str) -> None:
        if not public_url:
            return
        filename = self._filename_from_public_url(public_url)
        if filename is None:
            return
        target = (self.upload_dir / filename).resolve()
        upload_root = self.upload_dir.resolve()
        if not target.is_relative_to(upload_root):
            logger.warning("blocked_unsafe_image_delete", path=str(target))
            return
        if target.exists():
            target.unlink()

    def get_public_image_url(self, filename: str) -> str:
        return f"{self.public_path}/{filename}"

    def _filename_from_public_url(self, public_url: str) -> str | None:
        prefix = f"{self.public_path}/"
        if not public_url.startswith(prefix):
            return None
        name = public_url[len(prefix) :]
        if not name or "/" in name or "\\" in name:
            return None
        return name


def ensure_local_upload_directory() -> None:
    """Create the local upload directory if it does not exist (startup helper)."""
    settings = get_settings()
    if settings.storage_provider == "local":
        Path(settings.local_upload_dir).mkdir(parents=True, exist_ok=True)


@lru_cache
def get_image_storage_service() -> ImageStorageService:
    """Return the configured image storage service.

    The local provider is fully implemented for development. The S3 provider
    is intentionally not implemented yet: enabling it requires provisioning AWS
    infrastructure first, then adding an ``S3ImageStorageService`` that
    implements ``ImageStorageService`` (see the Phase 03A audit docs).
    """
    settings = get_settings()
    if settings.storage_provider == "s3":
        raise RuntimeError(
            "STORAGE_PROVIDER=s3 is configured but the S3 image storage service "
            "has not been implemented yet. Add an S3ImageStorageService that "
            "implements ImageStorageService before enabling S3 storage."
        )
    return LocalImageStorageService()
