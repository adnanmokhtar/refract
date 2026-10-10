package com.harbor.refunds;

import java.util.List;
import java.util.concurrent.ExecutorService;
import java.util.concurrent.Executors;

import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.stereotype.Service;

@Service
public class RefundService {
    private static final Logger log = LoggerFactory.getLogger(RefundService.class);

    private final ExecutorService notifier = Executors.newFixedThreadPool(4);
    private final PspGateway psp;
    private final RefundRepository refunds;
    private final CustomerNotifier customers;

    public RefundService(PspGateway psp, RefundRepository refunds, CustomerNotifier customers) {
        this.psp = psp;
        this.refunds = refunds;
        this.customers = customers;
    }

    public RefundResult refund(String orderId, long amountCents) {
        try {
            String pspRefundId = psp.refund(orderId, amountCents);
            refunds.save(orderId, amountCents, pspRefundId);
            notifier.submit(() -> customers.refundIssued(orderId, amountCents));
            return RefundResult.issued(pspRefundId);
        } catch (PspException e) {
            log.error("refund failed: " + e);
            return RefundResult.failed(orderId);
        }
    }

    public List<RefundRow> forOrder(String orderId) {
        return refunds.findByOrder(orderId);
    }
}
