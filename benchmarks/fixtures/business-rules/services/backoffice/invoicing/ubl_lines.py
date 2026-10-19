"""UBL invoice lines for the back office's B2B invoices."""


def ubl_line(line, customer):
    if customer.is_tax_exempt:
        line.tax_category = "Z"
        line.tax = 0
        line.rate_percent = 0
    return {
        "id": line.id,
        "net": str(line.net),
        "category": line.tax_category,
        "percent": str(line.rate_percent),
    }
