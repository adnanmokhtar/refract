package dev.returnsdesk.payouts;

/**
 * Computes a merchant's payout for a settlement day: captures minus refunds minus the platform fee,
 * never below the rolling reserve. Every computed payout is written to the audit trail.
 */
public final class PayoutCalculator {
    private final long feeBps;
    private final long reserveCents;
    private final PayoutAuditTrail audit;

    public PayoutCalculator(long feeBps, long reserveCents, PayoutAuditTrail audit) {
        this.feeBps = feeBps;
        this.reserveCents = reserveCents;
        this.audit = audit;
    }

    public Payout compute(String merchantId, long capturedCents, long refundedCents) {
        long fee = (capturedCents * feeBps + 5_000) / 10_000;
        long net = capturedCents - refundedCents - fee;
        long payable = Math.max(0, net - reserveCents);
        Payout payout = new Payout(merchantId, payable, fee, net - payable);
        audit.record(payout);
        return payout;
    }

    public record Payout(String merchantId, long payableCents, long feeCents, long heldCents) {}
}
