package com.acme.ledger.kafka;

import com.acme.ledger.PostingService;
import com.fasterxml.jackson.core.JsonProcessingException;
import com.fasterxml.jackson.databind.ObjectMapper;
import org.apache.kafka.clients.consumer.ConsumerRecord;
import org.springframework.kafka.annotation.KafkaListener;
import org.springframework.kafka.support.Acknowledgment;
import org.springframework.stereotype.Component;

/** Carrier costs per shipment, published by dispatch-go and the carrier gateway (topic shipment.costs). */
@Component
public class ShipmentCostListener {

    record ShipmentCost(String shipmentId, String carrier, long costMinor, String currency) {}

    private final ObjectMapper mapper = new ObjectMapper();
    private final PostingService postingService;

    public ShipmentCostListener(PostingService postingService) {
        this.postingService = postingService;
    }

    @KafkaListener(topics = "shipment.costs", groupId = "ledger-shipment-costs")
    public void onCost(ConsumerRecord<String, String> record, Acknowledgment ack) throws JsonProcessingException {
        ShipmentCost cost = mapper.readValue(record.value(), ShipmentCost.class);
        postingService.book("cost-" + cost.shipmentId(), record.value());
        ack.acknowledge();
    }
}
