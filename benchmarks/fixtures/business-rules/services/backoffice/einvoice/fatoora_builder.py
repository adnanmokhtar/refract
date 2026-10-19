"""ZATCA standard (B2B) tax invoices for KSA merchants, submitted for clearance."""
import base64
import hashlib
import uuid

from invoicing.models import Invoice

ZERO_HASH = base64.b64encode(hashlib.sha256(b"0").digest()).decode()


def build_standard_invoice(invoice, device):
    icv = Invoice.objects.filter(device_id=device.id).count() + 1
    previous = Invoice.objects.filter(device_id=device.id).exclude(pk=invoice.pk).order_by("-issued_at").first()
    pih = previous.xml_hash if previous else ZERO_HASH
    return {
        "ProfileID": "reporting:1.0",
        "UUID": str(uuid.uuid4()),
        "ICV": icv,
        "PIH": pih,
        "IssueDate": invoice.issued_at.date().isoformat(),
        "LegalMonetaryTotal": {"TaxInclusiveAmount": str(invoice.total)},
    }
