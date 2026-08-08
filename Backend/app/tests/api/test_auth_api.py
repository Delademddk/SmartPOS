"""API tests for the authentication flow (feature 02)."""

from __future__ import annotations


def _login(client, username="admin", password="Admin@123"):
    return client.post(
        "/api/v1/auth/login",
        json={"username": username, "password": password},
    )


def test_login_success(client) -> None:
    response = _login(client)
    assert response.status_code == 200
    body = response.json()
    assert body["success"] is True
    assert body["data"]["access_token"]
    assert body["data"]["refresh_token"]
    assert body["data"]["user"]["role_code"] == "ADMIN"


def test_login_invalid_credentials(client) -> None:
    response = client.post(
        "/api/v1/auth/login",
        json={"username": "admin", "password": "Wrong@123"},
    )
    assert response.status_code == 401
    assert response.json()["error"]["code"] == "INVALID_CREDENTIALS"


def test_me_requires_token(client) -> None:
    response = client.get("/api/v1/auth/me")
    assert response.status_code == 401


def test_me_returns_profile(client) -> None:
    login = _login(client)
    token = login.json()["data"]["access_token"]
    response = client.get(
        "/api/v1/auth/me",
        headers={"Authorization": f"Bearer {token}"},
    )
    assert response.status_code == 200
    assert response.json()["data"]["username"] == "admin"


def test_refresh_flow(client) -> None:
    login = _login(client)
    refresh_token = login.json()["data"]["refresh_token"]
    response = client.post(
        "/api/v1/auth/refresh",
        json={"refresh_token": refresh_token},
    )
    assert response.status_code == 200
    assert response.json()["data"]["access_token"]


def test_change_password_updates(client) -> None:
    login = _login(client)
    token = login.json()["data"]["access_token"]
    response = client.post(
        "/api/v1/auth/change-password",
        headers={"Authorization": f"Bearer {token}"},
        json={"current_password": "Admin@123", "new_password": "NewAdmin@123"},
    )
    assert response.status_code == 200
    # Old password no longer works.
    assert _login(client).status_code == 401
