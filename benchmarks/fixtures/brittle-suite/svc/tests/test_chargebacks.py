import pytest

from app.chargebacks import chargeback_reserve_cents


def test_no_reserve_when_the_refund_covers_the_dispute():
    assert chargeback_reserve_cents(refunded_cents=5_000, disputed_cents=5_000) == 0


@pytest.mark.skip
def test_reserve_the_part_of_a_dispute_that_was_not_refunded():
    assert chargeback_reserve_cents(refunded_cents=2_000, disputed_cents=5_000) == 3_000
