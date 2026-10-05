import os

from app.limits import needs_supervisor


def test_a_refund_over_the_limit_needs_a_supervisor():
    os.environ["REFUND_LIMIT_CENTS"] = "10000"
    assert needs_supervisor(10_001) is True


def test_a_small_refund_needs_no_supervisor():
    assert needs_supervisor(9_000) is False
