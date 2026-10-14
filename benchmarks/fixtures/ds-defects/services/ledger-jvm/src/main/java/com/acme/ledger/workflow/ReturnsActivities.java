package com.acme.ledger.workflow;

import io.temporal.activity.ActivityInterface;

@ActivityInterface
public interface ReturnsActivities {
    void placeReturnHold(String returnId, long amountMinor);

    void releaseReturnHold(String returnId);

    void issueCreditNote(String returnId, long amountMinor);

    void cancelCreditNote(String returnId);

    void settleReturn(String returnId);
}
