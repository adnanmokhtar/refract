from dataclasses import dataclass


@dataclass
class Subscription:
    id: str
    customer_ref: str
    plan: str
    interval: str  # "month" | "year"
    amount_cents: int
    currency: str


@dataclass
class Account:
    id: str
    email: str
    overdue_cents: int
