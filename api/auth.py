from datetime import datetime, timedelta, timezone
from typing import Optional
import bcrypt
import jwt
import os

JWT_SECRET = os.getenv("JWT_SECRET", "devsecret")
JWT_ALGO = "HS256"
JWT_EXP_MIN = int(os.getenv("JWT_EXP_MIN", "60"))

def hash_password(pw: str) -> str:
    return bcrypt.hashpw(pw.encode(), bcrypt.gensalt()).decode()

def verify_password(pw: str, hashed: str) -> bool:
    try:
        return bcrypt.checkpw(pw.encode(), hashed.encode())
    except Exception:
        return False

def make_jwt(user_id: int, email: str) -> str:
    exp = datetime.now(tz=timezone.utc) + timedelta(minutes=JWT_EXP_MIN)
    payload = {"sub": user_id, "email": email, "exp": exp}
    return jwt.encode(payload, JWT_SECRET, algorithm=JWT_ALGO)

def decode_jwt(token: str) -> Optional[dict]:
    try:
        return jwt.decode(token, JWT_SECRET, algorithms=[JWT_ALGO])
    except Exception:
        return None

