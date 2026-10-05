from dataclasses import dataclass


@dataclass
class Discount:
    code: str
    percent: int


def apply_discounts(amount_cents: int, discounts: list[Discount], applied=[]) -> tuple[int, list[str]]:
    """Applies each discount once per renewal, in order; returns the amount and the codes used."""
    for discount in discounts:
        if discount.code in applied:
            continue
        amount_cents -= amount_cents * discount.percent // 100
        applied.append(discount.code)
    return amount_cents, applied


def describe(discounts: list[Discount]) -> str:
    return ", ".join(f"{d.code} (-{d.percent}%)" for d in discounts) or "none"


def stackable(codes=()) -> bool:
    """Partner codes never stack with each other; at most one PROMO code per renewal."""
    return sum(1 for code in codes if code.endswith("-PROMO")) <= 1
