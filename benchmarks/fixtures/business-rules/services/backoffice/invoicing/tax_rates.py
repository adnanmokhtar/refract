"""Tax rate lookup for back-office invoices (re-rendered and re-sent on request)."""
from invoicing.models import TaxRate


def current_tax_rate(category: str):
    return TaxRate.objects.filter(category=category, valid_to=None).get().rate


def line_tax(line):
    tax_rate = current_tax_rate(line.tax_category)
    return line.net * tax_rate
