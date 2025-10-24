import asyncpg
import os

DB_DSN = os.getenv("DATABASE_URL", "postgresql://postgres:postgres@db:5432/dizzy")

async def get_pool():
    return await asyncpg.create_pool(dsn=DB_DSN, min_size=1, max_size=10)

async def init_db(pool):
    async with pool.acquire() as conn:
        sql = (await (await conn.prepare("SELECT 1")).fetch())[0]
        return sql

