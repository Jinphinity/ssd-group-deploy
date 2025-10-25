#!/usr/bin/env python3
"""
Migration runner for Dizzy's Disease API
Replaces one-off init scripts with proper migration system
"""
import asyncio
import asyncpg
import os
import sys
from pathlib import Path
from typing import List, Tuple

MIGRATIONS_DIR = Path(__file__).parent
SQL_DIR = Path(__file__).parent.parent / "sql"

async def create_migrations_table(conn: asyncpg.Connection):
    """Create migrations tracking table"""
    await conn.execute("""
        CREATE TABLE IF NOT EXISTS migrations (
            id SERIAL PRIMARY KEY,
            name VARCHAR(255) UNIQUE NOT NULL,
            applied_at TIMESTAMP DEFAULT NOW()
        )
    """)

async def get_applied_migrations(conn: asyncpg.Connection) -> List[str]:
    """Get list of already applied migrations"""
    rows = await conn.fetch("SELECT name FROM migrations ORDER BY applied_at")
    return [row['name'] for row in rows]

async def apply_migration(conn: asyncpg.Connection, name: str, sql_content: str):
    """Apply a single migration"""
    print(f"Applying migration: {name}")
    
    async with conn.transaction():
        # Execute the migration SQL
        await conn.execute(sql_content)
        
        # Record the migration as applied
        await conn.execute(
            "INSERT INTO migrations (name) VALUES ($1) ON CONFLICT (name) DO NOTHING",
            name
        )
    
    print(f"✅ Migration {name} applied successfully")

async def get_available_migrations() -> List[Tuple[str, str]]:
    """Get all available migration files"""
    migrations = []
    
    # Convert existing SQL files to migrations
    if SQL_DIR.exists():
        for sql_file in sorted(SQL_DIR.glob("*.sql")):
            content = sql_file.read_text()
            migrations.append((sql_file.name, content))
    
    return migrations

async def run_migrations():
    """Run all pending migrations"""
    database_url = os.getenv("DATABASE_URL", "postgresql://postgres:postgres@localhost:5432/dizzy")
    
    try:
        conn = await asyncpg.connect(database_url)
        print("✅ Connected to database")
        
        # Ensure migrations table exists
        await create_migrations_table(conn)
        
        # Get already applied migrations
        applied = await get_applied_migrations(conn)
        print(f"Already applied migrations: {len(applied)}")
        
        # Get available migrations
        available = await get_available_migrations()
        print(f"Available migrations: {len(available)}")
        
        # Apply pending migrations
        pending_count = 0
        for name, content in available:
            if name not in applied:
                await apply_migration(conn, name, content)
                pending_count += 1
        
        if pending_count == 0:
            print("✅ No pending migrations - database is up to date")
        else:
            print(f"✅ Applied {pending_count} migrations successfully")
        
        await conn.close()
        return True
        
    except Exception as e:
        print(f"❌ Migration failed: {str(e)}")
        return False

async def reset_database():
    """Reset database by dropping all tables and rerunning migrations"""
    database_url = os.getenv("DATABASE_URL", "postgresql://postgres:postgres@localhost:5432/dizzy")
    
    try:
        conn = await asyncpg.connect(database_url)
        print("✅ Connected to database for reset")
        
        # Drop all tables (cascading)
        await conn.execute("""
            DROP SCHEMA public CASCADE;
            CREATE SCHEMA public;
        """)
        print("✅ Dropped all tables")
        
        await conn.close()
        
        # Run migrations fresh
        return await run_migrations()
        
    except Exception as e:
        print(f"❌ Database reset failed: {str(e)}")
        return False

def main():
    """Main entry point"""
    if len(sys.argv) > 1 and sys.argv[1] == "--reset":
        print("🔄 Resetting database and applying all migrations...")
        success = asyncio.run(reset_database())
    else:
        print("🚀 Running database migrations...")
        success = asyncio.run(run_migrations())
    
    if success:
        print("🎉 Database migration completed successfully!")
        sys.exit(0)
    else:
        print("💥 Database migration failed!")
        sys.exit(1)

if __name__ == "__main__":
    main()