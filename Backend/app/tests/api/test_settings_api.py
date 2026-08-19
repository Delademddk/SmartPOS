"""API tests for the settings flow (feature 15).

Covers the complete settings lifecycle: create/update/read persistence, the
public display-settings endpoint (readable by cashiers), business info updates
with the exact frontend contract, and extra-field rejection.
"""

from __future__ import annotations


def _login(client, username="admin", password="Admin@123"):
    return client.post(
        "/api/v1/auth/login",
        json={"username": username, "password": password},
    )


def _token(client, username="admin", password="Admin@123"):
    login = _login(client, username, password)
    return login.json()["data"]["access_token"]


def _auth(token):
    return {"Authorization": f"Bearer {token}"}


def test_settings_create_update_read_persist(client) -> None:
    token = _token(client)

    create = client.post(
        "/api/v1/settings",
        json={
            "setting_key": "receipt_footer",
            "setting_value": "Thank you for shopping!",
            "data_type": "string",
            "category": "general",
            "description": "Footer text",
        },
        headers=_auth(token),
    )
    assert create.status_code == 201
    assert create.json()["data"]["setting_value"] == "Thank you for shopping!"

    update = client.put(
        "/api/v1/settings/receipt_footer",
        json={"setting_value": "Please come again!"},
        headers=_auth(token),
    )
    assert update.status_code == 200
    assert update.json()["data"]["setting_value"] == "Please come again!"

    read = client.get("/api/v1/settings", headers=_auth(token))
    assert read.status_code == 200
    values = {s["setting_key"]: s["setting_value"] for s in read.json()["data"]}
    assert values["receipt_footer"] == "Please come again!"


def test_settings_update_preserves_unrelated_fields(client) -> None:
    token = _token(client)
    client.post(
        "/api/v1/settings",
        json={"setting_key": "receipt_footer", "setting_value": "Thanks!", "data_type": "string"},
        headers=_auth(token),
    )
    client.post(
        "/api/v1/settings",
        json={"setting_key": "business_name", "setting_value": "ABC Store", "data_type": "string"},
        headers=_auth(token),
    )

    client.put(
        "/api/v1/settings/business_name",
        json={"setting_value": "XYZ Store"},
        headers=_auth(token),
    )

    read = client.get("/api/v1/settings", headers=_auth(token))
    values = {s["setting_key"]: s["setting_value"] for s in read.json()["data"]}
    assert values["receipt_footer"] == "Thanks!"
    assert values["business_name"] == "XYZ Store"


def test_settings_reject_invalid_data_type(client) -> None:
    token = _token(client)
    response = client.post(
        "/api/v1/settings",
        json={
            "setting_key": "bad_type",
            "setting_value": "10",
            "data_type": "number",
        },
        headers=_auth(token),
    )
    assert response.status_code == 422


def test_settings_accept_db_data_types(client) -> None:
    token = _token(client)
    for key, value, data_type in (
        ("low_stock_threshold_default", "10", "int"),
        ("receipt_show_tax", "true", "bool"),
        ("tax_rate_default", "7.5", "decimal"),
    ):
        response = client.post(
            "/api/v1/settings",
            json={
                "setting_key": key,
                "setting_value": value,
                "data_type": data_type,
            },
            headers=_auth(token),
        )
        assert response.status_code == 201, response.text


def test_public_settings_readable_by_cashier(client) -> None:
    token = _token(client)
    client.post(
        "/api/v1/settings",
        json={"setting_key": "receipt_footer", "setting_value": "Thanks!", "data_type": "string"},
        headers=_auth(token),
    )
    client.post(
        "/api/v1/settings",
        json={"setting_key": "business_name", "setting_value": "ABC Store", "data_type": "string"},
        headers=_auth(token),
    )
    client.post(
        "/api/v1/settings",
        json={"setting_key": "lockout_threshold", "setting_value": "5", "data_type": "int", "category": "system"},
        headers=_auth(token),
    )

    cashier_token = _token(client, "cashier", "Cashier@123")
    response = client.get("/api/v1/settings/public", headers=_auth(cashier_token))
    assert response.status_code == 200
    keys = {s["setting_key"] for s in response.json()["data"]}
    assert "business_name" in keys
    assert "lockout_threshold" not in keys


def test_public_settings_require_auth(client) -> None:
    response = client.get("/api/v1/settings/public")
    assert response.status_code == 401


def test_cashier_cannot_write_settings(client) -> None:
    cashier_token = _token(client, "cashier", "Cashier@123")
    response = client.post(
        "/api/v1/settings",
        json={"setting_key": "foo", "setting_value": "bar", "data_type": "string"},
        headers=_auth(cashier_token),
    )
    assert response.status_code == 403


def test_business_info_update_contract(client) -> None:
    token = _token(client)

    payload = {
        "business_name": "New Name",
        "legal_name": "New Legal",
        "tax_id": "TAX-1",
        "address_line1": "1 Main St",
        "address_line2": "Suite 2",
        "city": "Springfield",
        "state": "IL",
        "postal_code": "62701",
        "country": "USA",
        "phone": "555-0100",
        "email": "new@example.com",
        "website": "https://example.com",
        "currency_code": "USD",
    }
    update = client.put("/api/v1/business/info", json=payload, headers=_auth(token))
    assert update.status_code == 200, update.text
    data = update.json()["data"]
    assert data["business_name"] == "New Name"
    assert data["address_line1"] == "1 Main St"

    read = client.get("/api/v1/business/info", headers=_auth(token))
    assert read.json()["data"]["business_name"] == "New Name"

    # extra fields must be rejected (the old frontend sent `address`/`logo_url`)
    bad = client.put(
        "/api/v1/business/info",
        json={"business_name": "X", "address": "1 Main St", "logo_url": "http://x/logo.png"},
        headers=_auth(token),
    )
    assert bad.status_code == 422


def test_business_info_readable_by_cashier(client) -> None:
    token = _token(client)
    response = client.put(
        "/api/v1/business/info",
        json={"business_name": "Cashier Store", "currency_code": "USD"},
        headers=_auth(token),
    )
    assert response.status_code == 200

    cashier_token = _token(client, "cashier", "Cashier@123")
    read = client.get("/api/v1/business/info", headers=_auth(cashier_token))
    assert read.status_code == 200
    assert read.json()["data"]["business_name"] == "Cashier Store"


def test_get_currency_default_is_usd(client) -> None:
    token = _token(client)
    response = client.get("/api/v1/settings/currency", headers=_auth(token))
    assert response.status_code == 200
    data = response.json()["data"]
    assert data["currency_code"] == "USD"
    assert data["currency_symbol"] == "$"
    assert data["currency_locale"] == "en-US"


def test_update_currency_to_ghs_and_back(client) -> None:
    token = _token(client)

    update = client.put(
        "/api/v1/settings/currency",
        json={"currency_code": "GHS"},
        headers=_auth(token),
    )
    assert update.status_code == 200, update.text
    data = update.json()["data"]
    assert data["currency_code"] == "GHS"
    assert data["currency_symbol"] == "GH₵"
    assert data["currency_locale"] == "en-GH"

    read = client.get("/api/v1/settings/currency", headers=_auth(token))
    assert read.json()["data"]["currency_code"] == "GHS"

    business = client.get("/api/v1/business/info", headers=_auth(token))
    assert business.json()["data"]["currency_code"] == "GHS"

    settings = client.get("/api/v1/settings", headers=_auth(token))
    values = {s["setting_key"]: s["setting_value"] for s in settings.json()["data"]}
    assert values["currency_symbol"] == "GH₵"
    assert values["currency_code"] == "GHS"
    assert values["currency_locale"] == "en-GH"

    back = client.put(
        "/api/v1/settings/currency",
        json={"currency_code": "USD"},
        headers=_auth(token),
    )
    assert back.status_code == 200
    assert back.json()["data"]["currency_symbol"] == "$"
    assert back.json()["data"]["currency_locale"] == "en-US"


def test_update_currency_rejects_unknown_code(client) -> None:
    token = _token(client)
    response = client.put(
        "/api/v1/settings/currency",
        json={"currency_code": "XXX"},
        headers=_auth(token),
    )
    assert response.status_code == 422
    response = client.put(
        "/api/v1/settings/currency",
        json={"currency_code": "US"},
        headers=_auth(token),
    )
    assert response.status_code == 422


def test_cashier_cannot_update_currency(client) -> None:
    cashier_token = _token(client, "cashier", "Cashier@123")
    response = client.put(
        "/api/v1/settings/currency",
        json={"currency_code": "GHS"},
        headers=_auth(cashier_token),
    )
    assert response.status_code == 403


def test_currency_config_readable_by_cashier(client) -> None:
    cashier_token = _token(client, "cashier", "Cashier@123")
    response = client.get("/api/v1/settings/currency", headers=_auth(cashier_token))
    assert response.status_code == 200
    assert response.json()["data"]["currency_code"] == "USD"


def test_business_info_update_validates_currency(client) -> None:
    token = _token(client)
    response = client.put(
        "/api/v1/business/info",
        json={"currency_code": "XXX"},
        headers=_auth(token),
    )
    assert response.status_code == 422


def test_currency_mirror_settings_are_managed(client) -> None:
    token = _token(client)
    created = client.post(
        "/api/v1/settings",
        json={"setting_key": "currency_code", "setting_value": "USD", "data_type": "string"},
        headers=_auth(token),
    )
    assert created.status_code == 422

    client.put("/api/v1/settings/currency", json={"currency_code": "GHS"}, headers=_auth(token))

    edited = client.put(
        "/api/v1/settings/currency_symbol",
        json={"setting_value": "€"},
        headers=_auth(token),
    )
    assert edited.status_code == 422

    routed = client.put(
        "/api/v1/settings/currency_code",
        json={"setting_value": "USD"},
        headers=_auth(token),
    )
    assert routed.status_code == 200
    read = client.get("/api/v1/settings/currency", headers=_auth(token))
    assert read.json()["data"]["currency_code"] == "USD"