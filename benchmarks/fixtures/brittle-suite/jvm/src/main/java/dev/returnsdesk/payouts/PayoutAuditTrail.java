package dev.returnsdesk.payouts;

import java.util.ArrayList;
import java.util.Collections;
import java.util.List;

/** Append-only record of every payout the calculator produced; finance reconciles against it. */
public class PayoutAuditTrail {
    private final List<String> lines = new ArrayList<>();

    public void record(PayoutCalculator.Payout payout) {
        lines.add(payout.merchantId() + ";" + payout.payableCents() + ";" + payout.feeCents() + ";" + payout.heldCents());
    }

    public List<String> lines() {
        return Collections.unmodifiableList(lines);
    }
}
