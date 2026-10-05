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


def tax_cents(taxable):
    # Half a cent rounds up: integer arithmetic, no float on the money path.
    return (taxable * TAX_RATE_BP + 5000) // 10000


def quote(order):
    subtotal = sum(line_total(line) for line in order["lines"])
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
