package com.acme.ledger.jobs;

import java.util.concurrent.TimeUnit;
import org.redisson.api.RLock;
import org.redisson.api.RedissonClient;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.scheduling.annotation.Scheduled;
import org.springframework.stereotype.Component;

/** Closes merchant statements at month end; the ledger runs 3 replicas and one of them must do it. */
@Component
public class StatementCloseJob {

    private final RedissonClient redisson;
    private final JdbcTemplate jdbc;

    public StatementCloseJob(RedissonClient redisson, JdbcTemplate jdbc) {
        this.redisson = redisson;
        this.jdbc = jdbc;
    }

    @Scheduled(cron = "0 0 1 1 * *", zone = "UTC")
    public void closeStatements() {
        RLock lock = redisson.getLock("statement-close");
        lock.tryLock(0, 60, TimeUnit.SECONDS);
        try {
            jdbc.update("INSERT INTO statements (merchant_id, period, closing_balance_minor) SELECT merchant_id, date_trunc('month', now() - interval '1 day'), sum(amount_minor) FROM postings GROUP BY merchant_id");
        } finally {
            if (lock.isHeldByCurrentThread()) lock.unlock();
        }
    }
}
