from rest_framework import serializers

from .models import Refund


class RefundSerializer(serializers.ModelSerializer):
    order_number = serializers.CharField(source="order.number", read_only=True)
    store_name = serializers.SerializerMethodField()

    class Meta:
        model = Refund
        fields = ["id", "order_number", "store_name", "psp_refund_number", "reason", "status", "currency", "amount", "created_at", "settled_at"]
        read_only_fields = fields

    def get_store_name(self, obj):
        return obj.order.store.name
