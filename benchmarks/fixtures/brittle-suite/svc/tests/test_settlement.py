from app.limits import needs_supervisor
from app.settlement import SettlementLine, net_payout


class TestNetPayout:
    def __init__(self):
        self.line = SettlementLine(merchant_id="m_2", credits_cents=50_000, debits_cents=50_000)

    def test_a_fully_refunded_month_pays_out_minus_the_fee(self):
        assert net_payout(self.line, fee_bps=100) == -500

    def test_no_fee_without_credits(self):
        empty = SettlementLine(merchant_id="m_3", credits_cents=0, debits_cents=0)
        assert net_payout(empty, fee_bps=100) == 0


def test_a_large_settlement_correction_needs_a_supervisor():
    assert needs_supervisor(12_000) is True
