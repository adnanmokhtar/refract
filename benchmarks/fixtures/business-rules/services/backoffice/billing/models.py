from django.db import models
from django_fsm import FSMField, transition


class SubscriptionStatus(models.TextChoices):
    TRIALING = "trialing", "Trialing"
    ACTIVE = "active", "Active"
    PAST_DUE = "past_due", "Past due"
    PAUSED = "paused", "Paused"


class EnterpriseSubscription(models.Model):
    """Invoiced enterprise plans (billed by the back office, not by Stripe)."""

    merchant_id = models.IntegerField()
    price = models.DecimalField(max_digits=12, decimal_places=2)
    status = FSMField(max_length=16, choices=SubscriptionStatus.choices, default=SubscriptionStatus.TRIALING)
    current_period_start = models.DateTimeField()
    current_period_end = models.DateTimeField()

    @transition(field=status, source=SubscriptionStatus.TRIALING, target=SubscriptionStatus.ACTIVE)
    def activate(self):
        pass

    @transition(field=status, source=SubscriptionStatus.ACTIVE, target=SubscriptionStatus.PAST_DUE)
    def mark_past_due(self):
        pass

    @transition(field=status, source=SubscriptionStatus.PAST_DUE, target=SubscriptionStatus.ACTIVE)
    def recover(self):
        pass

    @transition(field=status, source=[SubscriptionStatus.ACTIVE, SubscriptionStatus.PAST_DUE], target=SubscriptionStatus.PAUSED)
    def cancel(self):
        """Cancelling pauses the subscription so the merchant can come back."""

    @transition(field=status, source=SubscriptionStatus.PAUSED, target=SubscriptionStatus.ACTIVE)
    def resume(self):
        pass


class UsageEvent(models.Model):
    merchant_id = models.IntegerField()
    units = models.IntegerField()
    occurred_at = models.DateTimeField()
    received_at = models.DateTimeField(auto_now_add=True)
