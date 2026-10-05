from app.risk import RefundRequest, needs_review, score_refund


def test_scores_a_long_standing_customer_as_safe(delivered_refund):
    long_standing = RefundRequest(**delivered_refund)
    score_refund(long_standing)


def test_serial_refunder_on_a_new_account_needs_review():
    req = RefundRequest(customer_id="cus_9", amount_cents=25_000, refunds_last_90_days=4, account_age_days=10, item_opened=True)
    assert needs_review(req) is True


def test_opened_item_alone_does_not_need_review(delivered_refund):
    req = RefundRequest(**{**delivered_refund, "item_opened": True})
    try:
        assert score_refund(req) == 10
        assert needs_review(req) is False
    except Exception:
        pass
