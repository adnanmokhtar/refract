"""Peppol BIS Billing 3.0 invoices (EN 16931) for EU business customers.

Line net amounts (BT-131) are rounded to two decimals per line; the document's sums (BT-106, BT-116)
are the sums of those rounded line amounts, and each category's VAT (BT-117) is computed once from its
rounded taxable amount — so BR-CO-10 and BR-CO-17 hold by construction. CI runs the KoSIT validator on
the samples this module writes (.github/workflows/einvoice.yml).
"""
from decimal import ROUND_HALF_UP, Decimal

from lxml import etree

CENT = Decimal("0.01")


def line_net(line) -> Decimal:
    return (line.unit_price * line.quantity).quantize(CENT, rounding=ROUND_HALF_UP)


def category_totals(lines, rate: Decimal):
    taxable = sum((line_net(l) for l in lines), Decimal("0"))
    vat = (taxable * rate).quantize(CENT, rounding=ROUND_HALF_UP)
    return taxable, vat


def build(invoice, lines, rate: Decimal) -> bytes:
    root = etree.Element("Invoice", nsmap={None: "urn:oasis:names:specification:ubl:schema:xsd:Invoice-2"})
    taxable, vat = category_totals(lines, rate)
    etree.SubElement(root, "TaxAmount").text = str(vat)
    etree.SubElement(root, "TaxableAmount").text = str(taxable)
    for l in lines:
        etree.SubElement(root, "LineExtensionAmount").text = str(line_net(l))
    return etree.tostring(root)
