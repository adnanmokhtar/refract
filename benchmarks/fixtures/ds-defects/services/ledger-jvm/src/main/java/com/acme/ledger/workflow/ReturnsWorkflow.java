package com.acme.ledger.workflow;

import io.temporal.workflow.WorkflowInterface;
import io.temporal.workflow.WorkflowMethod;

@WorkflowInterface
public interface ReturnsWorkflow {
    @WorkflowMethod
    void bookReturnCredit(String returnId, long amountMinor);
}
