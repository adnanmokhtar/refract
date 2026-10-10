package com.harbor.refunds;

import io.micrometer.core.instrument.Counter;
import io.micrometer.core.instrument.MeterRegistry;
import io.micrometer.core.instrument.Tag;
import io.micrometer.core.instrument.Tags;
import jakarta.servlet.http.HttpServletRequest;
import org.springframework.stereotype.Component;

@Component
public class RefundMetrics {
    private final MeterRegistry registry;

    public RefundMetrics(MeterRegistry registry) {
        this.registry = registry;
    }

    public void refundProcessed(HttpServletRequest request, String outcome) {
        Counter.builder("refunds.processed")
            .tags(Tags.of(Tag.of("uri", request.getRequestURI()), Tag.of("outcome", outcome)))
            .register(registry)
            .increment();
    }
}
