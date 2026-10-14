package com.acme.ledger.saga;

import io.eventuate.tram.commands.consumer.CommandWithDestination;
import io.eventuate.tram.sagas.orchestration.SagaDefinition;
import io.eventuate.tram.sagas.simpledsl.SimpleSaga;

/**
 * Pays out a merchant remittance. releaseFunds is the pivot: the bank transfer cannot be undone, so it runs last,
 * after every compensatable step has succeeded; a failure before it compensates, a failure after it is retried
 * forward by the payments service.
 */
public class RemittanceSaga implements SimpleSaga<RemittanceSagaData> {

    private final SagaDefinition<RemittanceSagaData> sagaDefinition =
            step()
                .invokeParticipant(this::validateRemittance)
                .withCompensation(this::rejectRemittance)
            .step()
                .invokeParticipant(this::postRemittance)
                .withCompensation(this::reverseRemittance)
            .step()
                .invokeParticipant(this::releaseFunds)
            .build();

    @Override
    public SagaDefinition<RemittanceSagaData> getSagaDefinition() {
        return sagaDefinition;
    }

    private CommandWithDestination validateRemittance(RemittanceSagaData d) { return Commands.to("ledger", "ValidateRemittance", d.remittanceId()); }
    private CommandWithDestination rejectRemittance(RemittanceSagaData d) { return Commands.to("ledger", "RejectRemittance", d.remittanceId()); }
    private CommandWithDestination postRemittance(RemittanceSagaData d) { return Commands.to("ledger", "PostRemittance", d.remittanceId()); }
    private CommandWithDestination reverseRemittance(RemittanceSagaData d) { return Commands.to("ledger", "ReverseRemittance", d.remittanceId()); }
    private CommandWithDestination releaseFunds(RemittanceSagaData d) { return Commands.to("payments", "ReleaseFunds", d.remittanceId()); }
}
