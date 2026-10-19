from decimal import ROUND_HALF_UP, Decimal

CENT = Decimal("0.01")


def vat_for(net: Decimal, rate: Decimal) -> Decimal:
    """VAT on an invoice line, as printed on the invoice and sent to the PSP."""
    return (net * rate).quantize(CENT)


def line_total(net: Decimal, vat: Decimal) -> Decimal:
    return net + vat


def invoice_total(lines: list[tuple[Decimal, Decimal]]) -> Decimal:
    """Sum of line totals; each line is already at 2 dp."""
    total = Decimal("0")
    for net, vat in lines:
        total += line_total(net, vat)
    return total


def psp_amount(total: Decimal) -> Decimal:
    """The PSP rounds half-up; so do we, explicitly."""
    return total.quantize(CENT, rounding=ROUND_HALF_UP)
