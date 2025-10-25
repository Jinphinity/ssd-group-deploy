import httpx
import os
import pytest

BASE = os.getenv("API_BASE", "http://api:8000")

@pytest.mark.asyncio
async def test_register_and_login():
    async with httpx.AsyncClient(base_url=BASE, timeout=10.0) as c:
        # Unique email per run
        email = f"test_{os.urandom(2).hex()}@example.com"
        password = "Pass1234!"
        r = await c.post("/auth/register", json={"email": email, "password": password, "display_name": "T"})
        assert r.status_code == 200
        data = r.json()
        token = data["token"]
        assert token
        assert data["user"]["email"] == email
        assert data["user"]["display_name"] == "T"
        r = await c.post("/auth/login", json={"email": email, "password": password})
        assert r.status_code == 200
        login_data = r.json()
        assert login_data["token"]
        assert login_data["user"]["email"] == email


@pytest.mark.asyncio
async def test_password_reset_flow():
    async with httpx.AsyncClient(base_url=BASE, timeout=10.0) as c:
        email = f"reset_{os.urandom(2).hex()}@example.com"
        old_password = "OldPass123!"
        new_password = "NewPass456!"

        # Register user
        r = await c.post("/auth/register", json={"email": email, "password": old_password, "display_name": "Reset User"})
        assert r.status_code == 200
        assert r.json()["user"]["email"] == email

        # Ensure login works with old password
        r = await c.post("/auth/login", json={"email": email, "password": old_password})
        assert r.status_code == 200

        # Request reset
        r = await c.post("/auth/request-reset", json={"email": email})
        assert r.status_code == 200
        reset_token = r.json().get("reset_token")
        assert reset_token

        # Confirm reset with new password
        r = await c.post("/auth/confirm-reset", json={"token": reset_token, "new_password": new_password})
        assert r.status_code == 200

        # Old password should now fail
        r = await c.post("/auth/login", json={"email": email, "password": old_password})
        assert r.status_code == 401

        # New password should succeed
        r = await c.post("/auth/login", json={"email": email, "password": new_password})
        assert r.status_code == 200
        assert r.json()["user"]["display_name"] == "Reset User"
