package com.acme.ledger.saga;

import io.eventuate.tram.commands.consumer.CommandWithDestination;
import io.eventuate.tram.sagas.orchestration.SagaDefinition;
import io.eventuate.tram.sagas.simpledsl.SimpleSaga;

/**
 * Approves a carrier's invoice for payment: open a review, lock the invoice in the carrier portal (no more edits),
 * post it to the ledger, schedule the payment.
 */
public class CarrierInvoiceSaga implements SimpleSaga<CarrierInvoiceSagaData> {

    private final SagaDefinition<CarrierInvoiceSagaData> sagaDefinition =
            step()
                .invokeParticipant(this::openReview)
                .withCompensation(this::cancelReview)
            .step()
                .invokeParticipant(this::lockCarrierInvoice)
            .step()
                .invokeParticipant(this::postToLedger)
                .withCompensation(this::reversePosting)
            .step()
                .invokeParticipant(this::schedulePayment)
                .withCompensation(this::cancelScheduledPayment)
            .build();

    @Override
    public SagaDefinition<CarrierInvoiceSagaData> getSagaDefinition() {
        return sagaDefinition;
    }

    private CommandWithDestination openReview(CarrierInvoiceSagaData d) { return Commands.to("ledger-review", "OpenReview", d.invoiceId()); }
    private CommandWithDestination cancelReview(CarrierInvoiceSagaData d) { return Commands.to("ledger-review", "CancelReview", d.invoiceId()); }
    private CommandWithDestination lockCarrierInvoice(CarrierInvoiceSagaData d) { return Commands.to("carrier-portal", "LockInvoice", d.invoiceId()); }
    private CommandWithDestination postToLedger(CarrierInvoiceSagaData d) { return Commands.to("ledger", "PostCarrierInvoice", d.invoiceId()); }
    private CommandWithDestination reversePosting(CarrierInvoiceSagaData d) { return Commands.to("ledger", "ReversePosting", d.invoiceId()); }
    private CommandWithDestination schedulePayment(CarrierInvoiceSagaData d) { return Commands.to("payments", "SchedulePayment", d.invoiceId()); }
    private CommandWithDestination cancelScheduledPayment(CarrierInvoiceSagaData d) { return Commands.to("payments", "CancelScheduledPayment", d.invoiceId()); }
}
