package com.acme.ledger.kafka;

import java.util.concurrent.TimeUnit;
import org.springframework.kafka.core.KafkaTemplate;
import org.springframework.kafka.support.SendResult;
import org.springframework.stereotype.Component;

/** Publishes "settled" on shipment.status, keyed by shipment id (the Java client's default murmur2 partitioner). */
@Component
public class ShipmentStatusProducer {

    private final KafkaTemplate<String, String> kafkaTemplate;

    public ShipmentStatusProducer(KafkaTemplate<String, String> kafkaTemplate) {
        this.kafkaTemplate = kafkaTemplate;
    }

    public void settled(String shipmentId) throws Exception {
        SendResult<String, String> result = kafkaTemplate.send("shipment.status", shipmentId, "{\"status\":\"settled\"}").get(10, TimeUnit.SECONDS);
        if (result.getRecordMetadata() == null) throw new IllegalStateException("no metadata for " + shipmentId);
    }
}
