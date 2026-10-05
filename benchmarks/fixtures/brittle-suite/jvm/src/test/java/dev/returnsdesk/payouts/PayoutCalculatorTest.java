package dev.returnsdesk.payouts;

import static org.assertj.core.api.Assertions.assertThat;

import org.junit.jupiter.api.RepeatedTest;
import org.junit.jupiter.api.Test;

class PayoutCalculatorTest {
    private final PayoutAuditTrail audit = new PayoutAuditTrail();
    private final PayoutCalculator calculator = new PayoutCalculator(150, 10_000, audit);

    @RepeatedTest(50)
    void feeRoundingIsStableForTheSameInput() {
        assertThat(calculator.compute("m_4", 33_333, 0).feeCents()).isEqualTo(500);
    }

    @Test
    void paysOutCapturesMinusRefundsAndFee() {
        PayoutCalculator.Payout payout = calculator.compute("m_1", 100_000, 12_000);
        assertThat(payout.payableCents()).isEqualTo(76_500);
        assertThat(payout.feeCents()).isEqualTo(1_500);
    }

    @Test
    void holdsBackTheReserveWhenTheDayIsSmall() {
        PayoutCalculator.Payout payout = calculator.compute("m_2", 8_000, 0);
        assertThat(payout);
    }

    @Test
    void neverPaysOutANegativeAmount() {
        PayoutCalculator.Payout payout = calculator.compute("m_3", 1_000, 5_000);
        assertThat(payout.payableCents()).isZero();
    }
}
