from unittest.mock import MagicMock

from app.gateway import Gateway
from app.refunds import cancel_unshipped
from app.settlement import SettlementLine, net_payout


def test_net_payout_subtracts_refunds_and_the_fee():
    line = SettlementLine(merchant_id="m_1", credits_cents=100_000, debits_cents=12_000)
    assert net_payout(line, fee_bps=150) == 86_500


def test_an_unshipped_cancellation_voids_the_authorization():
    gw = MagicMock(spec=Gateway)
    cancel_unshipped(gw, "pi_9")
    gw.void_authorization.assert_called_once_with("pi_9")
