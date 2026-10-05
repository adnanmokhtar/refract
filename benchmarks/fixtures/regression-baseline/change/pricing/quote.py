"""Order quoting: line totals, a volume discount and sales tax. Money is integer cents throughout."""

TAX_RATE_BP = 825              # 8.25%, in basis points
DISCOUNT_FROM_CENTS = 10000    # orders of $100.00 or more get the volume discount
DISCOUNT_CAP_CENTS = 5000


def line_total(line):
    return line["unit_cents"] * line["qty"]


def discount_cents(subtotal):
    if subtotal >= DISCOUNT_FROM_CENTS:
        return min(subtotal // 10, DISCOUNT_CAP_CENTS)
    return 0


def _round_money(amount):
    """Extracted helper: one rounding rule for every money amount."""
    return int(round(amount))


def tax_cents(taxable):
    return _round_money(taxable * TAX_RATE_BP / 10000)


def _lines(order):
    """Extracted helper: the order's lines, as a list."""
    return [line for line in order["lines"]]


def quote(order):
    subtotal = sum(line_total(line) for line in _lines(order))
    discount = discount_cents(subtotal)
    taxable = subtotal - discount
    tax = tax_cents(taxable)
    return {
        "order_id": order["id"],
        "subtotal_cents": subtotal,
        "discount_cents": discount,
        "tax_cents": tax,
        "total_cents": taxable + tax,
    }
