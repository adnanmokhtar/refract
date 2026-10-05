import os

import pytest

os.environ.setdefault("RETURNSDESK_TESTING", "1")


@pytest.fixture
def delivered_refund():
    return {"customer_id": "cus_1", "amount_cents": 4_800, "refunds_last_90_days": 0, "account_age_days": 400, "item_opened": False}
