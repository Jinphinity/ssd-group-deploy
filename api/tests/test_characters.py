import os
import uuid

import httpx
import pytest

BASE = os.getenv("API_BASE", "http://api:8000")


async def _register_user(client: httpx.AsyncClient):
    email = f"char_{uuid.uuid4().hex[:8]}@example.com"
    password = "Pass1234!"
    response = await client.post(
        "/auth/register",
        json={
            "email": email,
            "password": password,
            "display_name": "Character Tester",
        },
    )
    assert response.status_code == 200
    data = response.json()
    token = data["token"]
    return email, password, token


async def _auth_headers(client: httpx.AsyncClient):
    _, _, token = await _register_user(client)
    return {"Authorization": f"Bearer {token}"}


def _valid_character_payload(name: str):
    return {
        "name": name,
        "strength": 2,
        "dexterity": 2,
        "agility": 2,
        "endurance": 2,
        "accuracy": 1,
    }


@pytest.mark.asyncio
async def test_create_character_and_list():
    async with httpx.AsyncClient(base_url=BASE, timeout=10.0) as client:
        headers = await _auth_headers(client)

        create = await client.post("/characters", json=_valid_character_payload("Scout"), headers=headers)
        assert create.status_code == 200
        character = create.json()["character"]
        assert character["name"] == "Scout"
        assert character["strength"] == 2
        assert character["available_stat_points"] >= 0
        assert character["survivability_health"] == pytest.approx(100.0)
        assert character["nourishment_level"] == pytest.approx(100.0)

        listing = await client.get("/characters", headers=headers)
        assert listing.status_code == 200
        payload = listing.json()
        assert payload["max_characters"] == 5
        assert any(c["name"] == "Scout" for c in payload["characters"])


@pytest.mark.asyncio
async def test_character_name_uniqueness():
    async with httpx.AsyncClient(base_url=BASE, timeout=10.0) as client:
        headers = await _auth_headers(client)
        payload = _valid_character_payload("Ranger")

        first = await client.post("/characters", json=payload, headers=headers)
        assert first.status_code == 200

        duplicate = await client.post("/characters", json=payload, headers=headers)
        assert duplicate.status_code == 409


@pytest.mark.asyncio
async def test_character_limit_enforced():
    async with httpx.AsyncClient(base_url=BASE, timeout=10.0) as client:
        headers = await _auth_headers(client)

        for index in range(5):
            payload = _valid_character_payload(f"Hero{index}")
            response = await client.post("/characters", json=payload, headers=headers)
            assert response.status_code == 200

        overflow = await client.post("/characters", json=_valid_character_payload("Overflow"), headers=headers)
        assert overflow.status_code == 400
        assert overflow.json()["detail"] == "Maximum 5 characters per account"


@pytest.mark.asyncio
async def test_character_stat_validation():
    async with httpx.AsyncClient(base_url=BASE, timeout=10.0) as client:
        headers = await _auth_headers(client)
        invalid_payload = {
            "name": "Invalid",
            "strength": 5,
            "dexterity": 1,
            "agility": 1,
            "endurance": 1,
            "accuracy": 1,
        }

        response = await client.post("/characters", json=invalid_payload, headers=headers)
        assert response.status_code == 422
        data = response.json()
        assert data["error"]["code"] == "VALIDATION_FAILED"
        details = data["error"].get("details", {})
        assert any(
            "Total stat points" in message for message in details.get("validation_errors", [])
        )


@pytest.mark.asyncio
async def test_get_characters_requires_auth():
    async with httpx.AsyncClient(base_url=BASE, timeout=10.0) as client:
        response = await client.get("/characters")
        assert response.status_code == 401
