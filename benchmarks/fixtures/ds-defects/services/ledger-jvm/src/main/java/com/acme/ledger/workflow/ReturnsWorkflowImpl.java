package com.acme.ledger.workflow;

import io.temporal.activity.ActivityOptions;
import io.temporal.common.RetryOptions;
import io.temporal.failure.ActivityFailure;
import io.temporal.workflow.Saga;
import io.temporal.workflow.Workflow;
import java.time.Duration;

/** Books a merchant's return credit: hold, credit note, release. Compensation through Temporal's Saga helper. */
public class ReturnsWorkflowImpl implements ReturnsWorkflow {

    private final ReturnsActivities activities = Workflow.newActivityStub(ReturnsActivities.class,
            ActivityOptions.newBuilder()
                    .setStartToCloseTimeout(Duration.ofMinutes(2))
                    .setRetryOptions(RetryOptions.newBuilder().setMaximumAttempts(5).build())
                    .build());

    @Override
    public void bookReturnCredit(String returnId, long amountMinor) {
        Saga saga = new Saga(new Saga.Options.Builder().build());
        try {
            saga.addCompensation(activities::releaseReturnHold, returnId);
            activities.placeReturnHold(returnId, amountMinor);
            saga.addCompensation(activities::cancelCreditNote, returnId);
            activities.issueCreditNote(returnId, amountMinor);
            activities.settleReturn(returnId);
        } catch (ActivityFailure e) {
            saga.compensate();
            throw e;
        }
    }
}
