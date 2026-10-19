"""Ops repair: a payout the bank rejected out-of-band is marked failed, with an audit row."""
from django.core.management.base import BaseCommand

from payouts.audit import PayoutAudit
from payouts.models import Payout, PayoutStatus


class Command(BaseCommand):
    def add_arguments(self, parser):
        parser.add_argument("payout_id", type=int)
        parser.add_argument("--operator", required=True)

    def handle(self, payout_id, operator, **options):
        payout = Payout.objects.get(pk=payout_id)
        if payout.status != PayoutStatus.PROCESSING:
            raise SystemExit("only a processing payout can be failed")
        payout.status = PayoutStatus.FAILED
        payout.save(update_fields=["status"])
        PayoutAudit.objects.create(payout=payout, operator=operator, change="processing->failed")
