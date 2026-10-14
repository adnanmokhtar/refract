package com.acme.ledger.kafka;

import com.acme.ledger.PostingService;
import org.apache.kafka.clients.consumer.ConsumerRecord;
import org.springframework.kafka.annotation.KafkaListener;
import org.springframework.kafka.support.Acknowledgment;
import org.springframework.stereotype.Component;

/** Books every posting published on ledger.postings (COD credits, carrier costs, fees) into the ledger. */
@Component
public class PostingListener {

    private final PostingService postingService;

    public PostingListener(PostingService postingService) {
        this.postingService = postingService;
    }

    @KafkaListener(topics = "ledger.postings", groupId = "ledger-postings")
    public void onPosting(ConsumerRecord<String, String> record, Acknowledgment ack) {
        ack.acknowledge();
        postingService.book(record.key(), record.value());
    }
}
