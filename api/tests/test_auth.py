import httpx
import os
import pytest

BASE = os.getenv("API_BASE", "http://api:8000")

@pytest.mark.asyncio
async def test_register_and_login():
    async with httpx.AsyncClient(base_url=BASE, timeout=10.0) as c:
        # Unique email per run
        email = f"test_{os.urandom(2).hex()}@example.com"
        r = await c.post("/auth/register", json={"email": email, "password": "pass1234", "display_name": "T"})
        assert r.status_code == 200
        token = r.json()["token"]
        assert token
        r = await c.post("/auth/login", json={"email": email, "password": "pass1234"})
        assert r.status_code == 200
        assert r.json()["token"]
