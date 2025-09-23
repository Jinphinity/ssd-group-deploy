from fastapi import FastAPI, Depends, HTTPException, Header, Request
from fastapi.middleware.cors import CORSMiddleware
from pydantic import BaseModel
import asyncpg
from typing import Optional
import os
import time
import logging

from .db import get_pool
from .auth import hash_password, verify_password, make_jwt, decode_jwt
from .error_handling import (
    ErrorHandlingMiddleware, structured_logger, db_error_handler,
    security_logger, input_validator, get_correlation_id,
    validation_exception_handler, database_exception_handler,
    create_error_response
)

app = FastAPI(
    title="Dizzy's Disease API",
    version="1.0.0",
    description="API for Dizzy's Disease survival RPG"
)

# Configure structured logging
logging.basicConfig(
    level=logging.INFO,
    format='%(message)s',  # Use JSON format from our structured logger
    handlers=[
        logging.StreamHandler(),
        logging.FileHandler('api.log', mode='a')
    ]
)

# Add comprehensive error handling middleware
app.add_middleware(ErrorHandlingMiddleware, logger=structured_logger)

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# Add custom exception handlers
app.add_exception_handler(ValueError, validation_exception_handler)
app.add_exception_handler(asyncpg.PostgresError, database_exception_handler)

START_TIME = time.time()

async def pool_dep() -> asyncpg.Pool:
    if not hasattr(app.state, "pool"):
        app.state.pool = await get_pool()
    return app.state.pool

@app.get("/health")
async def health_check(pool: asyncpg.Pool = Depends(pool_dep)):
    """Health check endpoint for monitoring"""
    try:
        async with pool.acquire() as conn:
            await conn.fetchval("SELECT 1")
        return {
            "status": "healthy",
            "uptime": time.time() - START_TIME,
            "database": "connected"
        }
    except Exception as e:
        raise HTTPException(status_code=503, detail=f"Database connection failed: {str(e)}")

@app.get("/version")
async def version_info():
    """Version information endpoint"""
    return {
        "version": "1.0.0",
        "api_name": "Dizzy's Disease API",
        "commit_sha": os.getenv("COMMIT_SHA", "development"),
        "build_time": os.getenv("BUILD_TIME", "unknown"),
        "environment": os.getenv("ENVIRONMENT", "development")
    }

class RegisterIn(BaseModel):
    email: str
    password: str
    display_name: str

@app.post("/auth/register")
async def register(request: Request, data: RegisterIn, pool: asyncpg.Pool = Depends(pool_dep)):
    """User registration with comprehensive validation and logging"""
    correlation_id = get_correlation_id(request)
    client_ip = request.client.host if request.client else "unknown"

    # Input validation with business rules
    validation_errors = input_validator.validate_registration_data(
        data.dict(), correlation_id
    )
    if validation_errors:
        security_logger.log_security_violation(
            "invalid_registration_attempt",
            None,
            correlation_id,
            {"validation_errors": validation_errors, "client_ip": client_ip}
        )
        return create_error_response(
            status_code=422,
            error_code="VALIDATION_FAILED",
            message="Invalid input data",
            correlation_id=correlation_id,
            details={"validation_errors": validation_errors}
        )

    async with pool.acquire() as conn:
        try:
            pw = hash_password(data.password)
            user = await conn.fetchrow(
                """
                INSERT INTO users(email, password_hash, display_name)
                VALUES($1,$2,$3)
                RETURNING user_id, email
                """,
                data.email.lower().strip(), pw, data.display_name.strip()
            )

            # Create a starter character to satisfy market operations
            await conn.execute(
                """
                INSERT INTO characters(user_id, name) VALUES ($1, $2)
                """,
                user["user_id"], f"Survivor_{user['user_id']}"
            )

            # Log successful registration
            security_logger.log_authentication_event(
                "registration",
                user["user_id"],
                user["email"],
                True,
                correlation_id,
                client_ip
            )

            token = make_jwt(user["user_id"], user["email"])  # type: ignore
            structured_logger.log_event("user_registered", {
                "user_id": user["user_id"],
                "email": user["email"]
            }, correlation_id=correlation_id)

            return {"token": token}

        except asyncpg.UniqueViolationError:
            # Log failed registration attempt
            security_logger.log_authentication_event(
                "registration",
                None,
                data.email,
                False,
                correlation_id,
                client_ip,
                {"reason": "email_already_exists"}
            )
            raise HTTPException(status_code=409, detail="Email already registered")
        except Exception as e:
            structured_logger.log_event("registration_error", {
                "error_type": type(e).__name__,
                "error_message": str(e),
                "email": data.email
            }, level="ERROR", correlation_id=correlation_id)
            raise

class LoginIn(BaseModel):
    email: str
    password: str

@app.post("/auth/login")
async def login(request: Request, data: LoginIn, pool: asyncpg.Pool = Depends(pool_dep)):
    """User login with comprehensive security logging"""
    correlation_id = get_correlation_id(request)
    client_ip = request.client.host if request.client else "unknown"

    # Basic input validation
    if not data.email or not data.password:
        security_logger.log_authentication_event(
            "login",
            None,
            data.email or "empty",
            False,
            correlation_id,
            client_ip,
            {"reason": "missing_credentials"}
        )
        raise HTTPException(status_code=400, detail="Email and password are required")

    async with pool.acquire() as conn:
        try:
            user = await conn.fetchrow(
                "SELECT user_id, email, password_hash FROM users WHERE email=$1",
                data.email.lower().strip(),
            )

            if not user or not verify_password(data.password, user["password_hash"]):
                # Log failed login attempt
                security_logger.log_authentication_event(
                    "login",
                    user["user_id"] if user else None,
                    data.email,
                    False,
                    correlation_id,
                    client_ip,
                    {"reason": "invalid_credentials"}
                )
                raise HTTPException(status_code=401, detail="Invalid credentials")

            # Log successful login
            security_logger.log_authentication_event(
                "login",
                user["user_id"],
                user["email"],
                True,
                correlation_id,
                client_ip
            )

            token = make_jwt(user["user_id"], user["email"])
            structured_logger.log_event("user_logged_in", {
                "user_id": user["user_id"],
                "email": user["email"]
            }, correlation_id=correlation_id)

            return {"token": token}

        except HTTPException:
            raise  # Re-raise HTTP exceptions
        except Exception as e:
            structured_logger.log_event("login_error", {
                "error_type": type(e).__name__,
                "error_message": str(e),
                "email": data.email
            }, level="ERROR", correlation_id=correlation_id)
            raise HTTPException(status_code=500, detail="Login service temporarily unavailable")

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
async def market_buy(
    request: Request,
    data: BuyIn,
    user_id: int = Depends(auth_user),
    pool: asyncpg.Pool = Depends(pool_dep),
    x_request_id: Optional[str] = Header(None, alias="X-Request-Id")
):
    correlation_id = get_correlation_id(request)
    client_ip = request.client.host if request.client else "unknown"

    # X-Request-Id validation
    if not x_request_id:
        security_logger.log_security_violation(
            "missing_idempotency_header",
            user_id,
            correlation_id,
            {"endpoint": "/market/buy", "client_ip": client_ip}
        )
        raise HTTPException(status_code=400, detail="X-Request-Id header required for idempotency")

    # Comprehensive input validation for market transactions
    validation_errors = input_validator.validate_market_transaction(
        data.dict(), correlation_id
    )
    if validation_errors:
        security_logger.log_security_violation(
            "invalid_market_transaction",
            user_id,
            correlation_id,
            {"validation_errors": validation_errors, "client_ip": client_ip, "transaction_data": data.dict()}
        )
        return create_error_response(
            status_code=422,
            error_code="VALIDATION_FAILED",
            message="Invalid transaction data",
            correlation_id=correlation_id,
            details={"validation_errors": validation_errors}
        )

    async with pool.acquire() as conn:
        # Check if this request was already processed (idempotency)
        existing_order = await conn.fetchrow(
            "SELECT * FROM orders WHERE request_id = $1",
            x_request_id
        )
        if existing_order:
            return {"ok": True, "order_id": existing_order["request_id"], "duplicate": True}

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

            # Create idempotent order record first
            try:
                await conn.execute(
                    """
                    INSERT INTO orders (request_id, user_id, item_id, quantity, price, order_type)
                    VALUES ($1, $2, $3, $4, $5, 'buy')
                    ON CONFLICT (request_id) DO NOTHING
                    """,
                    x_request_id, user_id, data.item_id, data.quantity, price
                )
            except Exception:
                # If insertion fails due to conflict, return success (idempotency)
                return {"ok": True, "order_id": x_request_id, "duplicate": True}

            # Process the transaction
            await conn.execute("UPDATE characters SET money = money - $1 WHERE user_id=$2", price, user_id)
            await conn.execute("UPDATE market SET qty_available = qty_available - $1 WHERE settlement_id=$2 AND item_id=$3", data.quantity, data.settlement_id, data.item_id)
            await conn.execute("INSERT INTO inventories(character_id, item_id, quantity, durability_current) VALUES ($1, $2, $3, 100)", wallet["character_id"], data.item_id, data.quantity)

            # Mark order as completed
            await conn.execute("UPDATE orders SET completed = TRUE WHERE request_id = $1", x_request_id)

    return {"ok": True, "order_id": x_request_id, "duplicate": False}

class PerformanceReportIn(BaseModel):
    timestamp: float
    duration_seconds: float
    fps: dict
    memory: dict
    npcs: dict
    performance: dict
    platform: str
    renderer: str

@app.post("/performance/report")
async def performance_report(
    request: Request,
    data: PerformanceReportIn,
    user_id: int = Depends(auth_user),
    pool: asyncpg.Pool = Depends(pool_dep)
):
    """Accept performance reports from clients for monitoring with validation"""
    correlation_id = get_correlation_id(request)
    client_ip = request.client.host if request.client else "unknown"

    # Validate performance report data
    validation_errors = input_validator.validate_performance_report(
        data.dict(), correlation_id
    )
    if validation_errors:
        security_logger.log_security_violation(
            "invalid_performance_report",
            user_id,
            correlation_id,
            {"validation_errors": validation_errors, "client_ip": client_ip}
        )
        return create_error_response(
            status_code=422,
            error_code="VALIDATION_FAILED",
            message="Invalid performance data",
            correlation_id=correlation_id,
            details={"validation_errors": validation_errors}
        )
    async with pool.acquire() as conn:
        # Store performance data for analytics
        await conn.execute(
            """
            INSERT INTO events (type, payload_json)
            VALUES ('performance_report', $1)
            """,
            data.dict()
        )

    # Log performance issues
    avg_fps = data.fps.get("average", 0)
    npc_count = data.npcs.get("count", 0)
    meets_requirements = data.performance.get("meets_gate2_requirements", False)

    if not meets_requirements:
        print(f"⚠️ Performance issue detected - User {user_id}: {avg_fps:.1f} FPS with {npc_count} NPCs")

    return {
        "ok": True,
        "meets_requirements": meets_requirements,
        "recommendations": _generate_performance_recommendations(data)
    }

def _generate_performance_recommendations(data: PerformanceReportIn) -> list[str]:
    """Generate performance optimization recommendations"""
    recommendations = []

    avg_fps = data.fps.get("average", 0)
    avg_memory = data.memory.get("average_mb", 0)
    platform = data.platform

    if avg_fps < 30:
        recommendations.append("Consider reducing graphics quality or NPC count")
    if avg_memory > 500:
        recommendations.append("High memory usage detected - consider asset optimization")
    if platform == "Web" and avg_fps < 30:
        recommendations.append("HTML5 performance below target - optimize for web export")

    return recommendations

class MarketEventIn(BaseModel):
    event_type: str
    settlement_id: int
    price_changes: dict
    timestamp: float

@app.post("/market/events")
async def process_market_event(
    request: Request,
    data: MarketEventIn,
    user_id: int = Depends(auth_user),
    pool: asyncpg.Pool = Depends(pool_dep)
):
    """Process market events and update prices with validation"""
    correlation_id = get_correlation_id(request)
    client_ip = request.client.host if request.client else "unknown"

    # Validate market event data
    validation_errors = input_validator.validate_market_event(
        data.dict(), correlation_id
    )
    if validation_errors:
        security_logger.log_security_violation(
            "invalid_market_event",
            user_id,
            correlation_id,
            {"validation_errors": validation_errors, "client_ip": client_ip, "event_type": data.event_type}
        )
        return create_error_response(
            status_code=422,
            error_code="VALIDATION_FAILED",
            message="Invalid market event data",
            correlation_id=correlation_id,
            details={"validation_errors": validation_errors}
        )
    async with pool.acquire() as conn:
        # Store the market event
        await conn.execute(
            """
            INSERT INTO events (type, payload_json)
            VALUES ('market_event', $1)
            """,
            data.dict()
        )

        # Update market prices based on the event
        for item_name, price_data in data.price_changes.items():
            new_price = price_data["new"]
            await conn.execute(
                """
                UPDATE market
                SET current_price = $1
                WHERE settlement_id = $2 AND item_id = (
                    SELECT item_id FROM items WHERE name = $3
                )
                """,
                int(new_price), data.settlement_id, item_name
            )

        print(f"💰 Processed market event: {data.event_type} for settlement {data.settlement_id}")

    return {"ok": True, "event_processed": data.event_type}

@app.get("/market/prices")
async def get_market_prices(
    settlement_id: int = 1,
    pool: asyncpg.Pool = Depends(pool_dep)
):
    """Get current market prices for a settlement"""
    async with pool.acquire() as conn:
        rows = await conn.fetch(
            """
            SELECT i.name, m.current_price, m.qty_available
            FROM market m
            JOIN items i ON m.item_id = i.item_id
            WHERE m.settlement_id = $1
            """,
            settlement_id
        )

    prices = {}
    items = []
    for row in rows:
        prices[row["name"]] = row["current_price"]
        items.append({
            "name": row["name"],
            "price": row["current_price"],
            "quantity": row["qty_available"]
        })

    return {
        "prices": prices,
        "items": items,
        "settlement_id": settlement_id
    }

@app.get("/market/events")
async def get_market_events(
    settlement_id: int = 1,
    limit: int = 10,
    pool: asyncpg.Pool = Depends(pool_dep)
):
    """Get recent market events"""
    async with pool.acquire() as conn:
        rows = await conn.fetch(
            """
            SELECT type, payload_json, created_at
            FROM events
            WHERE type = 'market_event'
            AND payload_json->>'settlement_id' = $1::text
            ORDER BY created_at DESC
            LIMIT $2
            """,
            str(settlement_id), limit
        )

    events = []
    for row in rows:
        events.append({
            "type": row["type"],
            "data": row["payload_json"],
            "timestamp": row["created_at"].timestamp()
        })

    return {"events": events, "settlement_id": settlement_id}
