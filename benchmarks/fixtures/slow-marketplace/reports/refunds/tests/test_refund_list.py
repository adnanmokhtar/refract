import uuid

import pytest
from django.db import connection

from refunds.models import Refund


@pytest.fixture
def store_with_refunds(db):
    store_id, order_id = uuid.uuid4(), uuid.uuid4()
    with connection.cursor() as cur:
        cur.execute("insert into store (id, slug, name) values (%s, %s, 'Test store')", [store_id, f"s-{store_id.hex[:8]}"])
        cur.execute(
            """insert into "order" (id, number, store_id, total_cents, currency, created_at)
               values (%s, 'T-1', %s, 5000, 'EUR', now())""",
            [order_id, store_id],
        )
    for n in range(3):
        Refund.objects.create(order_id=order_id, psp_refund_number=1000 + n, reason="goodwill", currency="EUR", amount=5.0)
    return store_id


def test_finance_list_includes_store_names(finance_client, store_with_refunds):
    response = finance_client.get("/refunds/", HTTP_X_STAFF_USER="fin", HTTP_X_STAFF_GROUPS="finance")
    assert response.status_code == 200
    assert {r["store_name"] for r in response.json()} == {"Test store"}
