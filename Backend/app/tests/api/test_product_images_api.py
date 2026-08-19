"""API tests for product image upload, storage and serving (Phase 03A)."""

from __future__ import annotations

import io
import json
from pathlib import Path

from PIL import Image

from app.core.config import get_settings


def _login(client, username="admin", password="Admin@123"):
    response = client.post(
        "/api/v1/auth/login",
        json={"username": username, "password": password},
    )
    assert response.status_code == 200
    return response.json()["data"]["access_token"]


def _auth_headers(token: str) -> dict[str, str]:
    return {"Authorization": f"Bearer {token}"}


def _product_payload(**overrides) -> dict:
    payload = {
        "sku": "IMG-001",
        "product_name": "Coca Cola",
        "unit": "pcs",
        "unit_price": 1.5,
        "cost_price": 1.0,
    }
    payload.update(overrides)
    return payload


def _image_bytes(fmt: str = "PNG", size: tuple[int, int] = (64, 64)) -> tuple[bytes, str, str]:
    image = Image.new("RGB", size, (255, 0, 0))
    buffer = io.BytesIO()
    image.save(buffer, format=fmt)
    ext = "jpg" if fmt == "JPEG" else fmt.lower()
    mime = {
        "JPEG": "image/jpeg",
        "PNG": "image/png",
        "WEBP": "image/webp",
    }[fmt]
    return buffer.getvalue(), mime, f"photo.{ext}"


def _oversized_image_bytes() -> tuple[bytes, str, str]:
    noise = Image.effect_noise((2000, 2000), 80).convert("RGB")
    buffer = io.BytesIO()
    noise.save(buffer, format="JPEG", quality=90)
    return buffer.getvalue(), "image/jpeg", "big.jpg"


def _local_file_for(image_url: str) -> Path:
    return Path(get_settings().local_upload_dir) / Path(image_url).name


def _create_product(
    client,
    token: str,
    payload: dict | None = None,
    image: tuple[bytes, str, str] | None = None,
):
    data = {"data": json.dumps(payload or _product_payload())}
    files = {}
    if image is not None:
        files["image"] = (image[2], image[0], image[1])
    return client.post("/api/v1/products", headers=_auth_headers(token), data=data, files=files)


# ---------------------------------------------------------------------------
# Create
# ---------------------------------------------------------------------------


def test_create_product_without_image_stores_null(client) -> None:
    token = _login(client)
    response = _create_product(client, token)
    assert response.status_code == 201
    data = response.json()["data"]
    assert data["image_url"] is None


def test_create_product_with_valid_image(client) -> None:
    token = _login(client)
    response = _create_product(client, token, image=_image_bytes("PNG"))
    assert response.status_code == 201
    data = response.json()["data"]
    assert data["image_url"] is not None
    assert data["image_url"].startswith("/uploads/products/")
    assert data["image_url"].endswith(".png")
    assert _local_file_for(data["image_url"]).exists()


def test_create_product_accepts_all_supported_image_types(client) -> None:
    token = _login(client)
    for fmt in ("JPEG", "PNG", "WEBP"):
        response = _create_product(
            client,
            token,
            payload=_product_payload(sku=f"IMG-{fmt}"),
            image=_image_bytes(fmt),
        )
        assert response.status_code == 201, fmt
        assert response.json()["data"]["image_url"] is not None


def test_create_product_with_external_image_url_via_json(client) -> None:
    token = _login(client)
    response = client.post(
        "/api/v1/products",
        headers=_auth_headers(token),
        json=_product_payload(image_url="https://cdn.example.com/cola.jpg"),
    )
    assert response.status_code == 201
    assert response.json()["data"]["image_url"] == "https://cdn.example.com/cola.jpg"


def test_create_product_rejects_invalid_content_type(client) -> None:
    token = _login(client)
    response = _create_product(client, token, image=(b"hello world", "text/plain", "notes.txt"))
    assert response.status_code == 400
    assert response.json()["error"]["code"] == "INVALID_IMAGE"


def test_create_product_rejects_non_image_bytes(client) -> None:
    token = _login(client)
    response = _create_product(
        client,
        token,
        image=(b"not a real image", "image/jpeg", "fake.jpg"),
    )
    assert response.status_code == 400
    assert response.json()["error"]["code"] == "INVALID_IMAGE"


def test_create_product_rejects_oversized_image(client) -> None:
    token = _login(client)
    content, mime, name = _oversized_image_bytes()
    assert len(content) > get_settings().max_product_image_size
    response = _create_product(client, token, image=(content, mime, name))
    assert response.status_code == 400
    assert response.json()["error"]["code"] == "INVALID_IMAGE"


def test_create_product_multipart_missing_data_field(client) -> None:
    token = _login(client)
    response = client.post(
        "/api/v1/products",
        headers=_auth_headers(token),
        files={"image": ("photo.png", b"x", "image/png")},
    )
    assert response.status_code == 422


# ---------------------------------------------------------------------------
# Update
# ---------------------------------------------------------------------------


def test_update_preserves_image_when_not_changed(client) -> None:
    token = _login(client)
    created = _create_product(client, token, image=_image_bytes("PNG"))
    product_id = created.json()["data"]["product_id"]
    original_url = created.json()["data"]["image_url"]

    response = client.put(
        f"/api/v1/products/{product_id}",
        headers=_auth_headers(token),
        json={"product_name": "Coca Cola Zero"},
    )
    assert response.status_code == 200
    assert response.json()["data"]["image_url"] == original_url
    assert _local_file_for(original_url).exists()


def test_update_replaces_image_and_cleans_old_file(client) -> None:
    token = _login(client)
    created = _create_product(client, token, image=_image_bytes("PNG"))
    product_id = created.json()["data"]["product_id"]
    old_url = created.json()["data"]["image_url"]
    old_file = _local_file_for(old_url)
    assert old_file.exists()

    new_image = _image_bytes("WEBP")
    response = client.put(
        f"/api/v1/products/{product_id}",
        headers=_auth_headers(token),
        data={"data": json.dumps({"product_name": "Updated"})},
        files={"image": (new_image[2], new_image[0], new_image[1])},
    )
    assert response.status_code == 200
    new_url = response.json()["data"]["image_url"]
    assert new_url != old_url
    assert new_url.endswith(".webp")
    assert _local_file_for(new_url).exists()
    assert not old_file.exists()


def test_update_removes_image_via_multipart_flag(client) -> None:
    token = _login(client)
    created = _create_product(client, token, image=_image_bytes("PNG"))
    product_id = created.json()["data"]["product_id"]
    old_url = created.json()["data"]["image_url"]
    old_file = _local_file_for(old_url)
    assert old_file.exists()

    response = client.put(
        f"/api/v1/products/{product_id}",
        headers=_auth_headers(token),
        data={"data": json.dumps({}), "remove_image": "true"},
    )
    assert response.status_code == 200
    assert response.json()["data"]["image_url"] is None
    assert not old_file.exists()


def test_update_removes_image_via_json_null(client) -> None:
    token = _login(client)
    created = _create_product(client, token, image=_image_bytes("PNG"))
    product_id = created.json()["data"]["product_id"]
    old_url = created.json()["data"]["image_url"]
    old_file = _local_file_for(old_url)
    assert old_file.exists()

    response = client.put(
        f"/api/v1/products/{product_id}",
        headers=_auth_headers(token),
        json={"image_url": None},
    )
    assert response.status_code == 200
    assert response.json()["data"]["image_url"] is None
    assert not old_file.exists()


def test_update_reject_replace_and_remove_together(client) -> None:
    token = _login(client)
    created = _create_product(client, token, image=_image_bytes("PNG"))
    product_id = created.json()["data"]["product_id"]

    response = client.put(
        f"/api/v1/products/{product_id}",
        headers=_auth_headers(token),
        data={"data": json.dumps({}), "remove_image": "true"},
        files={"image": ("photo.png", b"x", "image/png")},
    )
    assert response.status_code == 400


# ---------------------------------------------------------------------------
# Retrieval
# ---------------------------------------------------------------------------


def test_retrieve_product_returns_image_url(client) -> None:
    token = _login(client)
    created = _create_product(client, token, image=_image_bytes("PNG"))
    product_id = created.json()["data"]["product_id"]
    image_url = created.json()["data"]["image_url"]

    response = client.get(
        f"/api/v1/products/{product_id}",
        headers=_auth_headers(token),
    )
    assert response.status_code == 200
    assert response.json()["data"]["image_url"] == image_url


def test_retrieve_existing_product_with_null_image_url(client) -> None:
    token = _login(client)
    created = _create_product(client, token)
    product_id = created.json()["data"]["product_id"]

    response = client.get(
        f"/api/v1/products/{product_id}",
        headers=_auth_headers(token),
    )
    assert response.status_code == 200
    assert response.json()["data"]["image_url"] is None


def test_list_products_includes_image_url(client) -> None:
    token = _login(client)
    _create_product(client, token, image=_image_bytes("PNG"))

    response = client.get("/api/v1/products", headers=_auth_headers(token))
    assert response.status_code == 200
    rows = response.json()["data"]
    assert any(row["image_url"] and row["image_url"].startswith("/uploads/products/") for row in rows)


# ---------------------------------------------------------------------------
# Static serving
# ---------------------------------------------------------------------------


def test_uploaded_image_is_served_over_http(client) -> None:
    token = _login(client)
    created = _create_product(client, token, image=_image_bytes("PNG"))
    image_url = created.json()["data"]["image_url"]

    response = client.get(image_url)
    assert response.status_code == 200
    assert response.headers["content-type"].startswith("image/png")
    assert response.content


# ---------------------------------------------------------------------------
# Security
# ---------------------------------------------------------------------------


def test_upload_requires_authentication(client) -> None:
    response = client.post(
        "/api/v1/products",
        data={"data": json.dumps(_product_payload())},
    )
    assert response.status_code == 401


def test_upload_requires_product_permission(client) -> None:
    cashier_token = _login(client, username="cashier", password="Cashier@123")
    response = _create_product(client, cashier_token, image=_image_bytes("PNG"))
    assert response.status_code == 403
