package com.acme.ledger.workflow;

import io.temporal.activity.ActivityOptions;
import io.temporal.common.RetryOptions;
import io.temporal.workflow.Workflow;
import java.time.Duration;

/**
 * Monthly merchant settlement. Executions stay open for the 3-day dispute window between the freeze and the
 * transfer, so every deploy meets open executions.
 */
public class SettlementWorkflowImpl implements SettlementWorkflow {

    private final SettlementActivities activities = Workflow.newActivityStub(SettlementActivities.class,
            ActivityOptions.newBuilder()
                    .setStartToCloseTimeout(Duration.ofMinutes(5))
                    .setRetryOptions(RetryOptions.newBuilder().setMaximumAttempts(5).build())
                    .build());

    @Override
    public void settle(String merchantId, String period) {
        long balance = activities.computeBalance(merchantId, period);
        activities.freezeStatement(merchantId, period);
        Workflow.sleep(Duration.ofDays(3));
        long finalBalance = activities.computeBalance(merchantId, period);
        activities.initiateTransfer(merchantId, finalBalance);
    }
}
