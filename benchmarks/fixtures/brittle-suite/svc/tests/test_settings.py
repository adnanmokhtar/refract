from app.limits import needs_supervisor, refund_limit_cents


def test_ops_can_raise_the_limit_live(monkeypatch):
    monkeypatch.setenv("REFUND_LIMIT_CENTS", "250000")
    assert refund_limit_cents() == 250_000
    assert needs_supervisor(200_000) is False
