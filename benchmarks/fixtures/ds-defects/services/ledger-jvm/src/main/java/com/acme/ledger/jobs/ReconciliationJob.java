package com.acme.ledger.jobs;

import java.time.Duration;
import net.javacrumbs.shedlock.spring.annotation.SchedulerLock;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.scheduling.annotation.Scheduled;
import org.springframework.stereotype.Component;

/**
 * Matches carrier invoices against postings and writes adjustment postings for the differences. Every 10
 * minutes, one replica at a time (ShedLock on the ledger database).
 */
@Component
public class ReconciliationJob {

    private final JdbcTemplate jdbc;
    private final Duration timeout;

    public ReconciliationJob(JdbcTemplate jdbc, @Value("${ledger.reconcile.timeout}") Duration timeout) {
        this.jdbc = jdbc;
        this.timeout = timeout;
    }

    @Scheduled(cron = "0 */10 * * * *", zone = "UTC")
    @SchedulerLock(name = "reconcile", lockAtMostFor = "PT1M", lockAtLeastFor = "PT30S")
    public void reconcile() {
        jdbc.setQueryTimeout((int) timeout.toSeconds());
        jdbc.update("INSERT INTO postings (reference, payload) SELECT 'adj-' || ci.id, jsonb_build_object('amountMinor', ci.amount_minor - p.amount_minor) FROM carrier_invoices ci JOIN postings p ON p.reference = 'cost-' || ci.shipment_id WHERE ci.amount_minor <> p.amount_minor AND NOT ci.reconciled");
        jdbc.update("UPDATE carrier_invoices SET reconciled = true WHERE NOT reconciled");
    }
}
