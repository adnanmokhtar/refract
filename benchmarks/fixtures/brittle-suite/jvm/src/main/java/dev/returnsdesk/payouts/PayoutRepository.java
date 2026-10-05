package dev.returnsdesk.payouts;

import java.sql.Connection;
import java.sql.PreparedStatement;
import java.sql.SQLException;

/** Writes payouts; the unique (merchant_id, settlement_day) key makes a re-run idempotent. */
public final class PayoutRepository {
    private final Connection connection;

    public PayoutRepository(Connection connection) {
        this.connection = connection;
    }

    public boolean insertOnce(PayoutCalculator.Payout payout, java.time.LocalDate day) throws SQLException {
        try (PreparedStatement st = connection.prepareStatement(
                "insert into payout (merchant_id, settlement_day, payable_cents, fee_cents) values (?, ?, ?, ?) "
                        + "on conflict (merchant_id, settlement_day) do nothing")) {
            st.setString(1, payout.merchantId());
            st.setObject(2, day);
            st.setLong(3, payout.payableCents());
            st.setLong(4, payout.feeCents());
            return st.executeUpdate() == 1;
        }
    }
}
