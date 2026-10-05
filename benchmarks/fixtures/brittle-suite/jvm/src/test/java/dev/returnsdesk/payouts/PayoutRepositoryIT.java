package dev.returnsdesk.payouts;

import static org.assertj.core.api.Assertions.assertThat;

import java.sql.Connection;
import java.sql.DriverManager;
import java.time.LocalDate;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;

/** Runs against the CI Postgres service (PAYOUTS_JDBC_URL); the idempotent insert is the whole point. */
class PayoutRepositoryIT {
    private PayoutRepository repository;

    @BeforeEach
    void connect() throws Exception {
        Connection connection = DriverManager.getConnection(System.getenv("PAYOUTS_JDBC_URL"));
        connection.createStatement().execute("truncate payout");
        repository = new PayoutRepository(connection);
    }

    @Test
    void aSecondRunOfTheSameSettlementDayInsertsNothing() throws Exception {
        PayoutCalculator.Payout payout = new PayoutCalculator.Payout("m_1", 76_500, 1_500, 10_000);
        LocalDate day = LocalDate.of(2026, 10, 5);

        assertThat(repository.insertOnce(payout, day)).isTrue();
        assertThat(repository.insertOnce(payout, day)).isFalse();
    }
}
