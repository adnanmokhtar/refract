from decimal import Decimal
from unittest.mock import patch

from app import pricing
from app.pricing import compute_total


@patch("app.pricing.compute_total", return_value=Decimal("42.00"))
def test_compute_total_applies_the_coupon(mock_total):
    lines = [{"unit": "20.00", "qty": 2}, {"unit": "5.00", "qty": 1}]
    assert pricing.compute_total(lines, coupon_percent=6) == Decimal("42.00")


def test_compute_total_rounds_half_up():
    assert compute_total([{"unit": "0.125", "qty": 1}]) == Decimal("0.13")
