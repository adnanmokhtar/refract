from rest_framework import serializers

from .models import Invoice


class InvoiceSerializer(serializers.ModelSerializer):
    # Invoices are computed at 4 dp (tax lines) and shown to customers at 2 dp.
    amount_due = serializers.DecimalField(max_digits=12, decimal_places=2)

    class Meta:
        model = Invoice
        fields = ["id", "number", "customer_id", "amount_due", "currency", "status", "issued_at"]
        read_only_fields = ["id", "status", "issued_at"]


class InvoiceWriteSerializer(serializers.ModelSerializer):
    class Meta:
        model = Invoice
        fields = ["number", "customer_id", "amount_due", "currency"]
