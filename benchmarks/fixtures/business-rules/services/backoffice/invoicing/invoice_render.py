"""Renders a back-office invoice to the PDF template's context (re-rendered on every download)."""
from merchants.models import CompanyProfile


def render_context(invoice):
    company = CompanyProfile.objects.get()
    lines = []
    for item in invoice.order.items.all():
        unit = item.variant.unit_price
        lines.append({"description": item.variant.title, "unit": unit, "quantity": item.quantity, "net": unit * item.quantity})
    return {
        "number": invoice.number,
        "lines": lines,
        "seller_name": company.legal_name,
        "seller_vat_id": company.vat_number,
    }
