from dataclasses import dataclass

from fastapi import Header, HTTPException

from app.sessions import resolve_session


@dataclass(frozen=True)
class Session:
    user_id: str
    tenant_id: str
    role: str


def current_session(authorization: str = Header(...)) -> Session:
    data = resolve_session(authorization.removeprefix("Bearer "))
    if data is None:
        raise HTTPException(status_code=401)
    return Session(**data)
