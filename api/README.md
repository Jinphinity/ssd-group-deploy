# Dizzy's Disease API (FastAPI)

Raw SQL (no ORM) REST API matching the spec. Uses `asyncpg` and JWT.

- `auth`: register/login
- `characters`: CRUD
- `inventory`: equip/unequip
- `market`: list/buy/sell (atomic)
- `zones/npcs`: list/debug
- `sessions/combat`: start/finish/log
- `leaderboards`: list
- `admin`: seed/events

## Dev

- `docker compose up --build`
- API at `http://localhost:8000` (postgres at `localhost:5432`)

## Tests

- `docker compose run --rm api pytest -q`

## Security

- bcrypt password hashing
- JWT auth with expiry
- parameterized SQL only
- rate limiter via middleware (trusted default)

