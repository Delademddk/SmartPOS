"""Unit tests for the image storage abstraction (Phase 03A)."""

from __future__ import annotations

import io

from PIL import Image
from starlette.datastructures import UploadFile

from app.exceptions import ImageValidationError
from app.services.image_storage import (
    LocalImageStorageService,
    get_image_storage_service,
)


def _upload(content: bytes, content_type: str, filename: str) -> UploadFile:
    return UploadFile(file=io.BytesIO(content), filename=filename)


def _png_content(size: tuple[int, int] = (64, 64)) -> bytes:
    buffer = io.BytesIO()
    Image.new("RGB", size, (0, 128, 255)).save(buffer, format="PNG")
    return buffer.getvalue()


def test_local_service_returns_public_url_path() -> None:
    service = LocalImageStorageService()
    assert service.get_public_image_url("abc.webp") == "/uploads/products/abc.webp"


def test_save_product_image_persists_file_and_returns_web_url() -> None:
    service = LocalImageStorageService()
    url = service.save_product_image(_upload(_png_content(), "image/png", "photo.png"))
    assert url.startswith("/uploads/products/")
    assert url.endswith(".png")
    assert (service.upload_dir / url.rsplit("/", 1)[1]).exists()


def test_save_generates_unique_filenames() -> None:
    service = LocalImageStorageService()
    url_a = service.save_product_image(_upload(_png_content(), "image/png", "a.png"))
    url_b = service.save_product_image(_upload(_png_content(), "image/png", "b.png"))
    assert url_a != url_b


def test_delete_product_image_removes_file() -> None:
    service = LocalImageStorageService()
    url = service.save_product_image(_upload(_png_content(), "image/png", "photo.png"))
    file_path = service.upload_dir / url.rsplit("/", 1)[1]
    assert file_path.exists()
    service.delete_product_image(url)
    assert not file_path.exists()


def test_delete_ignores_non_local_urls_and_missing_files() -> None:
    service = LocalImageStorageService()
    service.delete_product_image("https://cdn.example.com/foo.png")
    service.delete_product_image("/uploads/products/nonexistent-file.png")


def test_validation_rejects_disallowed_content_type() -> None:
    service = LocalImageStorageService()
    try:
        service.save_product_image(_upload(b"plain text", "text/plain", "x.txt"))
        raise AssertionError("Expected ImageValidationError")
    except ImageValidationError:
        pass


def test_validation_rejects_oversized_file() -> None:
    service = LocalImageStorageService()
    from app.core.config import get_settings

    oversized = b"a" * (get_settings().max_product_image_size + 1)
    try:
        service.save_product_image(_upload(oversized, "image/png", "big.png"))
        raise AssertionError("Expected ImageValidationError")
    except ImageValidationError:
        pass


def test_validation_rejects_non_image_bytes() -> None:
    service = LocalImageStorageService()
    try:
        service.save_product_image(_upload(b"not an image at all", "image/png", "fake.png"))
        raise AssertionError("Expected ImageValidationError")
    except ImageValidationError:
        pass


def test_validation_rejects_empty_file() -> None:
    service = LocalImageStorageService()
    try:
        service.save_product_image(_upload(b"", "image/png", "empty.png"))
        raise AssertionError("Expected ImageValidationError")
    except ImageValidationError:
        pass


def test_factory_returns_local_service(monkeypatch) -> None:
    from app.core.config import get_settings

    get_image_storage_service.cache_clear()
    settings = get_settings()
    monkeypatch.setattr(settings, "storage_provider", "local")
    assert isinstance(get_image_storage_service(), LocalImageStorageService)


def test_factory_rejects_unimplemented_s3_provider(monkeypatch) -> None:
    from app.core.config import get_settings

    get_image_storage_service.cache_clear()
    settings = get_settings()
    monkeypatch.setattr(settings, "storage_provider", "s3")
    try:
        get_image_storage_service()
        raise AssertionError("Expected RuntimeError for unimplemented S3 provider")
    except RuntimeError as exc:
        assert "S3ImageStorageService" in str(exc)
    finally:
        monkeypatch.setattr(settings, "storage_provider", "local")
        get_image_storage_service.cache_clear()
