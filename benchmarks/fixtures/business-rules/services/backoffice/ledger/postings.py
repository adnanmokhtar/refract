"""The settlement ledger's posting function: every entry's lines sum to zero per currency."""
import uuid
from collections import defaultdict

from django.db import transaction

from ledger.models import LedgerAccount, LedgerEntry, LedgerLine


class LedgerPostingError(Exception):
    pass


def assert_balanced(legs):
    sums = defaultdict(int)
    for account_code, currency, amount_minor in legs:
        sums[currency] += amount_minor
    if any(sums.values()):
        raise LedgerPostingError(f"unbalanced entry: {dict(sums)}")


def post_entry(source_type: str, source_id: str, legs, idempotency_key: str):
    assert_balanced(legs)
    with transaction.atomic():
        entry, created = LedgerEntry.objects.get_or_create(
            idempotency_key=idempotency_key, defaults={"source_type": source_type, "source_id": source_id}
        )
        if not created:
            return entry
        for account_code, currency, amount_minor in legs:
            account = LedgerAccount.objects.get(code=account_code)
            LedgerLine.objects.create(entry=entry, account=account, currency=currency, amount_minor=amount_minor)
        return entry


def post_payout(payout):
    idempotency_key = f"payout-{payout.id}-{uuid.uuid4()}"
    return post_entry(
        "payout",
        str(payout.id),
        [("merchant_payable", payout.currency, payout.amount_minor), ("bank", payout.currency, -payout.amount_minor)],
        idempotency_key,
    )


def post_capture(payment):
    amount_minor = payment.amount_authorized
    return post_entry(
        "capture",
        payment.id,
        [("psp_receivable", payment.currency, amount_minor), ("merchant_payable", payment.currency, -amount_minor)],
        f"capture-{payment.id}",
    )
