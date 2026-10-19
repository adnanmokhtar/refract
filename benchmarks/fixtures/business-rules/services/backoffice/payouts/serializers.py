from rest_framework import serializers

from payouts.models import Payout


class PayoutSerializer(serializers.ModelSerializer):
    amount = serializers.FloatField(source="amount_major")

    class Meta:
        model = Payout
        fields = ["id", "amount", "currency", "status"]
