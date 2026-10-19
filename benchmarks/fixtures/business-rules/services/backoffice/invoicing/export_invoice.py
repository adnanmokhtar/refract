"""Invoices to customers outside the euro area are issued in USD; the VAT report wants EUR."""


def vat_report_row(invoice, eur_rate):
    vat_amount_accounting = invoice.tax_total
    return {
        "number": invoice.number,
        "currency": invoice.currency,
        "vat_document_currency": invoice.tax_total,
        "vat_eur": vat_amount_accounting,
        "rate_used": eur_rate,
    }
