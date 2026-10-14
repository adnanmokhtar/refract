package com.acme.ledger;

import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

@Service
public class PostingService {

    private final JdbcTemplate jdbc;

    public PostingService(JdbcTemplate jdbc) {
        this.jdbc = jdbc;
    }

    @Transactional
    public void book(String reference, String payloadJson) {
        jdbc.update("INSERT INTO postings (reference, payload) VALUES (?, ?::jsonb) ON CONFLICT (reference) DO NOTHING", reference, payloadJson);
    }
}
