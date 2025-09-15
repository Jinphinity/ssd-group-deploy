import httpx
import os
import pytest

BASE = os.getenv("API_BASE", "http://api:8000")

async def _register(c):
    email = f"test_{os.urandom(2).hex()}@example.com"
    r = await c.post("/auth/register", json={"email": email, "password": "pass1234", "display_name": "T"})
    return r.json()["token"]

@pytest.mark.asyncio
async def test_market_list_and_buy():
    async with httpx.AsyncClient(base_url=BASE, timeout=10.0) as c:
        token = await _register(c)
        r = await c.get("/market")
        assert r.status_code == 200
        items = r.json()["items"]
        assert len(items) >= 1
        item_id = items[0]["item_id"]
        r = await c.post("/market/buy", headers={"Authorization": f"Bearer {token}"}, json={"settlement_id":1, "item_id": item_id, "quantity":1})
        assert r.status_code == 200
