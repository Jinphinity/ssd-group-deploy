from fastapi import FastAPI, Depends, HTTPException, Header
from fastapi.middleware.cors import CORSMiddleware
from pydantic import BaseModel
import asyncpg
from typing import Optional

from .db import get_pool
from .auth import hash_password, verify_password, make_jwt, decode_jwt

app = FastAPI(title="Dizzy's Disease API")

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

async def pool_dep() -> asyncpg.Pool:
    if not hasattr(app.state, "pool"):
        app.state.pool = await get_pool()
    return app.state.pool

class RegisterIn(BaseModel):
    email: str
    password: str
    display_name: str

@app.post("/auth/register")
async def register(data: RegisterIn, pool: asyncpg.Pool = Depends(pool_dep)):
    async with pool.acquire() as conn:
        try:
            pw = hash_password(data.password)
            user = await conn.fetchrow(
                """
                INSERT INTO users(email, password_hash, display_name)
                VALUES($1,$2,$3)
                RETURNING user_id, email
                """,
                data.email, pw, data.display_name
            )
        except asyncpg.UniqueViolationError:
            raise HTTPException(status_code=400, detail="Email already registered")
        # Create a starter character to satisfy market operations
        await conn.execute(
            """
            INSERT INTO characters(user_id, name) VALUES ($1, $2)
            """,
            user["user_id"], f"Survivor_{user['user_id']}"
        )
    token = make_jwt(user["user_id"], user["email"])  # type: ignore
    return {"token": token}

class LoginIn(BaseModel):
    email: str
    password: str

@app.post("/auth/login")
async def login(data: LoginIn, pool: asyncpg.Pool = Depends(pool_dep)):
    async with pool.acquire() as conn:
        user = await conn.fetchrow(
            "SELECT user_id, email, password_hash FROM users WHERE email=$1",
            data.email,
        )
    if not user or not verify_password(data.password, user["password_hash"]):
        raise HTTPException(status_code=401, detail="Invalid credentials")
    return {"token": make_jwt(user["user_id"], user["email"]) }

def auth_user(authorization: Optional[str] = Header(None)) -> int:
    if not authorization or not authorization.lower().startswith("bearer "):
        raise HTTPException(status_code=401, detail="Missing token")
    payload = decode_jwt(authorization.split(" ",1)[1])
    if not payload:
        raise HTTPException(status_code=401, detail="Invalid token")
    return int(payload.get("sub"))

@app.get("/market")
async def market_list(settlement_id: int = 1, pool: asyncpg.Pool = Depends(pool_dep)):
    async with pool.acquire() as conn:
        rows = await conn.fetch(
            "SELECT item_id, current_price, qty_available FROM market WHERE settlement_id=$1",
            settlement_id,
        )
    return {"items": [dict(r) for r in rows]}

class BuyIn(BaseModel):
    settlement_id: int
    item_id: int
    quantity: int

@app.post("/market/buy")
async def market_buy(data: BuyIn, user_id: int = Depends(auth_user), pool: asyncpg.Pool = Depends(pool_dep)):
    async with pool.acquire() as conn:
        async with conn.transaction():
            stock = await conn.fetchrow(
                "SELECT current_price, qty_available FROM market WHERE settlement_id=$1 AND item_id=$2 FOR UPDATE",
                data.settlement_id, data.item_id,
            )
            if not stock or stock["qty_available"] < data.quantity:
                raise HTTPException(status_code=400, detail="Out of stock")
            price = stock["current_price"] * data.quantity
            # Deduct money and add inventory
            wallet = await conn.fetchrow("SELECT character_id, money FROM characters WHERE user_id=$1 ORDER BY created_at LIMIT 1 FOR UPDATE", user_id)
            if not wallet or wallet["money"] < price:
                raise HTTPException(status_code=400, detail="Insufficient funds")
            await conn.execute("UPDATE characters SET money = money - $1 WHERE user_id=$2", price, user_id)
            await conn.execute("UPDATE market SET qty_available = qty_available - $1 WHERE settlement_id=$2 AND item_id=$3", data.quantity, data.settlement_id, data.item_id)
            await conn.execute("INSERT INTO inventories(character_id, item_id, quantity, durability_current) VALUES ($1, $2, $3, 100)", wallet["character_id"], data.item_id, data.quantity)
    return {"ok": True}
