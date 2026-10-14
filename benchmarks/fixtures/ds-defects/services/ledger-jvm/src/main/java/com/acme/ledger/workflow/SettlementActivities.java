package com.acme.ledger.workflow;

import io.temporal.activity.ActivityInterface;

@ActivityInterface
public interface SettlementActivities {
    long computeBalance(String merchantId, String period);

    void freezeStatement(String merchantId, String period);

    void notifyMerchant(String merchantId, String period, long balanceMinor);

    void initiateTransfer(String merchantId, long amountMinor);
}
