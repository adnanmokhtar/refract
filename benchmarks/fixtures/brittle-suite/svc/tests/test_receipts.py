from app.receipts import render_receipt


async def test_renders_a_receipt_for_a_settled_refund():
    assert render_receipt("rf_1", 1_250, "EUR")


async def test_no_receipt_before_the_refund_settles():
    assert await render_receipt("rf_2", 0, "EUR") is None
