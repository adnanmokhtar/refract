from datetime import date

from pydantic import BaseModel


class InboundEmail(BaseModel):
    id: str
    tenant_id: str
    sender: str
    subject: str
    body: str


class Customer(BaseModel):
    id: str
    first_name: str
    last_name: str
    email: str
    phone: str | None = None
    date_of_birth: date | None = None
    shipping_address: str | None = None
    internal_notes: str | None = None
    lifetime_value_cents: int = 0
