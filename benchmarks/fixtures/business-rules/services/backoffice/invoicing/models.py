from django.db import models
from django_fsm import FSMField, transition


class InvoiceStatus(models.TextChoices):
    DRAFT = "draft", "Draft"
    ISSUED = "issued", "Issued"
    PAID = "paid", "Paid"
    CREDITED = "credited", "Credited"
    VOID = "void", "Void"


class Invoice(models.Model):
    number = models.CharField(max_length=32, unique=True)
    status = FSMField(max_length=16, choices=InvoiceStatus.choices, default=InvoiceStatus.DRAFT)
    currency = models.CharField(max_length=3)
    net = models.DecimalField(max_digits=14, decimal_places=2)
    tax_total = models.DecimalField(max_digits=14, decimal_places=2)
    total = models.DecimalField(max_digits=14, decimal_places=2)
    issued_at = models.DateTimeField(null=True)
    buyer_name = models.CharField(max_length=200)
    buyer_address = models.TextField()
    buyer_vat_id = models.CharField(max_length=32, blank=True)

    @transition(field=status, source=InvoiceStatus.DRAFT, target=InvoiceStatus.ISSUED)
    def issue(self):
        pass

    @transition(field=status, source=InvoiceStatus.ISSUED, target=InvoiceStatus.PAID)
    def mark_paid(self):
        pass

    @transition(field=status, source=InvoiceStatus.ISSUED, target=InvoiceStatus.CREDITED)
    def credit(self):
        pass

    @transition(field=status, source=InvoiceStatus.DRAFT, target=InvoiceStatus.VOID)
    def discard(self):
        pass

    @transition(field=status, source=InvoiceStatus.ISSUED, target=InvoiceStatus.VOID)
    def void_issued(self):
        """Support asked for it: a wrong invoice disappears from the customer's account."""


class InvoiceLine(models.Model):
    invoice = models.ForeignKey(Invoice, related_name="lines", on_delete=models.PROTECT)
    description = models.CharField(max_length=200)
    unit_price = models.DecimalField(max_digits=14, decimal_places=2)
    quantity = models.IntegerField()
    net = models.DecimalField(max_digits=14, decimal_places=2)
    tax = models.DecimalField(max_digits=14, decimal_places=2)
    tax_category = models.CharField(max_length=2, default="S")


class CreditNote(models.Model):
    invoice = models.ForeignKey(Invoice, on_delete=models.PROTECT)
    amount_minor = models.BigIntegerField()
    reason = models.CharField(max_length=200)


class TaxRate(models.Model):
    category = models.CharField(max_length=8)
    rate = models.DecimalField(max_digits=5, decimal_places=4)
    valid_from = models.DateField()
    valid_to = models.DateField(null=True)
