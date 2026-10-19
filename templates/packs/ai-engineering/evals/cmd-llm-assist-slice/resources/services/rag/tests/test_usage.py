from unittest.mock import MagicMock, patch

from app.billing.usage import bill_usage


def test_bill_usage_prices_known_model():
    conn = MagicMock()
    with patch("app.billing.usage.get_conn") as get_conn:
        get_conn.return_value.__enter__.return_value = conn
        bill_usage("ws_demo", "claude-sonnet-5-5", 1_000_000, 0)
    args = conn.execute.call_args.args[1]
    assert args[-1] == 3.6
