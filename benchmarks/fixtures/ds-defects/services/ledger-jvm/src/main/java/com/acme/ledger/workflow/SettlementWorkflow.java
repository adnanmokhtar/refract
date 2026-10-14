package com.acme.ledger.workflow;

import io.temporal.workflow.WorkflowInterface;
import io.temporal.workflow.WorkflowMethod;

@WorkflowInterface
public interface SettlementWorkflow {
    @WorkflowMethod
    void settle(String merchantId, String period);
}
