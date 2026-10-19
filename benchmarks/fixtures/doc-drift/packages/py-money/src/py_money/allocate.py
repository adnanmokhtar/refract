"""Allocation of an amount across ratios without losing a minor unit."""


def allocate(amount_minor: int, ratios: list) -> list:
    total = sum(ratios)
    if total <= 0:
        raise ValueError("ratios must add up to a positive number")
    shares = [amount_minor * r // total for r in ratios]
    remainder = amount_minor - sum(shares)
    for i in range(remainder):
        shares[i % len(shares)] += 1
    return shares
